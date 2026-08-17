from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session

from ..auth import current_user
from ..db import get_db
from ..models import CollectionItem, User
from ..schemas import CollectionPut
from .cards import card_out, find_card

router = APIRouter(prefix="/api/collection", tags=["collection"])


@router.get("")
def my_collection(user: User = Depends(current_user), db: Session = Depends(get_db)):
    items = db.scalars(select(CollectionItem).where(CollectionItem.user_id == user.id)).all()
    return {
        "total_cards": sum(i.qty for i in items),
        "unique_cards": len(items),
        "items": [{"card": card_out(i.card), "qty": i.qty, "condition": i.condition, "lang": i.lang} for i in items],
    }


@router.put("/{card_id}")
def set_quantity(
    card_id: str,
    payload: CollectionPut,
    user: User = Depends(current_user),
    db: Session = Depends(get_db),
):
    card = find_card(db, card_id)
    if card is None:
        raise HTTPException(status_code=404, detail="Carte introuvable")

    item = db.scalar(select(CollectionItem).where(CollectionItem.user_id == user.id, CollectionItem.card_id == card.id))
    if payload.qty == 0:
        if item:
            db.delete(item)
            db.commit()
        return {"card_id": card.id, "qty": 0}

    if item is None:
        item = CollectionItem(user_id=user.id, card_id=card.id)
        db.add(item)
    item.qty = payload.qty
    item.condition = payload.condition
    item.lang = payload.lang
    db.commit()
    return {"card_id": card.id, "qty": item.qty, "condition": item.condition, "lang": item.lang}
