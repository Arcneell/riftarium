"""Compte joueur : avatar Légende, stats, export et suppression."""

from datetime import UTC, datetime

from fastapi import HTTPException
from sqlalchemy import delete, func, select, update
from sqlalchemy.orm import Session

from .models import AuthToken, Card, CollectionItem, Deck, DeckCard, DeckLike, DeckView, User, WishlistItem
from .moderation import review
from .security import sanitize_image_url


def avatar_urls(db: Session, users: list[User]) -> dict[int, str | None]:
    ids = {user.avatar_card_id for user in users if user.avatar_card_id}
    cards: dict[str, str | None] = {}
    if ids:
        rows = db.scalars(select(Card).where(Card.id.in_(ids))).all()
        cards = {card.id: sanitize_image_url(card.image_url) for card in rows}
    return {user.id: cards.get(user.avatar_card_id) if user.avatar_card_id else None for user in users}


def find_avatar_card(db: Session, card_id: str) -> Card | None:
    card = db.get(Card, card_id)
    if (
        card is None
        or card.type != "Legend"
        or card.alternate_art
        or card.signature
        or card.overnumbered
        or not card.image_url
    ):
        return None
    return card


def user_stats(db: Session, user: User) -> dict:
    unique, total = db.execute(
        select(func.count(func.distinct(CollectionItem.card_id)), func.coalesce(func.sum(CollectionItem.qty), 0)).where(
            CollectionItem.user_id == user.id
        )
    ).one()
    decks = db.scalar(select(func.count()).select_from(Deck).where(Deck.owner_id == user.id)) or 0
    public = (
        db.scalar(select(func.count()).select_from(Deck).where(Deck.owner_id == user.id, Deck.is_public.is_(True))) or 0
    )
    likes = db.scalar(select(func.coalesce(func.sum(Deck.likes_count), 0)).where(Deck.owner_id == user.id)) or 0
    return {
        "unique_cards": unique,
        "total_cards": int(total),
        "decks": decks,
        "public_decks": public,
        "likes_received": int(likes),
    }


def user_out(db: Session, user: User, *, include_email: bool = False, include_stats: bool = False) -> dict:
    payload = {
        "id": user.id,
        "handle": user.handle,
        "bio": user.bio or "",
        "avatar_card_id": user.avatar_card_id,
        "avatar_url": avatar_urls(db, [user]).get(user.id),
        "created_at": user.created_at.isoformat() if user.created_at else None,
    }
    if include_email:
        payload["email"] = user.email
        payload["email_verified"] = user.email_verified_at is not None
        payload["notify_moderation"] = user.notify_moderation
        payload["is_admin"] = user.is_admin
    if include_stats:
        payload["stats"] = user_stats(db, user)
    return payload


def list_legend_avatars(db: Session) -> list[dict]:
    rows = db.scalars(
        select(Card)
        .where(
            Card.type == "Legend",
            Card.alternate_art.is_(False),
            Card.signature.is_(False),
            Card.overnumbered.is_(False),
        )
        .order_by(Card.name, Card.id)
    ).all()
    seen: set[str] = set()
    avatars: list[dict] = []
    for card in rows:
        if not card.image_url:
            continue
        key = (card.name or "").lower()
        if key in seen:
            continue
        seen.add(key)
        avatars.append(
            {
                "id": card.id,
                "name": card.name,
                "image_url": sanitize_image_url(card.image_url),
                "orientation": card.orientation,
                "domains": card.domains or [],
            }
        )
    return avatars


