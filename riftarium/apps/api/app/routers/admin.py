"""Administration du site : statistiques, comptes, suspension et modération des decks.

Accès réservé aux comptes marqués is_admin, pilotés exclusivement par la variable
d'environnement ADMIN_EMAILS (source de vérité unique, appliquée au démarrage :
voir sync_admin_flags). Ces routes complètent — sans les remplacer — les endpoints
X-Admin-Token de app/main.py (sync, secours), utilisables sans compte.
"""

import logging
from datetime import UTC, datetime, timedelta

from fastapi import APIRouter, Depends, Header, HTTPException, Query, Request
from fastapi.security import HTTPAuthorizationCredentials
from sqlalchemy import func, or_, select
from sqlalchemy.orm import Session

from .. import mailer
from ..auth import bearer, current_user, optional_user
from ..config import settings
from ..db import get_db
from ..models import Card, CardSet, CollectionItem, Deck, PageHit, User, utcnow
from ..profiles import delete_user_account
from ..schemas import ModerationIn, SuspendIn
from ..security import enforce_same_origin, require_admin_token
from .cards import escape_like

log = logging.getLogger("riftarium")

router = APIRouter(prefix="/api/admin", tags=["admin"])

MODERATION_STATUSES = ("pending", "published", "rejected")


def admin_email_allowlist() -> set[str]:
    """Adresses admin déclarées dans ADMIN_EMAILS (séparées par des virgules, casse ignorée)."""
    return {part.strip().lower() for part in settings.admin_emails.split(",") if part.strip()}


def sync_admin_flags(db: Session) -> None:
    """Aligne users.is_admin sur ADMIN_EMAILS (appelé au démarrage).

    La variable d'environnement est la seule source de vérité : le drapeau est
    accordé aux comptes listés et retiré aux autres. Chaque changement est loggé.
    """
    wanted = admin_email_allowlist()
    changed = False
    for user in db.scalars(select(User).where(User.is_admin.is_(True))).all():
        if user.email.lower() not in wanted:
            user.is_admin = False
            changed = True
            log.info("droits admin retirés à %s (%s) : absent de ADMIN_EMAILS", user.handle, user.email)
    if wanted:
        rows = db.scalars(select(User).where(func.lower(User.email).in_(wanted), User.is_admin.is_(False))).all()
        for user in rows:
            user.is_admin = True
            changed = True
            log.info("droits admin accordés à %s (%s) via ADMIN_EMAILS", user.handle, user.email)
    if changed:
        db.commit()


def require_admin_user(
    request: Request,
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer),
    db: Session = Depends(get_db),
) -> User:
    """Session authentifiée (current_user) ET compte administrateur, sinon 403.

    Toute défaillance (non connecté, jeton invalide, compte suspendu, non admin)
    répond uniformément 403 « Accès réservé » : la zone admin ne révèle rien.
    """
    try:
        user = current_user(request, credentials, db)
    except HTTPException:
        raise HTTPException(status_code=403, detail="Accès réservé") from None
    if not user.is_admin:
        raise HTTPException(status_code=403, detail="Accès réservé")
    return user


def apply_deck_moderation(db: Session, deck_id: int, status: str) -> dict:
    """Décision de modération sur un deck (partagée avec l'endpoint X-Admin-Token de main.py).

    Quand la décision sort le deck de la file « pending », le propriétaire est
    prévenu par e-mail en arrière-plan (thread du mailer, pas BackgroundTasks :
    cette fonction est aussi appelable hors contexte requête). Jamais bloquant.
    """
    deck = db.get(Deck, deck_id)
    if deck is None:
        raise HTTPException(status_code=404, detail="Deck introuvable")
    previous = deck.moderation_status
    deck.moderation_status = "published" if status == "approved" else "rejected"
    db.commit()
    if previous == "pending" and deck.moderation_status != previous:
        _notify_moderation_outcome(deck)
    return {"deck_id": deck.id, "moderation_status": deck.moderation_status}


def _notify_moderation_outcome(deck: Deck) -> None:
    """Notifie le propriétaire, seulement si son adresse est vérifiée et la préférence active."""
    owner = deck.owner
    if owner is None or owner.email_verified_at is None or not owner.notify_moderation:
        return
    approved = deck.moderation_status == "published"
    mailer.send_moderation_email_async(owner.email, deck.name, deck.id, approved)


