"""Profils publics, hauts faits et amis.

Un réseau social sans publication : on ne poste rien, on montre son profil, ses
hauts faits et — si on l'autorise — ses stats de duels, sa collection et ses
decks publics. Les « amis » sont des suivis unilatéraux, sans messagerie.
Contrat commun avec le mobile et le web : docs/profils-et-hauts-faits.md.
"""

from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, Query, Request
from sqlalchemy import func, or_, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from ..achievements import evaluate_achievements, unlocked_achievements
from ..auth import current_user, ensure_not_suspended, optional_user
from ..db import get_db
from ..models import Card, CardSet, CollectionItem, Deck, Follow, Match, MatchPlayer, User, utcnow
from ..profiles import avatar_urls
from ..schemas import AchievementOut, FollowsOut, PublicProfileOut, PublicUserOut
from ..security import allow_rate, client_ip
from .cards import card_out, escape_like
from .collection import my_collection
from .play import _iso, my_history, my_stats

router = APIRouter(prefix="/api", tags=["users"])

SEARCH_LIMIT = 10
SEARCH_RATE_LIMIT = 20  # recherches par minute et par IP (même cadence que les salons)
PROFILE_LEGENDS = 5  # légendes les plus jouées affichées sur le profil public
UNKNOWN_USER = "Joueur introuvable"


def limit_search(request: Request) -> None:
    """Rate limit de la recherche de joueurs : même mécanique que limit_play, compteur dédié."""
    if not allow_rate(f"search:{client_ip(request)}", SEARCH_RATE_LIMIT):
        raise HTTPException(status_code=429, detail="Trop de recherches — réessayez dans une minute")


def _suspended(user: User) -> bool:
    """Suspension en cours : réutilise la règle d'auth (une suspension expirée ne compte pas)."""
    try:
        ensure_not_suspended(user)
    except HTTPException:
        return True
    return False


def _not_suspended_clause():
    """Comptes visibles publiquement : jamais suspendus, ou suspension expirée."""
    return or_(User.suspended_until.is_(None), User.suspended_until <= utcnow())


def load_public_user(db: Session, handle: str) -> User:
    """Compte visité, par pseudo (casse ignorée). Un compte suspendu n'existe pas ici."""
    target = db.scalar(select(User).where(func.lower(User.handle) == (handle or "").strip().lower()))
    if target is None or _suspended(target):
        raise HTTPException(status_code=404, detail=UNKNOWN_USER)
    return target


def _ensure_visible(target: User, viewer: User | None, allowed: bool, message: str) -> None:
    """Une section masquée reste accessible à son propriétaire, 403 pour les autres."""
    if allowed or (viewer is not None and viewer.id == target.id):
        return
    raise HTTPException(status_code=403, detail=message)


def _public_user_out(db: Session, users: list[User]) -> list[dict]:
    avatars = avatar_urls(db, users)
    return [{"id": user.id, "handle": user.handle, "avatar_url": avatars.get(user.id)} for user in users]


def _follow_counts(db: Session, target: User) -> tuple[int, int]:
    followers = db.scalar(select(func.count()).select_from(Follow).where(Follow.followed_id == target.id)) or 0
    following = db.scalar(select(func.count()).select_from(Follow).where(Follow.follower_id == target.id)) or 0
    return int(followers), int(following)


def _collection_summary(db: Session, target: User) -> dict:
    """Résumé de collection : totaux et avancement par set, en trois agrégats."""
    unique_cards, total_cards = db.execute(
        select(func.count(func.distinct(CollectionItem.card_id)), func.coalesce(func.sum(CollectionItem.qty), 0)).where(
            CollectionItem.user_id == target.id
        )
    ).one()
    totals = dict(db.execute(select(Card.set_id, func.count()).group_by(Card.set_id)).all())
    owned = dict(
        db.execute(
            select(Card.set_id, func.count(func.distinct(Card.id)))
            .join(CollectionItem, CollectionItem.card_id == Card.id)
            .where(CollectionItem.user_id == target.id)
            .group_by(Card.set_id)
        ).all()
    )
    sets = [
        {
            "set_id": card_set.set_id,
            "name": card_set.name,
            "owned": int(owned.get(card_set.set_id, 0)),
            "total": int(totals.get(card_set.set_id, 0)),
        }
        for card_set in db.scalars(select(CardSet).order_by(CardSet.published_on, CardSet.set_id))
        if totals.get(card_set.set_id)
    ]
    return {"unique_cards": int(unique_cards), "total_cards": int(total_cards), "sets": sets}


