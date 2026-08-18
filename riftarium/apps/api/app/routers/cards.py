import re

from fastapi import APIRouter, Depends, HTTPException, Query, Response
from sqlalchemy import String, case, cast, func, or_, select
from sqlalchemy.orm import Session

from ..auth import optional_user
from ..cache import cache_get, cache_set
from ..config import settings
from ..db import get_db
from ..models import Card, CardSet, CollectionItem, User

router = APIRouter(prefix="/api", tags=["cards"])


def _cacheable_headers(response: Response) -> None:
    """Les réponses anonymes sont stables (les cartes changent à la sync) : le navigateur peut les garder."""
    response.headers["Cache-Control"] = "public, max-age=300"
    response.headers["Vary"] = "Authorization"


# ogn-037a-298 / ogn-037*-298 → famille ogn-037-298. Les ids promo/rune (ven-sp4-006, ven-r04) restent uniques.
_VARIANT_ID_RE = re.compile(r"^([a-z0-9]+)-(\d+)([a-z*]?)-(\d+)$", re.IGNORECASE)

RARITY_RANK = case(
    (Card.rarity == "Common", 0),
    (Card.rarity == "Uncommon", 1),
    (Card.rarity == "Rare", 2),
    (Card.rarity == "Epic", 3),
    (Card.rarity == "Showcase", 4),
    (Card.rarity == "Promo", 5),
    else_=6,
)


def csv_parts(value: str | None) -> list[str]:
    if not value:
        return []
    return [part.strip() for part in value.split(",") if part.strip()]


def find_card(db: Session, ident: str) -> Card | None:
    """Résout une carte par id Riftcodex, sinon par riftbound_id (version de base d'abord)."""
    card = db.get(Card, ident)
    if card is None:
        card = db.scalar(
            select(Card).where(func.lower(Card.riftbound_id) == ident.lower()).order_by(Card.alternate_art, Card.id)
        )
    return card


def is_foil(card: Card) -> bool:
    return bool(card.alternate_art or card.signature or card.overnumbered or card.rarity == "Showcase")


def card_out(card: Card, owned_qty: int | None = None) -> dict:
    payload = {
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
        "tags": card.tags or [],
        "alternate_art": card.alternate_art,
        "signature": card.signature,
        "overnumbered": card.overnumbered,
        "foil": is_foil(card),
    }
    if owned_qty is not None:
        payload["owned_qty"] = owned_qty
    return payload


def owned_quantities(db: Session, user: User | None, card_ids: list[str]) -> dict[str, int]:
    if user is None or not card_ids:
        return {}
    rows = db.execute(
        select(CollectionItem.card_id, CollectionItem.qty).where(
            CollectionItem.user_id == user.id, CollectionItem.card_id.in_(card_ids)
        )
    ).all()
    return {card_id: qty for card_id, qty in rows}


def variant_family(riftbound_id: str | None) -> str:
    ident = (riftbound_id or "").strip().lower()
    match = _VARIANT_ID_RE.match(ident)
    if not match:
        return ident
    set_id, number, _marker, suffix = match.groups()
    return f"{set_id}-{number}-{suffix}"


def variant_id_clause(family: str):
    """Correspond à l'id de base et aux variantes à une lettre (a, *)."""
    lowered = func.lower(Card.riftbound_id)
    clauses = [lowered == family]
    prefix, sep, suffix = family.rpartition("-")
    if sep and "-" in prefix:
        clauses.append(lowered.like(f"{prefix}_-{suffix}"))
    return or_(*clauses)


def variant_cards(db: Session, card: Card) -> list[Card]:
    family = variant_family(card.riftbound_id)
    if not family:
        return [card]
    rows = list(
        db.scalars(
            select(Card)
            .where(variant_id_clause(family))
            .order_by(Card.alternate_art, Card.signature, Card.overnumbered, Card.id)
        ).all()
    )
    seen: dict[str, Card] = {}
    for row in rows:
        key = (row.riftbound_id or row.id).lower()
        if key not in seen or row.id == card.id:
            seen[key] = row
    result = list(seen.values())
    if not any(row.id == card.id for row in result):
        result.insert(0, card)
    return result


