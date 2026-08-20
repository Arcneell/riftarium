import hashlib

from fastapi import APIRouter, Depends, HTTPException, Query, Request
from sqlalchemy import String, case, cast, func, or_, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session, selectinload

from ..auth import current_user, optional_user
from ..db import get_db
from ..deckbuild import assemble_list, has_champion, legends_in, load_pool, main_candidates
from ..models import Card, CollectionItem, Deck, DeckCard, DeckLike, DeckView, User
from ..moderation import review
from ..prices import current_rate, to_eur
from ..profiles import avatar_urls
from ..schemas import DeckIn, ExampleDeckIn
from ..security import client_ip, sanitize_image_url
from ..validation import validate_deck
from ..variants import copy_family
from .cards import card_out, csv_parts, escape_like, owned_quantities, wished_quantities

router = APIRouter(prefix="/api", tags=["decks"])

_UNSET = object()


def deck_out(
    deck: Deck,
    viewer: User | None = None,
    db: Session | None = None,
    *,
    liked: bool | None = None,
    owned: dict[str, int] | None = None,
    wished: dict[str, int] | None = None,
    owner_avatar=_UNSET,
    rate: float | None = _UNSET,
) -> dict:
    """Sérialise un deck. liked/owned/wished/owner_avatar/rate peuvent être pré-calculés en lot (cf. _decks_out)."""
    if rate is _UNSET:
        rate = current_rate(db) if db is not None else None
    if liked is None:
        liked = bool(
            viewer
            and db
            and db.scalar(select(DeckLike).where(DeckLike.deck_id == deck.id, DeckLike.user_id == viewer.id))
        )
    if owned is None:
        owned = owned_quantities(db, viewer, [dc.card_id for dc in deck.cards]) if viewer and db else {}
    if wished is None:
        wished = wished_quantities(db, viewer, [dc.card_id for dc in deck.cards]) if viewer and db else {}
    if owner_avatar is _UNSET:
        owner_avatar = avatar_urls(db, [deck.owner]).get(deck.owner.id) if db and deck.owner else None
    has_viewer = viewer is not None and db is not None

    # Estimation du deck en euros : total = somme qty × prix ; missing = coût des
    # exemplaires manquants (qty − owned_qty, borné à 0), calculable seulement
    # pour un visiteur connecté (owned_qty inconnu sinon). Null si rien n'est pricé.
    priced = [(dc, to_eur(dc.card.price_usd, rate)) for dc in deck.cards]
    known = [(dc, price) for dc, price in priced if price is not None]
    total_eur = round(sum(dc.qty * price for dc, price in known), 2) if known else None
    missing_eur = None
    if has_viewer and known:
        missing_eur = round(sum(max(0, dc.qty - owned.get(dc.card_id, 0)) * price for dc, price in known), 2)

    return {
        "id": deck.id,
        "name": deck.name,
        "description": deck.description,
        "format": deck.format,
        "is_public": deck.is_public,
        "moderation_status": deck.moderation_status,
        "likes": deck.likes_count,
        "liked_by_me": liked,
        "views": deck.views_count,
        "owner": deck.owner.handle,
        "owner_avatar": owner_avatar,
        "card_count": sum(dc.qty for dc in deck.cards),
        "prices": {"total_eur": total_eur, "missing_eur": missing_eur},
        "cards": [
            {
                "card": card_out(
                    dc.card,
                    owned.get(dc.card_id, 0) if has_viewer else None,
                    rate,
                    wished.get(dc.card_id, 0) if has_viewer else None,
                ),
                "qty": dc.qty,
            }
            for dc in deck.cards
        ],
        "checks": validate_deck([(dc.card, dc.qty) for dc in deck.cards]),
        "updated_at": deck.updated_at.isoformat() if deck.updated_at else None,
    }


