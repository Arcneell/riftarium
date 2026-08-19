from collections import defaultdict

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from ..auth import current_user
from ..db import get_db
from ..models import Card, CollectionItem, User
from ..schemas import CollectionBulk, CollectionEntryIn, CollectionEntryPatch, CollectionPut
from .cards import apply_filters, card_out, find_card

router = APIRouter(prefix="/api/collection", tags=["collection"])

MAX_QTY = 999
ENTRY_ORDER = (CollectionItem.condition, CollectionItem.lang)


def entry_out(entry: CollectionItem) -> dict:
    return {"id": entry.id, "qty": entry.qty, "condition": entry.condition, "lang": entry.lang}


def card_state(db: Session, user: User, card: Card) -> dict:
    """Tous les lots d'une carte : la réponse standard des mutations."""
    entries = db.scalars(
        select(CollectionItem)
        .where(CollectionItem.user_id == user.id, CollectionItem.card_id == card.id)
        .order_by(*ENTRY_ORDER)
    ).all()
    return {
        "card_id": card.id,
        "total_qty": sum(entry.qty for entry in entries),
        "entries": [entry_out(entry) for entry in entries],
    }


def find_entry(db: Session, user: User, card_id: str, condition: str, lang: str) -> CollectionItem | None:
    return db.scalar(
        select(CollectionItem).where(
            CollectionItem.user_id == user.id,
            CollectionItem.card_id == card_id,
            CollectionItem.condition == condition,
            CollectionItem.lang == lang,
        )
    )


@router.get("")
def my_collection(
    q: str | None = None,
    set_id: str | None = None,
    type_: str | None = Query(None, alias="type"),  # « type » masquerait le builtin Python
    domain: str | None = None,
    rarity: str | None = None,
    energy: str | None = None,
    page: int = Query(1, ge=1),
    size: int = Query(30, ge=1, le=100),
    user: User = Depends(current_user),
    db: Session = Depends(get_db),
):
    # DISTINCT sur l'id seul : Postgres ne sait pas comparer les colonnes JSON de cards.
    id_query = apply_filters(
        select(CollectionItem.card_id)
        .join(Card, CollectionItem.card_id == Card.id)
        .where(CollectionItem.user_id == user.id)
        .distinct(),
        q=q,
        set_id=set_id,
        type_=type_,
        domain=domain,
        rarity=rarity,
        energy=energy,
    )
    total = db.scalar(select(func.count()).select_from(id_query.subquery())) or 0
    cards = db.scalars(
        select(Card)
        .where(Card.id.in_(id_query))
        .order_by(Card.set_id, Card.collector_number, Card.id)
        .offset((page - 1) * size)
        .limit(size)
    ).all()

    entries_by_card: dict[str, list[CollectionItem]] = defaultdict(list)
    if cards:
        rows = db.scalars(
            select(CollectionItem)
            .where(CollectionItem.user_id == user.id, CollectionItem.card_id.in_([card.id for card in cards]))
            .order_by(*ENTRY_ORDER)
        ).all()
        for entry in rows:
            entries_by_card[entry.card_id].append(entry)

    # Stats globales (toute la collection), indépendantes des filtres.
    unique_cards, total_cards = db.execute(
        select(func.count(func.distinct(CollectionItem.card_id)), func.coalesce(func.sum(CollectionItem.qty), 0)).where(
            CollectionItem.user_id == user.id
        )
    ).one()

    return {
        "total_cards": total_cards,
        "unique_cards": unique_cards,
        "total": total,
        "page": page,
        "size": size,
        "items": [
            {
                "card": card_out(card),
                "total_qty": sum(entry.qty for entry in entries_by_card[card.id]),
                "entries": [entry_out(entry) for entry in entries_by_card[card.id]],
            }
            for card in cards
        ],
    }