def apply_filters(query, *, q, set_id, type, domain, rarity, energy):
    if q:
        like = f"%{q.lower()}%"
        query = query.where(
            func.lower(Card.name).like(like)
            | func.lower(func.coalesce(Card.text_plain, "")).like(like)
            | func.lower(Card.riftbound_id).like(like)
        )
    sets = [value.upper() for value in csv_parts(set_id)]
    if sets:
        query = query.where(Card.set_id.in_(sets))
    types = csv_parts(type)
    if types:
        query = query.where(Card.type.in_(types))
    rarities = csv_parts(rarity)
    if rarities:
        query = query.where(Card.rarity.in_(rarities))
    domains = csv_parts(domain)
    if domains:
        query = query.where(or_(*[cast(Card.domains, String).like(f'%"{item}"%') for item in domains]))
    energies = csv_parts(energy)
    if energies:
        clauses = []
        for token in energies:
            try:
                if token.endswith("+"):
                    clauses.append(Card.energy >= int(token[:-1]))
                else:
                    clauses.append(Card.energy == int(token))
            except ValueError:
                continue
        if clauses:
            query = query.where(or_(*clauses))
    return query


@router.get("/cards")
def list_cards(
    response: Response,
    q: str | None = None,
    set_id: str | None = None,
    type: str | None = None,
    domain: str | None = None,
    rarity: str | None = None,
    energy: str | None = None,
    sort: str | None = None,
    page: int = Query(1, ge=1),
    size: int = Query(30, ge=1, le=100),
    db: Session = Depends(get_db),
    viewer: User | None = Depends(optional_user),
):
    # Cache uniquement les réponses anonymes et déterministes (owned_qty est propre à chaque compte).
    cache_key = None
    if viewer is None and sort != "random":
        _cacheable_headers(response)
        cache_key = f"cards:list:{q}|{set_id}|{type}|{domain}|{rarity}|{energy}|{sort}|{page}|{size}"
        cached = cache_get(cache_key)
        if cached is not None:
            return cached

    query = apply_filters(
        select(Card),
        q=q,
        set_id=set_id,
        type=type,
        domain=domain,
        rarity=rarity,
        energy=energy,
    )

    total = db.scalar(select(func.count()).select_from(query.subquery())) or 0
    if sort == "random":
        order = [func.random()]
    elif sort == "rarity":
        order = [RARITY_RANK, Card.set_id, Card.collector_number, Card.id]
    else:
        order = [Card.set_id, Card.collector_number, Card.id]
    rows = db.scalars(query.order_by(*order).offset((page - 1) * size).limit(size)).all()
    owned = owned_quantities(db, viewer, [card.id for card in rows])
    payload = {
        "total": total,
        "page": page,
        "size": size,
        "items": [card_out(card, owned.get(card.id, 0) if viewer else None) for card in rows],
    }
    if cache_key:
        cache_set(cache_key, payload, settings.cache_ttl_seconds)
    return payload


@router.get("/cards/{card_id}/variants")
def list_variants(
    card_id: str,
    db: Session = Depends(get_db),
    viewer: User | None = Depends(optional_user),
):
    card = find_card(db, card_id)
    if card is None:
        raise HTTPException(status_code=404, detail="Carte introuvable")
    rows = variant_cards(db, card)
    owned = owned_quantities(db, viewer, [row.id for row in rows])
    return [card_out(row, owned.get(row.id, 0) if viewer else None) for row in rows]


@router.get("/cards/{card_id}")
def get_card(
    card_id: str,
    response: Response,
    db: Session = Depends(get_db),
    viewer: User | None = Depends(optional_user),
):
    cache_key = None
    if viewer is None:
        _cacheable_headers(response)
        cache_key = f"cards:detail:{card_id.lower()}"
        cached = cache_get(cache_key)
        if cached is not None:
            return cached

    card = find_card(db, card_id)
    if card is None:
        raise HTTPException(status_code=404, detail="Carte introuvable")
    rows = variant_cards(db, card)
    owned = owned_quantities(db, viewer, [row.id for row in rows] + [card.id])
    payload = card_out(card, owned.get(card.id, 0) if viewer else None)
    payload["variants"] = [card_out(row, owned.get(row.id, 0) if viewer else None) for row in rows]
    if cache_key:
        cache_set(cache_key, payload, settings.cache_ttl_seconds)
    return payload


@router.get("/sets")
def list_sets(response: Response, db: Session = Depends(get_db)):
    _cacheable_headers(response)
    cached = cache_get("sets:list")
    if cached is not None:
        return cached
    rows = db.scalars(select(CardSet).order_by(CardSet.published_on)).all()
    payload = [
        {
            "set_id": s.set_id,
            "name": s.name,
            "card_count": s.card_count,
            "published_on": s.published_on,
        }
        for s in rows
    ]
    cache_set("sets:list", payload, settings.cache_ttl_seconds)
    return payload
