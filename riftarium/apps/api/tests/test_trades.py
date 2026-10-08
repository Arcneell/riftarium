"""Échanges entre joueurs : réglages, offres, correspondances, demandes et e-mails.

Contrat : docs/echanges.md.
"""

from datetime import UTC, datetime, timedelta

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


# ---------- Ma liste « À échanger » ----------


def my_offers(client, headers):
    return client.get("/api/trades/offers", headers=headers).json()


def test_offer_bounded_by_lot(client, register_user):
    headers = account(client, register_user, "alice")
    entry = add_lot(client, headers, PHOENIX, qty=3)
    assert client.put(f"/api/trades/offers/{entry}", json={"qty": 4}, headers=headers).status_code == 422
    response = client.put(f"/api/trades/offers/{entry}", json={"qty": 2}, headers=headers)
    assert response.status_code == 200
    body = response.json()
    assert body["qty"] == 2 and body["entry_qty"] == 3 and body["entry_id"] == entry
    assert body["card"]["id"] == PHOENIX and body["condition"] == "NM" and body["lang"] == "EN"
    # Mise à jour de la même offre (pas de doublon).
    offer(client, headers, entry, qty=3)
    assert [item["qty"] for item in my_offers(client, headers)] == [3]
    assert client.put(f"/api/trades/offers/{entry}", json={"qty": 0}, headers=headers).status_code == 204
    assert my_offers(client, headers) == []


def test_offer_delete_is_idempotent(client, register_user):
    headers = account(client, register_user, "alice")
    entry = add_lot(client, headers, PHOENIX)
    offer(client, headers, entry)
    assert client.delete(f"/api/trades/offers/{entry}", headers=headers).status_code == 204
    assert client.delete(f"/api/trades/offers/{entry}", headers=headers).status_code == 204
    assert my_offers(client, headers) == []


def test_offer_on_someone_elses_lot_is_404(client, register_user):
    alice = account(client, register_user, "alice")
    entry = add_lot(client, alice, PHOENIX)
    bob = account(client, register_user, "bob")
    assert client.put(f"/api/trades/offers/{entry}", json={"qty": 1}, headers=bob).status_code == 404
    assert client.put("/api/trades/offers/99999", json={"qty": 1}, headers=bob).status_code == 404


def test_offers_require_login(client):
    assert client.get("/api/trades/offers").status_code == 401


def test_offer_clamped_when_lot_shrinks(client, register_user):
    headers = account(client, register_user, "alice")
    entry = add_lot(client, headers, PHOENIX, qty=3)
    offer(client, headers, entry, qty=3)
    assert client.patch(f"/api/collection/entries/{entry}", json={"qty": 1}, headers=headers).status_code == 200
    assert [(item["qty"], item["entry_qty"]) for item in my_offers(client, headers)] == [(1, 1)]


def test_offer_clamped_by_bulk(client, register_user):
    headers = account(client, register_user, "alice")
    entry = add_lot(client, headers, PHOENIX, qty=3)
    offer(client, headers, entry, qty=3)
    bulk = {"card_ids": [PHOENIX], "qty_delta": -2}
    assert client.post("/api/collection/bulk", json=bulk, headers=headers).status_code == 200
    assert [item["qty"] for item in my_offers(client, headers)] == [1]


def test_offer_dropped_when_lot_merged(client, register_user):
    headers = account(client, register_user, "alice")
    played = add_lot(client, headers, PHOENIX, qty=1, condition="LP")
    add_lot(client, headers, PHOENIX, qty=1, condition="NM")
    offer(client, headers, played)
    # Reclassement LP → NM : le lot LP fusionne dans le lot NM et disparaît.
    patch = client.patch(f"/api/collection/entries/{played}", json={"condition": "NM"}, headers=headers)
    assert patch.status_code == 200
    assert my_offers(client, headers) == []


def test_offer_dropped_when_lot_removed(client, register_user):
    headers = account(client, register_user, "alice")
    entry = add_lot(client, headers, PHOENIX, qty=2)
    offer(client, headers, entry)
    put = client.put(f"/api/collection/{PHOENIX}", json={"qty": 0, "condition": "NM", "lang": "EN"}, headers=headers)
    assert put.status_code == 200
    assert my_offers(client, headers) == []


# ---------- Correspondances ----------


def offers_by_handle(card_block):
    return [item["owner"]["handle"] for item in card_block["offers"]]


def test_matches_require_enabled(client, register_user):
    headers = account(client, register_user, "alice")
    for path in ("/api/trades/matches/wanted", "/api/trades/matches/offered", f"/api/trades/cards/{PHOENIX}/offers"):
        assert client.get(path, headers=headers).status_code == 403


