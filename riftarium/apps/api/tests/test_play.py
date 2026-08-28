"""Suivi des matchs : salons, compteur partagé, confirmation, historique et statistiques."""

from datetime import UTC, datetime, timedelta

import app.db as db_module
from app.models import Match, Room
from sqlalchemy import select

from conftest import bearer_headers

LEGEND = "ogn-247-298"  # Daughter of the Void (type Legend)
NOT_LEGEND = "ogn-200-298"  # Sky Splitter (type Spell)


def deck_payload(**overrides):
    payload = {
        "name": "Étincelle de Fureur",
        "description": "Deck aggro de test.",
        "format": "tournament",
        "is_public": False,
        "cards": [
            {"card_id": "ogn-247-298", "qty": 1},
            {"card_id": "ogn-275-298", "qty": 1},
            {"card_id": "ogn-276-298", "qty": 1},
            {"card_id": "ogn-277-298", "qty": 1},
            {"card_id": "ogn-007-298", "qty": 12},
            {"card_id": "ogn-037-298", "qty": 3},
            {"card_id": "ogn-119-298", "qty": 2},
        ],
    }
    payload.update(overrides)
    return payload


def account(client, register_user, handle):
    """Inscrit un compte et renvoie (en-têtes Bearer, identifiant)."""
    assert register_user(client, handle).status_code == 201
    headers = bearer_headers(client)
    user_id = client.get("/api/auth/me", headers=headers).json()["id"]
    return headers, user_id


def expire_room(code):
    """Repousse l'expiration d'un salon dans le passé (impossible via l'API)."""
    with db_module.SessionLocal() as session:
        room = session.scalar(select(Room).where(Room.code == code))
        room.expires_at = datetime.now(UTC) - timedelta(minutes=1)
        session.commit()


def backdate_match(match_id, days):
    """Antidate la fin d'un match (historique et fenêtre des 30 jours)."""
    with db_module.SessionLocal() as session:
        match = session.get(Match, match_id)
        match.ended_at = datetime.now(UTC) - timedelta(days=days)
        session.commit()


def counter(winner_id, loser_id, *, score=8, rounds=1):
    """Instantané valide du compteur pour les deux joueurs."""
    return {
        "round": rounds,
        "turn": 5,
        "active_user_id": winner_id,
        "scores": {str(winner_id): score, str(loser_id): 3},
        "xp": {str(winner_id): 4, str(loser_id): 2},
        "rounds_won": {str(winner_id): rounds, str(loser_id): 0},
    }


def live_match(client, host, guest, host_id, *, mode="duel", host_deck=None, legend=LEGEND):
    """Salon complet, deux joueurs prêts, match lancé : renvoie (code, MatchOut)."""
    room = client.post("/api/play/rooms", json={"mode": mode}, headers=host)
    assert room.status_code == 201, room.text
    code = room.json()["code"]
    assert client.post(f"/api/play/rooms/{code}/join", headers=guest).status_code == 200
    mine = {"legend_card_id": legend, "deck_id": host_deck, "ready": True}
    assert client.put(f"/api/play/rooms/{code}/me", json=mine, headers=host).status_code == 200
    theirs = {"legend_card_id": legend, "ready": True}
    assert client.put(f"/api/play/rooms/{code}/me", json=theirs, headers=guest).status_code == 200
    started = client.post(f"/api/play/rooms/{code}/start", json={"first_player_id": host_id}, headers=host)
    assert started.status_code == 201, started.text
    return code, started.json()


def played_match(
    client, host, guest, host_id, guest_id, *, winner_id, outcome="confirmed", mode="duel", host_deck=None
):
    """Déroule un match complet jusqu'au statut demandé et renvoie son identifiant."""
    _code, match = live_match(client, host, guest, host_id, mode=mode, host_deck=host_deck)
    loser_id = guest_id if winner_id == host_id else host_id
    body = {"winner_user_id": winner_id, "result": counter(winner_id, loser_id)}
    finish = client.post(f"/api/play/matches/{match['id']}/finish", json=body, headers=host)
    assert finish.status_code == 200, finish.text
    if outcome == "confirmed":
        assert client.post(f"/api/play/matches/{match['id']}/confirm", headers=guest).status_code == 200
    elif outcome == "disputed":
        assert client.post(f"/api/play/matches/{match['id']}/dispute", headers=guest).status_code == 200
    return match["id"]