def _iso(value: datetime | None) -> str | None:
    return value.isoformat() if value else None


def _visits_stats(db: Session, now: datetime) -> dict:
    """Fréquentation agrégée (page_hits) : totaux glissants et détail des 30 derniers jours."""
    today = now.date()
    since_7d = today - timedelta(days=6)
    since_30d = today - timedelta(days=29)
    rows = db.execute(
        select(PageHit.day, func.sum(PageHit.hits), func.sum(PageHit.uniques))
        .where(PageHit.day >= since_30d)
        .group_by(PageHit.day)
        .order_by(PageHit.day)
    ).all()
    daily = [{"day": day.isoformat(), "hits": int(hits), "uniques": int(uniques)} for day, hits, uniques in rows]
    sections = db.execute(
        select(PageHit.section, func.sum(PageHit.hits))
        .where(PageHit.day >= since_7d, PageHit.section != "site", PageHit.hits > 0)
        .group_by(PageHit.section)
        .order_by(func.sum(PageHit.hits).desc())
    ).all()
    last_7d = [entry for entry in daily if entry["day"] >= since_7d.isoformat()]
    today_entry = next((entry for entry in daily if entry["day"] == today.isoformat()), None)
    return {
        "today_hits": today_entry["hits"] if today_entry else 0,
        "hits_7d": sum(entry["hits"] for entry in last_7d),
        "hits_30d": sum(entry["hits"] for entry in daily),
        "uniques_today": today_entry["uniques"] if today_entry else 0,
        "uniques_7d": sum(entry["uniques"] for entry in last_7d),
        "daily": daily,
        "sections_7d": [{"section": section, "hits": int(hits)} for section, hits in sections],
    }


def _daily_series(db: Session, column, now: datetime, days: int = 30) -> list[dict]:
    """Comptes par jour sur les `days` derniers jours, jours vides à zéro (pour les graphiques)."""
    start = (now - timedelta(days=days - 1)).date()
    rows = db.execute(select(func.date(column), func.count()).where(column >= start).group_by(func.date(column))).all()
    # func.date() renvoie un objet date (Postgres) ou une chaîne ISO (SQLite) : on normalise.
    counts = {str(day): total for day, total in rows}
    return [
        {"day": str(start + timedelta(days=offset)), "count": counts.get(str(start + timedelta(days=offset)), 0)}
        for offset in range(days)
    ]


@router.get("/stats")
def admin_stats(_admin: User = Depends(require_admin_user), db: Session = Depends(get_db)):
    """Tableau de bord : compteurs globaux et dernières activités."""
    now = datetime.now(UTC)

    def count(model, *where) -> int:
        return db.scalar(select(func.count()).select_from(model).where(*where)) or 0

    signups = db.scalars(select(User).order_by(User.created_at.desc(), User.id.desc()).limit(10)).all()
    recent_decks = db.scalars(select(Deck).order_by(Deck.created_at.desc(), Deck.id.desc()).limit(10)).all()
    entries_total, cards_total = db.execute(
        select(func.count(), func.coalesce(func.sum(CollectionItem.qty), 0)).select_from(CollectionItem)
    ).one()
    likes_total, views_total = db.execute(
        select(func.coalesce(func.sum(Deck.likes_count), 0), func.coalesce(func.sum(Deck.views_count), 0))
    ).one()
    return {
        "users": {
            "total": count(User),
            "new_7d": count(User, User.created_at >= now - timedelta(days=7)),
            "new_30d": count(User, User.created_at >= now - timedelta(days=30)),
            "suspended": count(User, User.suspended_until > now),
            "verified": count(User, User.email_verified_at.is_not(None)),
        },
        "decks": {
            "total": count(Deck),
            "public": count(Deck, Deck.is_public.is_(True)),
            "pending": count(Deck, Deck.moderation_status == "pending"),
            "published": count(Deck, Deck.moderation_status == "published"),
            "rejected": count(Deck, Deck.moderation_status == "rejected"),
            "likes_total": int(likes_total),
            "views_total": int(views_total),
        },
        "collection": {"entries_total": entries_total, "cards_total": int(cards_total)},
        "cards": {"total": count(Card), "sets": count(CardSet)},
        "visits": _visits_stats(db, now),
        # Séries quotidiennes (30 jours, jours vides à zéro) pour les graphiques.
        "series": {
            "signups_daily": _daily_series(db, User.created_at, now),
            "decks_daily": _daily_series(db, Deck.created_at, now),
        },
        "recent": {
            "signups": [{"handle": user.handle, "created_at": _iso(user.created_at)} for user in signups],
            "decks": [
                {
                    "id": deck.id,
                    "name": deck.name,
                    "owner": deck.owner.handle if deck.owner else None,
                    "moderation_status": deck.moderation_status,
                    "created_at": _iso(deck.created_at),
                }
                for deck in recent_decks
            ],
        },
    }