def test_wanted_crosses_wishlist(client, register_user):
    bob = account(client, register_user, "bob", zone="sud")
    offer(client, bob, add_lot(client, bob, PHOENIX, qty=2), qty=2)
    offer(client, bob, add_lot(client, bob, LEE))  # pas dans la wishlist d'alice
    # Comptes exclus : non inscrit aux échanges, suspendu.
    carl = account(client, register_user, "carl")
    offer(client, carl, add_lot(client, carl, PHOENIX))
    dave = account(client, register_user, "dave", zone="sud")
    offer(client, dave, add_lot(client, dave, PHOENIX))
    set_user("dave", suspended_until=datetime.now(UTC) + timedelta(days=3))

    alice = account(client, register_user, "alice", zone="sud")
    offer(client, alice, add_lot(client, alice, PHOENIX))  # sa propre offre n'apparaît pas
    wish(client, alice, PHOENIX)
    body = client.get("/api/trades/matches/wanted", headers=alice).json()
    assert body["total"] == 1
    block = body["items"][0]
    assert block["card"]["id"] == PHOENIX and block["wanted_qty"] == 1
    assert offers_by_handle(block) == ["bob"]
    first = block["offers"][0]
    assert first["qty"] == 2 and first["owner"]["zone"] == "sud"
    assert first["mutual"] is False and first["pending_request_id"] is None
    assert "contact" not in str(first)


def test_wanted_sorts_my_zone_then_mutual(client, register_user):
    north = account(client, register_user, "nordiste", zone="nord")
    offer(client, north, add_lot(client, north, PHOENIX))
    plain = account(client, register_user, "sudiste", zone="sud")
    offer(client, plain, add_lot(client, plain, PHOENIX))
    friend = account(client, register_user, "complice", zone="sud")
    offer(client, friend, add_lot(client, friend, PHOENIX))
    wish(client, friend, LEE)  # cherche une carte qu'alice propose

    alice = account(client, register_user, "alice", zone="sud")
    offer(client, alice, add_lot(client, alice, LEE))
    wish(client, alice, PHOENIX)
    block = client.get("/api/trades/matches/wanted", headers=alice).json()["items"][0]
    assert offers_by_handle(block) == ["complice", "sudiste", "nordiste"]
    assert block["offers"][0]["mutual"] is True


def test_wanted_zone_and_search_filters(client, register_user):
    north = account(client, register_user, "nordiste", zone="nord")
    offer(client, north, add_lot(client, north, PHOENIX))
    offer(client, north, add_lot(client, north, AHRI))
    alice = account(client, register_user, "alice", zone="sud")
    wish(client, alice, PHOENIX)
    wish(client, alice, AHRI)
    assert client.get("/api/trades/matches/wanted", headers=alice).json()["total"] == 2
    assert client.get("/api/trades/matches/wanted?zone=sud", headers=alice).json()["total"] == 0
    found = client.get("/api/trades/matches/wanted?q=ahri", headers=alice).json()
    assert [block["card"]["id"] for block in found["items"]] == [AHRI]


def test_offered_lists_seekers(client, register_user):
    alice = account(client, register_user, "alice", zone="sud")
    offer(client, alice, add_lot(client, alice, PHOENIX))
    bob = account(client, register_user, "bob", zone="est")
    wish(client, bob, PHOENIX)
    wish(client, bob, AHRI)  # alice ne la propose pas
    carl = account(client, register_user, "carl")  # non inscrit
    wish(client, carl, PHOENIX)
    body = client.get("/api/trades/matches/offered", headers=alice).json()
    assert body["total"] == 1
    item = body["items"][0]
    assert item["user"]["handle"] == "bob" and item["user"]["zone"] == "est"
    assert [card["id"] for card in item["cards"]] == [PHOENIX]


def test_card_offers_counts_my_zone(client, register_user):
    for handle, zone in (("bob1", "sud"), ("bob2", "nord"), ("bob3", "sud")):
        headers = account(client, register_user, handle, zone=zone)
        offer(client, headers, add_lot(client, headers, PHOENIX))
    alice = account(client, register_user, "alice", zone="sud")
    body = client.get(f"/api/trades/cards/{PHOENIX}/offers", headers=alice).json()
    assert body["total"] == 3 and body["in_my_zone"] == 2
    assert [item["owner"]["zone"] for item in body["offers"]] == ["sud", "sud", "nord"]
    assert client.get(f"/api/trades/cards/{PHOENIX}/offers?zone=nord", headers=alice).json()["total"] == 1
