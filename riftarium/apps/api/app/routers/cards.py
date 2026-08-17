from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import String, cast, func, select
from sqlalchemy.orm import Session

from ..db import get_db
from ..models import Card, CardSet

router = APIRouter(prefix="/api", tags=["cards"])


def find_card(db: Session, ident: str) -> Card | None:
    """Résout une carte par id Riftcodex, sinon par riftbound_id (version de base d'abord)."""
    card = db.get(Card, ident)
    if card is None:
        card = db.scalar(
            select(Card).where(func.lower(Card.riftbound_id) == ident.lower()).order_by(Card.alternate_art, Card.id)
        )
    return card


def card_out(card: Card) -> dict:
    return {
        "id": card.id,
        "riftbound_id": card.riftbound_id,
        "name": card.name,
        "collector_number": card.collector_number,
        "set_id": card.set_id,
        "type": card.type,
        "supertype": card.supertype,
        "rarity": card.rarity,
        "domains": card.domains,
        "energy": card.energy,
        "might": card.might,
        "power": card.power,
        "text": card.text_plain,
        "flavour": card.text_flavour,
        "image_url": card.image_url,
        "artist": card.artist,
        "orientation": card.orientation,
        "alternate_art": card.alternate_art,
    }


@router.get("/cards")
def list_cards(
    q: str | None = None,
    set_id: str | None = None,
    type: str | None = None,
    domain: str | None = None,
    rarity: str | None = None,
    sort: str | None = None,
    page: int = Query(1, ge=1),
    size: int = Query(30, ge=1, le=100),
    db: Session = Depends(get_db),
):
    query = select(Card)
    if q:
        like = f"%{q.lower()}%"
        query = query.where(
            func.lower(Card.name).like(like)
            | func.lower(func.coalesce(Card.text_plain, "")).like(like)
            | func.lower(Card.riftbound_id).like(like)
        )
    if set_id:
        query = query.where(Card.set_id == set_id.upper())
    if type:
        query = query.where(Card.type == type)
    if rarity:
        query = query.where(Card.rarity == rarity)
    if domain:
        # domains est un JSON array ; filtre portable SQLite/PostgreSQL
        query = query.where(cast(Card.domains, String).like(f'%"{domain}"%'))

    total = db.scalar(select(func.count()).select_from(query.subquery())) or 0
    # sort=random : tirage à chaque appel, la pagination n'a alors plus de sens
    order = [func.random()] if sort == "random" else [Card.set_id, Card.collector_number]
    rows = db.scalars(query.order_by(*order).offset((page - 1) * size).limit(size)).all()
    return {"total": total, "page": page, "size": size, "items": [card_out(c) for c in rows]}


@router.get("/cards/{card_id}")
def get_card(card_id: str, db: Session = Depends(get_db)):
    card = find_card(db, card_id)
    if card is None:
        raise HTTPException(status_code=404, detail="Carte introuvable")
    return card_out(card)


@router.get("/sets")
def list_sets(db: Session = Depends(get_db)):
    rows = db.scalars(select(CardSet).order_by(CardSet.published_on)).all()
    return [
        {"set_id": s.set_id, "name": s.name, "card_count": s.card_count, "published_on": s.published_on} for s in rows
    ]
