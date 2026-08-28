"""Suivi des matchs : salons, compteur partagé, historique et statistiques.

Le serveur n'arbitre aucune règle du jeu (politique Riot) : il transporte,
horodate et recoupe ce que les joueurs saisissent eux-mêmes. Contrat commun
avec le mobile et le web : docs/suivi-des-matchs.md.
"""

from __future__ import annotations

import secrets
from datetime import UTC, datetime, timedelta

from fastapi import APIRouter, Depends, HTTPException, Query, Request
from sqlalchemy import case, func, select
from sqlalchemy.orm import Session, aliased

from ..auth import current_user
from ..db import get_db
from ..models import Card, Deck, Match, MatchPlayer, Room, RoomPlayer, User
from ..profiles import avatar_urls
from ..schemas import MatchFinishIn, MatchState, MatchStateIn, RoomCreate, RoomPlayerIn, RoomStartIn
from ..security import limit_play, sanitize_image_url
from .cards import card_out

router = APIRouter(prefix="/api/play", tags=["play"])

# Alphabet sans 0/O ni 1/I : un code se dicte de vive voix sans ambiguïté.
ROOM_CODE_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
ROOM_CODE_LENGTH = 6
ROOM_TTL = timedelta(hours=2)

VICTORY_SCORE = 8
ROUNDS_TO_WIN = {"duel": 1, "match": 2}

ACTIVE_ROOM_STATUSES = ("open", "playing")
LIVE_MATCH_STATUSES = ("live", "awaiting_confirmation")
# Un match contesté est exclu des statistiques mais reste dans l'historique.
COUNTED_MATCH_STATUSES = ("confirmed", "abandoned")
HISTORY_STATUSES = ("confirmed", "disputed", "abandoned")
RECENT_DAYS = 30

ROOM_BUSY = "Vous avez déjà un salon en cours — terminez-le ou annulez-le"


# --------------------------------------------------------------------------- outils


def _aware(moment: datetime | None) -> datetime | None:
    """SQLite restitue des datetimes naïfs (stockés en UTC) : on les recolle à UTC."""
    if moment is None:
        return None
    return moment if moment.tzinfo else moment.replace(tzinfo=UTC)


def _iso(moment: datetime | None) -> str | None:
    aware = _aware(moment)
    return aware.isoformat() if aware else None


def room_status(room: Room) -> str:
    """Statut effectif : un salon resté ouvert au-delà de son expiration vaut « annulé »."""
    if room.status == "open" and _aware(room.expires_at) <= datetime.now(UTC):
        return "cancelled"
    return room.status


def new_room_code(db: Session) -> str:
    """Code à 6 caractères tiré au sort, retiré tant qu'il est déjà pris."""
    while True:
        code = "".join(secrets.choice(ROOM_CODE_ALPHABET) for _ in range(ROOM_CODE_LENGTH))
        if db.scalar(select(Room.id).where(Room.code == code)) is None:
            return code


def load_room(db: Session, code: str) -> Room:
    room = db.scalar(select(Room).where(Room.code == (code or "").strip().upper()))
    if room is None:
        raise HTTPException(status_code=404, detail="Salon introuvable")
    return room


def room_seats(db: Session, room: Room) -> list[RoomPlayer]:
    return list(db.scalars(select(RoomPlayer).where(RoomPlayer.room_id == room.id).order_by(RoomPlayer.seat)))


def my_seat(db: Session, room: Room, user: User) -> RoomPlayer:
    seat = db.scalar(select(RoomPlayer).where(RoomPlayer.room_id == room.id, RoomPlayer.user_id == user.id))
    if seat is None:
        raise HTTPException(status_code=403, detail="Vous ne participez pas à ce salon")
    return seat


def active_room(db: Session, user_id: int) -> Room | None:
    """Salon en cours (ouvert ou en partie, non expiré) où le joueur occupe un siège."""
    rooms = db.scalars(
        select(Room)
        .join(RoomPlayer, RoomPlayer.room_id == Room.id)
        .where(RoomPlayer.user_id == user_id, Room.status.in_(ACTIVE_ROOM_STATUSES))
        .order_by(Room.id.desc())
    ).all()
    for room in rooms:
        if room_status(room) in ACTIVE_ROOM_STATUSES:
            return room
    return None


