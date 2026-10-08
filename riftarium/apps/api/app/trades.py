"""Échanges entre joueurs : logique de domaine (contrat dans docs/echanges.md).

Le routeur (routers/trades.py) reste mince : correspondances, recalage des
offres sur la collection, machine à états des demandes et sérialiseurs vivent
ici. La base SQLite des tests n'applique pas les clés étrangères : toute
cascade est donc aussi faite par le code.
"""

from __future__ import annotations

from sqlalchemy import delete, or_, select, update
from sqlalchemy.orm import Session

from .models import CollectionItem, TradeOffer, TradeRequest, User, utcnow
from .routers.cards import card_out


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


# ---------- Offres ----------


def _drop_offers(db: Session, offer_ids: list[int]) -> None:
    """Supprime des offres : leurs demandes en attente sont annulées, les autres détachées."""
    if not offer_ids:
        return
    db.execute(
        update(TradeRequest)
        .where(TradeRequest.trade_offer_id.in_(offer_ids), TradeRequest.status == "pending")
        .values(status="cancelled", responded_at=utcnow())
        .execution_options(synchronize_session=False)
    )
    db.execute(
        update(TradeRequest)
        .where(TradeRequest.trade_offer_id.in_(offer_ids))
        .values(trade_offer_id=None)
        .execution_options(synchronize_session=False)
    )
    db.execute(delete(TradeOffer).where(TradeOffer.id.in_(offer_ids)).execution_options(synchronize_session=False))


def remove_offer(db: Session, offer: TradeOffer) -> None:
    _drop_offers(db, [offer.id])


def sync_offers(db: Session, user_id: int) -> None:
    """Recale les offres d'un compte sur sa collection, après toute modification de lots.

    Lot disparu (supprimé, fusionné dans un autre) : l'offre part et ses demandes
    en attente sont annulées. Lot diminué : l'offre est ramenée à sa quantité.
    En production, PostgreSQL a déjà supprimé l'offre (CASCADE) et détaché ses
    demandes (SET NULL) au flush : les demandes en attente sans offre sont donc
    annulées elles aussi.
    """
    db.flush()
    gone: list[int] = []
    for item in db.scalars(select(TradeOffer).where(TradeOffer.user_id == user_id)).all():
        entry = db.get(CollectionItem, item.collection_item_id)
        if entry is None or entry.user_id != user_id:
            gone.append(item.id)
        elif item.qty > entry.qty:
            item.qty = entry.qty
    _drop_offers(db, gone)
    db.execute(
        update(TradeRequest)
        .where(
            TradeRequest.owner_id == user_id,
            TradeRequest.status == "pending",
            TradeRequest.trade_offer_id.is_(None),
        )
        .values(status="cancelled", responded_at=utcnow())
        .execution_options(synchronize_session=False)
    )


def offer_out(item: TradeOffer) -> dict:
    """Une offre de ma liste « À échanger »."""
    entry = item.entry
    return {
        "id": item.id,
        "entry_id": entry.id,
        "card": card_out(entry.card),
        "condition": entry.condition,
        "lang": entry.lang,
        "qty": item.qty,
        "entry_qty": entry.qty,
        "created_at": _iso(item.created_at),
    }
