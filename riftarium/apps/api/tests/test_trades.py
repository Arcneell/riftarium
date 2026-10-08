"""Échanges entre joueurs : réglages, offres, correspondances, demandes et e-mails.

Contrat : docs/echanges.md.
"""

from datetime import UTC, datetime

import app.db as db_module
from app.models import User
from sqlalchemy import select

from conftest import bearer_headers

PHOENIX = "ogn-037-298"
AHRI = "ogn-119-298"
LEE = "ogn-078-298"


def account(client, register_user, handle, *, zone=None, verified=True):
    """Inscrit un compte (adresse vérifiée par défaut), active les échanges si `zone` est donnée."""
    assert register_user(client, handle).status_code == 201
    headers = bearer_headers(client)
    if verified:
        set_user(handle, email_verified_at=datetime.now(UTC))
    if zone:
        enable(client, headers, zone, f"Discord : {handle}")
    return headers


def set_user(handle, **values):
    with db_module.SessionLocal() as session:
        user = session.scalar(select(User).where(User.handle == handle))
        for key, value in values.items():
            setattr(user, key, value)
        session.commit()


def enable(client, headers, zone, contact):
    response = client.patch(
        "/api/auth/me", json={"trade_enabled": True, "trade_zone": zone, "trade_contact": contact}, headers=headers
    )
    assert response.status_code == 200, response.text
    return response.json()


def add_lot(client, headers, card_id, qty=1, condition="NM", lang="EN"):
    """Ajoute un lot à la collection et renvoie son identifiant."""
    response = client.post(
        f"/api/collection/{card_id}/entries",
        json={"qty": qty, "condition": condition, "lang": lang},
        headers=headers,
    )
    assert response.status_code == 200, response.text
    return next(e["id"] for e in response.json()["entries"] if e["condition"] == condition and e["lang"] == lang)


def offer(client, headers, entry_id, qty=1):
    response = client.put(f"/api/trades/offers/{entry_id}", json={"qty": qty}, headers=headers)
    assert response.status_code == 200, response.text
    return response.json()["id"]


def wish(client, headers, card_id, qty=1):
    assert client.put(f"/api/wishlist/{card_id}", json={"qty": qty}, headers=headers).status_code == 204


def ask(client, headers, offer_id, message=""):
    return client.post("/api/trades/requests", json={"offer_id": offer_id, "message": message}, headers=headers)


# ---------- Réglages ----------


def test_settings_default_off(client, register_user):
    headers = account(client, register_user, "alice")
    me = client.get("/api/auth/me", headers=headers).json()
    assert me["trade_enabled"] is False
    assert me["trade_zone"] is None and me["trade_contact"] is None
    assert me["notify_trades"] is True


def test_enable_requires_zone_and_contact(client, register_user):
    headers = account(client, register_user, "alice")
    assert client.patch("/api/auth/me", json={"trade_enabled": True}, headers=headers).status_code == 422
    blank = {"trade_enabled": True, "trade_zone": "sud", "trade_contact": "   "}
    assert client.patch("/api/auth/me", json=blank, headers=headers).status_code == 422
    body = enable(client, headers, "sud", " Discord : alice ")
    assert body["trade_enabled"] is True
    assert body["trade_zone"] == "sud"
    assert body["trade_contact"] == "Discord : alice"
    # Vider le contact alors que les échanges sont actifs : refusé.
    assert client.patch("/api/auth/me", json={"trade_contact": ""}, headers=headers).status_code == 422


def test_zone_must_be_known(client, register_user):
    headers = account(client, register_user, "alice")
    assert client.patch("/api/auth/me", json={"trade_zone": "paris"}, headers=headers).status_code == 422


def test_contact_not_in_public_profile(client, register_user):
    account(client, register_user, "alice", zone="nord")
    profile = client.get("/api/users/alice").json()
    assert "trade_contact" not in profile


def test_notify_trades_toggle(client, register_user):
    headers = account(client, register_user, "alice")
    body = client.patch("/api/auth/me", json={"notify_trades": False}, headers=headers).json()
    assert body["notify_trades"] is False