def _decks_out(db: Session, decks: list[Deck], viewer: User | None) -> list[dict]:
    """Sérialisation en lot : likes, quantités possédées et avatars en une requête chacun."""
    ids = [deck.id for deck in decks]
    liked_ids: set[int] = set()
    owned: dict[str, int] = {}
    wished: dict[str, int] = {}
    if viewer is not None and ids:
        liked_ids = set(
            db.scalars(select(DeckLike.deck_id).where(DeckLike.user_id == viewer.id, DeckLike.deck_id.in_(ids))).all()
        )
        card_ids = list({dc.card_id for deck in decks for dc in deck.cards})
        owned = owned_quantities(db, viewer, card_ids)
        wished = wished_quantities(db, viewer, card_ids)
    avatars = avatar_urls(db, [deck.owner for deck in decks if deck.owner])
    rate = current_rate(db)
    return [
        deck_out(
            deck,
            viewer,
            db,
            liked=deck.id in liked_ids,
            owned=owned,
            wished=wished,
            owner_avatar=avatars.get(deck.owner.id) if deck.owner else None,
            rate=rate,
        )
        for deck in decks
    ]


def _reload_deck(db: Session, deck_id: int) -> Deck:
    """Recharge un deck fraîchement écrit avec cartes pré-chargées (évite les lazy-loads unitaires)."""
    return db.scalar(
        select(Deck)
        .options(selectinload(Deck.cards).joinedload(DeckCard.card))
        .where(Deck.id == deck_id)
        .execution_options(populate_existing=True)
    )


def _apply(deck: Deck, payload: DeckIn, db: Session) -> None:
    deck.name = payload.name
    deck.description = payload.description
    deck.format = payload.format
    deck.is_public = payload.is_public
    deck.moderation_status = review(f"{payload.name}\n{payload.description}")

    deck.cards.clear()
    if deck.id is not None:
        db.flush()  # supprime les anciennes lignes avant réinsertion (contrainte unique deck/carte)

    # Dédoublonnage par identifiant : les quantités des doublons s'additionnent.
    wanted: dict[str, int] = {}
    for entry in payload.cards:
        wanted[entry.card_id] = wanted.get(entry.card_id, 0) + entry.qty

    # Résolution en lot : d'abord par id Riftcodex, puis par riftbound_id pour le reste.
    resolved: dict[str, Card] = {}
    if wanted:
        rows = db.scalars(select(Card).where(Card.id.in_(list(wanted)))).all()
        resolved = {card.id: card for card in rows}
    missing = {ident.lower(): ident for ident in wanted if ident not in resolved}
    if missing:
        fallback = db.scalars(
            select(Card)
            .where(func.lower(Card.riftbound_id).in_(missing))
            .order_by(Card.alternate_art, Card.id)  # version de base d'abord, comme find_card
        ).all()
        for card in fallback:
            ident = missing.get((card.riftbound_id or "").lower())
            if ident is not None and ident not in resolved:
                resolved[ident] = card
    unknown = [ident for ident in wanted if ident not in resolved]
    if unknown:
        raise HTTPException(status_code=422, detail=f"Carte inconnue : {unknown[0]}")

    # Deux identifiants peuvent résoudre la même carte : on fusionne aussi par carte résolue.
    quantities: dict[str, int] = {}
    for ident, qty in wanted.items():
        card_id = resolved[ident].id
        quantities[card_id] = quantities.get(card_id, 0) + qty
    for card_id, qty in quantities.items():
        deck.cards.append(DeckCard(card_id=card_id, qty=qty))


@router.get("/decks/mine")
def my_decks(user: User = Depends(current_user), db: Session = Depends(get_db)):
    decks = db.scalars(select(Deck).where(Deck.owner_id == user.id).order_by(Deck.updated_at.desc())).all()
    return _decks_out(db, list(decks), user)


@router.post("/decks", status_code=201)
def create_deck(payload: DeckIn, user: User = Depends(current_user), db: Session = Depends(get_db)):
    deck = Deck(owner_id=user.id)
    _apply(deck, payload, db)
    db.add(deck)
    db.commit()
    return deck_out(_reload_deck(db, deck.id), user, db)


