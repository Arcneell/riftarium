import app.db as db_module
from app.models import Card
from app.sync import _upsert_card


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
