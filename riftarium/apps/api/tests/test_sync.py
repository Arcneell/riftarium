import app.db as db_module
import httpx
import pytest
import respx
from app.models import Card, CardSet
from app.sync import _upsert_card, _upsert_set, run_sync
from sqlalchemy import func, select

BASE = "https://riftcodex.test"


def card_payload(card_id, name, collector_number, set_id="ogn"):
    return {
        "id": card_id,
        "riftbound_id": card_id,
        "name": name,
        "collector_number": collector_number,
        "attributes": {"energy": 2},
        "classification": {"type": "Unit", "rarity": "Common", "domain": ["Fury"]},
        "text": {"plain": "Test."},
        "media": {"image_url": "https://cdn.example/test.png", "artist": "Riot"},
        "set": {"set_id": set_id},
        "metadata": {"updated_on": "2026-08-01"},
    }


SETS_PAYLOAD = {
    "items": [
        {"set_id": "OGN", "name": "Origins (maj)", "card_count": 298, "published_on": "2025-10-01"},
        {"set_id": "XYZ", "name": "Set non synchronisé", "card_count": 10, "published_on": "2026-01-01"},
    ]
}


@pytest.fixture()
def sync_settings(monkeypatch):
    from app import sync as sync_module

    monkeypatch.setattr(sync_module.settings, "riftcodex_base_url", BASE)
    monkeypatch.setattr(sync_module.settings, "sync_sets", "OGN")
    monkeypatch.setattr(sync_module.settings, "riftcodex_page_delay", 0.0)


def _mock_happy_path():
    respx.get(f"{BASE}/sets").mock(return_value=httpx.Response(200, json=SETS_PAYLOAD))
    respx.get(f"{BASE}/cards", params={"page": "1"}).mock(
        return_value=httpx.Response(
            200,
            json={
                "items": [card_payload("ogn-901-298", "Sync Unit A", 901)],
                "pages": 2,
            },
        )
    )
    respx.get(f"{BASE}/cards", params={"page": "2"}).mock(
        return_value=httpx.Response(
            200,
            json={
                "items": [card_payload("ogn-902-298", "Sync Unit B", 902)],
                "pages": 2,
            },
        )
    )


@respx.mock
def test_run_sync_paginates_and_upserts(client, sync_settings):
    _mock_happy_path()
    with db_module.SessionLocal() as session:
        cards_before = session.scalar(select(func.count(Card.id)))
        counts = run_sync(session)
        assert counts == {"sets": 1, "cards": 2}  # XYZ (hors SYNC_SETS) est ignoré

        # Le set OGN existait (seed) : mis à jour sans doublon.
        ogn = session.get(CardSet, "OGN")
        assert ogn.name == "Origins (maj)" and ogn.card_count == 298
        assert session.get(CardSet, "XYZ") is None

        # Les deux pages ont été parcourues et les cartes insérées.
        assert session.scalar(select(func.count(Card.id))) == cards_before + 2
        card = session.get(Card, "ogn-901-298")
        assert card.name == "Sync Unit A"
        assert card.set_id == "OGN"
        assert card.image_url == "https://cdn.example/test.png"  # hôte de dev autorisé hors prod


@respx.mock
def test_run_sync_twice_does_not_duplicate(client, sync_settings):
    _mock_happy_path()
    with db_module.SessionLocal() as session:
        first = run_sync(session)
        total_after_first = session.scalar(select(func.count(Card.id)))
        second = run_sync(session)  # re-sync : upsert, pas de réinsertion
        assert first == second == {"sets": 1, "cards": 2}
        assert session.scalar(select(func.count(Card.id))) == total_after_first
        assert session.scalar(select(func.count(CardSet.set_id)).where(CardSet.set_id == "OGN")) == 1


@respx.mock
def test_run_sync_network_error_mid_sync_keeps_partial_state(client, sync_settings):
    respx.get(f"{BASE}/sets").mock(return_value=httpx.Response(200, json=SETS_PAYLOAD))
    respx.get(f"{BASE}/cards", params={"page": "1"}).mock(
        return_value=httpx.Response(
            200,
            json={"items": [card_payload("ogn-901-298", "Sync Unit A", 901)], "pages": 3},
        )
    )
    respx.get(f"{BASE}/cards", params={"page": "2"}).mock(side_effect=httpx.ConnectError("réseau coupé"))

    with db_module.SessionLocal() as session:
        with pytest.raises(httpx.ConnectError):
            run_sync(session)
        # État partiel toléré : la page 1 (commitée) reste en base, la sync est relançable.
        assert session.get(Card, "ogn-901-298") is not None
        assert session.get(CardSet, "OGN").name == "Origins (maj)"


@respx.mock
def test_run_sync_stops_set_on_http_error_without_raising(client, sync_settings):
    respx.get(f"{BASE}/sets").mock(return_value=httpx.Response(200, json=SETS_PAYLOAD))
    respx.get(f"{BASE}/cards").mock(return_value=httpx.Response(503))

    with db_module.SessionLocal() as session:
        counts = run_sync(session)  # une page en erreur interrompt le set, sans faire échouer la sync
        assert counts == {"sets": 1, "cards": 0}


def test_upsert_set_inserts_then_updates(client):
    with db_module.SessionLocal() as session:
        _upsert_set(session, {"set_id": "NEW", "name": "Nouveau", "card_count": 5, "published_on": "2026-01-01"})
        session.commit()
        assert session.get(CardSet, "NEW").card_count == 5

        _upsert_set(session, {"set_id": "NEW", "name": "Nouveau v2", "card_count": None})
        session.commit()
        row = session.get(CardSet, "NEW")
        assert row.name == "Nouveau v2"
        assert row.card_count == 0  # card_count absent ou nul → 0
        assert row.published_on is None
        assert session.scalar(select(func.count(CardSet.set_id)).where(CardSet.set_id == "NEW")) == 1


def test_sync_reads_signature_and_overnumbered_flags(client):
    payload = {
        "id": "ogn-301-298",
        "riftbound_id": "ogn-301-298",
        "name": "Phoenix Signature",
        "collector_number": 301,
        "orientation": "portrait",
        "tags": ["champion"],
        "attributes": {"energy": 4, "might": 5},
        "classification": {"type": "Unit", "rarity": "Epic", "domain": ["Fury"]},
        "text": {"plain": "Assault. :rb_might:", "flavour": "Rise."},
        "media": {"image_url": "https://cdn.example/phoenix.png", "artist": "Riot"},
        "set": {"set_id": "ogn"},
        "metadata": {
            "alternate_art": False,
            "signature": True,
            "overnumbered": True,
            "updated_on": "2026-08-01",
        },
    }
    with db_module.SessionLocal() as session:
        _upsert_card(session, payload)
        session.commit()
        row = session.get(Card, "ogn-301-298")
        assert row is not None
        assert row.signature is True
        assert row.overnumbered is True
        assert row.alternate_art is False
        assert row.tags == ["champion"]
        assert row.text_plain == "Assault. :rb_might:"

    detail = client.get("/api/cards/ogn-301-298").json()
    assert detail["signature"] is True
    assert detail["overnumbered"] is True
    assert detail["foil"] is True
    assert detail["tags"] == ["champion"]