@router.post("/decks/{deck_id}/copy", status_code=201)
def copy_deck(deck_id: int, user: User = Depends(current_user), db: Session = Depends(get_db)):
    """Copie un deck accessible (le sien, ou public publié) dans « Mes decks ».

    La copie est privée, créditée à l'auteur d'origine, et repasse par la
    modération comme n'importe quel deck (elle est privée : sans incidence).
    """
    src = db.get(Deck, deck_id)
    if src is None or (src.owner_id != user.id and not (src.is_public and src.moderation_status == "published")):
        raise HTTPException(status_code=404, detail="Deck introuvable")

    name = f"{src.name} (copie)"[:80]
    description = src.description or ""
    if src.owner_id != user.id and src.owner is not None:
        credit = f"D'après « {src.name} » de {src.owner.handle}."
        description = f"{credit}\n\n{description}"[:2000] if description else credit

    deck = Deck(
        owner_id=user.id,
        name=name,
        description=description,
        format=src.format,
        is_public=False,
        moderation_status=review(f"{name}\n{description}"),
    )
    for entry in src.cards:
        deck.cards.append(DeckCard(card_id=entry.card_id, qty=entry.qty))
    db.add(deck)
    db.commit()
    return deck_out(_reload_deck(db, deck.id), user, db)


@router.get("/decks/{deck_id}")
def get_deck(
    deck_id: int,
    viewer: User | None = Depends(optional_user),
    db: Session = Depends(get_db),
):
    deck = db.get(Deck, deck_id)
    if deck is None:
        raise HTTPException(status_code=404, detail="Deck introuvable")
    is_owner = viewer is not None and viewer.id == deck.owner_id
    if not is_owner and not (deck.is_public and deck.moderation_status == "published"):
        raise HTTPException(status_code=404, detail="Deck introuvable")
    return deck_out(deck, viewer, db)


def _owned_families(db: Session, user: User) -> dict[str, int]:
    """Quantités possédées agrégées par nom de jeu (reprints et variantes confondus)."""
    # Seules les colonnes utiles à copy_family sont lues (pas d'hydratation ORM complète).
    rows = db.execute(
        select(Card.name, Card.type, Card.riftbound_id, Card.id, CollectionItem.qty)
        .join(Card, Card.id == CollectionItem.card_id)
        .where(CollectionItem.user_id == user.id)
    ).all()
    owned_by_family: dict[str, int] = {}
    for row in rows:
        family = copy_family(row)
        owned_by_family[family] = owned_by_family.get(family, 0) + int(row.qty or 0)
    return owned_by_family


@router.post("/decks/example", status_code=201)
def create_example_deck(payload: ExampleDeckIn, user: User = Depends(current_user), db: Session = Depends(get_db)):
    """Génère un deck de tournoi d'exemple.

    mode="owned" : privilégie les cartes de la collection (idéalement jouable immédiatement).
    mode="discover" : privilégie les cartes non possédées, pour tester la liste d'achats.
    """
    prefer_owned = payload.mode == "owned"
    owned = _owned_families(db, user)
    pool = load_pool(db)
    if not pool:
        raise HTTPException(status_code=422, detail="Aucune carte en base : lancez une synchronisation")

    legends = legends_in(pool)
    if not legends:
        raise HTTPException(status_code=422, detail="Aucune légende disponible")

    def owned_qty(card: Card) -> int:
        return owned.get(copy_family(card), 0)

    def coverage(legend: Card) -> int:
        return sum(min(owned_qty(c), 3) for c in main_candidates(pool, legend))

    viable = [card for card in legends if has_champion(card, main_candidates(pool, card))] or legends
    if prefer_owned:
        legend = max(viable, key=lambda c: (owned_qty(c) > 0, coverage(c)))
    else:
        legend = max(viable, key=lambda c: len(main_candidates(pool, c)))

    entries = assemble_list(pool, legend, owned=owned, prefer_owned=prefer_owned)
    deck = Deck(owner_id=user.id)
    deck.name = f"Exemple · {legend.name}"[:80]
    deck.description = (
        "Deck d'exemple généré à partir de votre collection."
        if prefer_owned
        else "Deck d'exemple généré pour découvrir de nouvelles cartes : "
        "ouvrez « Trouver les cartes manquantes » pour la liste d'achats."
    )
    deck.format = "tournament"
    deck.is_public = False
    deck.moderation_status = review(f"{deck.name}\n{deck.description}")
    for card, qty in entries:
        deck.cards.append(DeckCard(card_id=card.id, qty=qty))
    db.add(deck)
    db.commit()
    return deck_out(_reload_deck(db, deck.id), user, db)