def _lookup(db: Session, user_ids, card_ids, deck_ids) -> tuple[dict, dict, dict, dict]:
    """Charge en lot les références affichées (joueurs, avatars, légendes, decks)."""
    users = {user.id: user for user in db.scalars(select(User).where(User.id.in_(set(user_ids))))}
    avatars = avatar_urls(db, list(users.values()))
    cards = {card.id: card for card in db.scalars(select(Card).where(Card.id.in_(set(card_ids))))}
    decks = {deck.id: deck for deck in db.scalars(select(Deck).where(Deck.id.in_(set(deck_ids))))}
    return users, avatars, cards, decks


def _user_payload(user: User | None, avatars: dict) -> dict | None:
    if user is None:  # compte supprimé : le match reste, le joueur est anonymisé
        return None
    return {"id": user.id, "handle": user.handle, "avatar_url": avatars.get(user.id)}


def _deck_payload(deck: Deck | None) -> dict | None:
    if deck is None:
        return None
    return {"id": deck.id, "name": deck.name, "format": deck.format}


def _legend_payload(cards: dict, card_id: str | None) -> dict | None:
    card = cards.get(card_id) if card_id else None
    return card_out(card) if card is not None else None


def room_out(db: Session, room: Room) -> dict:
    seats = room_seats(db, room)
    users, avatars, cards, decks = _lookup(
        db,
        [seat.user_id for seat in seats],
        [seat.legend_card_id for seat in seats if seat.legend_card_id],
        [seat.deck_id for seat in seats if seat.deck_id],
    )
    return {
        "code": room.code,
        "mode": room.mode,
        "status": room_status(room),
        "host_id": room.host_id,
        "players": [
            {
                "user": _user_payload(users.get(seat.user_id), avatars),
                "seat": seat.seat,
                "legend": _legend_payload(cards, seat.legend_card_id),
                "deck": _deck_payload(decks.get(seat.deck_id) if seat.deck_id else None),
                "ready": seat.ready,
            }
            for seat in seats
        ],
        "match_id": room.match_id,
        "expires_at": _iso(room.expires_at),
        "version": room.version,
        "victory_score": VICTORY_SCORE,
        "rounds_to_win": ROUNDS_TO_WIN[room.mode],
    }


def load_match(db: Session, match_id: int) -> Match:
    match = db.get(Match, match_id)
    if match is None:
        raise HTTPException(status_code=404, detail="Match introuvable")
    return match


def match_seats(db: Session, match: Match) -> list[MatchPlayer]:
    return list(db.scalars(select(MatchPlayer).where(MatchPlayer.match_id == match.id).order_by(MatchPlayer.seat)))


def ensure_participant(db: Session, match: Match, user: User) -> list[MatchPlayer]:
    seats = match_seats(db, match)
    if all(seat.user_id != user.id for seat in seats):
        raise HTTPException(status_code=403, detail="Ce match n'est pas le vôtre")
    return seats


def match_out(db: Session, match: Match, seats: list[MatchPlayer] | None = None) -> dict:
    seats = match_seats(db, match) if seats is None else seats
    users, avatars, cards, decks = _lookup(
        db,
        [seat.user_id for seat in seats],
        [seat.legend_card_id for seat in seats if seat.legend_card_id],
        [seat.deck_id for seat in seats if seat.deck_id],
    )
    room_code = db.scalar(select(Room.code).where(Room.id == match.room_id)) if match.room_id else None
    return {
        "id": match.id,
        "room_code": room_code,
        "mode": match.mode,
        "status": match.status,
        "host_id": match.host_id,
        "first_player_id": match.first_player_id,
        "started_at": _iso(match.started_at),
        "ended_at": _iso(match.ended_at),
        "winner_user_id": match.winner_user_id,
        "players": [
            {
                "user": _user_payload(users.get(seat.user_id), avatars),
                "seat": seat.seat,
                "legend": _legend_payload(cards, seat.legend_card_id),
                "deck": _deck_payload(decks.get(seat.deck_id) if seat.deck_id else None),
                "score": seat.score,
                "rounds_won": seat.rounds_won,
                "confirmed": seat.confirmed_at is not None,
            }
            for seat in seats
        ],
        "state": match.state or {},
        "result": match.result,
        "version": match.version,
    }


