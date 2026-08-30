"""Profils publics, hauts faits et amis : confidentialité, suivis, catalogue et déblocages."""

from datetime import UTC, datetime, timedelta

import app.db as db_module
from app.achievements import CATALOGUE
from app.models import Achievement, Follow, Match, MatchPlayer, User
from sqlalchemy import func, select

from conftest import bearer_headers

LEGEND = "ogn-247-298"  # Daughter of the Void (domaines Fury + Mind)
# Toutes les cartes de base du set OGN semé par conftest (ni alt-art, ni signature).
BASE_CARDS = (
    "ogn-247-298",
    "ogn-275-298",
    "ogn-276-298",
    "ogn-277-298",
    "ogn-007-298",
    "ogn-037-298",
    "ogn-119-298",
    "ogn-078-298",
    "ogn-200-298",
)


def account(client, register_user, handle):
    """Inscrit un compte et renvoie (en-têtes Bearer, identifiant)."""
    assert register_user(client, handle).status_code == 201
    headers = bearer_headers(client)
    return headers, client.get("/api/auth/me", headers=headers).json()["id"]


def make_users(*handles):
    """Crée des comptes directement en base (adversaires et suivis : jamais connectés)."""
    ids = {}
    with db_module.SessionLocal() as session:
        for handle in handles:
            user = User(
                handle=handle,
                email=f"{handle}@example.net",
                password_hash="x",
                token_version=1,
                created_at=datetime.now(UTC),
            )
            session.add(user)
            session.flush()
            ids[handle] = user.id
        session.commit()
    return ids


def add_matches(user_id, opponent_id, *, count, wins, mode="duel", legend=LEGEND, status="confirmed"):
    """Insère des matchs terminés en base : un par jour, les victoires en dernier.

    Passer par l'API demanderait un salon et deux sessions par partie ; ici seul
    l'agrégat compte. Les `wins` derniers matchs (les plus récents) sont gagnés,
    ce qui donne une meilleure série égale à `wins`.
    """
    with db_module.SessionLocal() as session:
        for index in range(count):
            moment = datetime.now(UTC) - timedelta(days=index)
            won = index < wins
            match = Match(
                mode=mode,
                status=status,
                host_id=user_id,
                first_player_id=user_id,
                started_at=moment,
                ended_at=moment,
                winner_user_id=user_id if won else opponent_id,
                state={},
                version=1,
                result={},
            )
            session.add(match)
            session.flush()
            session.add(
                MatchPlayer(
                    match_id=match.id,
                    user_id=user_id,
                    seat=0,
                    legend_card_id=legend,
                    score=8 if won else 3,
                    rounds_won=1 if won else 0,
                )
            )
            session.add(
                MatchPlayer(
                    match_id=match.id,
                    user_id=opponent_id,
                    seat=1,
                    legend_card_id=legend,
                    score=3 if won else 8,
                    rounds_won=0 if won else 1,
                )
            )
        session.commit()


def suspend(user_id, days=7):
    with db_module.SessionLocal() as session:
        user = session.get(User, user_id)
        user.suspended_until = datetime.now(UTC) + timedelta(days=days)
        user.suspension_reason = "test"
        session.commit()


def own_base_set(client, headers):
    """Possède toutes les cartes de base du set OGN (complétion à 100 %)."""
    for card_id in BASE_CARDS:
        assert client.put(f"/api/collection/{card_id}", json={"qty": 1}, headers=headers).status_code == 200


