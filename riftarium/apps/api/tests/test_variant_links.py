"""Variantes reliées par le nom : légende de base ↔ overnumbered ↔ signée, runes de base entre sets.

Les numéros de collection diffèrent (ogn-251 / ogn-301), la famille d'identifiant ne suffit pas.
"""

import pytest


def _card(card_id, riftbound_id, name, set_id, card_type, **flags):
    from app.models import Card

    return Card(
        id=card_id,
        riftbound_id=riftbound_id,
        name=name,
        set_id=set_id,
        type=card_type,
        rarity="Rare",
        domains=["Fury"],
        **flags,
    )


@pytest.fixture
def linked_cards(client):
    import app.db as db_module
    from app.models import CardSet

    with db_module.SessionLocal() as session:
        for set_id, name in (("VEN", "Vendetta"), ("PR", "Promo")):
            if session.get(CardSet, set_id) is None:
                session.add(CardSet(set_id=set_id, name=name, card_count=1))
        session.add_all(
            [
                _card("leg-base", "ogn-251-298", "Jinx - Loose Cannon", "OGN", "Legend"),
                _card(
                    "leg-on", "ogn-301-298", "Jinx - Loose Cannon (Overnumbered)", "OGN", "Legend", overnumbered=True
                ),
                _card("leg-sig", "ogn-301*-298", "Jinx - Loose Cannon (Signature)", "OGN", "Legend", signature=True),
                _card("unit-ogn", "ogn-202-298", "Jinx - Rebel", "OGN", "Unit"),
                _card("unit-pr", "pr-202-298", "Jinx - Rebel", "PR", "Unit"),
                _card("rune-ogn", "ogn-907-298", "Fury Rune", "OGN", "Rune"),
                _card("rune-ogn-alt", "ogn-907a-298", "Fury Rune (Alternate Art)", "OGN", "Rune", alternate_art=True),
                _card("rune-ven", "ven-r01", "Fury Rune", "VEN", "Rune"),
                _card("rune-calm", "ogn-042-298", "Calm Rune", "OGN", "Rune"),
            ]
        )
        session.commit()


def _variant_ids(client, card_id):
    return {item["id"] for item in client.get(f"/api/cards/{card_id}").json()["variants"]}


def test_legende_reliee_a_son_overnumbered_et_sa_signature(client, linked_cards):
    expected = {"leg-base", "leg-on", "leg-sig"}
    assert _variant_ids(client, "leg-base") == expected
    assert _variant_ids(client, "leg-on") == expected
    listed = client.get("/api/cards/leg-sig/variants").json()
    assert {item["id"] for item in listed} == expected


def test_la_reimpression_promo_reste_a_part(client, linked_cards):
    assert _variant_ids(client, "unit-ogn") == {"unit-ogn"}
    assert _variant_ids(client, "unit-pr") == {"unit-pr"}


def test_rune_de_base_reliee_entre_les_sets(client, linked_cards):
    # La rune Fury du jeu de données commun (ogn-007-298) est une impression de plus.
    expected = {"ogn-007-298", "rune-ogn", "rune-ogn-alt", "rune-ven"}
    assert _variant_ids(client, "rune-ogn") == expected
    assert _variant_ids(client, "rune-ven") == expected
    assert _variant_ids(client, "rune-calm") == {"rune-calm"}