def initial_state(user_ids: list[int], first_player_id: int) -> dict:
    """Compteur à zéro : manche 1, tour 1, la main au joueur désigné par le tirage."""
    zeros = {str(user_id): 0 for user_id in user_ids}
    return {
        "round": 1,
        "turn": 1,
        "active_user_id": first_player_id,
        "scores": dict(zeros),
        "xp": dict(zeros),
        "rounds_won": dict(zeros),
    }


def check_state(state: MatchState, seats: list[MatchPlayer]) -> None:
    """Le compteur doit porter exactement sur les deux joueurs du match (422 sinon)."""
    if set(state.scores) != {str(seat.user_id) for seat in seats}:
        raise HTTPException(status_code=422, detail="Le compteur doit porter sur les deux joueurs du match")


def apply_result(seats: list[MatchPlayer], result: dict) -> None:
    """Recopie scores et manches du résultat dans les participations (stats agrégées)."""
    scores = result.get("scores") or {}
    rounds = result.get("rounds_won") or {}
    for seat in seats:
        seat.score = int(scores.get(str(seat.user_id), 0))
        seat.rounds_won = int(rounds.get(str(seat.user_id), 0))


def close_room(db: Session, match: Match) -> None:
    """Le salon d'un match terminé passe à « finished » : il ne bloque plus le joueur."""
    if match.room_id is None:
        return
    room = db.get(Room, match.room_id)
    if room is not None and room.status == "playing":
        room.status = "finished"
        room.version += 1


# --------------------------------------------------------------------------- salons


@router.post("/rooms", status_code=201)
def create_room(
    payload: RoomCreate,
    request: Request,
    user: User = Depends(current_user),
    db: Session = Depends(get_db),
):
    """Crée un salon et y installe l'hôte (siège 0). Un seul salon actif par compte."""
    limit_play(request)
    if active_room(db, user.id) is not None:
        raise HTTPException(status_code=409, detail=ROOM_BUSY)
    now = datetime.now(UTC)
    room = Room(
        code=new_room_code(db),
        host_id=user.id,
        mode=payload.mode,
        status="open",
        created_at=now,
        expires_at=now + ROOM_TTL,
        version=1,
    )
    db.add(room)
    db.flush()
    db.add(RoomPlayer(room_id=room.id, user_id=user.id, seat=0, ready=False))
    db.commit()
    return room_out(db, room)


@router.get("/rooms/{code}")
def read_room(code: str, user: User = Depends(current_user), db: Session = Depends(get_db)):
    """Lecture par code (le code vaut secret : qui le connaît peut suivre le salon)."""
    return room_out(db, load_room(db, code))


@router.post("/rooms/{code}/join")
def join_room(
    code: str,
    request: Request,
    user: User = Depends(current_user),
    db: Session = Depends(get_db),
):
    """Prend le siège 1. Sans effet si le joueur est déjà assis dans ce salon."""
    limit_play(request)
    room = load_room(db, code)
    if room.host_id == user.id:
        raise HTTPException(status_code=409, detail="Vous êtes déjà l'hôte de ce salon")
    if room_status(room) != "open":
        raise HTTPException(status_code=409, detail="Ce salon n'est plus ouvert")
    seats = room_seats(db, room)
    if any(seat.user_id == user.id for seat in seats):
        return room_out(db, room)
    if len(seats) >= 2:
        raise HTTPException(status_code=409, detail="Ce salon est déjà complet")
    if active_room(db, user.id) is not None:
        raise HTTPException(status_code=409, detail=ROOM_BUSY)
    db.add(RoomPlayer(room_id=room.id, user_id=user.id, seat=1, ready=False))
    room.version += 1
    db.commit()
    return room_out(db, room)


