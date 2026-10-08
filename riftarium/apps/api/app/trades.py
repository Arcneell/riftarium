"""Échanges entre joueurs : logique de domaine (contrat dans docs/echanges.md).

Le routeur (routers/trades.py) reste mince : correspondances, recalage des
offres sur la collection, machine à états des demandes et sérialiseurs vivent
ici. La base SQLite des tests n'applique pas les clés étrangères : toute
cascade est donc aussi faite par le code.
"""

from __future__ import annotations

from fastapi import HTTPException
from sqlalchemy import and_, delete, or_, select, update
from sqlalchemy.orm import Session

from .models import CollectionItem, TradeOffer, TradeRequest, User, WishlistItem, utcnow
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


# ---------- Correspondances ----------


def require_enabled(user: User) -> None:
    if not user.trade_enabled:
        raise HTTPException(status_code=403, detail="Activez les échanges pour voir les correspondances")


def _active_owner(now):
    """Comptes visibles dans les échanges : inscrits et non suspendus."""
    return and_(
        User.trade_enabled.is_(True),
        or_(User.suspended_until.is_(None), User.suspended_until <= now),
    )


def _avatars(db: Session, users) -> dict[int, str | None]:
    # Import local : profiles importe ce module (réglages, export, suppression).
    from .profiles import avatar_urls

    return avatar_urls(db, list({user.id: user for user in users}.values()))


def public_user(user: User, avatars: dict[int, str | None]) -> dict:
    return {"handle": user.handle, "avatar_url": avatars.get(user.id), "zone": user.trade_zone}


def _my_offered_cards(db: Session, viewer: User) -> list[str]:
    return list(
        db.scalars(
            select(CollectionItem.card_id)
            .join(TradeOffer, TradeOffer.collection_item_id == CollectionItem.id)
            .where(TradeOffer.user_id == viewer.id)
            .distinct()
        ).all()
    )


def _visible_offers(db: Session, viewer: User, card_ids: list[str], zone: str | None) -> list:
    """Offres des autres sur ces cartes : lignes (offre, lot, propriétaire)."""
    query = (
        select(TradeOffer, CollectionItem, User)
        .join(CollectionItem, TradeOffer.collection_item_id == CollectionItem.id)
        .join(User, TradeOffer.user_id == User.id)
        .where(
            _active_owner(utcnow()),
            TradeOffer.user_id != viewer.id,
            CollectionItem.card_id.in_(card_ids),
        )
    )
    if zone:
        query = query.where(User.trade_zone == zone)
    return list(db.execute(query).unique().all())


def _offers_out(db: Session, viewer: User, rows: list) -> list[dict]:
    """OfferOut triées : ma zone, puis « échange possible », puis la plus récente."""
    if not rows:
        return []
    owner_ids = {owner.id for _, _, owner in rows}
    my_cards = _my_offered_cards(db, viewer)
    mutual_ids: set[int] = set()
    if my_cards:
        mutual_ids = set(
            db.scalars(
                select(WishlistItem.user_id).where(
                    WishlistItem.user_id.in_(owner_ids), WishlistItem.card_id.in_(my_cards)
                )
            ).all()
        )
    pending = dict(
        db.execute(
            select(TradeRequest.trade_offer_id, TradeRequest.id).where(
                TradeRequest.requester_id == viewer.id,
                TradeRequest.status == "pending",
                TradeRequest.trade_offer_id.in_([item.id for item, _, _ in rows]),
            )
        ).all()
    )
    avatars = _avatars(db, [owner for _, _, owner in rows])
    ordered = sorted(
        rows,
        key=lambda row: (row[2].trade_zone != viewer.trade_zone, row[2].id not in mutual_ids, -row[0].id),
    )
    return [
        {
            "offer_id": item.id,
            "owner": public_user(owner, avatars),
            "condition": entry.condition,
            "lang": entry.lang,
            "qty": item.qty,
            "mutual": owner.id in mutual_ids,
            "pending_request_id": pending.get(item.id),
        }
        for item, entry, owner in ordered
    ]


def _in_my_zone(viewer: User, offers: list[dict]) -> int:
    return sum(1 for item in offers if item["owner"]["zone"] == viewer.trade_zone)


def _page(items: list, page: int, size: int) -> dict:
    start = (page - 1) * size
    return {"items": items[start : start + size], "total": len(items), "page": page, "size": size}


def matches_wanted(db: Session, viewer: User, *, zone: str | None, q: str, page: int, size: int) -> dict:
    """« Ils ont ce que je cherche » : offres des autres sur ma wishlist, groupées par carte.

    Tri des cartes : nombre d'offres dans ma zone, puis nom. Les volumes (une
    communauté locale) permettent de trier et paginer en Python.
    """
    wanted = dict(
        db.execute(select(WishlistItem.card_id, WishlistItem.qty).where(WishlistItem.user_id == viewer.id)).all()
    )
    rows = _visible_offers(db, viewer, list(wanted), zone) if wanted else []
    needle = q.strip().lower()
    by_card: dict[str, list] = {}
    for row in rows:
        card = row[1].card
        if needle and needle not in card.name.lower():
            continue
        by_card.setdefault(card.id, []).append(row)
    blocks = []
    for card_rows in by_card.values():
        offers = _offers_out(db, viewer, card_rows)
        blocks.append((_in_my_zone(viewer, offers), card_rows[0][1].card, offers))
    blocks.sort(key=lambda block: (-block[0], block[1].name, block[1].id))
    items = [{"card": card_out(card), "wanted_qty": wanted[card.id], "offers": offers} for _, card, offers in blocks]
    return _page(items, page, size)


def matches_offered(db: Session, viewer: User, *, zone: str | None, page: int, size: int) -> dict:
    """« Ils cherchent ce que j'ai » : comptes dont la wishlist croise mes offres."""
    my_cards = _my_offered_cards(db, viewer)
    if not my_cards:
        return _page([], page, size)
    query = (
        select(WishlistItem, User)
        .join(User, WishlistItem.user_id == User.id)
        .where(_active_owner(utcnow()), User.id != viewer.id, WishlistItem.card_id.in_(my_cards))
    )
    if zone:
        query = query.where(User.trade_zone == zone)
    by_user: dict[int, tuple[User, list]] = {}
    for wished, user in db.execute(query).unique().all():
        by_user.setdefault(user.id, (user, []))[1].append(wished.card)
    avatars = _avatars(db, [user for user, _ in by_user.values()])
    seekers = sorted(by_user.values(), key=lambda pair: (pair[0].trade_zone != viewer.trade_zone, pair[0].handle))
    items = [
        {
            "user": public_user(user, avatars),
            "cards": [card_out(card) for card in sorted(cards, key=lambda card: (card.name, card.id))],
        }
        for user, cards in seekers
    ]
    return _page(items, page, size)


def card_offers(db: Session, viewer: User, card_id: str, *, zone: str | None) -> dict:
    """Offres des autres sur une carte (bloc « À l'échange » de la fiche)."""
    offers = _offers_out(db, viewer, _visible_offers(db, viewer, [card_id], zone))
    return {"offers": offers, "total": len(offers), "in_my_zone": _in_my_zone(viewer, offers)}