@router.get("/decks/{deck_id}/missing")
def deck_missing(deck_id: int, user: User = Depends(current_user), db: Session = Depends(get_db)):
    """Liste d'achats : ce qui manque à la collection pour jouer le deck."""
    deck = db.get(Deck, deck_id)
    if deck is None or deck.owner_id != user.id:
        raise HTTPException(status_code=404, detail="Deck introuvable")

    owned_by_family = _owned_families(db, user)

    # Deux variantes d'une même carte dans le deck partagent le même besoin.
    needs: dict[str, dict] = {}
    for dc in deck.cards:
        family = copy_family(dc.card)
        slot = needs.setdefault(family, {"card": dc.card, "needed": 0})
        slot["needed"] += dc.qty

    rate = current_rate(db)
    items = []
    for family, slot in needs.items():
        have = owned_by_family.get(family, 0)
        missing = max(0, slot["needed"] - have)
        if missing:
            items.append(
                {"card": card_out(slot["card"], rate=rate), "needed": slot["needed"], "owned": have, "missing": missing}
            )
    items.sort(key=lambda item: (item["card"]["set_id"] or "", item["card"]["collector_number"] or 0))
    return {
        "items": items,
        "missing_total": sum(item["missing"] for item in items),
        "deck_total": sum(dc.qty for dc in deck.cards),
    }


@router.put("/decks/{deck_id}")
def update_deck(
    deck_id: int,
    payload: DeckIn,
    user: User = Depends(current_user),
    db: Session = Depends(get_db),
):
    deck = db.get(Deck, deck_id)
    if deck is None or deck.owner_id != user.id:
        raise HTTPException(status_code=404, detail="Deck introuvable")
    _apply(deck, payload, db)
    db.commit()
    return deck_out(_reload_deck(db, deck.id), user, db)


@router.delete("/decks/{deck_id}", status_code=204)
def delete_deck(deck_id: int, user: User = Depends(current_user), db: Session = Depends(get_db)):
    deck = db.get(Deck, deck_id)
    if deck is None or deck.owner_id != user.id:
        raise HTTPException(status_code=404, detail="Deck introuvable")
    db.delete(deck)
    db.commit()


@router.post("/decks/{deck_id}/like")
def toggle_like(deck_id: int, user: User = Depends(current_user), db: Session = Depends(get_db)):
    deck = db.get(Deck, deck_id)
    if deck is None or not (deck.is_public and deck.moderation_status == "published"):
        raise HTTPException(status_code=404, detail="Deck introuvable")
    like = db.scalar(select(DeckLike).where(DeckLike.deck_id == deck.id, DeckLike.user_id == user.id))
    if like:
        db.delete(like)
        # Décrément côté serveur (jamais négatif) : sûr face aux requêtes concurrentes.
        deck.likes_count = case((Deck.likes_count > 0, Deck.likes_count - 1), else_=0)
        liked = False
        db.commit()
    else:
        db.add(DeckLike(deck_id=deck.id, user_id=user.id))
        deck.likes_count = Deck.likes_count + 1
        liked = True
        try:
            db.commit()
        except IntegrityError:  # double-clic concurrent : le like existe déjà (uq_deck_like)
            db.rollback()
    return {"deck_id": deck.id, "likes": deck.likes_count, "liked_by_me": liked}


def _visitor_key(user: User | None, request: Request) -> str:
    if user:
        return f"u:{user.id}"
    ip = client_ip(request)
    return "a:" + hashlib.sha256(ip.encode()).hexdigest()[:24]


def _legend_decks():
    return select(DeckCard.deck_id).join(Card, Card.id == DeckCard.card_id).where(Card.type == "Legend")


def _community_deck_out(
    deck: Deck,
    *,
    legend: Card | None,
    card_count: int,
    liked: bool,
    owner_avatar: str | None = None,
    missing_cards: int | None = None,
    missing_cost_eur: float | None = None,
) -> dict:
    domains = [d for d in (legend.domains or []) if d != "Colorless"] if legend else []
    return {
        "id": deck.id,
        "name": deck.name,
        "description": deck.description,
        "format": deck.format,
        "likes": deck.likes_count,
        "liked_by_me": liked,
        "views": deck.views_count,
        "owner": deck.owner.handle,
        "owner_avatar": owner_avatar,
        "card_count": card_count,
        "legend": card_out(legend) if legend else None,
        "domains": domains,
        # Manque par rapport à la collection du visiteur connecté (null si anonyme) :
        # nombre d'exemplaires manquants et coût estimé des manquants pricés.
        "missing_cards": missing_cards,
        "missing_cost_eur": missing_cost_eur,
        "updated_at": deck.updated_at.isoformat() if deck.updated_at else None,
    }


