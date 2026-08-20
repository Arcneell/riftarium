"""Page d'administration : droits ADMIN_EMAILS, stats, comptes, suspension, decks."""

from datetime import UTC, datetime, timedelta

import app.db as db_module
import pytest
from app.config import settings
from app.main import app
from app.models import CollectionItem, Deck, DeckCard, DeckLike, DeckView, User
from fastapi.testclient import TestClient
from sqlalchemy import select

from conftest import bearer_headers


def deck_payload(name="Deck admin-test", **overrides):
    payload = {"name": name, "description": "", "format": "free", "is_public": True, "cards": []}
    payload.update(overrides)
    return payload


def grant_admin(handle):
    with db_module.SessionLocal() as session:
        user = session.scalar(select(User).where(User.handle == handle))
        user.is_admin = True
        session.commit()
        return user.id


def get_user(handle):
    with db_module.SessionLocal() as session:
        return session.scalar(select(User).where(User.handle == handle))


@pytest.fixture()
def admin_auth(client, register_user):
    assert register_user(client, "superviseur").status_code == 201
    headers = bearer_headers(client)
    grant_admin("superviseur")
    return headers


@pytest.fixture()
def member(client, register_user):
    """Un compte simple « membre » : (headers, id)."""
    assert register_user(client, "membre").status_code == 201
    headers = bearer_headers(client)
    return headers, get_user("membre").id


# ---------- droits pilotés par ADMIN_EMAILS ----------


def test_startup_grants_and_revokes_admin_from_env(client, register_user, monkeypatch):
    register_user(client, "future-admin", email="Future-Admin@example.org")
    register_user(client, "ancien-admin", email="ancien-admin@example.org")
    grant_admin("ancien-admin")

    # Liste avec casse différente et espaces : le compte listé gagne les droits,
    # l'ancien admin absent de la liste les perd (source de vérité unique).
    monkeypatch.setattr(settings, "admin_emails", "  FUTURE-ADMIN@example.org , inconnue@example.org ")
    with TestClient(app):
        pass

    assert get_user("future-admin").is_admin is True
    assert get_user("ancien-admin").is_admin is False


def test_startup_with_empty_admin_emails_revokes_everyone(client, register_user):
    register_user(client, "solo-admin")
    grant_admin("solo-admin")
    # settings.admin_emails vaut "" (défaut) : tout drapeau existant est retiré.
    with TestClient(app):
        pass
    assert get_user("solo-admin").is_admin is False


# ---------- contrôle d'accès ----------

ADMIN_ROUTES = [
    ("GET", "/api/admin/stats", None),
    ("GET", "/api/admin/users", None),
    ("POST", "/api/admin/users/1/suspend", {"hours": 1, "reason": "test"}),
    ("DELETE", "/api/admin/users/1/suspend", None),
    ("DELETE", "/api/admin/users/1", None),
    ("GET", "/api/admin/decks", None),
    ("POST", "/api/admin/decks/1/moderation", {"status": "approved"}),
    ("DELETE", "/api/admin/decks/1", None),
]


def test_admin_routes_refuse_anonymous_and_non_admin(client, auth):
    for method, url, body in ADMIN_ROUTES:
        anonymous = client.request(method, url, json=body)
        assert anonymous.status_code == 403, f"{method} {url} anonyme : {anonymous.status_code}"
        assert anonymous.json()["detail"] in {"Accès réservé"}
        logged = client.request(method, url, json=body, headers=auth)
        assert logged.status_code == 403, f"{method} {url} non-admin : {logged.status_code}"
        assert logged.json()["detail"] == "Accès réservé"


def test_admin_mutations_reject_cross_origin(client, admin_auth, member):
    _, member_id = member
    response = client.post(
        f"/api/admin/users/{member_id}/suspend",
        json={"hours": 1, "reason": "test"},
        headers={**admin_auth, "Origin": "https://evil.example"},
    )
    assert response.status_code == 403
    assert response.json()["detail"] == "Origine non autorisée"
    assert get_user("membre").suspended_until is None  # rien n'a été appliqué


# ---------- statistiques ----------