@router.put("/rooms/{code}/me")
def set_my_seat(
    code: str,
    payload: RoomPlayerIn,
    user: User = Depends(current_user),
    db: Session = Depends(get_db),
):
    """Choix personnels (remplacement complet : un champ absent remet la valeur à zéro)."""
    room = load_room(db, code)
    seat = my_seat(db, room, user)
    if room_status(room) != "open":
        raise HTTPException(status_code=409, detail="Ce salon n'est plus ouvert")
    if payload.legend_card_id:
        card = db.get(Card, payload.legend_card_id)
        if card is None or card.type != "Legend":
            raise HTTPException(status_code=422, detail="Choisissez une carte Légende")
    if payload.deck_id:
        deck = db.get(Deck, payload.deck_id)
        if deck is None or deck.owner_id != user.id:
            raise HTTPException(status_code=422, detail="Ce deck ne vous appartient pas")
    seat.legend_card_id = payload.legend_card_id
    seat.deck_id = payload.deck_id
    seat.ready = payload.ready
    room.version += 1
    db.commit()
    return room_out(db, room)


@router.post("/rooms/{code}/leave")
def leave_room(code: str, user: User = Depends(current_user), db: Session = Depends(get_db)):
    """L'invité quitte : le salon redevient ouvert avec l'hôte seul."""
    room = load_room(db, code)
    if room.host_id == user.id:
        raise HTTPException(status_code=403, detail="L'hôte ne quitte pas son salon : il l'annule")
    seat = my_seat(db, room, user)
    if room_status(room) != "open":
        raise HTTPException(status_code=409, detail="Ce salon n'est plus ouvert")
    db.delete(seat)
    room.version += 1
    db.commit()
    return room_out(db, room)


@router.delete("/rooms/{code}")
def cancel_room(code: str, user: User = Depends(current_user), db: Session = Depends(get_db)):
    """L'hôte annule son salon."""
    room = load_room(db, code)
    if room.host_id != user.id:
        raise HTTPException(status_code=403, detail="Seul l'hôte peut annuler le salon")
    room.status = "cancelled"
    room.version += 1
    db.commit()
    return room_out(db, room)


@router.post("/rooms/{code}/start", status_code=201)
def start_match(
    code: str,
    payload: RoomStartIn,
    user: User = Depends(current_user),
    db: Session = Depends(get_db),
):
    """Lance le match : légendes et decks sont figés, le salon passe en « playing »."""
    room = load_room(db, code)
    if room.host_id != user.id:
        raise HTTPException(status_code=403, detail="Seul l'hôte peut lancer la partie")
    if room_status(room) != "open":
        raise HTTPException(status_code=409, detail="Ce salon n'est plus ouvert")
    seats = room_seats(db, room)
    if len(seats) < 2 or not all(seat.ready for seat in seats):
        raise HTTPException(status_code=409, detail="Les deux joueurs doivent être prêts")
    user_ids = [seat.user_id for seat in seats]
    if payload.first_player_id not in user_ids:
        raise HTTPException(status_code=422, detail="Le premier joueur doit être l'un des deux participants")

    match = Match(
        room_id=room.id,
        mode=room.mode,
        status="live",
        host_id=room.host_id,
        first_player_id=payload.first_player_id,
        started_at=datetime.now(UTC),
        state=initial_state(user_ids, payload.first_player_id),
        version=1,
    )
    db.add(match)
    db.flush()
    for seat in seats:
        db.add(
            MatchPlayer(
                match_id=match.id,
                user_id=seat.user_id,
                seat=seat.seat,
                legend_card_id=seat.legend_card_id,
                deck_id=seat.deck_id,
                score=0,
                rounds_won=0,
            )
        )
    room.status = "playing"
    room.match_id = match.id
    room.version += 1
    db.commit()
    return match_out(db, match)


# --------------------------------------------------------------------------- matchs


@router.get("/matches/{match_id}")
def read_match(match_id: int, user: User = Depends(current_user), db: Session = Depends(get_db)):
    """Instantané complet du match (réservé aux deux participants)."""
    match = load_match(db, match_id)
    seats = ensure_participant(db, match, user)
    return match_out(db, match, seats)