def _buildable_deck_filter(viewer: User):
    """Sous-requête des decks NON constructibles : au moins une carte en déficit.

    Comparaison par identifiant exact de carte (même mécanique qu'owned_quantities) :
    une quantité demandée supérieure à la quantité possédée disqualifie le deck.
    Filtre côté SQL : le tri et la pagination du listing s'appliquent donc
    naturellement APRÈS filtrage, sans page élargie en mémoire.
    """
    owned_sub = (
        select(CollectionItem.card_id.label("card_id"), func.sum(CollectionItem.qty).label("owned"))
        .where(CollectionItem.user_id == viewer.id)
        .group_by(CollectionItem.card_id)
        .subquery()
    )
    return (
        select(DeckCard.deck_id)
        .outerjoin(owned_sub, owned_sub.c.card_id == DeckCard.card_id)
        .where(DeckCard.qty > func.coalesce(owned_sub.c.owned, 0))
    )


def _community_missing(db: Session, decks: list[Deck], viewer: User | None) -> dict[int, tuple[int, float | None]]:
    """Manque par deck pour la page du listing : deck_id → (missing_cards, missing_cost_eur).

    Une seule requête collection pour toutes les cartes de la page (owned_quantities),
    puis une passe en mémoire sur deck.cards (déjà chargées par le selectin du modèle).
    """
    if viewer is None or not decks:
        return {}
    rate = current_rate(db)
    card_ids = list({dc.card_id for deck in decks for dc in deck.cards})
    owned = owned_quantities(db, viewer, card_ids)
    result: dict[int, tuple[int, float | None]] = {}
    for deck in decks:
        shortfall = {dc.card_id: max(0, dc.qty - owned.get(dc.card_id, 0)) for dc in deck.cards}
        missing_cards = sum(shortfall.values())
        # Même convention que deck_out : coût des manquants pricés, null si
        # aucune carte du deck n'a de prix connu (0.0 si tout est couvert).
        known = [(dc, to_eur(dc.card.price_usd, rate)) for dc in deck.cards]
        known = [(dc, price) for dc, price in known if price is not None]
        cost = round(sum(shortfall[dc.card_id] * price for dc, price in known), 2) if known else None
        result[deck.id] = (missing_cards, cost)
    return result


@router.post("/decks/{deck_id}/view")
def record_view(
    deck_id: int,
    request: Request,
    viewer: User | None = Depends(optional_user),
    db: Session = Depends(get_db),
):
    """Compte une visite unique par visiteur. Le propriétaire n'est pas compté."""
    deck = db.get(Deck, deck_id)
    if deck is None or not (deck.is_public and deck.moderation_status == "published"):
        raise HTTPException(status_code=404, detail="Deck introuvable")
    if viewer is not None and viewer.id == deck.owner_id:
        return {"deck_id": deck.id, "views": deck.views_count, "counted": False}

    key = _visitor_key(viewer, request)
    if db.scalar(select(DeckView).where(DeckView.deck_id == deck.id, DeckView.visitor_key == key)):
        return {"deck_id": deck.id, "views": deck.views_count, "counted": False}

    db.add(DeckView(deck_id=deck.id, visitor_key=key))
    deck.views_count = Deck.views_count + 1  # incrément côté serveur : pas de perte en cas de concurrence
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        deck = db.get(Deck, deck_id)
        return {"deck_id": deck_id, "views": deck.views_count if deck else 0, "counted": False}
    return {"deck_id": deck.id, "views": deck.views_count, "counted": True}


@router.get("/community/legends")
def community_legends(db: Session = Depends(get_db)):
    """Légendes présentes dans au moins un deck public, pour le filtre."""
    rows = db.execute(
        select(Card.id, Card.name, Card.image_url, func.count(Deck.id))
        .join(DeckCard, DeckCard.card_id == Card.id)
        .join(Deck, Deck.id == DeckCard.deck_id)
        .where(Card.type == "Legend", Deck.is_public.is_(True), Deck.moderation_status == "published")
        .group_by(Card.id, Card.name, Card.image_url)
        .order_by(func.count(Deck.id).desc(), Card.name)
    ).all()
    return [
        {"id": card_id, "name": name, "image_url": sanitize_image_url(image_url), "deck_count": n}
        for card_id, name, image_url, n in rows
    ]