def test_admin_stats_reflect_seeded_data(client, admin_auth, member):
    member_headers, _ = member
    public = client.post("/api/decks", json=deck_payload(name="Deck public"), headers=member_headers).json()
    pending = client.post("/api/decks", json=deck_payload(name="deck de connard"), headers=member_headers).json()
    assert pending["moderation_status"] == "pending"
    client.put("/api/collection/ogn-037-298", json={"qty": 3}, headers=member_headers)
    client.put("/api/collection/ogn-200-298", json={"qty": 1}, headers=member_headers)
    assert client.post(f"/api/decks/{public['id']}/like", headers=admin_auth).status_code == 200

    stats = client.get("/api/admin/stats", headers=admin_auth)
    assert stats.status_code == 200
    data = stats.json()
    assert data["users"] == {"total": 2, "new_7d": 2, "new_30d": 2, "suspended": 0, "verified": 0}
    assert data["decks"] == {"total": 2, "public": 2, "pending": 1, "likes_total": 1, "views_total": 0}
    assert data["collection"] == {"entries_total": 2, "cards_total": 4}
    assert data["cards"] == {"total": 11, "sets": 1}
    assert [entry["handle"] for entry in data["recent"]["signups"]] == ["membre", "superviseur"]
    recent_decks = data["recent"]["decks"]
    assert {deck["name"] for deck in recent_decks} == {"Deck public", "deck de connard"}
    assert all(deck["owner"] == "membre" and deck["created_at"] for deck in recent_decks)
    assert data["visits"]["today_hits"] == 0  # aucune fréquentation enregistrée


# ---------- listing et recherche des comptes ----------


def test_admin_users_listing_and_search(client, admin_auth, member):
    member_headers, member_id = member
    client.post("/api/decks", json=deck_payload(), headers=member_headers)
    client.put("/api/collection/ogn-037-298", json={"qty": 2}, headers=member_headers)

    listing = client.get("/api/admin/users", headers=admin_auth)
    assert listing.status_code == 200
    data = listing.json()
    assert data["total"] == 2
    assert [item["handle"] for item in data["items"]] == ["membre", "superviseur"]  # created_at desc
    entry = next(item for item in data["items"] if item["id"] == member_id)
    assert entry["email"] == "membre@example.org"
    assert entry["email_verified"] is False
    assert entry["is_admin"] is False
    assert entry["suspended_until"] is None and entry["suspension_reason"] is None
    assert entry["decks_count"] == 1 and entry["collection_count"] == 1

    # Recherche insensible à la casse, sur pseudo OU e-mail.
    assert client.get("/api/admin/users", params={"q": "MEMB"}, headers=admin_auth).json()["total"] == 1
    by_email = client.get("/api/admin/users", params={"q": "membre@EXAMPLE"}, headers=admin_auth).json()
    assert by_email["total"] == 1
    # Les jokers SQL sont neutralisés : « % » ne matche pas tout.
    assert client.get("/api/admin/users", params={"q": "%"}, headers=admin_auth).json()["total"] == 0

    paged = client.get("/api/admin/users", params={"page_size": 1, "page": 2}, headers=admin_auth).json()
    assert paged["total"] == 2 and paged["size"] == 1 and paged["page"] == 2
    assert len(paged["items"]) == 1
    assert client.get("/api/admin/users", params={"page_size": 51}, headers=admin_auth).status_code == 422


# ---------- suspension ----------


def test_suspension_blocks_login_and_active_sessions(client, admin_auth, member):
    member_headers, member_id = member
    response = client.post(
        f"/api/admin/users/{member_id}/suspend",
        json={"hours": 48, "reason": "Propos interdits en description"},
        headers=admin_auth,
    )
    assert response.status_code == 204

    # Login refusé avec un message français explicite (date JJ/MM/AAAA HH:MM + motif).
    login = client.post("/api/auth/login", json={"email": "membre@example.org", "password": "motdepasse123"})
    assert login.status_code == 403
    detail = login.json()["detail"]
    assert detail.startswith("Compte suspendu jusqu'au ")
    assert "— motif : Propos interdits en description" in detail
    expected = get_user("membre").suspended_until.strftime("%d/%m/%Y %H:%M")
    assert expected in detail

    # La session déjà ouverte est coupée aussi.
    assert client.get("/api/auth/me", headers=member_headers).status_code == 403
    assert client.get("/api/decks/mine", headers=member_headers).status_code == 403

    # Levée de la suspension : tout revient à la normale.
    lifted = client.delete(f"/api/admin/users/{member_id}/suspend", headers=admin_auth)
    assert lifted.status_code == 204
    assert get_user("membre").suspended_until is None
    assert client.get("/api/auth/me", headers=member_headers).status_code == 200
    relogin = client.post("/api/auth/login", json={"email": "membre@example.org", "password": "motdepasse123"})
    assert relogin.status_code == 200


