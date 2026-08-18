from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session

from ..auth import current_user, optional_user
from ..db import get_db
from ..models import Deck, DeckCard, DeckLike, User
from ..moderation import review
from ..schemas import DeckIn
from ..validation import validate_deck
from .cards import card_out, find_card

router = APIRouter(prefix="/api", tags=["decks"])


def deck_out(deck: Deck, viewer: User | None = None, db: Session | None = None) -> dict:
    liked = False
    if viewer and db:
        liked = (
            db.scalar(select(DeckLike).where(DeckLike.deck_id == deck.id, DeckLike.user_id == viewer.id)) is not None
        )
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
        "cards": [{"card": card_out(dc.card), "qty": dc.qty} for dc in deck.cards],
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
