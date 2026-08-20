"""Notifications e-mail de modération : préférence utilisateur et envoi ciblé.

Le propriétaire d'un deck sorti de la file « pending » (approbation ou rejet)
reçoit un e-mail — uniquement si son adresse est vérifiée ET si la préférence
notify_moderation (activée par défaut) n'a pas été désactivée depuis le profil.
"""

import logging
from datetime import UTC, datetime

import app.db as db_module
import pytest
from app import mailer
from app.models import User
from sqlalchemy import select

from conftest import bearer_headers

ADMIN_TOKEN_HEADERS = {"X-Admin-Token": "test-admin-token-ok"}
PENDING_NAME = "deck de connard"  # terme banni : la création part en file « pending »


def deck_payload(name, **overrides):
    payload = {"name": name, "description": "", "format": "free", "is_public": True, "cards": []}
    payload.update(overrides)
    return payload


def verify_address(handle):
    with db_module.SessionLocal() as session:
        user = session.scalar(select(User).where(User.handle == handle))
        user.email_verified_at = datetime.now(UTC)
        session.commit()


def moderate(client, deck_id, status):
    response = client.post(
        f"/api/admin/decks/{deck_id}/moderation", json={"status": status}, headers=ADMIN_TOKEN_HEADERS
    )
    assert response.status_code == 200, response.text
    return response.json()


@pytest.fixture()
def moderation_outbox(monkeypatch):
    """Capture les notifications : liste de tuples (to, deck_name, deck_id, approved)."""
    sent = []
    monkeypatch.setattr(
        mailer,
        "send_moderation_email_async",
        lambda to, deck_name, deck_id, approved: sent.append((to, deck_name, deck_id, approved)),
    )
    return sent


@pytest.fixture()
def owner(client, register_user):
    assert register_user(client, "proprio").status_code == 201
    return bearer_headers(client)


# ---------- préférence utilisateur ----------


def test_notify_moderation_defaults_to_true_and_is_patchable_without_password(client, owner):
    assert client.get("/api/auth/me", headers=owner).json()["notify_moderation"] is True

    patched = client.patch("/api/auth/me", json={"notify_moderation": False}, headers=owner)
    assert patched.status_code == 200  # pas de current_password requis pour cette préférence
    assert patched.json()["notify_moderation"] is False
    assert client.get("/api/auth/me", headers=owner).json()["notify_moderation"] is False

    assert client.patch("/api/auth/me", json={"notify_moderation": True}, headers=owner).status_code == 200
    assert client.get("/api/auth/me", headers=owner).json()["notify_moderation"] is True


# ---------- déclenchement à la décision de modération ----------


def test_approval_notifies_verified_owner(client, owner, moderation_outbox):
    verify_address("proprio")
    deck = client.post("/api/decks", json=deck_payload(PENDING_NAME), headers=owner).json()
    assert deck["moderation_status"] == "pending"

    assert moderate(client, deck["id"], "approved")["moderation_status"] == "published"
    assert moderation_outbox == [("proprio@example.org", PENDING_NAME, deck["id"], True)]


def test_rejection_notifies_verified_owner(client, owner, moderation_outbox):
    verify_address("proprio")
    deck = client.post("/api/decks", json=deck_payload(PENDING_NAME), headers=owner).json()

    assert moderate(client, deck["id"], "rejected")["moderation_status"] == "rejected"
    assert moderation_outbox == [("proprio@example.org", PENDING_NAME, deck["id"], False)]


def test_no_email_when_address_is_not_verified(client, owner, moderation_outbox):
    deck = client.post("/api/decks", json=deck_payload(PENDING_NAME), headers=owner).json()
    moderate(client, deck["id"], "approved")
    assert moderation_outbox == []


def test_no_email_when_preference_is_disabled(client, owner, moderation_outbox):
    verify_address("proprio")
    assert client.patch("/api/auth/me", json={"notify_moderation": False}, headers=owner).status_code == 200
    deck = client.post("/api/decks", json=deck_payload(PENDING_NAME), headers=owner).json()
    moderate(client, deck["id"], "rejected")
    assert moderation_outbox == []


def test_no_email_when_status_does_not_change(client, owner, moderation_outbox):
    verify_address("proprio")
    # Deck au nom sain : publié directement, jamais passé par « pending ».
    published = client.post("/api/decks", json=deck_payload("Deck déjà publié"), headers=owner).json()
    assert published["moderation_status"] == "published"
    moderate(client, published["id"], "approved")  # re-approuver un deck publié
    assert moderation_outbox == []

    # Un deck « pending » approuvé deux fois ne notifie qu'une seule fois.
    pending = client.post("/api/decks", json=deck_payload(PENDING_NAME), headers=owner).json()
    moderate(client, pending["id"], "approved")
    moderate(client, pending["id"], "approved")
    assert moderation_outbox == [("proprio@example.org", PENDING_NAME, pending["id"], True)]


# ---------- contenu du message et helper asynchrone ----------


def test_moderation_email_contents_in_console_mode(caplog, monkeypatch):
    monkeypatch.setattr(mailer.settings, "smtp_host", "")
    monkeypatch.setattr(mailer.settings, "public_base_url", "http://localhost:8888")

    with caplog.at_level(logging.INFO, logger="riftarium.mailer"):
        mailer.send_moderation_email("joueur@example.org", "Contrôle du Vide", 42, approved=True)
    assert "joueur@example.org" in caplog.text
    assert "Votre deck “Contrôle du Vide” est publié — Riftarium" in caplog.text
    assert "http://localhost:8888/decks/42" in caplog.text
    assert "visible par toute la communauté" in caplog.text
    assert "désactiver ces notifications depuis votre profil" in caplog.text

    caplog.clear()
    with caplog.at_level(logging.INFO, logger="riftarium.mailer"):
        mailer.send_moderation_email("joueur@example.org", "Contrôle du Vide", 42, approved=False)
    assert "Votre deck “Contrôle du Vide” n'a pas été retenu — Riftarium" in caplog.text
    assert "http://localhost:8888/decks/42" in caplog.text
    # Ton bienveillant : pas de motif détaillé, invitation à re-proposer le deck.
    assert "le modifier puis le proposer à nouveau" in caplog.text
    assert "désactiver ces notifications depuis votre profil" in caplog.text


def test_send_moderation_email_async_delivers_in_background_thread(monkeypatch):
    sent = []
    monkeypatch.setattr(mailer, "send_moderation_email", lambda *args: sent.append(args))
    thread = mailer.send_moderation_email_async("joueur@example.org", "Deck du fond", 7, True)
    assert thread is not None
    thread.join(timeout=5)
    assert sent == [("joueur@example.org", "Deck du fond", 7, True)]


def test_send_moderation_email_async_logs_thread_failure(monkeypatch, caplog):
    class BrokenThread:
        def __init__(self, *args, **kwargs):
            raise RuntimeError("plus de threads disponibles")

    monkeypatch.setattr(mailer.threading, "Thread", BrokenThread)
    with caplog.at_level(logging.ERROR, logger="riftarium.mailer"):
        assert mailer.send_moderation_email_async("joueur@example.org", "Deck", 1, False) is None
    assert "impossible de lancer l'envoi" in caplog.text