@router.post("/bulk")
def bulk_update(
    payload: CollectionBulk,
    user: User = Depends(current_user),
    db: Session = Depends(get_db),
):
    """Opérations de masse. qty/qty_delta s'appliquent à chaque lot des cartes visées."""
    items = db.scalars(
        select(CollectionItem).where(CollectionItem.user_id == user.id, CollectionItem.card_id.in_(payload.card_ids))
    ).all()

    updated = 0
    removed = 0
    by_card: dict[str, list[CollectionItem]] = defaultdict(list)
    for item in items:
        by_card[item.card_id].append(item)

    for entries in by_card.values():
        if payload.remove:
            for entry in entries:
                db.delete(entry)
                removed += 1
            continue
        survivors: dict[tuple[str, str], CollectionItem] = {}
        for entry in entries:
            if payload.qty is not None:
                entry.qty = payload.qty
            if payload.qty_delta:
                entry.qty = entry.qty + payload.qty_delta
            entry.qty = max(0, min(MAX_QTY, entry.qty))
            if payload.condition:
                entry.condition = payload.condition
            if payload.lang:
                entry.lang = payload.lang
            if entry.qty == 0:
                db.delete(entry)
                removed += 1
                continue
            key = (entry.condition, entry.lang)
            twin = survivors.get(key)
            if twin is None:
                survivors[key] = entry
                updated += 1
            else:  # reclassement qui retombe sur un lot existant : fusion des quantités
                twin.qty = min(MAX_QTY, twin.qty + entry.qty)
                db.delete(entry)
    db.commit()
    return {"updated": updated, "removed": removed}


@router.post("/{card_id}/entries")
def add_entry(
    card_id: str,
    payload: CollectionEntryIn,
    user: User = Depends(current_user),
    db: Session = Depends(get_db),
):
    card = find_card(db, card_id)
    if card is None:
        raise HTTPException(status_code=404, detail="Carte introuvable")

    entry = find_entry(db, user, card.id, payload.condition, payload.lang)
    if entry is None:
        db.add(
            CollectionItem(
                user_id=user.id, card_id=card.id, qty=payload.qty, condition=payload.condition, lang=payload.lang
            )
        )
    else:  # même état et même langue : on additionne
        entry.qty = min(MAX_QTY, entry.qty + payload.qty)
    db.commit()
    return card_state(db, user, card)


@router.patch("/entries/{entry_id}")
def update_entry(
    entry_id: int,
    payload: CollectionEntryPatch,
    user: User = Depends(current_user),
    db: Session = Depends(get_db),
):
    entry = db.get(CollectionItem, entry_id)
    if entry is None or entry.user_id != user.id:
        raise HTTPException(status_code=404, detail="Lot introuvable")
    card = db.get(Card, entry.card_id)

    qty = entry.qty if payload.qty is None else payload.qty
    condition = payload.condition or entry.condition
    lang = payload.lang or entry.lang

    if qty == 0:
        db.delete(entry)
    else:
        twin = db.scalar(
            select(CollectionItem).where(
                CollectionItem.user_id == user.id,
                CollectionItem.card_id == entry.card_id,
                CollectionItem.condition == condition,
                CollectionItem.lang == lang,
                CollectionItem.id != entry.id,
            )
        )
        if twin is not None:  # le nouvel état/langue existe déjà : fusion des lots
            twin.qty = min(MAX_QTY, twin.qty + qty)
            db.delete(entry)
        else:
            entry.qty = qty
            entry.condition = condition
            entry.lang = lang
    db.commit()
    return card_state(db, user, card)


@router.get("/{card_id}")
def get_item(
    card_id: str,
    user: User = Depends(current_user),
    db: Session = Depends(get_db),
):
    card = find_card(db, card_id)
    if card is None:
        raise HTTPException(status_code=404, detail="Carte introuvable")
    return card_state(db, user, card)


@router.put("/{card_id}")
def set_quantity(
    card_id: str,
    payload: CollectionPut,
    user: User = Depends(current_user),
    db: Session = Depends(get_db),
):
    """Fixe la quantité du lot (état, langue) donné — 0 le supprime."""
    card = find_card(db, card_id)
    if card is None:
        raise HTTPException(status_code=404, detail="Carte introuvable")

    entry = find_entry(db, user, card.id, payload.condition, payload.lang)
    if payload.qty == 0:
        if entry:
            db.delete(entry)
            db.commit()
        return {"card_id": card.id, "qty": 0, "condition": payload.condition, "lang": payload.lang}

    if entry is None:
        entry = CollectionItem(user_id=user.id, card_id=card.id, condition=payload.condition, lang=payload.lang)
        db.add(entry)
    entry.qty = payload.qty
    db.commit()
    return {
        "card_id": card.id,
        "qty": entry.qty,
        "condition": entry.condition,
        "lang": entry.lang,
    }
