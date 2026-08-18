from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from ..auth import current_user, optional_user
from ..db import get_db
from ..models import Card, CollectionItem, Deck, DeckCard, DeckLike, User
from ..moderation import review
from ..schemas import DeckIn, ExampleDeckIn
from ..validation import MAIN_TYPES, validate_deck
from ..variants import variant_family
from .cards import card_out, find_card, owned_quantities

router = APIRouter(prefix="/api", tags=["decks"])


def deck_out(deck: Deck, viewer: User | None = None, db: Session | None = None) -> dict:
    liked = False
    owned: dict[str, int] = {}
    if viewer and db:
        liked = (
            db.scalar(select(DeckLike).where(DeckLike.deck_id == deck.id, DeckLike.user_id == viewer.id)) is not None
        )
        owned = owned_quantities(db, viewer, [dc.card_id for dc in deck.cards])
    has_viewer = viewer is not None and db is not None
    return {
        "id": deck.id,
        "name": deck.name,
        "description": deck.description,
        "format": deck.format,
        "is_public": deck.is_public,
        "moderation_status": deck.moderation_status,
        "likes": deck.likes_count,
        "liked_by_me": liked,
        "owner": deck.owner.handle,
        "card_count": sum(dc.qty for dc in deck.cards),
        "cards": [
            {"card": card_out(dc.card, owned.get(dc.card_id, 0) if has_viewer else None), "qty": dc.qty}
            for dc in deck.cards
        ],
        "checks": validate_deck([(dc.card, dc.qty) for dc in deck.cards]),
        "updated_at": deck.updated_at.isoformat() if deck.updated_at else None,
    }


def _apply(deck: Deck, payload: DeckIn, db: Session) -> None:
    deck.name = payload.name
    deck.description = payload.description
    deck.format = payload.format
    deck.is_public = payload.is_public
    deck.moderation_status = review(f"{payload.name}\n{payload.description}")

    deck.cards.clear()
    if deck.id is not None:
        db.flush()  # supprime les anciennes lignes avant réinsertion (contrainte unique deck/carte)
    for entry in payload.cards:
        card = find_card(db, entry.card_id)
        if card is None:
            raise HTTPException(status_code=422, detail=f"Carte inconnue : {entry.card_id}")
        deck.cards.append(DeckCard(card_id=card.id, qty=entry.qty))


@router.get("/decks/mine")
def my_decks(user: User = Depends(current_user), db: Session = Depends(get_db)):
    decks = db.scalars(select(Deck).where(Deck.owner_id == user.id).order_by(Deck.updated_at.desc())).all()
    return [deck_out(d, user, db) for d in decks]


@router.post("/decks", status_code=201)
def create_deck(payload: DeckIn, user: User = Depends(current_user), db: Session = Depends(get_db)):
    deck = Deck(owner_id=user.id)
    _apply(deck, payload, db)
    db.add(deck)
    db.commit()
    return deck_out(deck, user, db)


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
    """Quantités possédées agrégées par famille de variantes (l'art alternatif compte pour la base)."""
    rows = db.execute(
        select(Card.riftbound_id, func.sum(CollectionItem.qty))
        .join(Card, Card.id == CollectionItem.card_id)
        .where(CollectionItem.user_id == user.id)
        .group_by(Card.riftbound_id)
    ).all()
    owned_by_family: dict[str, int] = {}
    for riftbound_id, qty in rows:
        family = variant_family(riftbound_id)
        owned_by_family[family] = owned_by_family.get(family, 0) + int(qty or 0)
    return owned_by_family