# ---------- salons ----------


def test_create_room_returns_a_code_and_refuses_a_second_active_room(client, auth):
    created = client.post("/api/play/rooms", json={"mode": "match"}, headers=auth)
    assert created.status_code == 201, created.text
    room = created.json()
    assert len(room["code"]) == 6
    assert set(room["code"]) <= set("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
    assert room["status"] == "open"
    assert room["victory_score"] == 8 and room["rounds_to_win"] == 2
    assert [player["seat"] for player in room["players"]] == [0]
    assert room["players"][0]["user"]["handle"] == "testeur"
    assert room["match_id"] is None and room["version"] == 1

    again = client.post("/api/play/rooms", json={"mode": "duel"}, headers=auth)
    assert again.status_code == 409
    assert "salon en cours" in again.json()["detail"]

    # Le code vaut secret : sa lecture ne demande rien de plus qu'un compte.
    read = client.get(f"/api/play/rooms/{room['code']}", headers=auth)
    assert read.status_code == 200 and read.json()["code"] == room["code"]
    assert client.get("/api/play/rooms/ZZZZZZ", headers=auth).status_code == 404


def test_join_seats_the_guest_and_refuses_host_full_and_expired_rooms(client, auth, register_user):
    guest, _guest_id = account(client, register_user, "invite")
    third, _third_id = account(client, register_user, "curieux")
    code = client.post("/api/play/rooms", json={"mode": "duel"}, headers=auth).json()["code"]

    assert client.post(f"/api/play/rooms/{code}/join", headers=auth).status_code == 409  # l'hôte est déjà assis

    joined = client.post(f"/api/play/rooms/{code}/join", headers=guest)
    assert joined.status_code == 200, joined.text
    assert [player["seat"] for player in joined.json()["players"]] == [0, 1]
    assert joined.json()["version"] == 2
    again = client.post(f"/api/play/rooms/{code}/join", headers=guest)  # déjà assis : sans effet
    assert again.status_code == 200 and again.json()["version"] == 2

    full = client.post(f"/api/play/rooms/{code}/join", headers=third)
    assert full.status_code == 409 and "complet" in full.json()["detail"]

    # L'invité quitte : le salon redevient ouvert avec l'hôte seul.
    left = client.post(f"/api/play/rooms/{code}/leave", headers=guest)
    assert left.status_code == 200 and [p["seat"] for p in left.json()["players"]] == [0]
    assert client.post(f"/api/play/rooms/{code}/leave", headers=auth).status_code == 403
    assert client.post(f"/api/play/rooms/{code}/leave", headers=third).status_code == 403

    # Qui a déjà son propre salon actif ne peut pas en rejoindre un autre.
    assert client.post("/api/play/rooms", json={"mode": "duel"}, headers=third).status_code == 201
    busy = client.post(f"/api/play/rooms/{code}/join", headers=third)
    assert busy.status_code == 409 and "salon en cours" in busy.json()["detail"]

    expire_room(code)
    assert client.get(f"/api/play/rooms/{code}", headers=auth).json()["status"] == "cancelled"
    expired = client.post(f"/api/play/rooms/{code}/join", headers=guest)
    assert expired.status_code == 409 and "plus ouvert" in expired.json()["detail"]
    # Un salon expiré ne bloque plus la création d'un nouveau.
    assert client.post("/api/play/rooms", json={"mode": "duel"}, headers=auth).status_code == 201


def test_seat_choices_reject_a_non_legend_card_and_someone_elses_deck(client, auth, register_user):
    deck_id = client.post("/api/decks", json=deck_payload(), headers=auth).json()["id"]
    guest, _guest_id = account(client, register_user, "invite")
    code = client.post("/api/play/rooms", json={"mode": "duel"}, headers=auth).json()["code"]
    client.post(f"/api/play/rooms/{code}/join", headers=guest)

    wrong_card = client.put(f"/api/play/rooms/{code}/me", json={"legend_card_id": NOT_LEGEND}, headers=auth)
    assert wrong_card.status_code == 422 and "Légende" in wrong_card.json()["detail"]
    unknown = client.put(f"/api/play/rooms/{code}/me", json={"legend_card_id": "inconnue"}, headers=auth)
    assert unknown.status_code == 422

    stolen = client.put(f"/api/play/rooms/{code}/me", json={"deck_id": deck_id}, headers=guest)
    assert stolen.status_code == 422 and "appartient" in stolen.json()["detail"]
    assert client.put(f"/api/play/rooms/{code}/me", json={"deck_id": 9999}, headers=auth).status_code == 422

    ok = client.put(
        f"/api/play/rooms/{code}/me",
        json={"legend_card_id": LEGEND, "deck_id": deck_id, "ready": True},
        headers=auth,
    )
    assert ok.status_code == 200
    seat = ok.json()["players"][0]
    assert seat["legend"]["id"] == LEGEND and seat["deck"] == {
        "id": deck_id,
        "name": "Étincelle de Fureur",
        "format": "tournament",
    }
    assert seat["ready"] is True


def test_start_requires_both_players_ready_and_creates_a_live_match(client, auth, register_user):
    guest, guest_id = account(client, register_user, "invite")
    host_id = client.get("/api/auth/me", headers=auth).json()["id"]
    code = client.post("/api/play/rooms", json={"mode": "duel"}, headers=auth).json()["code"]
    client.post(f"/api/play/rooms/{code}/join", headers=guest)

    assert (
        client.post(f"/api/play/rooms/{code}/start", json={"first_player_id": host_id}, headers=guest).status_code
        == 403
    )
    not_ready = client.post(f"/api/play/rooms/{code}/start", json={"first_player_id": host_id}, headers=auth)
    assert not_ready.status_code == 409 and "prêts" in not_ready.json()["detail"]

    client.put(f"/api/play/rooms/{code}/me", json={"legend_card_id": LEGEND, "ready": True}, headers=auth)
    client.put(f"/api/play/rooms/{code}/me", json={"legend_card_id": LEGEND, "ready": True}, headers=guest)
    assert (
        client.post(f"/api/play/rooms/{code}/start", json={"first_player_id": 424242}, headers=auth).status_code == 422
    )

    started = client.post(f"/api/play/rooms/{code}/start", json={"first_player_id": guest_id}, headers=auth)
    assert started.status_code == 201, started.text
    match = started.json()
    assert match["status"] == "live" and match["room_code"] == code
    assert match["first_player_id"] == guest_id and match["version"] == 1
    assert match["state"] == {
        "round": 1,
        "turn": 1,
        "active_user_id": guest_id,
        "scores": {str(host_id): 0, str(guest_id): 0},
        "xp": {str(host_id): 0, str(guest_id): 0},
        "rounds_won": {str(host_id): 0, str(guest_id): 0},
    }
    assert [player["confirmed"] for player in match["players"]] == [False, False]

    room = client.get(f"/api/play/rooms/{code}", headers=auth).json()
    assert room["status"] == "playing" and room["match_id"] == match["id"]
    # Le salon en partie ne se modifie plus.
    assert client.put(f"/api/play/rooms/{code}/me", json={"ready": False}, headers=auth).status_code == 409


# ---------- compteur ----------


def test_state_is_host_only_versioned_and_validated(client, auth, register_user):
    guest, guest_id = account(client, register_user, "invite")
    host_id = client.get("/api/auth/me", headers=auth).json()["id"]
    _code, match = live_match(client, auth, guest, host_id)
    url = f"/api/play/matches/{match['id']}/state"
    snapshot = counter(host_id, guest_id, score=3)

    assert client.put(url, json={"version": 1, "state": snapshot}, headers=guest).status_code == 403
    negative = {**snapshot, "scores": {str(host_id): -1, str(guest_id): 0}}
    assert client.put(url, json={"version": 1, "state": negative}, headers=auth).status_code == 422
    lonely = {**snapshot, "scores": {str(host_id): 1}}
    assert client.put(url, json={"version": 1, "state": lonely}, headers=auth).status_code == 422
    intruder = {
        "round": 1,
        "turn": 1,
        "active_user_id": 999,
        "scores": {"999": 0, "998": 0},
        "xp": {"999": 0, "998": 0},
        "rounds_won": {"999": 0, "998": 0},
    }
    wrong_players = client.put(url, json={"version": 1, "state": intruder}, headers=auth)
    assert wrong_players.status_code == 422 and "deux joueurs" in wrong_players.json()["detail"]

    updated = client.put(url, json={"version": 1, "state": snapshot}, headers=auth)
    assert updated.status_code == 200, updated.text
    assert updated.json()["version"] == 2
    assert updated.json()["state"]["scores"][str(host_id)] == 3

    stale = client.put(url, json={"version": 1, "state": snapshot}, headers=auth)
    assert stale.status_code == 409 and stale.json()["detail"] == "Instantané dépassé, recharge le match"

    read = client.get(f"/api/play/matches/{match['id']}", headers=guest)
    assert read.status_code == 200 and read.json()["version"] == 2


def test_finish_awaits_confirmation_then_the_guest_confirms(client, auth, register_user):
    guest, guest_id = account(client, register_user, "invite")
    host_id = client.get("/api/auth/me", headers=auth).json()["id"]
    code, match = live_match(client, auth, guest, host_id)
    url = f"/api/play/matches/{match['id']}"

    assert client.post(f"{url}/confirm", headers=guest).status_code == 409  # match encore en cours
    body = {"winner_user_id": 4242, "result": counter(host_id, guest_id)}
    assert client.post(f"{url}/finish", json=body, headers=auth).status_code == 422
    body = {"winner_user_id": host_id, "result": counter(host_id, guest_id)}
    assert client.post(f"{url}/finish", json=body, headers=guest).status_code == 403

    finished = client.post(f"{url}/finish", json=body, headers=auth)
    assert finished.status_code == 200, finished.text
    payload = finished.json()
    assert payload["status"] == "awaiting_confirmation" and payload["winner_user_id"] == host_id
    assert payload["ended_at"] is not None and payload["result"]["scores"][str(host_id)] == 8
    host_seat = next(player for player in payload["players"] if player["user"]["id"] == host_id)
    guest_seat = next(player for player in payload["players"] if player["user"]["id"] == guest_id)
    assert host_seat["confirmed"] is True and host_seat["score"] == 8 and host_seat["rounds_won"] == 1
    assert guest_seat["confirmed"] is False and guest_seat["score"] == 3
    assert client.get(f"/api/play/rooms/{code}", headers=auth).json()["status"] == "finished"
    assert client.post(f"{url}/finish", json=body, headers=auth).status_code == 409
    assert (
        client.put(f"{url}/state", json={"version": 2, "state": counter(host_id, guest_id)}, headers=auth).status_code
        == 409
    )

    confirmed = client.post(f"{url}/confirm", headers=guest)
    assert confirmed.status_code == 200 and confirmed.json()["status"] == "confirmed"
    assert all(player["confirmed"] for player in confirmed.json()["players"])
    assert client.post(f"{url}/dispute", headers=guest).status_code == 409


def test_dispute_excludes_the_match_from_statistics(client, auth, register_user):
    guest, guest_id = account(client, register_user, "invite")
    host_id = client.get("/api/auth/me", headers=auth).json()["id"]
    match_id = played_match(client, auth, guest, host_id, guest_id, winner_id=host_id, outcome="disputed")

    read = client.get(f"/api/play/matches/{match_id}", headers=auth).json()
    assert read["status"] == "disputed"
    assert client.get("/api/play/stats", headers=auth).json()["totals"]["played"] == 0
    history = client.get("/api/play/history", headers=auth).json()
    assert history["total"] == 1 and history["items"][0]["outcome"] == "disputed"


def test_abandon_gives_the_win_to_the_other_player(client, auth, register_user):
    guest, guest_id = account(client, register_user, "invite")
    host_id = client.get("/api/auth/me", headers=auth).json()["id"]
    code, match = live_match(client, auth, guest, host_id)

    abandoned = client.post(f"/api/play/matches/{match['id']}/abandon", headers=guest)
    assert abandoned.status_code == 200, abandoned.text
    assert abandoned.json()["status"] == "abandoned"
    assert abandoned.json()["winner_user_id"] == host_id
    assert client.get(f"/api/play/rooms/{code}", headers=auth).json()["status"] == "finished"
    assert client.post(f"/api/play/matches/{match['id']}/abandon", headers=guest).status_code == 409

    stats = client.get("/api/play/stats", headers=auth).json()
    assert stats["totals"] == {
        "played": 1,
        "won": 1,
        "lost": 0,
        "win_rate": 1.0,
        "current_streak": 1,
        "best_streak": 1,
    }


# ---------- reprise, historique, statistiques ----------


def test_current_returns_the_active_room_then_the_live_match(client, auth, register_user):
    guest, guest_id = account(client, register_user, "invite")
    host_id = client.get("/api/auth/me", headers=auth).json()["id"]
    assert client.get("/api/play/current", headers=auth).json() == {"room": None, "match": None}

    code = client.post("/api/play/rooms", json={"mode": "duel"}, headers=auth).json()["code"]
    current = client.get("/api/play/current", headers=auth).json()
    assert current["room"]["code"] == code and current["match"] is None

    client.post(f"/api/play/rooms/{code}/join", headers=guest)
    client.put(f"/api/play/rooms/{code}/me", json={"legend_card_id": LEGEND, "ready": True}, headers=auth)
    client.put(f"/api/play/rooms/{code}/me", json={"legend_card_id": LEGEND, "ready": True}, headers=guest)
    match = client.post(f"/api/play/rooms/{code}/start", json={"first_player_id": host_id}, headers=auth).json()

    resumed = client.get("/api/play/current", headers=guest).json()
    assert resumed["room"]["status"] == "playing" and resumed["match"]["id"] == match["id"]

    # L'hôte annule son salon : il n'y a plus rien à reprendre côté salon.
    cancelled = client.request("DELETE", f"/api/play/rooms/{code}", headers=auth)
    assert cancelled.status_code == 200 and cancelled.json()["status"] == "cancelled"
    assert client.request("DELETE", f"/api/play/rooms/{code}", headers=guest).status_code == 403
    assert client.get("/api/play/current", headers=auth).json()["room"] is None


def test_history_and_statistics_aggregate_confirmed_matches(client, auth, register_user):
    guest, guest_id = account(client, register_user, "invite")
    host_id = client.get("/api/auth/me", headers=auth).json()["id"]
    deck_id = client.post("/api/decks", json=deck_payload(), headers=auth).json()["id"]

    first = played_match(client, auth, guest, host_id, guest_id, winner_id=guest_id, host_deck=deck_id)
    second = played_match(client, auth, guest, host_id, guest_id, winner_id=host_id, host_deck=deck_id)
    third = played_match(client, auth, guest, host_id, guest_id, winner_id=host_id, host_deck=deck_id)
    backdate_match(first, days=5)
    backdate_match(second, days=2)

    history = client.get("/api/play/history?page=1&size=2", headers=auth).json()
    assert history["total"] == 3 and history["page"] == 1 and history["size"] == 2
    assert [item["match_id"] for item in history["items"]] == [third, second]
    latest = history["items"][0]
    assert latest["outcome"] == "win" and latest["opponent"]["handle"] == "invite"
    assert latest["my_score"] == 8 and latest["opponent_score"] == 3
    assert latest["my_rounds"] == 1 and latest["opponent_rounds"] == 0
    assert latest["my_legend"]["id"] == LEGEND and latest["opponent_legend"]["id"] == LEGEND
    assert latest["my_deck"]["id"] == deck_id and latest["opponent_deck"] is None
    assert latest["played_at"] is not None and latest["mode"] == "duel"

    page_two = client.get("/api/play/history?page=2&size=2", headers=auth).json()
    assert [item["match_id"] for item in page_two["items"]] == [first]
    assert page_two["items"][0]["outcome"] == "loss"

    stats = client.get("/api/play/stats", headers=auth).json()
    assert stats["totals"] == {
        "played": 3,
        "won": 2,
        "lost": 1,
        "win_rate": 0.667,
        "current_streak": 2,
        "best_streak": 2,
    }
    assert stats["by_format"] == [{"mode": "duel", "played": 3, "won": 2, "lost": 1}]
    assert stats["by_deck"] == [
        {
            "deck_id": deck_id,
            "name": "Étincelle de Fureur",
            "format": "tournament",
            "played": 3,
            "won": 2,
            "lost": 1,
            "win_rate": 0.667,
        }
    ]
    assert stats["by_legend"] == [
        {
            "card_id": LEGEND,
            "name": "Daughter of the Void",
            "image_url": "https://cdn.example/ahri-legend.png",
            "played": 3,
            "won": 2,
            "lost": 1,
        }
    ]
    assert stats["by_opponent_legend"][0]["card_id"] == LEGEND
    assert stats["by_opponent_legend"][0]["played"] == 3

    recent = stats["recent"]
    assert len(recent) == 30
    today = datetime.now(UTC).date()
    assert recent[-1]["day"] == today.isoformat()
    assert recent[0]["day"] == (today - timedelta(days=29)).isoformat()
    assert recent[-1] == {"day": today.isoformat(), "played": 1, "won": 1}
    by_day = {row["day"]: row for row in recent}
    assert by_day[(today - timedelta(days=5)).isoformat()] == {
        "day": (today - timedelta(days=5)).isoformat(),
        "played": 1,
        "won": 0,
    }
    assert by_day[(today - timedelta(days=10)).isoformat()]["played"] == 0

    # Le point de vue de l'adversaire est le symétrique exact.
    guest_stats = client.get("/api/play/stats", headers=guest).json()
    assert guest_stats["totals"]["won"] == 1 and guest_stats["totals"]["current_streak"] == 0


def test_empty_statistics_for_a_player_without_any_match(client, auth):
    stats = client.get("/api/play/stats", headers=auth).json()
    assert stats["totals"] == {
        "played": 0,
        "won": 0,
        "lost": 0,
        "win_rate": 0.0,
        "current_streak": 0,
        "best_streak": 0,
    }
    assert stats["by_format"] == [] and stats["by_deck"] == [] and stats["by_legend"] == []
    assert stats["by_opponent_legend"] == [] and len(stats["recent"]) == 30
    assert client.get("/api/play/history", headers=auth).json() == {"total": 0, "page": 1, "size": 20, "items": []}


# ---------- confidentialité ----------


def test_a_third_party_cannot_read_or_touch_someone_elses_match(client, auth, register_user):
    guest, guest_id = account(client, register_user, "invite")
    third, _third_id = account(client, register_user, "curieux")
    host_id = client.get("/api/auth/me", headers=auth).json()["id"]
    _code, match = live_match(client, auth, guest, host_id)
    url = f"/api/play/matches/{match['id']}"

    assert client.get(url, headers=third).status_code == 403
    assert client.post(f"{url}/abandon", headers=third).status_code == 403
    assert client.post(f"{url}/confirm", headers=third).status_code == 403
    state = {"version": 1, "state": counter(host_id, guest_id)}
    assert client.put(f"{url}/state", json=state, headers=third).status_code == 403
    assert client.get("/api/play/matches/424242", headers=third).status_code == 404
    assert client.get(url).status_code == 401


def test_account_deletion_keeps_the_match_and_anonymises_the_opponent(client, auth, register_user):
    guest, guest_id = account(client, register_user, "invite")
    host_id = client.get("/api/auth/me", headers=auth).json()["id"]
    match_id = played_match(client, auth, guest, host_id, guest_id, winner_id=guest_id)
    open_code = client.post("/api/play/rooms", json={"mode": "duel"}, headers=guest).json()["code"]

    gone = client.request(
        "DELETE", "/api/auth/me", json={"password": "motdepasse123", "handle": "invite"}, headers=guest
    )
    assert gone.status_code == 204, gone.text

    read = client.get(f"/api/play/matches/{match_id}", headers=auth)
    assert read.status_code == 200
    payload = read.json()
    assert payload["status"] == "confirmed" and payload["winner_user_id"] is None
    assert [player["user"] for player in payload["players"]] == [
        {"id": host_id, "handle": "testeur", "avatar_url": None}
    ]

    history = client.get("/api/play/history", headers=auth).json()
    assert history["total"] == 1
    item = history["items"][0]
    assert item["opponent"] is None and item["opponent_legend"] is None and item["opponent_score"] == 0
    assert item["outcome"] == "loss"  # le gagnant est devenu inconnu

    # Le salon que le compte supprimé hébergeait est annulé.
    assert client.get(f"/api/play/rooms/{open_code}", headers=auth).json()["status"] == "cancelled"