def test_expired_suspension_is_ignored(client, member):
    member_headers, member_id = member
    with db_module.SessionLocal() as session:
        user = session.get(User, member_id)
        user.suspended_until = datetime.now(UTC) - timedelta(hours=1)
        user.suspension_reason = "ancienne sanction"
        session.commit()
    assert client.get("/api/auth/me", headers=member_headers).status_code == 200
    relogin = client.post("/api/auth/login", json={"email": "membre@example.org", "password": "motdepasse123"})
    assert relogin.status_code == 200


def test_suspension_validation_and_self_suspension(client, admin_auth, member):
    _, member_id = member
    admin_id = get_user("superviseur").id

    me = client.post(f"/api/admin/users/{admin_id}/suspend", json={"hours": 1, "reason": "oups"}, headers=admin_auth)
    assert me.status_code == 400  # un admin ne peut pas se suspendre lui-même

    zero = client.post(f"/api/admin/users/{member_id}/suspend", json={"hours": 0, "reason": "x"}, headers=admin_auth)
    assert zero.status_code == 422  # hours=0 interdit
    too_long = client.post(
        f"/api/admin/users/{member_id}/suspend", json={"hours": 24 * 3650 + 1, "reason": "x"}, headers=admin_auth
    )
    assert too_long.status_code == 422
    blank = client.post(f"/api/admin/users/{member_id}/suspend", json={"hours": 1, "reason": "   "}, headers=admin_auth)
    assert blank.status_code == 422
    missing = client.post("/api/admin/users/999999/suspend", json={"hours": 1, "reason": "x"}, headers=admin_auth)
    assert missing.status_code == 404
    assert client.delete("/api/admin/users/999999/suspend", headers=admin_auth).status_code == 404


# ---------- suppression de compte ----------


def test_admin_delete_user_cascades(client, admin_auth, member, register_user):
    member_headers, member_id = member
    register_user(client, "autre")
    autre_headers = bearer_headers(client)
    autre_deck = client.post("/api/decks", json=deck_payload(name="Deck d'autre"), headers=autre_headers).json()

    client.post("/api/decks", json=deck_payload(name="Deck du membre"), headers=member_headers)
    client.put("/api/collection/ogn-037-298", json={"qty": 2}, headers=member_headers)
    like = client.post(f"/api/decks/{autre_deck['id']}/like", headers=member_headers)
    assert like.json()["likes"] == 1

    assert client.delete(f"/api/admin/users/{member_id}", headers=admin_auth).status_code == 204

    with db_module.SessionLocal() as session:
        assert session.get(User, member_id) is None
        assert session.scalars(select(Deck).where(Deck.owner_id == member_id)).all() == []
        assert session.scalars(select(CollectionItem).where(CollectionItem.user_id == member_id)).all() == []
        assert session.scalars(select(DeckLike).where(DeckLike.user_id == member_id)).all() == []
        assert session.get(Deck, autre_deck["id"]).likes_count == 0  # like décrémenté

    assert client.delete("/api/admin/users/999999", headers=admin_auth).status_code == 404


def test_admin_accounts_cannot_be_deleted(client, admin_auth, register_user):
    admin_id = get_user("superviseur").id
    register_user(client, "co-admin")
    other_admin_id = grant_admin("co-admin")

    # Ni soi-même, ni un autre administrateur : retirer d'abord les droits via ADMIN_EMAILS.
    assert client.delete(f"/api/admin/users/{admin_id}", headers=admin_auth).status_code == 400
    assert client.delete(f"/api/admin/users/{other_admin_id}", headers=admin_auth).status_code == 400
    assert get_user("co-admin") is not None