def _public_decks(db: Session, target: User) -> list[dict]:
    """Decks publics du joueur : résumé (la fiche complète reste sur /api/decks/{id})."""
    decks = db.scalars(
        select(Deck)
        .where(Deck.owner_id == target.id, Deck.is_public.is_(True), Deck.moderation_status == "published")
        .order_by(Deck.likes_count.desc(), Deck.updated_at.desc(), Deck.id)
    ).all()
    payload = []
    for deck in decks:
        legend = next((entry.card for entry in deck.cards if entry.card.type == "Legend"), None)
        payload.append(
            {
                "id": deck.id,
                "name": deck.name,
                "format": deck.format,
                "legend": card_out(legend) if legend is not None else None,
                "likes": deck.likes_count,
            }
        )
    return payload


# --------------------------------------------------------------------------- profils publics


# Déclarée avant /users/{handle} : « search » serait sinon capturé comme un pseudo.
@router.get("/users/search", response_model=list[PublicUserOut])
def search_users(
    request: Request,
    q: str = Query(min_length=2, max_length=32),
    db: Session = Depends(get_db),
):
    """Jusqu'à 10 comptes dont le pseudo commence par `q` (casse ignorée, suspendus exclus)."""
    limit_search(request)
    needle = f"{escape_like(q.strip().lower())}%"
    users = db.scalars(
        select(User)
        .where(func.lower(User.handle).like(needle, escape="\\"), _not_suspended_clause())
        .order_by(User.handle)
        .limit(SEARCH_LIMIT)
    ).all()
    return _public_user_out(db, list(users))


@router.get("/users/{handle}", response_model=PublicProfileOut)
def public_profile(
    handle: str,
    viewer: User | None = Depends(optional_user),
    db: Session = Depends(get_db),
):
    """Profil public : les sections que le joueur n'expose pas valent null."""
    target = load_public_user(db, handle)
    is_me = viewer is not None and viewer.id == target.id
    followers_count, following_count = _follow_counts(db, target)
    # Le profil est le point de passage obligé : on en profite pour enregistrer
    # les hauts faits atteints depuis la dernière visite.
    evaluate_achievements(db, target)

    stats = None
    if target.show_stats or is_me:
        full = my_stats(user=target, db=db)
        stats = {"totals": full["totals"], "by_legend": full["by_legend"][:PROFILE_LEGENDS]}

    is_followed = None
    if viewer is not None:
        is_followed = (
            db.scalar(
                select(func.count())
                .select_from(Follow)
                .where(Follow.follower_id == viewer.id, Follow.followed_id == target.id)
            )
            or 0
        ) > 0

    return {
        "id": target.id,
        "handle": target.handle,
        "avatar_url": avatar_urls(db, [target]).get(target.id),
        "bio": target.bio or "",
        "created_at": _iso(target.created_at),
        "is_me": is_me,
        "is_followed": is_followed,
        "followers_count": followers_count,
        "following_count": following_count,
        "visibility": {
            "show_stats": bool(target.show_stats),
            "show_collection": bool(target.show_collection),
            "show_decks": bool(target.show_decks),
            "show_achievements": bool(target.show_achievements),
        },
        "stats": stats,
        "achievements": unlocked_achievements(db, target) if (target.show_achievements or is_me) else None,
        "collection_summary": _collection_summary(db, target) if (target.show_collection or is_me) else None,
        "decks": _public_decks(db, target) if (target.show_decks or is_me) else None,
    }


