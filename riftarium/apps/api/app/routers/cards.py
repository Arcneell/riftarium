from fastapi import APIRouter, Depends, HTTPException, Query, Response
from sqlalchemy import String, case, cast, func, or_, select
from sqlalchemy.orm import Session

from ..auth import optional_user
from ..cache import cache_get, cache_set
from ..config import settings
from ..db import get_db
from ..imagehash import ALGO as HASH_ALGO
from ..models import Card, CardSet, CollectionItem, User
from ..security import sanitize_image_url
from ..variants import variant_family, variant_id_clause

router = APIRouter(prefix="/api", tags=["cards"])


def _cacheable_headers(response: Response) -> None:
    """Les réponses anonymes sont stables (les cartes changent à la sync) : le navigateur peut les garder."""
    response.headers["Cache-Control"] = "public, max-age=300"
    # L'authentification passe par header Bearer OU cookie de session : les deux font varier la réponse.
    response.headers["Vary"] = "Authorization, Cookie"


def escape_like(value: str) -> str:
    """Neutralise les jokers SQL (%, _) d'une saisie utilisateur pour un LIKE avec escape='\\\\'."""
    return value.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")


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
        "image_url": sanitize_image_url(card.image_url),
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
        select(CollectionItem.card_id, func.sum(CollectionItem.qty))
        .where(CollectionItem.user_id == user.id, CollectionItem.card_id.in_(card_ids))
        .group_by(CollectionItem.card_id)
    ).all()
    return {card_id: qty for card_id, qty in rows}


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


def apply_filters(query, *, q, set_id, type_, domain, rarity, energy):
    if q:
        like = f"%{escape_like(q.lower())}%"
        query = query.where(
            func.lower(Card.name).like(like, escape="\\")
            | func.lower(func.coalesce(Card.text_plain, "")).like(like, escape="\\")
            | func.lower(Card.riftbound_id).like(like, escape="\\")
        )
    sets = [value.upper() for value in csv_parts(set_id)]
    if sets:
        query = query.where(Card.set_id.in_(sets))
    types = csv_parts(type_)
    if types:
        query = query.where(Card.type.in_(types))
    rarities = csv_parts(rarity)
    if rarities:
        query = query.where(Card.rarity.in_(rarities))
    domains = csv_parts(domain)
    if domains:
        query = query.where(
            or_(*[cast(Card.domains, String).like(f'%"{escape_like(item)}"%', escape="\\") for item in domains])
        )
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
    type_: str | None = Query(None, alias="type"),  # « type » masquerait le builtin Python
    domain: str | None = None,
    rarity: str | None = None,
    energy: str | None = None,
    owned: str | None = None,
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
        cache_key = f"cards:list:{q}|{set_id}|{type_}|{domain}|{rarity}|{energy}|{sort}|{page}|{size}"
        cached = cache_get(cache_key)
        if cached is not None:
            return cached

    query = apply_filters(
        select(Card),
        q=q,
        set_id=set_id,
        type_=type_,
        domain=domain,
        rarity=rarity,
        energy=energy,
    )

    # Filtre possédé/manquant : dépend du compte, donc jamais atteint par le cache anonyme.
    if viewer is not None and owned in {"0", "1"}:
        owned_ids = select(CollectionItem.card_id).where(CollectionItem.user_id == viewer.id, CollectionItem.qty > 0)
        query = query.where(Card.id.in_(owned_ids) if owned == "1" else Card.id.not_in(owned_ids))

    total = db.scalar(select(func.count()).select_from(query.subquery())) or 0
    if sort == "random":
        order = [func.random()]
    elif sort == "rarity":
        order = [RARITY_RANK, Card.set_id, Card.collector_number, Card.id]
    else:
        order = [Card.set_id, Card.collector_number, Card.id]
    rows = db.scalars(query.order_by(*order).offset((page - 1) * size).limit(size)).all()
    owned_map = owned_quantities(db, viewer, [card.id for card in rows])
    payload = {
        "total": total,
        "page": page,
        "size": size,
        "items": [card_out(card, owned_map.get(card.id, 0) if viewer else None) for card in rows],
    }
    if cache_key:
        cache_set(cache_key, payload, settings.cache_ttl_seconds)
    return payload


# Déclaré avant /cards/{card_id} : sinon « hashes » serait capturé comme un id de carte.
@router.get("/cards/hashes")
def list_card_hashes(response: Response, db: Session = Depends(get_db)):
    """Index des empreintes perceptuelles (scan mobile) : le matching se fait côté client.

    Endpoint public et stable entre deux syncs : cache long côté navigateur
    (l'index complet pèse ~130 octets par carte) et cache serveur invalidé
    par la sync et par le recalcul admin (préfixe « cards: »).
    """
    response.headers["Cache-Control"] = "public, max-age=3600"
    response.headers["Vary"] = "Authorization, Cookie"
    cached = cache_get("cards:hashes")
    if cached is not None:
        return cached
    rows = db.execute(select(Card.id, Card.image_hash).where(Card.image_hash.is_not(None)).order_by(Card.id)).all()
    payload = {
        "algo": HASH_ALGO,
        "count": len(rows),
        "items": [{"id": card_id, "h": image_hash} for card_id, image_hash in rows],
    }
    cache_set("cards:hashes", payload, settings.cache_ttl_seconds)
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
        # Pas de lower() : find_card résout l'id primaire avec sa casse exacte,
        # deux casse différentes peuvent désigner des cartes différentes.
        cache_key = f"cards:detail:{card_id}"
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