# ---------- decks : listing, modération, suppression ----------


def test_admin_decks_listing_and_filters(client, admin_auth, member):
    member_headers, _ = member
    client.post("/api/decks", json=deck_payload(name="Deck publié"), headers=member_headers)
    pending = client.post("/api/decks", json=deck_payload(name="deck de connard"), headers=member_headers).json()
    client.post("/api/decks", json=deck_payload(name="Deck privé", is_public=False), headers=member_headers)

    listing = client.get("/api/admin/decks", headers=admin_auth)
    assert listing.status_code == 200
    data = listing.json()
    assert data["total"] == 3
    entry = next(item for item in data["items"] if item["id"] == pending["id"])
    assert entry["owner"] == "membre"
    assert entry["moderation_status"] == "pending"
    assert entry["is_public"] is True
    assert entry["likes_count"] == 0 and entry["views_count"] == 0 and entry["updated_at"]

    only_pending = client.get("/api/admin/decks", params={"status": "pending"}, headers=admin_auth).json()
    assert [item["id"] for item in only_pending["items"]] == [pending["id"]]
    assert client.get("/api/admin/decks", params={"status": "published"}, headers=admin_auth).json()["total"] == 2
    assert client.get("/api/admin/decks", params={"status": "inconnu"}, headers=admin_auth).status_code == 422
    assert client.get("/api/admin/decks", params={"q": "privé"}, headers=admin_auth).json()["total"] == 1
    assert client.get("/api/admin/decks", params={"q": "MEMBRE"}, headers=admin_auth).json()["total"] == 3
    assert client.get("/api/admin/decks", params={"q": "%"}, headers=admin_auth).json()["total"] == 0


def test_admin_deck_moderation_with_session(client, admin_auth, member):
    member_headers, _ = member
    pending = client.post("/api/decks", json=deck_payload(name="deck de connard"), headers=member_headers).json()
    url = f"/api/admin/decks/{pending['id']}/moderation"

    approved = client.post(url, json={"status": "approved"}, headers=admin_auth)
    assert approved.status_code == 200
    assert approved.json() == {"deck_id": pending["id"], "moderation_status": "published"}
    assert client.get("/api/community/decks").json()["total"] == 1

    rejected = client.post(url, json={"status": "rejected"}, headers=admin_auth)
    assert rejected.json()["moderation_status"] == "rejected"
    assert client.get("/api/community/decks").json()["total"] == 0

    assert client.post(url, json={"status": "nimporte"}, headers=admin_auth).status_code == 422
    missing = client.post("/api/admin/decks/999999/moderation", json={"status": "approved"}, headers=admin_auth)
    assert missing.status_code == 404


def test_admin_delete_deck_removes_everything(client, admin_auth, member):
    member_headers, _ = member
    payload = deck_payload(name="Deck à supprimer", cards=[{"card_id": "ogn-037-298", "qty": 3}])
    deck = client.post("/api/decks", json=payload, headers=member_headers).json()
    client.post(f"/api/decks/{deck['id']}/like", headers=admin_auth)
    client.post(f"/api/decks/{deck['id']}/view", headers=admin_auth)

    assert client.delete(f"/api/admin/decks/{deck['id']}", headers=admin_auth).status_code == 204

    with db_module.SessionLocal() as session:
        assert session.get(Deck, deck["id"]) is None
        assert session.scalars(select(DeckCard).where(DeckCard.deck_id == deck["id"])).all() == []
        assert session.scalars(select(DeckLike).where(DeckLike.deck_id == deck["id"])).all() == []
        assert session.scalars(select(DeckView).where(DeckView.deck_id == deck["id"])).all() == []

    assert client.delete("/api/admin/decks/999999", headers=admin_auth).status_code == 404


# ---------- /api/auth/me ----------


def test_me_exposes_is_admin(client, admin_auth, member):
    member_headers, _ = member
    assert client.get("/api/auth/me", headers=member_headers).json()["is_admin"] is False
    assert client.get("/api/auth/me", headers=admin_auth).json()["is_admin"] is True