@router.get("/users")
def admin_list_users(
    q: str | None = None,
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=50),
    _admin: User = Depends(require_admin_user),
    db: Session = Depends(get_db),
):
    """Liste paginée des comptes, recherche sur pseudo OU e-mail (insensible à la casse)."""
    query = select(User)
    if q:
        needle = f"%{escape_like(q.strip().lower())}%"
        query = query.where(
            or_(
                func.lower(User.handle).like(needle, escape="\\"),
                func.lower(User.email).like(needle, escape="\\"),
            )
        )
    total = db.scalar(select(func.count()).select_from(query.subquery())) or 0
    users = db.scalars(
        query.order_by(User.created_at.desc(), User.id.desc()).offset((page - 1) * page_size).limit(page_size)
    ).all()

    ids = [user.id for user in users]
    decks_counts: dict[int, int] = {}
    collection_counts: dict[int, int] = {}
    if ids:
        decks_counts = dict(
            db.execute(select(Deck.owner_id, func.count()).where(Deck.owner_id.in_(ids)).group_by(Deck.owner_id)).all()
        )
        collection_counts = dict(
            db.execute(
                select(CollectionItem.user_id, func.count())
                .where(CollectionItem.user_id.in_(ids))
                .group_by(CollectionItem.user_id)
            ).all()
        )
    return {
        "total": total,
        "page": page,
        "size": page_size,
        "items": [
            {
                "id": user.id,
                "handle": user.handle,
                "email": user.email,
                "created_at": _iso(user.created_at),
                "email_verified": user.email_verified_at is not None,
                "is_admin": user.is_admin,
                "suspended_until": _iso(user.suspended_until),
                "suspension_reason": user.suspension_reason,
                "decks_count": decks_counts.get(user.id, 0),
                "collection_count": collection_counts.get(user.id, 0),
            }
            for user in users
        ],
    }


def _get_target_user(db: Session, user_id: int) -> User:
    target = db.get(User, user_id)
    if target is None:
        raise HTTPException(status_code=404, detail="Utilisateur introuvable")
    return target


@router.post("/users/{user_id}/suspend", status_code=204)
def admin_suspend_user(
    user_id: int,
    payload: SuspendIn,
    admin: User = Depends(require_admin_user),
    db: Session = Depends(get_db),
    _: None = Depends(enforce_same_origin),
):
    """Suspend un compte : login et sessions refusés jusqu'à la date calculée."""
    target = _get_target_user(db, user_id)
    if target.id == admin.id:
        raise HTTPException(status_code=400, detail="Impossible de suspendre votre propre compte")
    target.suspended_until = utcnow() + timedelta(hours=payload.hours)
    target.suspension_reason = payload.reason
    db.commit()
    log.info(
        "admin %s (#%s) : suspension de %s (#%s) jusqu'au %s — motif : %s",
        admin.handle,
        admin.id,
        target.handle,
        target.id,
        target.suspended_until.isoformat(),
        payload.reason,
    )


@router.delete("/users/{user_id}/suspend", status_code=204)
def admin_unsuspend_user(
    user_id: int,
    admin: User = Depends(require_admin_user),
    db: Session = Depends(get_db),
    _: None = Depends(enforce_same_origin),
):
    """Lève la suspension d'un compte (sans effet si le compte n'est pas suspendu)."""
    target = _get_target_user(db, user_id)
    target.suspended_until = None
    target.suspension_reason = None
    db.commit()
    log.info("admin %s (#%s) : levée de la suspension de %s (#%s)", admin.handle, admin.id, target.handle, target.id)