def deck_payload(**overrides):
    payload = {
        "name": "Étincelle de Fureur",
        "description": "Deck de test.",
        "format": "tournament",
        "is_public": True,
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


# ---------- réglages de confidentialité ----------


def test_privacy_settings_are_returned_and_patched_without_password(client, auth):
    me = client.get("/api/auth/me", headers=auth).json()
    assert me["show_stats"] is False and me["show_collection"] is False
    assert me["show_decks"] is True and me["show_achievements"] is True

    patched = client.patch(
        "/api/auth/me",
        json={"show_stats": True, "show_collection": True, "show_decks": False, "show_achievements": False},
        headers=auth,
    )
    assert patched.status_code == 200, patched.text
    body = patched.json()
    assert body["show_stats"] is True and body["show_collection"] is True
    assert body["show_decks"] is False and body["show_achievements"] is False
    assert client.get("/api/auth/me", headers=auth).json()["show_stats"] is True


# ---------- profil public ----------


def test_public_profile_hides_sections_until_they_are_opened(client, auth, register_user):
    own_base_set(client, auth)
    assert client.post("/api/decks", json=deck_payload(), headers=auth).status_code == 201

    anonymous = client.get("/api/users/testeur")
    assert anonymous.status_code == 200, anonymous.text
    profile = anonymous.json()
    assert profile["handle"] == "testeur"
    assert profile["is_me"] is False and profile["is_followed"] is None
    assert profile["followers_count"] == 0 and profile["following_count"] == 0
    assert profile["visibility"] == {
        "show_stats": False,
        "show_collection": False,
        "show_decks": True,
        "show_achievements": True,
    }
    assert profile["stats"] is None and profile["collection_summary"] is None
    assert [deck["name"] for deck in profile["decks"]] == ["Étincelle de Fureur"]
    assert profile["decks"][0]["legend"]["id"] == LEGEND
    assert any(item["key"] == "set_complete" for item in profile["achievements"])

    # Le propriétaire voit ses propres sections même masquées.
    mine = client.get("/api/users/testeur", headers=auth).json()
    assert mine["is_me"] is True and mine["is_followed"] is False
    assert mine["stats"]["totals"]["played"] == 0
    assert mine["collection_summary"]["unique_cards"] == len(BASE_CARDS)
    assert mine["collection_summary"]["sets"][0]["set_id"] == "OGN"

    assert client.patch("/api/auth/me", json={"show_stats": True}, headers=auth).status_code == 200
    assert client.get("/api/users/testeur").json()["stats"]["totals"]["played"] == 0


def test_public_profile_is_404_for_unknown_and_suspended_accounts(client, auth, register_user):
    _headers, banned_id = account(client, register_user, "banni")
    assert client.get("/api/users/banni").status_code == 200
    suspend(banned_id)
    assert client.get("/api/users/banni").status_code == 404
    assert client.get("/api/users/inconnu").status_code == 404


def test_public_collection_and_history_follow_the_privacy_settings(client, auth, register_user):
    other, other_id = account(client, register_user, "adversaire")
    own_base_set(client, other)
    add_matches(other_id, client.get("/api/auth/me", headers=auth).json()["id"], count=2, wins=1)

    assert client.get("/api/users/adversaire/collection", headers=auth).status_code == 403
    assert client.get("/api/users/adversaire/history", headers=auth).status_code == 403
    # Le propriétaire n'est jamais bloqué par ses propres réglages.
    assert client.get("/api/users/adversaire/collection", headers=other).status_code == 200

    assert (
        client.patch("/api/auth/me", json={"show_collection": True, "show_stats": True}, headers=other).status_code
        == 200
    )

    collection = client.get("/api/users/adversaire/collection?q=phoenix", headers=auth)
    assert collection.status_code == 200, collection.text
    body = collection.json()
    assert body["unique_cards"] == len(BASE_CARDS)
    assert [item["card"]["id"] for item in body["items"]] == ["ogn-037-298"]
    assert body["items"][0]["total_qty"] == 1
    assert "entries" not in body["items"][0]  # états et langues restent privés

    history = client.get("/api/users/adversaire/history", headers=auth)
    assert history.status_code == 200, history.text
    assert history.json()["total"] == 2
    assert {item["outcome"] for item in history.json()["items"]} == {"win", "loss"}
    assert history.json()["items"][0]["opponent"]["handle"] == "testeur"


# ---------- recherche ----------


def test_search_matches_a_prefix_and_ignores_suspended_accounts(client, auth, register_user):
    make_users("marin", "marine", "marinier", "zoe")
    _headers, banned_id = account(client, register_user, "marius")
    suspend(banned_id)

    found = client.get("/api/users/search?q=mar")
    assert found.status_code == 200, found.text
    assert [item["handle"] for item in found.json()] == ["marin", "marine", "marinier"]
    assert set(found.json()[0]) == {"id", "handle", "avatar_url"}

    assert client.get("/api/users/search?q=m").status_code == 422  # 2 caractères minimum
    assert client.get("/api/users/search?q=arin").json() == []  # préfixe, pas sous-chaîne

    make_users(*[f"limite{index}" for index in range(12)])
    assert len(client.get("/api/users/search?q=limite").json()) == 10


# ---------- amis ----------


def test_follow_is_idempotent_refuses_self_and_feeds_both_lists(client, auth, register_user):
    other, other_id = account(client, register_user, "copain")
    add_matches(other_id, 999, count=1, wins=1)

    assert client.put("/api/users/testeur/follow", headers=auth).status_code == 409
    assert client.put("/api/users/copain/follow", headers=auth).status_code == 204
    assert client.put("/api/users/copain/follow", headers=auth).status_code == 204  # idempotent
    assert client.put("/api/users/inconnu/follow", headers=auth).status_code == 404

    mine = client.get("/api/me/follows", headers=auth).json()
    assert [item["handle"] for item in mine["following"]] == ["copain"]
    assert mine["following"][0]["last_match_at"] is not None
    assert mine["followers"] == []

    theirs = client.get("/api/me/follows", headers=other).json()
    assert [item["handle"] for item in theirs["followers"]] == ["testeur"]
    assert theirs["following"] == []

    profile = client.get("/api/users/copain", headers=auth).json()
    assert profile["is_followed"] is True and profile["followers_count"] == 1

    assert client.delete("/api/users/copain/follow", headers=auth).status_code == 204
    assert client.delete("/api/users/copain/follow", headers=auth).status_code == 204  # idempotent
    assert client.get("/api/me/follows", headers=auth).json()["following"] == []


# ---------- hauts faits ----------


def test_achievements_catalogue_unlocks_each_family_once(client, auth):
    me_id = client.get("/api/auth/me", headers=auth).json()["id"]
    friends = make_users("rival", "ami1", "ami2", "ami3", "ami4", "ami5")
    add_matches(me_id, friends["rival"], count=12, wins=10)
    own_base_set(client, auth)
    assert client.post("/api/decks", json=deck_payload(), headers=auth).status_code == 201
    for handle in ("ami1", "ami2", "ami3", "ami4", "ami5"):
        assert client.put(f"/api/users/{handle}/follow", headers=auth).status_code == 204

    response = client.get("/api/me/achievements", headers=auth)
    assert response.status_code == 200, response.text
    items = response.json()
    assert len(items) == len(CATALOGUE)  # catalogue complet, débloqué ou non
    by_key = {item["key"]: item for item in items}
    assert set(item["family"] for item in items) == {"duels", "collection", "decks", "social"}
    assert by_key["veteran_10"]["current"] == 12 and by_key["veteran_10"]["threshold"] == 10
    assert by_key["winner_10"]["current"] == 10 and by_key["streak_10"]["current"] == 10
    assert by_key["six_domains"]["current"] == 2  # Fury + Mind, la seule légende semée
    assert by_key["giant_slayer"]["current"] == 0 and by_key["marathon"]["current"] == 0
    assert by_key["regular"]["current"] == 12 and by_key["regular"]["unlocked_at"] is None
    assert by_key["collector_100"]["current"] == len(BASE_CARDS)
    assert by_key["set_complete"]["current"] == 1
    assert by_key["architect_1"]["current"] == 1 and by_key["sociable_5"]["current"] == 5
    assert by_key["first_blood"]["tier"] == "bronze" and by_key["set_complete"]["tier"] == "prism"
    assert by_key["first_blood"]["icon"] and by_key["first_blood"]["description"]

    unlocked = {key for key, item in by_key.items() if item["unlocked_at"]}
    assert unlocked == {
        "first_blood",
        "veteran_10",
        "winner_10",
        "streak_3",
        "streak_5",
        "streak_10",
        "set_complete",
        "architect_1",
        "sociable_5",
    }

    # Deuxième lecture : la date de déblocage est figée, aucune ligne en double.
    again = {item["key"]: item for item in client.get("/api/me/achievements", headers=auth).json()}
    assert again["winner_10"]["unlocked_at"] == by_key["winner_10"]["unlocked_at"]
    with db_module.SessionLocal() as session:
        assert session.scalar(select(func.count()).select_from(Achievement)) == len(unlocked)
        progress = session.scalar(select(Achievement.progress).where(Achievement.key == "veteran_10"))
        assert progress == 12  # valeur atteinte au déblocage

    # Le profil public n'affiche que les débloqués, dans l'ordre de déblocage.
    public = client.get("/api/users/testeur").json()["achievements"]
    assert {item["key"] for item in public} == unlocked
    assert all(item["unlocked_at"] for item in public)


def test_achievements_are_evaluated_after_a_confirmed_match(client, auth, register_user):
    guest, guest_id = account(client, register_user, "invite")
    me_id = client.get("/api/auth/me", headers=auth).json()["id"]

    room = client.post("/api/play/rooms", json={"mode": "duel"}, headers=auth).json()["code"]
    assert client.post(f"/api/play/rooms/{room}/join", headers=guest).status_code == 200
    seat = {"legend_card_id": LEGEND, "ready": True}
    assert client.put(f"/api/play/rooms/{room}/me", json=seat, headers=auth).status_code == 200
    assert client.put(f"/api/play/rooms/{room}/me", json=seat, headers=guest).status_code == 200
    match = client.post(f"/api/play/rooms/{room}/start", json={"first_player_id": me_id}, headers=auth).json()
    result = {
        "round": 1,
        "turn": 5,
        "active_user_id": me_id,
        "scores": {str(me_id): 8, str(guest_id): 3},
        "xp": {str(me_id): 4, str(guest_id): 2},
        "rounds_won": {str(me_id): 1, str(guest_id): 0},
    }
    finish = {"winner_user_id": me_id, "result": result}
    assert client.post(f"/api/play/matches/{match['id']}/finish", json=finish, headers=auth).status_code == 200
    assert client.post(f"/api/play/matches/{match['id']}/confirm", headers=guest).status_code == 200

    # Le perdant a confirmé : son « Habitué » n'est pas encore atteint, mais le
    # vainqueur décroche « Premier sang » sans avoir à ouvrir son profil.
    with db_module.SessionLocal() as session:
        keys = set(session.scalars(select(Achievement.key).where(Achievement.user_id == guest_id)))
        assert keys == set()
        assert session.scalar(select(Achievement).where(Achievement.user_id == me_id)) is None
    assert client.get("/api/users/testeur").json()["achievements"][0]["key"] == "first_blood"


def test_abandon_records_the_winners_achievement(client, auth, register_user):
    guest, guest_id = account(client, register_user, "deserteur")
    me_id = client.get("/api/auth/me", headers=auth).json()["id"]
    room = client.post("/api/play/rooms", json={"mode": "duel"}, headers=auth).json()["code"]
    assert client.post(f"/api/play/rooms/{room}/join", headers=guest).status_code == 200
    seat = {"legend_card_id": LEGEND, "ready": True}
    assert client.put(f"/api/play/rooms/{room}/me", json=seat, headers=auth).status_code == 200
    assert client.put(f"/api/play/rooms/{room}/me", json=seat, headers=guest).status_code == 200
    match = client.post(f"/api/play/rooms/{room}/start", json={"first_player_id": me_id}, headers=auth).json()

    assert client.post(f"/api/play/matches/{match['id']}/abandon", headers=guest).status_code == 200
    # L'abandon est compté sans confirmation : le gagnant (moi) décroche son premier sang.
    assert client.get("/api/me/achievements", headers=auth).json()[0]["unlocked_at"] is not None


# ---------- suppression de compte et export ----------


def test_account_deletion_removes_achievements_and_follows(client, auth, register_user):
    other, other_id = account(client, register_user, "temoin")
    me_id = client.get("/api/auth/me", headers=auth).json()["id"]
    add_matches(me_id, other_id, count=1, wins=1)
    assert client.put("/api/users/temoin/follow", headers=auth).status_code == 204
    assert client.put("/api/users/testeur/follow", headers=other).status_code == 204
    assert client.get("/api/me/achievements", headers=auth).json()[0]["unlocked_at"] is not None

    deleted = client.request(
        "DELETE", "/api/auth/me", json={"password": "motdepasse123", "handle": "testeur"}, headers=auth
    )
    assert deleted.status_code == 204, deleted.text
    with db_module.SessionLocal() as session:
        assert session.scalar(select(func.count()).select_from(Achievement)) == 0
        assert session.scalar(select(func.count()).select_from(Follow)) == 0
    assert client.get("/api/users/testeur").status_code == 404
    assert client.get("/api/me/follows", headers=other).json() == {"following": [], "followers": []}


def test_export_carries_achievements_and_follows(client, auth, register_user):
    other, other_id = account(client, register_user, "voisin")
    me_id = client.get("/api/auth/me", headers=auth).json()["id"]
    add_matches(me_id, other_id, count=1, wins=1)
    assert client.put("/api/users/voisin/follow", headers=auth).status_code == 204
    assert client.put("/api/users/testeur/follow", headers=other).status_code == 204
    client.get("/api/me/achievements", headers=auth)

    export = client.get("/api/auth/export", headers=auth)
    assert export.status_code == 200, export.text
    body = export.json()
    assert [item["key"] for item in body["achievements"]] == ["first_blood"]
    assert body["achievements"][0]["progress"] == 1 and body["achievements"][0]["unlocked_at"]
    assert body["follows"] == {"following": ["voisin"], "followers": ["voisin"]}