@router.put("/matches/{match_id}/state")
def update_state(
    match_id: int,
    payload: MatchStateIn,
    user: User = Depends(current_user),
    db: Session = Depends(get_db),
):
    """Remplace l'instantané du compteur (hôte seul), avec contrôle de version optimiste."""
    match = load_match(db, match_id)
    seats = ensure_participant(db, match, user)
    if match.host_id != user.id:
        raise HTTPException(status_code=403, detail="Seul l'hôte tient le compteur")
    if match.status != "live":
        raise HTTPException(status_code=409, detail="Ce match n'est plus en cours")
    check_state(payload.state, seats)
    if payload.version != match.version:
        raise HTTPException(status_code=409, detail="Instantané dépassé, recharge le match")
    match.state = payload.state.model_dump()
    match.version += 1
    db.commit()
    return match_out(db, match, seats)


@router.post("/matches/{match_id}/finish")
def finish_match(
    match_id: int,
    payload: MatchFinishIn,
    user: User = Depends(current_user),
    db: Session = Depends(get_db),
):
    """L'hôte déclare le résultat : il est confirmé d'office, l'invité doit confirmer."""
    match = load_match(db, match_id)
    seats = ensure_participant(db, match, user)
    if match.host_id != user.id:
        raise HTTPException(status_code=403, detail="Seul l'hôte déclare la fin du match")
    if match.status != "live":
        raise HTTPException(status_code=409, detail="Ce match n'est plus en cours")
    if all(seat.user_id != payload.winner_user_id for seat in seats):
        raise HTTPException(status_code=422, detail="Le gagnant doit être l'un des deux joueurs")
    check_state(payload.result, seats)

    now = datetime.now(UTC)
    result = payload.result.model_dump()
    match.status = "awaiting_confirmation"
    match.winner_user_id = payload.winner_user_id
    match.ended_at = now
    match.result = result
    match.version += 1
    apply_result(seats, result)
    for seat in seats:
        if seat.user_id == user.id:
            seat.confirmed_at = now
    close_room(db, match)
    db.commit()
    return match_out(db, match, seats)


@router.post("/matches/{match_id}/confirm")
def confirm_match(match_id: int, user: User = Depends(current_user), db: Session = Depends(get_db)):
    """Confirmation d'un joueur ; les deux confirmations valident le match (stats)."""
    match = load_match(db, match_id)
    seats = ensure_participant(db, match, user)
    if match.status != "awaiting_confirmation":
        raise HTTPException(status_code=409, detail="Ce match n'attend pas de confirmation")
    for seat in seats:
        if seat.user_id == user.id and seat.confirmed_at is None:
            seat.confirmed_at = datetime.now(UTC)
    if all(seat.confirmed_at is not None for seat in seats):
        match.status = "confirmed"
    match.version += 1
    db.commit()
    return match_out(db, match, seats)


@router.post("/matches/{match_id}/dispute")
def dispute_match(match_id: int, user: User = Depends(current_user), db: Session = Depends(get_db)):
    """Contestation : le match reste dans l'historique mais sort des statistiques."""
    match = load_match(db, match_id)
    seats = ensure_participant(db, match, user)
    if match.status != "awaiting_confirmation":
        raise HTTPException(status_code=409, detail="Ce match n'attend pas de confirmation")
    match.status = "disputed"
    match.version += 1
    db.commit()
    return match_out(db, match, seats)


@router.post("/matches/{match_id}/abandon")
def abandon_match(match_id: int, user: User = Depends(current_user), db: Session = Depends(get_db)):
    """Abandon : défaite de celui qui abandonne, comptée sans confirmation de l'autre."""
    match = load_match(db, match_id)
    seats = ensure_participant(db, match, user)
    if match.status not in LIVE_MATCH_STATUSES:
        raise HTTPException(status_code=409, detail="Ce match est déjà terminé")
    result = match.result or match.state or {}
    match.status = "abandoned"
    match.winner_user_id = next(seat.user_id for seat in seats if seat.user_id != user.id)
    match.ended_at = datetime.now(UTC)
    match.result = result
    match.version += 1
    apply_result(seats, result)
    close_room(db, match)
    db.commit()
    return match_out(db, match, seats)


# --------------------------------------------------------------------------- reprise