@router.get("/users/{handle}/collection")
def public_collection(
    handle: str,
    q: str | None = None,
    set_id: str | None = None,
    page: int = Query(1, ge=1),
    size: int = Query(30, ge=1, le=100),
    viewer: User | None = Depends(optional_user),
    db: Session = Depends(get_db),
):
    """Collection du joueur, même forme que /api/collection mais sans les lots détaillés."""
    target = load_public_user(db, handle)
    _ensure_visible(target, viewer, bool(target.show_collection), "Ce joueur ne partage pas sa collection")
    payload = my_collection(
        q=q,
        set_id=set_id,
        type_=None,
        domain=None,
        rarity=None,
        energy=None,
        sort=None,
        page=page,
        size=size,
        user=target,
        db=db,
    )
    for item in payload["items"]:  # les états et langues possédés ne regardent que le propriétaire
        item.pop("entries", None)
    return payload


@router.get("/users/{handle}/history")
def public_history(
    handle: str,
    page: int = Query(1, ge=1),
    size: int = Query(20, ge=1, le=50),
    viewer: User | None = Depends(optional_user),
    db: Session = Depends(get_db),
):
    """Historique des matchs suivis, du point de vue du profil consulté."""
    target = load_public_user(db, handle)
    _ensure_visible(target, viewer, bool(target.show_stats), "Ce joueur ne partage pas ses parties")
    return my_history(page=page, size=size, user=target, db=db)


# --------------------------------------------------------------------------- hauts faits


@router.get("/me/achievements", response_model=list[AchievementOut])
def my_achievements(user: User = Depends(current_user), db: Session = Depends(get_db)):
    """Tout le catalogue avec ma progression ; les déblocages atteints sont enregistrés."""
    return evaluate_achievements(db, user)


# --------------------------------------------------------------------------- amis


@router.get("/me/follows", response_model=FollowsOut)
def my_follows(user: User = Depends(current_user), db: Session = Depends(get_db)):
    """Mon carnet : les joueurs que je suis (avec leur dernier match) et mes abonnés."""
    following = list(
        db.scalars(
            select(User)
            .join(Follow, Follow.followed_id == User.id)
            .where(Follow.follower_id == user.id)
            .order_by(Follow.created_at.desc(), User.handle)
        ).all()
    )
    followers = list(
        db.scalars(
            select(User)
            .join(Follow, Follow.follower_id == User.id)
            .where(Follow.followed_id == user.id)
            .order_by(Follow.created_at.desc(), User.handle)
        ).all()
    )
    last_match: dict[int, str | None] = {}
    if following:
        rows = db.execute(
            select(MatchPlayer.user_id, func.max(func.coalesce(Match.ended_at, Match.started_at)))
            .join(Match, Match.id == MatchPlayer.match_id)
            .where(MatchPlayer.user_id.in_([item.id for item in following]))
            .group_by(MatchPlayer.user_id)
        ).all()
        last_match = {user_id: _iso(moment) for user_id, moment in rows}
    return {
        "following": [
            {**payload, "last_match_at": last_match.get(payload["id"])} for payload in _public_user_out(db, following)
        ],
        "followers": _public_user_out(db, followers),
    }


@router.put("/users/{handle}/follow", status_code=204)
def follow_user(handle: str, user: User = Depends(current_user), db: Session = Depends(get_db)):
    """Suit un joueur. Idempotent : suivre deux fois ne change rien et répond 204."""
    target = load_public_user(db, handle)
    if target.id == user.id:
        raise HTTPException(status_code=409, detail="Vous ne pouvez pas vous suivre vous-même")
    existing = db.scalar(select(Follow).where(Follow.follower_id == user.id, Follow.followed_id == target.id))
    if existing is not None:
        return
    db.add(Follow(follower_id=user.id, followed_id=target.id))
    try:
        db.commit()
    except IntegrityError:  # course entre deux clics : le suivi existe déjà, tant mieux
        db.rollback()


@router.delete("/users/{handle}/follow", status_code=204)
def unfollow_user(handle: str, user: User = Depends(current_user), db: Session = Depends(get_db)):
    """Ne suit plus un joueur. Idempotent lui aussi."""
    target = load_public_user(db, handle)
    existing = db.scalar(select(Follow).where(Follow.follower_id == user.id, Follow.followed_id == target.id))
    if existing is not None:
        db.delete(existing)
        db.commit()
