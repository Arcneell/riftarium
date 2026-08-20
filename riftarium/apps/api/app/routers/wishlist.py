"""Wishlist : les cartes recherchées par le joueur (liste d'achats persistante)."""

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session

from ..auth import current_user
from ..db import get_db
from ..models import Deck, User, WishlistItem
from ..prices import current_rate, to_eur
from ..schemas import WishlistPut
from .cards import card_out, find_card, owned_quantities

router = APIRouter(prefix="/api/wishlist", tags=["wishlist"])

MAX_WISH_QTY = 99  # aligné sur le schéma WishlistPut


def find_wish(db: Session, user: User, card_id: str) -> WishlistItem | None:
    return db.scalar(select(WishlistItem).where(WishlistItem.user_id == user.id, WishlistItem.card_id == card_id))


@router.get("")
def my_wishlist(
    user: User = Depends(current_user),
    db: Session = Depends(get_db),
):
    """Toute la wishlist, la plus récente d'abord, avec valeur totale estimée."""
    items = db.scalars(
        select(WishlistItem)
        .where(WishlistItem.user_id == user.id)
        .order_by(WishlistItem.created_at.desc(), WishlistItem.id.desc())
    ).all()
    rate = current_rate(db)
    owned = owned_quantities(db, user, [item.card_id for item in items])

    # Valeur : somme qty × prix des cartes pricées ; null si rien n'est pricé.
    priced = [(item, to_eur(item.card.price_usd, rate)) for item in items]
    known = [(item, price) for item, price in priced if price is not None]
    value_eur = round(sum(item.qty * price for item, price in known), 2) if known else None

    return {
        "total": len(items),
        "value_eur": value_eur,
        "items": [
            {
                "card": card_out(item.card, owned.get(item.card_id, 0), rate, item.qty),
                "qty": item.qty,
                "created_at": item.created_at.isoformat() if item.created_at else None,
            }
            for item in items
        ],
    }


@router.put("/{card_id}", status_code=204)
def set_wish(
    card_id: str,
    payload: WishlistPut,
    user: User = Depends(current_user),
    db: Session = Depends(get_db),
):
    """Upsert : fixe la quantité visée pour la carte (créée si absente de la wishlist)."""
    card = find_card(db, card_id)
    if card is None:
        raise HTTPException(status_code=404, detail="Carte introuvable")
    entry = find_wish(db, user, card.id)
    if entry is None:
        db.add(WishlistItem(user_id=user.id, card_id=card.id, qty=payload.qty))
    else:
        entry.qty = payload.qty
    db.commit()


@router.delete("/{card_id}", status_code=204)
def remove_wish(
    card_id: str,
    user: User = Depends(current_user),
    db: Session = Depends(get_db),
):
    """Retire la carte de la wishlist (sans erreur si elle n'y était pas)."""
    card = find_card(db, card_id)
    if card is None:
        raise HTTPException(status_code=404, detail="Carte introuvable")
    entry = find_wish(db, user, card.id)
    if entry is not None:
        db.delete(entry)
        db.commit()


@router.post("/from-deck/{deck_id}")
def wish_from_deck(
    deck_id: int,
    user: User = Depends(current_user),
    db: Session = Depends(get_db),
):
    """Ajoute à la wishlist les exemplaires manquants pour jouer le deck.

    Deck accessible : le sien, ou public et publié. Manque par identifiant exact
    de carte (qty du deck − qty possédée). Upsert « jusqu'au besoin, pas au-delà » :
    la quantité en wishlist est portée au manque si elle est inférieure, jamais
    réduite — un second appel n'ajoute donc rien (idempotent).
    """
    deck = db.get(Deck, deck_id)
    accessible = deck is not None and (
        deck.owner_id == user.id or (deck.is_public and deck.moderation_status == "published")
    )
    if not accessible:
        raise HTTPException(status_code=404, detail="Deck introuvable")

    card_ids = [dc.card_id for dc in deck.cards]
    owned = owned_quantities(db, user, card_ids)
    existing = {
        entry.card_id: entry
        for entry in db.scalars(
            select(WishlistItem).where(WishlistItem.user_id == user.id, WishlistItem.card_id.in_(card_ids))
        )
    }

    added = 0
    for dc in deck.cards:
        missing = min(MAX_WISH_QTY, max(0, dc.qty - owned.get(dc.card_id, 0)))
        if missing == 0:
            continue
        entry = existing.get(dc.card_id)
        if entry is None:
            db.add(WishlistItem(user_id=user.id, card_id=dc.card_id, qty=missing))
            added += missing
        elif entry.qty < missing:
            added += missing - entry.qty
            entry.qty = missing
    db.commit()
    return {"added": added}
