"""Échanges entre joueurs : offres, correspondances et demandes.

Contrat : docs/echanges.md. La logique vit dans app/trades.py ; ce routeur ne
fait que l'authentification, la validation et la sérialisation.
"""

from typing import Literal

from fastapi import APIRouter, Depends, HTTPException, Query, Response
from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from .. import trades
from ..auth import current_user
from ..db import get_db
from ..models import CollectionItem, TradeOffer, TradeRequest, User
from ..schemas import TradeOfferPut, TradeRequestIn
from ..security import limit_trades

router = APIRouter(prefix="/api/trades", tags=["trades"])


def _my_entry(db: Session, user: User, entry_id: int) -> CollectionItem:
    entry = db.get(CollectionItem, entry_id)
    if entry is None or entry.user_id != user.id:
        raise HTTPException(status_code=404, detail="Lot introuvable")
    return entry


def _offer_of(db: Session, entry: CollectionItem) -> TradeOffer | None:
    return db.scalar(select(TradeOffer).where(TradeOffer.collection_item_id == entry.id))


# ---------- Ma liste « À échanger » ----------


@router.get("/offers")
def my_offers(user: User = Depends(current_user), db: Session = Depends(get_db)):
    items = db.scalars(select(TradeOffer).where(TradeOffer.user_id == user.id).order_by(TradeOffer.created_at)).all()
    return [trades.offer_out(item) for item in items]


@router.put("/offers/{entry_id}", dependencies=[Depends(limit_trades)])
def put_offer(
    entry_id: int,
    payload: TradeOfferPut,
    user: User = Depends(current_user),
    db: Session = Depends(get_db),
):
    entry = _my_entry(db, user, entry_id)
    existing = _offer_of(db, entry)
    if payload.qty == 0:
        if existing is not None:
            trades.remove_offer(db, existing)
            db.commit()
        return Response(status_code=204)
    if payload.qty > entry.qty:
        raise HTTPException(status_code=422, detail=f"Ce lot ne compte que {entry.qty} exemplaire(s)")
    if existing is None:
        existing = TradeOffer(user_id=user.id, collection_item_id=entry.id, qty=payload.qty)
        db.add(existing)
    else:
        existing.qty = payload.qty
    db.commit()
    db.refresh(existing)
    return trades.offer_out(existing)


@router.delete("/offers/{entry_id}", status_code=204, dependencies=[Depends(limit_trades)])
def delete_offer(entry_id: int, user: User = Depends(current_user), db: Session = Depends(get_db)):
    entry = _my_entry(db, user, entry_id)
    existing = _offer_of(db, entry)
    if existing is not None:
        trades.remove_offer(db, existing)
        db.commit()


# ---------- Correspondances ----------

Zone = Literal["nord", "sud", "est", "ouest"]


@router.get("/matches/wanted")
def matches_wanted(
    zone: Zone | None = None,
    q: str = Query(default="", max_length=80),
    page: int = Query(default=1, ge=1),
    size: int = Query(default=24, ge=1, le=48),
    user: User = Depends(current_user),
    db: Session = Depends(get_db),
):
    trades.require_enabled(user)
    return trades.matches_wanted(db, user, zone=zone, q=q, page=page, size=size)


@router.get("/matches/offered")
def matches_offered(
    zone: Zone | None = None,
    page: int = Query(default=1, ge=1),
    size: int = Query(default=24, ge=1, le=48),
    user: User = Depends(current_user),
    db: Session = Depends(get_db),
):
    trades.require_enabled(user)
    return trades.matches_offered(db, user, zone=zone, page=page, size=size)


@router.get("/cards/{card_id}/offers")
def card_offers(
    card_id: str,
    zone: Zone | None = None,
    user: User = Depends(current_user),
    db: Session = Depends(get_db),
):
    trades.require_enabled(user)
    return trades.card_offers(db, user, card_id, zone=zone)


# ---------- Demandes ----------

Status = Literal["pending", "accepted", "declined", "cancelled", "done"]
Action = Literal["accept", "decline", "cancel", "done"]


@router.post("/requests", status_code=201, dependencies=[Depends(limit_trades)])
def create_request(
    payload: TradeRequestIn,
    user: User = Depends(current_user),
    db: Session = Depends(get_db),
):
    req = trades.create_request(db, user, payload.offer_id, payload.message)
    try:
        db.commit()
    except IntegrityError:  # double clic : l'index unique partiel a tranché
        db.rollback()
        raise HTTPException(status_code=409, detail="Vous avez déjà une demande en cours sur cette offre") from None
    db.refresh(req)
    return trades.request_out(db, user, req)


@router.get("/requests/summary")
def requests_summary(user: User = Depends(current_user), db: Session = Depends(get_db)):
    count = db.scalar(
        select(func.count(TradeRequest.id)).where(TradeRequest.owner_id == user.id, TradeRequest.status == "pending")
    )
    return {"incoming_pending": count or 0}


@router.get("/requests")
def list_requests(
    box: Literal["in", "out"] = "in",
    status: Status | None = None,
    page: int = Query(default=1, ge=1),
    size: int = Query(default=20, ge=1, le=50),
    user: User = Depends(current_user),
    db: Session = Depends(get_db),
):
    side = TradeRequest.owner_id if box == "in" else TradeRequest.requester_id
    query = select(TradeRequest).where(side == user.id)
    if status:
        query = query.where(TradeRequest.status == status)
    total = db.scalar(select(func.count()).select_from(query.subquery())) or 0
    items = db.scalars(
        query.order_by(TradeRequest.created_at.desc(), TradeRequest.id.desc()).offset((page - 1) * size).limit(size)
    ).all()
    return {"items": trades.requests_out(db, user, list(items)), "total": total, "page": page, "size": size}


@router.get("/requests/{request_id}")
def get_request(request_id: int, user: User = Depends(current_user), db: Session = Depends(get_db)):
    return trades.request_out(db, user, trades.find_request(db, user, request_id))


@router.post("/requests/{request_id}/{action}", dependencies=[Depends(limit_trades)])
def act_on_request(
    request_id: int,
    action: Action,
    user: User = Depends(current_user),
    db: Session = Depends(get_db),
):
    req = trades.find_request(db, user, request_id)
    trades.transition(req, user, action)
    db.commit()
    db.refresh(req)
    return trades.request_out(db, user, req)