@router.get("/community/decks")
def community_decks(
    q: str | None = None,
    legend: str | None = None,
    domain: str | None = None,
    format: str | None = None,
    sort: str = Query("likes"),
    liked: str | None = None,
    buildable: str | None = None,
    page: int = Query(1, ge=1),
    size: int = Query(20, ge=1, le=50),
    viewer: User | None = Depends(optional_user),
    db: Session = Depends(get_db),
):
    query = select(Deck).where(Deck.is_public.is_(True), Deck.moderation_status == "published")
    legend_ids = csv_parts(legend)
    if legend_ids:
        query = query.where(Deck.id.in_(_legend_decks().where(Card.id.in_(legend_ids))))
    domains = csv_parts(domain)
    if domains:
        query = query.where(
            Deck.id.in_(
                _legend_decks().where(
                    or_(*[cast(Card.domains, String).like(f'%"{escape_like(item)}"%', escape="\\") for item in domains])
                )
            )
        )
    formats = csv_parts(format)
    if formats:
        query = query.where(Deck.format.in_(formats))
    if liked in {"1", "true"} and viewer is not None:
        query = query.where(Deck.id.in_(select(DeckLike.deck_id).where(DeckLike.user_id == viewer.id)))
    # Decks constructibles : toutes les cartes couvertes par la collection
    # (anonyme : paramètre ignoré, comme « liked »).
    if buildable in {"1", "true"} and viewer is not None:
        query = query.where(Deck.id.not_in(_buildable_deck_filter(viewer)))
    if q:
        needle = f"%{escape_like(q.lower())}%"
        query = query.where(
            or_(
                func.lower(Deck.name).like(needle, escape="\\"),
                func.lower(func.coalesce(Deck.description, "")).like(needle, escape="\\"),
                Deck.owner_id.in_(select(User.id).where(func.lower(User.handle).like(needle, escape="\\"))),
                Deck.id.in_(_legend_decks().where(func.lower(Card.name).like(needle, escape="\\"))),
            )
        )

    order = {
        "views": (Deck.views_count.desc(), Deck.likes_count.desc(), Deck.updated_at.desc()),
        "recent": (Deck.updated_at.desc(), Deck.likes_count.desc()),
    }.get(sort, (Deck.likes_count.desc(), Deck.views_count.desc(), Deck.updated_at.desc()))
    query = query.order_by(*order)

    total = db.scalar(select(func.count()).select_from(query.order_by(None).subquery())) or 0
    decks = db.scalars(query.offset((page - 1) * size).limit(size)).all()
    ids = [deck.id for deck in decks]

    counts: dict[int, int] = (
        dict(
            db.execute(
                select(DeckCard.deck_id, func.coalesce(func.sum(DeckCard.qty), 0))
                .where(DeckCard.deck_id.in_(ids))
                .group_by(DeckCard.deck_id)
            ).all()
        )
        if ids
        else {}
    )
    legends: dict[int, Card] = {}
    if ids:
        for deck_id, card in db.execute(
            select(DeckCard.deck_id, Card)
            .join(Card, Card.id == DeckCard.card_id)
            .where(DeckCard.deck_id.in_(ids), Card.type == "Legend")
        ):
            legends.setdefault(deck_id, card)
    liked_ids: set[int] = set()
    if viewer is not None and ids:
        liked_ids = set(
            db.scalars(select(DeckLike.deck_id).where(DeckLike.user_id == viewer.id, DeckLike.deck_id.in_(ids))).all()
        )
    owner_pics = avatar_urls(db, [deck.owner for deck in decks if deck.owner])
    missing = _community_missing(db, list(decks), viewer)

    return {
        "total": total,
        "page": page,
        "size": size,
        "items": [
            _community_deck_out(
                deck,
                legend=legends.get(deck.id),
                card_count=int(counts.get(deck.id, 0)),
                liked=deck.id in liked_ids,
                owner_avatar=owner_pics.get(deck.owner.id) if deck.owner else None,
                missing_cards=missing.get(deck.id, (None, None))[0],
                missing_cost_eur=missing.get(deck.id, (None, None))[1],
            )
            for deck in decks
        ],
    }