@router.get("/current")
def my_current(user: User = Depends(current_user), db: Session = Depends(get_db)):
    """Reprise après fermeture de l'application : salon actif et/ou match en cours."""
    room = active_room(db, user.id)
    match = db.scalar(
        select(Match)
        .join(MatchPlayer, MatchPlayer.match_id == Match.id)
        .where(MatchPlayer.user_id == user.id, Match.status.in_(LIVE_MATCH_STATUSES))
        .order_by(Match.id.desc())
        .limit(1)
    )
    return {
        "room": room_out(db, room) if room is not None else None,
        "match": match_out(db, match) if match is not None else None,
    }


# --------------------------------------------------------------------------- historique


def _outcome(match: Match, user: User) -> str:
    if match.status == "disputed":
        return "disputed"
    return "win" if match.winner_user_id == user.id else "loss"


@router.get("/history")
def my_history(
    page: int = Query(1, ge=1),
    size: int = Query(20, ge=1, le=50),
    user: User = Depends(current_user),
    db: Session = Depends(get_db),
):
    """Mes matchs terminés, les plus récents d'abord."""
    query = (
        select(Match)
        .join(MatchPlayer, MatchPlayer.match_id == Match.id)
        .where(MatchPlayer.user_id == user.id, Match.status.in_(HISTORY_STATUSES))
    )
    total = db.scalar(select(func.count()).select_from(query.subquery())) or 0
    played_at = func.coalesce(Match.ended_at, Match.started_at)
    matches = db.scalars(query.order_by(played_at.desc(), Match.id.desc()).offset((page - 1) * size).limit(size)).all()

    match_ids = [match.id for match in matches]
    seats = list(db.scalars(select(MatchPlayer).where(MatchPlayer.match_id.in_(match_ids))))
    users, avatars, cards, decks = _lookup(
        db,
        [seat.user_id for seat in seats],
        [seat.legend_card_id for seat in seats if seat.legend_card_id],
        [seat.deck_id for seat in seats if seat.deck_id],
    )
    by_match: dict[int, list[MatchPlayer]] = {}
    for seat in seats:
        by_match.setdefault(seat.match_id, []).append(seat)

    items = []
    for match in matches:
        rows = by_match.get(match.id, [])
        mine = next((seat for seat in rows if seat.user_id == user.id), None)
        other = next((seat for seat in rows if seat.user_id != user.id), None)
        items.append(
            {
                "match_id": match.id,
                "mode": match.mode,
                "status": match.status,
                "played_at": _iso(match.ended_at or match.started_at),
                # null quand l'adversaire a supprimé son compte (match anonymisé).
                "opponent": _user_payload(users.get(other.user_id), avatars) if other else None,
                "my_legend": _legend_payload(cards, mine.legend_card_id) if mine else None,
                "opponent_legend": _legend_payload(cards, other.legend_card_id) if other else None,
                "my_deck": _deck_payload(decks.get(mine.deck_id) if mine and mine.deck_id else None),
                "opponent_deck": _deck_payload(decks.get(other.deck_id) if other and other.deck_id else None),
                "my_score": mine.score if mine else 0,
                "opponent_score": other.score if other else 0,
                "my_rounds": mine.rounds_won if mine else 0,
                "opponent_rounds": other.rounds_won if other else 0,
                "outcome": _outcome(match, user),
            }
        )
    return {"total": total, "page": page, "size": size, "items": items}


# --------------------------------------------------------------------------- statistiques


def _counted(user: User):
    """Base des statistiques : mes participations aux matchs confirmés ou abandonnés."""
    return (
        select(MatchPlayer)
        .join(Match, Match.id == MatchPlayer.match_id)
        .where(MatchPlayer.user_id == user.id, Match.status.in_(COUNTED_MATCH_STATUSES))
    )


def _tally(user: User):
    """Colonnes agrégées communes : parties jouées et parties gagnées."""
    won = func.coalesce(func.sum(case((Match.winner_user_id == user.id, 1), else_=0)), 0)
    return func.count(), won


def _rate(played: int, won: int) -> float:
    return round(won / played, 3) if played else 0.0


def _streaks(db: Session, user: User) -> tuple[int, int]:
    """Série en cours et meilleure série de victoires, sur l'historique trié du joueur."""
    winners = db.scalars(
        _counted(user)
        .with_only_columns(Match.winner_user_id)
        .order_by(func.coalesce(Match.ended_at, Match.started_at), Match.id)
    ).all()
    current = best = 0
    for winner in winners:
        current = current + 1 if winner == user.id else 0
        best = max(best, current)
    return current, best