@router.post("/decks/example", status_code=201)
def create_example_deck(payload: ExampleDeckIn, user: User = Depends(current_user), db: Session = Depends(get_db)):
    """Génère un deck de tournoi d'exemple.

    mode="owned" : privilégie les cartes de la collection (idéalement jouable immédiatement).
    mode="discover" : privilégie les cartes non possédées, pour tester la liste d'achats.
    """
    prefer_owned = payload.mode == "owned"
    owned = _owned_families(db, user)
    all_cards = db.scalars(select(Card).order_by(Card.set_id, Card.collector_number, Card.id)).all()
    if not all_cards:
        raise HTTPException(status_code=422, detail="Aucune carte en base : lancez une synchronisation")

    def family(card: Card) -> str:
        return variant_family(card.riftbound_id) or card.id

    def owned_qty(card: Card) -> int:
        return owned.get(family(card), 0)

    def is_base(card: Card) -> bool:
        return not (card.alternate_art or card.signature or card.overnumbered)

    def domains(card: Card) -> set[str]:
        return {d for d in (card.domains or []) if d != "Colorless"}

    # Une seule carte par famille, version de base de préférence.
    families: dict[str, Card] = {}
    for card in all_cards:
        current = families.get(family(card))
        if current is None or (is_base(card) and not is_base(current)):
            families[family(card)] = card
    pool = list(families.values())

    legends = [c for c in pool if c.type == "Legend"]
    if not legends:
        raise HTTPException(status_code=422, detail="Aucune légende disponible")

    def main_candidates(legend: Card) -> list[Card]:
        return [c for c in pool if c.type in MAIN_TYPES and domains(c) <= domains(legend)]

    def has_champion(legend: Card, candidates: list[Card]) -> bool:
        tags = set(legend.tags or [])
        return not tags or any(tags & set(c.tags or []) for c in candidates)

    def coverage(legend: Card) -> int:
        return sum(min(owned_qty(c), 3) for c in main_candidates(legend))

    viable = [c for c in legends if has_champion(c, main_candidates(c))] or legends
    if prefer_owned:
        legend = max(viable, key=lambda c: (owned_qty(c) > 0, coverage(c)))
    else:
        legend = max(viable, key=lambda c: len(main_candidates(c)))

    def ownership_rank(card: Card) -> int:
        # 0 = à prendre d'abord ; possédé d'abord en mode collection, l'inverse en découverte
        return -int(owned_qty(card) > 0) if prefer_owned else int(owned_qty(card) > 0)

    battlefields = sorted(
        (c for c in pool if c.type == "Battlefield"),
        key=lambda c: (ownership_rank(c), c.set_id or "", c.collector_number or 0),
    )[:3]

    rune_pool = sorted(
        (c for c in pool if c.type == "Rune" and domains(c) <= domains(legend)),
        key=lambda c: (ownership_rank(c), c.set_id or "", c.collector_number or 0),
    )
    rune_entries: list[tuple[Card, int]] = []
    rune_total = 0
    for rune in rune_pool:
        if rune_total >= 12:
            break
        qty = min(12 - rune_total, owned_qty(rune)) if prefer_owned else 12 - rune_total
        if qty > 0:
            rune_entries.append((rune, qty))
            rune_total += qty
    if rune_total < 12 and rune_pool:  # complète avec la première rune disponible
        top_up = 12 - rune_total
        existing = next((entry for entry in rune_entries if entry[0].id == rune_pool[0].id), None)
        if existing:
            rune_entries[rune_entries.index(existing)] = (existing[0], existing[1] + top_up)
        else:
            rune_entries.append((rune_pool[0], top_up))

    tags = set(legend.tags or [])

    def is_champion(card: Card) -> bool:
        return bool(tags & set(card.tags or []))

    def copy_cap(card: Card) -> int:
        return 1 if "[unique]" in (card.text_plain or "").lower() else 3

    candidates = sorted(
        main_candidates(legend),
        key=lambda c: (
            -int(is_champion(c)),  # garantit le champion élu en tête
            ownership_rank(c),
            c.energy if c.energy is not None else 99,
            c.set_id or "",
            c.collector_number or 0,
        ),
    )
    main_entries: list[tuple[Card, int]] = []
    main_total = 0
    for card in candidates:  # premier passage : respecte la préférence de possession
        if main_total >= 40:
            break
        qty = min(copy_cap(card), owned_qty(card)) if prefer_owned else copy_cap(card)
        if qty > 0:
            main_entries.append((card, qty))
            main_total += qty
    if main_total < 40:  # second passage : complète avec le reste du pool
        for card in candidates:
            if main_total >= 40:
                break
            already = next((entry for entry in main_entries if entry[0].id == card.id), None)
            room = copy_cap(card) - (already[1] if already else 0)
            qty = min(room, 40 - main_total)
            if qty <= 0:
                continue
            if already:
                main_entries[main_entries.index(already)] = (card, already[1] + qty)
            else:
                main_entries.append((card, qty))
            main_total += qty

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
    deck.cards.append(DeckCard(card_id=legend.id, qty=1))
    for battlefield in battlefields:
        deck.cards.append(DeckCard(card_id=battlefield.id, qty=1))
    for rune, qty in rune_entries:
        deck.cards.append(DeckCard(card_id=rune.id, qty=min(qty, 12)))
    for card, qty in main_entries:
        deck.cards.append(DeckCard(card_id=card.id, qty=qty))
    db.add(deck)
    db.commit()
    return deck_out(deck, user, db)


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
        family = variant_family(dc.card.riftbound_id) or dc.card.id
        slot = needs.setdefault(family, {"card": dc.card, "needed": 0})
        slot["needed"] += dc.qty

    items = []
    for family, slot in needs.items():
        have = owned_by_family.get(family, 0)
        missing = max(0, slot["needed"] - have)
        if missing:
            items.append({"card": card_out(slot["card"]), "needed": slot["needed"], "owned": have, "missing": missing})
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
    return deck_out(deck, user, db)


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
        deck.likes_count = max(0, deck.likes_count - 1)
        liked = False
    else:
        db.add(DeckLike(deck_id=deck.id, user_id=user.id))
        deck.likes_count += 1
        liked = True
    db.commit()
    return {"deck_id": deck.id, "likes": deck.likes_count, "liked_by_me": liked}


@router.get("/community/decks")
def community_decks(
    page: int = 1,
    size: int = 20,
    viewer: User | None = Depends(optional_user),
    db: Session = Depends(get_db),
):
    query = (
        select(Deck)
        .where(Deck.is_public.is_(True), Deck.moderation_status == "published")
        .order_by(Deck.likes_count.desc(), Deck.updated_at.desc())
    )
    decks = db.scalars(query.offset((max(page, 1) - 1) * size).limit(min(size, 50))).all()
    return [deck_out(d, viewer, db) for d in decks]