@router.delete("/users/{user_id}", status_code=204)
def admin_delete_user(
    user_id: int,
    admin: User = Depends(require_admin_user),
    db: Session = Depends(get_db),
    _: None = Depends(enforce_same_origin),
):
    """Supprime un compte et toutes ses données (decks, collection, likes, jetons)."""
    target = _get_target_user(db, user_id)
    if target.is_admin:  # couvre aussi l'auto-suppression : un admin n'est jamais supprimable ici
        raise HTTPException(status_code=400, detail="Impossible de supprimer un compte administrateur")
    delete_user_account(db, target)
    db.commit()
    log.info("admin %s (#%s) : suppression du compte %s (#%s)", admin.handle, admin.id, target.handle, target.id)


@router.get("/decks")
def admin_list_decks(
    status: str | None = Query(None, pattern="^(pending|published|rejected)$"),
    q: str | None = None,
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=50),
    _admin: User = Depends(require_admin_user),
    db: Session = Depends(get_db),
):
    """Liste paginée des decks (tous statuts), filtrable par statut de modération."""
    query = select(Deck)
    if status:
        query = query.where(Deck.moderation_status == status)
    if q:
        needle = f"%{escape_like(q.strip().lower())}%"
        query = query.where(
            or_(
                func.lower(Deck.name).like(needle, escape="\\"),
                Deck.owner_id.in_(select(User.id).where(func.lower(User.handle).like(needle, escape="\\"))),
            )
        )
    total = db.scalar(select(func.count()).select_from(query.subquery())) or 0
    decks = db.scalars(
        query.order_by(Deck.updated_at.desc(), Deck.id.desc()).offset((page - 1) * page_size).limit(page_size)
    ).all()
    return {
        "total": total,
        "page": page,
        "size": page_size,
        "items": [
            {
                "id": deck.id,
                "name": deck.name,
                "owner": deck.owner.handle if deck.owner else None,
                "is_public": deck.is_public,
                "moderation_status": deck.moderation_status,
                "likes_count": deck.likes_count,
                "views_count": deck.views_count,
                "updated_at": _iso(deck.updated_at),
            }
            for deck in decks
        ],
    }


@router.post("/decks/{deck_id}/moderation")
def admin_moderate_deck(
    deck_id: int,
    payload: ModerationIn,
    x_admin_token: str | None = Header(default=None, alias="X-Admin-Token"),
    user: User | None = Depends(optional_user),
    db: Session = Depends(get_db),
    _: None = Depends(enforce_same_origin),
):
    """Décision de modération sur un deck (débloque les decks « pending »).

    Accepte une session administrateur OU le jeton X-Admin-Token historique
    (secours sans compte) : même chemin, même sémantique, logique partagée.
    """
    if x_admin_token is not None:
        require_admin_token(x_admin_token)
        actor = "jeton X-Admin-Token"
    elif user is not None and user.is_admin:
        actor = f"admin {user.handle} (#{user.id})"
    else:
        raise HTTPException(status_code=403, detail="Accès réservé")
    result = apply_deck_moderation(db, deck_id, payload.status)
    log.info("%s : modération du deck #%s → %s", actor, deck_id, result["moderation_status"])
    return result


@router.delete("/decks/{deck_id}", status_code=204)
def admin_delete_deck(
    deck_id: int,
    admin: User = Depends(require_admin_user),
    db: Session = Depends(get_db),
    _: None = Depends(enforce_same_origin),
):
    """Supprime un deck (cartes, likes et vues associés compris)."""
    deck = db.get(Deck, deck_id)
    if deck is None:
        raise HTTPException(status_code=404, detail="Deck introuvable")
    owner = deck.owner.handle if deck.owner else "?"
    name = deck.name
    db.delete(deck)  # les cascades du modèle emportent deck_cards, deck_likes et deck_views
    db.commit()
    log.info(
        "admin %s (#%s) : suppression du deck #%s (%s, propriétaire %s)", admin.handle, admin.id, deck_id, name, owner
    )
