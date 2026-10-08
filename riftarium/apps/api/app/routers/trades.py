"""Échanges entre joueurs : offres, correspondances et demandes.

Contrat : docs/echanges.md. La logique vit dans app/trades.py ; ce routeur ne
fait que l'authentification, la validation et la sérialisation.
"""

from fastapi import APIRouter, Depends, HTTPException, Response
from sqlalchemy import select
from sqlalchemy.orm import Session

from .. import trades
from ..auth import current_user
from ..db import get_db
from ..models import CollectionItem, TradeOffer, User
from ..schemas import TradeOfferPut
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