def _recent(db: Session, user: User) -> list[dict]:
    """Activité des 30 derniers jours, jours sans partie inclus (valeurs à zéro)."""
    today = datetime.now(UTC).date()
    since = datetime.combine(today - timedelta(days=RECENT_DAYS - 1), datetime.min.time(), tzinfo=UTC)
    day = func.date(Match.ended_at)
    played, won = _tally(user)
    rows = db.execute(
        _counted(user)
        .with_only_columns(day.label("day"), played.label("played"), won.label("won"))
        .where(Match.ended_at.is_not(None), Match.ended_at >= since)
        .group_by(day)
    ).all()
    counts = {str(row.day)[:10]: (int(row.played), int(row.won)) for row in rows}
    days = []
    for offset in range(RECENT_DAYS - 1, -1, -1):
        key = (today - timedelta(days=offset)).isoformat()
        count, victories = counts.get(key, (0, 0))
        days.append({"day": key, "played": count, "won": victories})
    return days


def _legend_stats(rows) -> list[dict]:
    return [
        {
            "card_id": card_id,
            "name": name,
            "image_url": sanitize_image_url(image_url),
            "played": int(count),
            "won": int(victories),
            "lost": int(count) - int(victories),
        }
        for card_id, name, image_url, count, victories in rows
    ]


@router.get("/stats")
def my_stats(user: User = Depends(current_user), db: Session = Depends(get_db)):
    """Statistiques agrégées en SQL : totaux, formats, decks, légendes et 30 derniers jours."""
    played, won = _tally(user)
    total_played, total_won = db.execute(_counted(user).with_only_columns(played, won)).one()
    total_played, total_won = int(total_played), int(total_won)
    current_streak, best_streak = _streaks(db, user)

    formats = db.execute(
        _counted(user).with_only_columns(Match.mode, played, won).group_by(Match.mode).order_by(func.count().desc())
    ).all()
    by_deck = db.execute(
        _counted(user)
        .join(Deck, Deck.id == MatchPlayer.deck_id)
        .with_only_columns(Deck.id, Deck.name, Deck.format, played, won)
        .group_by(Deck.id, Deck.name, Deck.format)
        .order_by(func.count().desc(), Deck.id)
    ).all()
    by_legend = db.execute(
        _counted(user)
        .join(Card, Card.id == MatchPlayer.legend_card_id)
        .with_only_columns(Card.id, Card.name, Card.image_url, played, won)
        .group_by(Card.id, Card.name, Card.image_url)
        .order_by(func.count().desc(), Card.id)
    ).all()
    opponent = aliased(MatchPlayer)
    by_opponent_legend = db.execute(
        _counted(user)
        .join(opponent, (opponent.match_id == MatchPlayer.match_id) & (opponent.user_id != MatchPlayer.user_id))
        .join(Card, Card.id == opponent.legend_card_id)
        .with_only_columns(Card.id, Card.name, Card.image_url, played, won)
        .group_by(Card.id, Card.name, Card.image_url)
        .order_by(func.count().desc(), Card.id)
    ).all()

    return {
        "totals": {
            "played": total_played,
            "won": total_won,
            "lost": total_played - total_won,
            "win_rate": _rate(total_played, total_won),
            "current_streak": current_streak,
            "best_streak": best_streak,
        },
        "by_format": [
            {"mode": mode, "played": int(count), "won": int(victories), "lost": int(count) - int(victories)}
            for mode, count, victories in formats
        ],
        "by_deck": [
            {
                "deck_id": deck_id,
                "name": name,
                "format": deck_format,
                "played": int(count),
                "won": int(victories),
                "lost": int(count) - int(victories),
                "win_rate": _rate(int(count), int(victories)),
            }
            for deck_id, name, deck_format, count, victories in by_deck
        ],
        "by_legend": _legend_stats(by_legend),
        "by_opponent_legend": _legend_stats(by_opponent_legend),
        "recent": _recent(db, user),
    }
