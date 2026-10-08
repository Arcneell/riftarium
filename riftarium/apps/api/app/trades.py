"""Échanges entre joueurs : logique de domaine (contrat dans docs/echanges.md).

Le routeur (routers/trades.py) reste mince : correspondances, recalage des
offres sur la collection, machine à états des demandes et sérialiseurs vivent
ici. La base SQLite des tests n'applique pas les clés étrangères : toute
cascade est donc aussi faite par le code.
"""

from __future__ import annotations

from sqlalchemy import delete, or_, select, update
from sqlalchemy.orm import Session

from .models import TradeOffer, TradeRequest, User, utcnow


def _iso(moment) -> str | None:
    return moment.isoformat() if moment else None


def cancel_pending_for_user(db: Session, user_id: int) -> int:
    """Annule les demandes en attente reçues et envoyées (désinscription des échanges)."""
    result = db.execute(
        update(TradeRequest)
        .where(
            TradeRequest.status == "pending",
            or_(TradeRequest.requester_id == user_id, TradeRequest.owner_id == user_id),
        )
        .values(status="cancelled", responded_at=utcnow())
        .execution_options(synchronize_session=False)
    )
    return result.rowcount or 0


def delete_user_trades(db: Session, user_id: int) -> None:
    """Clôture du compte : ses demandes (des deux côtés) puis ses offres."""
    db.execute(delete(TradeRequest).where(or_(TradeRequest.requester_id == user_id, TradeRequest.owner_id == user_id)))
    db.execute(delete(TradeOffer).where(TradeOffer.user_id == user_id))


def export_trades(db: Session, user: User) -> dict:
    """Export RGPD : réglages, offres et demandes, sans le contact de l'autre partie."""
    offers = db.scalars(select(TradeOffer).where(TradeOffer.user_id == user.id).order_by(TradeOffer.id)).all()
    requests = db.scalars(
        select(TradeRequest)
        .where(or_(TradeRequest.requester_id == user.id, TradeRequest.owner_id == user.id))
        .order_by(TradeRequest.id)
    ).all()
    return {
        "enabled": bool(user.trade_enabled),
        "zone": user.trade_zone,
        "contact": user.trade_contact,
        "notify": bool(user.notify_trades),
        "offers": [
            {
                "card_id": item.entry.card_id,
                "condition": item.entry.condition,
                "lang": item.entry.lang,
                "qty": item.qty,
            }
            for item in offers
        ],
        "requests": [
            {
                "box": "out" if req.requester_id == user.id else "in",
                "card_id": req.card_id,
                "condition": req.condition,
                "lang": req.lang,
                "message": req.message,
                "status": req.status,
                "created_at": _iso(req.created_at),
            }
            for req in requests
        ],
    }
