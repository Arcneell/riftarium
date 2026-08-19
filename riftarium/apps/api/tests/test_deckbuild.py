"""assemble_list : invariants du générateur de decks, y compris en mode shuffle."""

import random

from app.deckbuild import assemble_list, copy_cap, has_champion, legends_in, main_candidates
from app.models import Card
from app.validation import validate_deck
from app.variants import copy_family


def make_pool():
    pool = [
        Card(
            id="ogn-247-298",
            riftbound_id="ogn-247-298",
            name="Daughter of the Void",
            set_id="OGN",
            type="Legend",
            domains=["Fury", "Mind"],
            collector_number=247,
            tags=["Ahri"],
        )
    ]
    for index in range(5):
        pool.append(
            Card(
                id=f"ogn-27{index}-298",
                riftbound_id=f"ogn-27{index}-298",
                name=f"Battlefield {index}",
                set_id="OGN",
                type="Battlefield",
                domains=["Colorless"],
                collector_number=270 + index,
            )
        )
    pool.append(
        Card(
            id="ogn-007-298",
            riftbound_id="ogn-007-298",
            name="Fury Rune",
            set_id="OGN",
            type="Rune",
            domains=["Fury"],
            collector_number=7,
        )
    )
    pool.append(
        Card(
            id="ogn-008-298",
            riftbound_id="ogn-008-298",
            name="Mind Rune",
            set_id="OGN",
            type="Rune",
            domains=["Mind"],
            collector_number=8,
        )
    )
    pool.append(  # rune hors domaines de la légende : doit être exclue
        Card(
            id="ogn-009-298",
            riftbound_id="ogn-009-298",
            name="Calm Rune",
            set_id="OGN",
            type="Rune",
            domains=["Calm"],
            collector_number=9,
        )
    )
    pool.append(  # champion élu (tag partagé avec la légende)
        Card(
            id="ogn-119-298",
            riftbound_id="ogn-119-298",
            name="Ahri, Inquisitive",
            set_id="OGN",
            type="Unit",
            domains=["Mind"],
            energy=3,
            collector_number=119,
            tags=["Ahri"],
        )
    )
    pool.append(  # carte [Unique] : plafonnée à 1 exemplaire
        Card(
            id="ogn-200-298",
            riftbound_id="ogn-200-298",
            name="Sky Splitter",
            set_id="OGN",
            type="Spell",
            domains=["Mind"],
            energy=8,
            collector_number=200,
            text_plain="[Unique] Destroy target unit.",
        )
    )
    pool.append(  # unité hors domaines : doit être exclue du deck principal
        Card(
            id="ogn-078-298",
            riftbound_id="ogn-078-298",
            name="Lee Sin, Ascetic",
            set_id="OGN",
            type="Unit",
            domains=["Calm"],
            energy=3,
            collector_number=78,
        )
    )
    for index in range(15):
        pool.append(
            Card(
                id=f"ogn-{30 + index:03d}-298",
                riftbound_id=f"ogn-{30 + index:03d}-298",
                name=f"Fury Unit {index}",
                set_id="OGN",
                type="Unit",
                domains=["Fury"],
                energy=index % 6,
                collector_number=30 + index,
            )
        )
    return pool


def entries_snapshot(entries):
    return [(card.id, qty) for card, qty in entries]


def assert_invariants(entries, legend):
    by_type = {}
    for card, qty in entries:
        by_type.setdefault(card.type, []).append((card, qty))

    assert entries[0][0] is legend and entries[0][1] == 1
    assert len(by_type["Legend"]) == 1

    battlefields = by_type["Battlefield"]
    assert len(battlefields) <= 3
    assert all(qty == 1 for _, qty in battlefields)
    assert len({card.id for card, _ in battlefields}) == len(battlefields)

    assert sum(qty for _, qty in by_type["Rune"]) == 12
    allowed = {"Fury", "Mind"}
    for card, _ in by_type["Rune"]:
        assert {d for d in card.domains if d != "Colorless"} <= allowed

    main = by_type.get("Unit", []) + by_type.get("Spell", []) + by_type.get("Gear", [])
    assert sum(qty for _, qty in main) <= 40
    for card, qty in main:
        assert qty <= copy_cap(card)  # 3 max, 1 pour les [Unique]
        assert {d for d in card.domains if d != "Colorless"} <= allowed


def test_assemble_list_shuffle_is_deterministic_with_seed():
    pool = make_pool()
    legend = legends_in(pool)[0]

    first = assemble_list(pool, legend, shuffle=True, rng=random.Random(42))
    second = assemble_list(pool, legend, shuffle=True, rng=random.Random(42))
    assert entries_snapshot(first) == entries_snapshot(second)  # même graine → même deck

    assert_invariants(first, legend)
    checks = {c["rule"]: c["ok"] for c in validate_deck(first)}
    assert checks["legend"] and checks["battlefields"] and checks["runes"]
    assert checks["copies"] and checks["unique"] and checks["domains"]
    assert checks["main_size"]  # 15 unités x3 : le deck principal atteint 40
    assert checks["champion"]  # le shuffle garde les champions en tête de liste


def test_assemble_list_sorted_mode_matches_invariants_too():
    pool = make_pool()
    legend = legends_in(pool)[0]
    entries = assemble_list(pool, legend)
    assert_invariants(entries, legend)
    # sans shuffle, l'assemblage est déjà déterministe
    assert entries_snapshot(entries) == entries_snapshot(assemble_list(pool, legend))


def test_assemble_list_prefer_owned_tops_up_runes():
    pool = make_pool()
    legend = legends_in(pool)[0]
    fury_rune = next(card for card in pool if card.name == "Fury Rune")
    ahri = next(card for card in pool if card.name == "Ahri, Inquisitive")
    owned = {copy_family(fury_rune): 4, copy_family(ahri): 2}

    entries = assemble_list(pool, legend, owned=owned, prefer_owned=True)
    assert_invariants(entries, legend)
    runes = {card.id: qty for card, qty in entries if card.type == "Rune"}
    assert sum(runes.values()) == 12  # 4 possédées + complément automatique
    assert runes["ogn-007-298"] >= 4


def test_assemble_list_prefer_owned_with_empty_collection_still_completes():
    pool = make_pool()
    legend = legends_in(pool)[0]
    entries = assemble_list(pool, legend, owned={}, prefer_owned=True)
    assert_invariants(entries, legend)  # rien de possédé : runes et deck principal complétés quand même
    assert sum(qty for card, qty in entries if card.type == "Rune") == 12


def test_helpers_champion_and_candidates():
    pool = make_pool()
    legend = legends_in(pool)[0]
    candidates = main_candidates(pool, legend)
    ids = {card.id for card in candidates}
    assert "ogn-078-298" not in ids  # Calm : hors domaines de la légende
    assert "ogn-119-298" in ids
    assert has_champion(legend, candidates) is True
    assert has_champion(legend, [card for card in candidates if not card.tags]) is False