def apply_profile(db: Session, user: User, data: dict) -> None:
    if "bio" in data:
        bio = (data["bio"] or "").strip()
        if review(bio) != "published":
            raise HTTPException(status_code=422, detail="Cette biographie n'est pas autorisée")
        user.bio = bio
    if "avatar_card_id" in data:
        card_id = data["avatar_card_id"]
        if not card_id:
            user.avatar_card_id = None
        elif find_avatar_card(db, card_id) is None:
            raise HTTPException(status_code=422, detail="Avatar invalide : choisissez une légende de la liste")
        else:
            user.avatar_card_id = card_id
    if "notify_moderation" in data:
        user.notify_moderation = bool(data["notify_moderation"])
    if "handle" in data and data["handle"] != user.handle:
        if review(data["handle"]) != "published":
            raise HTTPException(status_code=422, detail="Ce pseudo n'est pas autorisé")
        taken = db.scalar(select(User).where(User.handle == data["handle"], User.id != user.id))
        if taken:
            raise HTTPException(status_code=409, detail="Cette valeur est déjà utilisée")
        user.handle = data["handle"]
    if "email" in data and data["email"] != user.email:
        taken = db.scalar(select(User).where(User.email == data["email"], User.id != user.id))
        if taken:
            raise HTTPException(status_code=409, detail="Cette valeur est déjà utilisée")
        user.email = data["email"]
        user.email_verified_at = None  # la nouvelle adresse devra être vérifiée à son tour


def export_account(db: Session, user: User) -> dict:
    """Export RGPD : toutes les données rattachées au compte, sans exception.

    Doit rester aligné sur delete_user_account — ce qui est supprimé à la clôture
    du compte est de la donnée détenue, donc de la donnée exportable.
    """
    items = db.scalars(select(CollectionItem).where(CollectionItem.user_id == user.id)).all()
    wishes = db.scalars(
        select(WishlistItem).where(WishlistItem.user_id == user.id).order_by(WishlistItem.created_at)
    ).all()
    decks = db.scalars(select(Deck).where(Deck.owner_id == user.id).order_by(Deck.updated_at.desc())).all()
    return {
        "handle": user.handle,
        "email": user.email,
        "bio": user.bio or "",
        "avatar_card_id": user.avatar_card_id,
        "exported_at": datetime.now(UTC).isoformat(),
        "collection": [
            {"card_id": item.card_id, "qty": item.qty, "condition": item.condition, "lang": item.lang} for item in items
        ],
        "wishlist": [
            {
                "card_id": wish.card_id,
                "qty": wish.qty,
                "created_at": wish.created_at.isoformat() if wish.created_at else None,
            }
            for wish in wishes
        ],
        "decks": [
            {
                "name": deck.name,
                "description": deck.description,
                "format": deck.format,
                "is_public": deck.is_public,
                "cards": [{"card_id": entry.card_id, "qty": entry.qty} for entry in deck.cards],
            }
            for deck in decks
        ],
    }


def delete_user_account(db: Session, user: User) -> None:
    liked_ids = list(db.scalars(select(DeckLike.deck_id).where(DeckLike.user_id == user.id)).all())
    if liked_ids:
        # Décrément côté serveur : pas de lecture-modification-écriture concurrente.
        db.execute(
            update(Deck)
            .where(Deck.id.in_(liked_ids), Deck.owner_id != user.id, Deck.likes_count > 0)
            .values(likes_count=Deck.likes_count - 1)
            .execution_options(synchronize_session=False)
        )
    db.execute(delete(DeckLike).where(DeckLike.user_id == user.id))
    db.execute(delete(AuthToken).where(AuthToken.user_id == user.id))
    db.execute(delete(CollectionItem).where(CollectionItem.user_id == user.id))
    db.execute(delete(WishlistItem).where(WishlistItem.user_id == user.id))
    db.execute(delete(DeckView).where(DeckView.visitor_key == f"u:{user.id}"))
    owned_ids = list(db.scalars(select(Deck.id).where(Deck.owner_id == user.id)).all())
    if owned_ids:
        db.execute(delete(DeckLike).where(DeckLike.deck_id.in_(owned_ids)))
        db.execute(delete(DeckView).where(DeckView.deck_id.in_(owned_ids)))
        db.execute(delete(DeckCard).where(DeckCard.deck_id.in_(owned_ids)))
        db.execute(delete(Deck).where(Deck.id.in_(owned_ids)))
    db.delete(user)
