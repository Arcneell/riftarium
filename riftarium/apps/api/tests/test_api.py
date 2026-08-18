def deck_payload(**overrides):
    payload = {
        "name": "Étincelle de Fureur",
        "description": "Deck aggro de test.",
        "format": "tournament",
        "is_public": True,
        "cards": [
            {"card_id": "ogn-247-298", "qty": 1},  # légende Fury/Mind
            {"card_id": "ogn-275-298", "qty": 1},
            {"card_id": "ogn-276-298", "qty": 1},
            {"card_id": "ogn-277-298", "qty": 1},
            {"card_id": "ogn-007-298", "qty": 12},  # runes
            {"card_id": "ogn-037-298", "qty": 3},  # unités Fury
            {"card_id": "ogn-119-298", "qty": 2},  # unités Mind
        ],
    }
    payload.update(overrides)
    return payload


def check(checks, rule):
    return next(c for c in checks if c["rule"] == rule)


# ---------- santé & cartes ----------


def test_health(client):
    response = client.get("/api/health")
    assert response.status_code == 200
    assert response.json()["cards"] == 11


def test_cards_list_and_filters(client):
    assert client.get("/api/cards").json()["total"] == 11
    assert client.get("/api/cards", params={"type": "Unit"}).json()["total"] == 5
    assert client.get("/api/cards", params={"domain": "Fury"}).json()["total"] == 5
    hits = client.get("/api/cards", params={"q": "phoenix"}).json()
    assert hits["total"] == 3 and {item["id"] for item in hits["items"]} >= {"ogn-037-298"}


def test_cards_multi_filters(client):
    payload = client.get("/api/cards", params={"rarity": "Epic,Rare", "type": "Unit,Spell"}).json()
    assert payload["total"] == 5
    ids = {card["id"] for card in payload["items"]}
    assert "ogn-037-298" in ids
    assert "ogn-200-298" in ids
    assert "ogn-007-298" not in ids


def test_cards_energy_filter(client):
    exact = client.get("/api/cards", params={"energy": "3,4"}).json()
    assert {card["energy"] for card in exact["items"]} <= {3, 4}
    high = client.get("/api/cards", params={"energy": "7+"}).json()
    assert high["total"] == 1 and high["items"][0]["id"] == "ogn-200-298"
    ignored = client.get("/api/cards", params={"energy": "nope"})
    assert ignored.status_code == 200
    assert ignored.json()["total"] == 11


def test_variant_family_ignores_unrelated_ids():
    from app.variants import canonical_name, variant_family

    assert variant_family("ogn-037-298") == "ogn-037-298"
    assert variant_family("OGN-037A-298") == "ogn-037-298"
    assert variant_family("ogn-037*-298") == "ogn-037-298"
    assert variant_family("ven-004-166") == "ven-004-166"
    assert variant_family("ven-004a-166") == "ven-004-166"
    assert variant_family("ven-sp4-006") == "ven-sp4-006"
    assert variant_family("ven-r04") == "ven-r04"
    assert canonical_name("Jinx - Demolitionist") == canonical_name("Jinx, Demolitionist")
    assert canonical_name("Seal of Discord (Overnumbered)") == "seal of discord"
    assert canonical_name("Immortal Phoenix (Alternate Art)") == "immortal phoenix"


def test_card_variants_and_foil(client):
    detail = client.get("/api/cards/ogn-037-298").json()
    variant_ids = {item["id"] for item in detail["variants"]}
    assert variant_ids == {"ogn-037-298", "ogn-037a-298", "ogn-037*-298"}
    alt = next(item for item in detail["variants"] if item["alternate_art"])
    sig = next(item for item in detail["variants"] if item["signature"])
    assert alt["foil"] is True and sig["foil"] is True
    listed = client.get("/api/cards/ogn-037-298/variants").json()
    assert {item["id"] for item in listed} == variant_ids


def test_variants_do_not_mix_unrelated_collector_numbers(client):
    import app.db as db_module
    from app.models import Card, CardSet

    with db_module.SessionLocal() as session:
        session.add(CardSet(set_id="VEN", name="Vendetta", card_count=4))
        session.add_all(
            [
                Card(
                    id="ven-r04",
                    riftbound_id="ven-r04",
                    name="Body Rune",
                    set_id="VEN",
                    type="Rune",
                    rarity="Common",
                    domains=["Body"],
                    collector_number=4,
                ),
                Card(
                    id="ven-sp4",
                    riftbound_id="ven-sp4-006",
                    name="Sett, Brawler",
                    set_id="VEN",
                    type="Unit",
                    rarity="Epic",
                    domains=["Body"],
                    collector_number=4,
                ),
                Card(
                    id="ven-004",
                    riftbound_id="ven-004-166",
                    name="Dune Surfer",
                    set_id="VEN",
                    type="Unit",
                    rarity="Common",
                    domains=["Body"],
                    collector_number=4,
                ),
                Card(
                    id="ven-004a",
                    riftbound_id="ven-004a-166",
                    name="Dune Surfer (Alternate Art)",
                    set_id="VEN",
                    type="Unit",
                    rarity="Showcase",
                    domains=["Body"],
                    collector_number=4,
                    alternate_art=True,
                ),
            ]
        )
        session.commit()

    sett = client.get("/api/cards/ven-sp4").json()
    assert {item["id"] for item in sett["variants"]} == {"ven-sp4"}
    rune = client.get("/api/cards/ven-r04").json()
    assert {item["id"] for item in rune["variants"]} == {"ven-r04"}
    dune = client.get("/api/cards/ven-004").json()
    assert {item["id"] for item in dune["variants"]} == {"ven-004", "ven-004a"}


def test_cards_owned_qty(client, auth):
    client.put("/api/collection/ogn-037-298", json={"qty": 2}, headers=auth)
    anonymous = client.get("/api/cards", params={"q": "Immortal Phoenix"}).json()["items"]
    assert all("owned_qty" not in card for card in anonymous)
    owned = client.get("/api/cards", params={"q": "Immortal Phoenix"}, headers=auth).json()["items"]
    by_id = {card["id"]: card["owned_qty"] for card in owned}
    assert by_id["ogn-037-298"] == 2
    assert by_id["ogn-037a-298"] == 0


def test_cards_rarity_sort(client):
    items = client.get("/api/cards", params={"sort": "rarity", "size": 20}).json()["items"]
    ranks = {
        "Common": 0,
        "Uncommon": 1,
        "Rare": 2,
        "Epic": 3,
        "Showcase": 4,
        "Promo": 5,
    }
    values = [ranks[card["rarity"]] for card in items]
    assert values == sorted(values)
    assert items[0]["rarity"] == "Common"


def test_cards_random_sort(client):
    """Le tirage aléatoire rebat les cartes sans en perdre ni en inventer."""
    ordered = client.get("/api/cards", params={"size": 20}).json()["items"]
    shuffled = client.get("/api/cards", params={"sort": "random", "size": 20}).json()["items"]
    assert {c["id"] for c in shuffled} == {c["id"] for c in ordered}


def test_cards_random_preserves_filters(client):
    payload = client.get("/api/cards", params={"sort": "random", "type": "Unit", "size": 20}).json()
    assert payload["total"] == 5
    assert {card["id"] for card in payload["items"]} == {
        "ogn-037-298",
        "ogn-119-298",
        "ogn-078-298",
        "ogn-037a-298",
        "ogn-037*-298",
    }


def test_cards_unknown_sort_keeps_default_order(client):
    default = [card["id"] for card in client.get("/api/cards", params={"size": 20}).json()["items"]]
    unknown = [card["id"] for card in client.get("/api/cards", params={"sort": "name", "size": 20}).json()["items"]]
    assert unknown == default


def test_cards_random_page_meta(client):
    payload = client.get("/api/cards", params={"sort": "random", "page": 1, "size": 3}).json()
    assert payload["total"] == 11
    assert payload["page"] == 1
    assert payload["size"] == 3
    assert len(payload["items"]) == 3
    assert len({card["id"] for card in payload["items"]}) == 3


def test_cards_random_front_contract(client):
    """Le carrousel demande 40 cartes : l'API répond 200 et conserve le schéma."""
    payload = client.get("/api/cards", params={"sort": "random", "size": 40}).json()
    assert payload["total"] == 11
    assert len(payload["items"]) == 11
    assert all("id" in card and "image_url" in card and "name" in card for card in payload["items"])


def test_card_detail_and_404(client):
    assert client.get("/api/cards/ogn-037-298").json()["name"] == "Immortal Phoenix"
    assert client.get("/api/cards/xxx-000-000").status_code == 404


def test_sets(client):
    sets = client.get("/api/sets").json()
    assert sets[0]["set_id"] == "OGN"


# ---------- auth ----------


def test_register_login_me(client):
    creds = {
        "handle": "maelle",
        "email": "maelle@example.org",
        "password": "supersecret1",
    }
    assert client.post("/api/auth/register", json=creds).status_code == 201
    assert client.post("/api/auth/register", json=creds).status_code == 409

    login = client.post("/api/auth/login", json={"email": creds["email"], "password": creds["password"]})
    assert login.status_code == 200
    token = login.json()["token"]

    me = client.get("/api/auth/me", headers={"Authorization": f"Bearer {token}"})
    assert me.json()["handle"] == "maelle"

    bad = client.post("/api/auth/login", json={"email": creds["email"], "password": "mauvais-mdp"})
    assert bad.status_code == 401


def test_protected_routes_require_auth(client):
    assert client.get("/api/collection").status_code == 401
    assert client.post("/api/decks", json=deck_payload()).status_code == 401


# ---------- collection ----------


def test_collection_crud(client, auth):
    put = client.put(
        "/api/collection/ogn-037-298",
        json={"qty": 3, "condition": "NM", "lang": "FR"},
        headers=auth,
    )
    assert put.status_code == 200 and put.json()["qty"] == 3

    coll = client.get("/api/collection", headers=auth).json()
    assert coll["total_cards"] == 3 and coll["unique_cards"] == 1
    assert coll["items"][0]["card"]["name"] == "Immortal Phoenix"

    # la suppression vise le lot précis (état + langue)
    client.put("/api/collection/ogn-037-298", json={"qty": 0, "condition": "NM", "lang": "FR"}, headers=auth)
    assert client.get("/api/collection", headers=auth).json()["unique_cards"] == 0

    assert client.put("/api/collection/xxx-000-000", json={"qty": 1}, headers=auth).status_code == 404


def test_collection_get_item(client, auth):
    empty = client.get("/api/collection/ogn-037-298", headers=auth).json()
    assert empty == {"card_id": "ogn-037-298", "total_qty": 0, "entries": []}

    client.put("/api/collection/ogn-037-298", json={"qty": 2, "condition": "EX", "lang": "FR"}, headers=auth)
    item = client.get("/api/collection/ogn-037-298", headers=auth).json()
    assert item["total_qty"] == 2
    assert [(e["qty"], e["condition"], e["lang"]) for e in item["entries"]] == [(2, "EX", "FR")]

    assert client.get("/api/collection/xxx-000-000", headers=auth).status_code == 404


def test_collection_multiple_entries(client, auth):
    # deux lots de la même carte : états et langues différents
    add = client.post(
        "/api/collection/ogn-037-298/entries", json={"qty": 2, "condition": "NM", "lang": "EN"}, headers=auth
    )
    assert add.status_code == 200
    state = client.post(
        "/api/collection/ogn-037-298/entries", json={"qty": 1, "condition": "PL", "lang": "FR"}, headers=auth
    ).json()
    assert state["total_qty"] == 3 and len(state["entries"]) == 2

    coll = client.get("/api/collection", headers=auth).json()
    assert coll["total_cards"] == 3 and coll["unique_cards"] == 1
    assert coll["items"][0]["total_qty"] == 3 and len(coll["items"][0]["entries"]) == 2

    # owned_qty agrège tous les lots
    owned = client.get("/api/cards", params={"q": "Immortal Phoenix"}, headers=auth).json()["items"]
    assert {card["id"]: card["owned_qty"] for card in owned}["ogn-037-298"] == 3

    # ajout sur un lot existant : addition
    state = client.post(
        "/api/collection/ogn-037-298/entries", json={"qty": 3, "condition": "NM", "lang": "EN"}, headers=auth
    ).json()
    assert state["total_qty"] == 6

    # PATCH : modifier un lot ; retomber sur un lot existant fusionne
    pl_entry = next(e for e in state["entries"] if e["condition"] == "PL")
    merged = client.patch(
        f"/api/collection/entries/{pl_entry['id']}",
        json={"condition": "NM", "lang": "EN"},
        headers=auth,
    ).json()
    assert merged["total_qty"] == 6 and len(merged["entries"]) == 1

    # PATCH qty 0 supprime le lot
    entry_id = merged["entries"][0]["id"]
    emptied = client.patch(f"/api/collection/entries/{entry_id}", json={"qty": 0}, headers=auth).json()
    assert emptied == {"card_id": "ogn-037-298", "total_qty": 0, "entries": []}
    assert client.patch(f"/api/collection/entries/{entry_id}", json={"qty": 1}, headers=auth).status_code == 404


def test_collection_filters_and_pagination(client, auth):
    client.put("/api/collection/ogn-037-298", json={"qty": 2}, headers=auth)
    client.put("/api/collection/ogn-007-298", json={"qty": 4}, headers=auth)
    client.put("/api/collection/ogn-200-298", json={"qty": 1}, headers=auth)

    coll = client.get("/api/collection", headers=auth).json()
    assert coll["total_cards"] == 7 and coll["unique_cards"] == 3 and coll["total"] == 3

    units = client.get("/api/collection", params={"type": "Unit"}, headers=auth).json()
    assert units["total"] == 1 and units["items"][0]["card"]["id"] == "ogn-037-298"
    # les stats restent globales, indépendantes des filtres
    assert units["total_cards"] == 7 and units["unique_cards"] == 3

    hits = client.get("/api/collection", params={"q": "phoenix"}, headers=auth).json()
    assert {item["card"]["id"] for item in hits["items"]} == {"ogn-037-298"}

    high = client.get("/api/collection", params={"energy": "7+"}, headers=auth).json()
    assert high["total"] == 1 and high["items"][0]["card"]["id"] == "ogn-200-298"

    page = client.get("/api/collection", params={"size": 2, "page": 2}, headers=auth).json()
    assert page["total"] == 3 and len(page["items"]) == 1


def test_collection_bulk(client, auth):
    for card_id in ("ogn-037-298", "ogn-007-298", "ogn-200-298"):
        client.put(f"/api/collection/{card_id}", json={"qty": 1}, headers=auth)

    res = client.post(
        "/api/collection/bulk",
        json={"card_ids": ["ogn-037-298", "ogn-007-298"], "qty_delta": 2, "condition": "EX", "lang": "FR"},
        headers=auth,
    )
    assert res.status_code == 200 and res.json() == {"updated": 2, "removed": 0}
    by_id = {item["card"]["id"]: item for item in client.get("/api/collection", headers=auth).json()["items"]}
    assert by_id["ogn-037-298"]["total_qty"] == 3
    assert by_id["ogn-037-298"]["entries"][0]["condition"] == "EX"
    assert by_id["ogn-037-298"]["entries"][0]["lang"] == "FR"
    assert by_id["ogn-200-298"]["total_qty"] == 1 and by_id["ogn-200-298"]["entries"][0]["condition"] == "NM"

    # un delta qui passe sous zéro retire la carte
    res = client.post("/api/collection/bulk", json={"card_ids": ["ogn-200-298"], "qty_delta": -5}, headers=auth)
    assert res.json() == {"updated": 0, "removed": 1}

    res = client.post(
        "/api/collection/bulk",
        json={"card_ids": ["ogn-037-298", "ogn-007-298"], "remove": True},
        headers=auth,
    )
    assert res.json() == {"updated": 0, "removed": 2}
    assert client.get("/api/collection", headers=auth).json()["unique_cards"] == 0

    assert client.post("/api/collection/bulk", json={"card_ids": []}, headers=auth).status_code == 422
    assert client.post("/api/collection/bulk", json=deck_payload()).status_code == 401


# ---------- decks & validation ----------


def test_deck_create_and_validation(client, auth):
    created = client.post("/api/decks", json=deck_payload(), headers=auth)
    assert created.status_code == 201
    deck = created.json()
    checks = {c["rule"]: c["ok"] for c in deck["checks"]}
    assert checks["legend"] and checks["battlefields"] and checks["runes"]
    assert checks["copies"] and checks["domains"]
    assert not checks["main_size"]  # 5 cartes principales < 40


def test_deck_domain_violation(client, auth):
    payload = deck_payload()
    payload["cards"].append({"card_id": "ogn-078-298", "qty": 1})  # Lee Sin : Calm, hors Fury/Mind
    deck = client.post("/api/decks", json=payload, headers=auth).json()
    assert not check(deck["checks"], "domains")["ok"]
    assert "Lee Sin" in check(deck["checks"], "domains")["message"]


def test_deck_update_delete_and_ownership(client, auth):
    deck_id = client.post("/api/decks", json=deck_payload(), headers=auth).json()["id"]

    updated = client.put(f"/api/decks/{deck_id}", json=deck_payload(name="V2"), headers=auth)
    assert updated.json()["name"] == "V2"

    other = client.post(
        "/api/auth/register",
        json={
            "handle": "intrus",
            "email": "intrus@example.org",
            "password": "motdepasse123",
        },
    ).json()["token"]
    other_auth = {"Authorization": f"Bearer {other}"}
    assert client.put(f"/api/decks/{deck_id}", json=deck_payload(), headers=other_auth).status_code == 404
    assert client.delete(f"/api/decks/{deck_id}", headers=other_auth).status_code == 404

    assert client.delete(f"/api/decks/{deck_id}", headers=auth).status_code == 204


def test_cards_owned_filter(client, auth):
    client.put("/api/collection/ogn-037-298", json={"qty": 2}, headers=auth)

    owned = client.get("/api/cards", params={"owned": "1"}, headers=auth).json()
    assert owned["total"] == 1 and owned["items"][0]["id"] == "ogn-037-298"

    not_owned = client.get("/api/cards", params={"owned": "0"}, headers=auth).json()
    assert not_owned["total"] == 10
    assert "ogn-037-298" not in {card["id"] for card in not_owned["items"]}

    # anonyme : le paramètre est ignoré
    assert client.get("/api/cards", params={"owned": "1"}).json()["total"] == 11


def test_deck_missing_list(client, auth):
    deck_id = client.post("/api/decks", json=deck_payload(), headers=auth).json()["id"]
    # l'art alternatif du Phénix compte pour la famille : besoin 3, possédé 1 → manque 2
    client.put("/api/collection/ogn-037a-298", json={"qty": 1}, headers=auth)
    client.put("/api/collection/ogn-007-298", json={"qty": 12}, headers=auth)

    data = client.get(f"/api/decks/{deck_id}/missing", headers=auth).json()
    by_id = {item["card"]["id"]: item for item in data["items"]}
    assert by_id["ogn-037-298"]["needed"] == 3
    assert by_id["ogn-037-298"]["owned"] == 1
    assert by_id["ogn-037-298"]["missing"] == 2
    assert "ogn-007-298" not in by_id  # les 12 runes sont possédées
    assert data["deck_total"] == 21
    assert data["missing_total"] == sum(item["missing"] for item in data["items"])

    assert client.get(f"/api/decks/{deck_id}/missing").status_code == 401


def test_deck_copies_counted_across_variants(client, auth):
    payload = deck_payload()
    payload["cards"].append({"card_id": "ogn-037a-298", "qty": 1})  # 3 + 1 alt-art = 4 exemplaires
    deck = client.post("/api/decks", json=payload, headers=auth).json()
    copies = check(deck["checks"], "copies")
    assert not copies["ok"]
    assert "Immortal Phoenix" in copies["message"]


def test_deck_copies_counted_across_reprints(client, auth):
    import app.db as db_module
    from app.models import Card

    with db_module.SessionLocal() as session:
        session.add_all(
            [
                Card(
                    id="pr-037-298",
                    riftbound_id="pr-037-298",
                    name="Immortal Phoenix",
                    set_id="OGN",
                    type="Unit",
                    domains=["Fury"],
                    energy=4,
                ),
                Card(
                    id="ven-030-166",
                    riftbound_id="ven-030-166",
                    name="Jinx, Demolitionist",
                    set_id="OGN",
                    type="Unit",
                    domains=["Fury"],
                    energy=2,
                ),
                Card(
                    id="ogn-030-298",
                    riftbound_id="ogn-030-298",
                    name="Jinx - Demolitionist",
                    set_id="OGN",
                    type="Unit",
                    domains=["Fury"],
                    energy=2,
                ),
            ]
        )
        session.commit()

    payload = deck_payload()
    payload["cards"].extend(
        [
            {"card_id": "pr-037-298", "qty": 1},  # 3 phoenix + 1 reprint = 4
            {"card_id": "ogn-030-298", "qty": 3},
            {"card_id": "ven-030-166", "qty": 3},  # même nom, autre set
        ]
    )
    deck = client.post("/api/decks", json=payload, headers=auth).json()
    copies = check(deck["checks"], "copies")
    assert not copies["ok"]
    assert "Immortal Phoenix" in copies["message"]
    assert "Jinx" in copies["message"]


def test_deck_unique_rule(client, auth):
    payload = deck_payload()
    payload["cards"].append({"card_id": "ogn-200-298", "qty": 2})  # sort [Unique]
    deck = client.post("/api/decks", json=payload, headers=auth).json()
    unique = check(deck["checks"], "unique")
    assert not unique["ok"]
    assert "Sky Splitter" in unique["message"]


def test_deck_champion_rule(client, auth):
    deck = client.post("/api/decks", json=deck_payload(), headers=auth).json()
    assert check(deck["checks"], "champion")["ok"]  # Ahri (tag de la légende) est dans le deck principal

    payload = deck_payload()
    payload["cards"] = [card for card in payload["cards"] if card["card_id"] != "ogn-119-298"]
    deck = client.post("/api/decks", json=payload, headers=auth).json()
    assert not check(deck["checks"], "champion")["ok"]


def test_example_deck_owned_mode(client, auth):
    for card_id, qty in [
        ("ogn-247-298", 1),
        ("ogn-275-298", 1),
        ("ogn-276-298", 1),
        ("ogn-277-298", 1),
        ("ogn-007-298", 12),
        ("ogn-037-298", 3),
        ("ogn-119-298", 3),
    ]:
        client.put(f"/api/collection/{card_id}", json={"qty": qty}, headers=auth)

    response = client.post("/api/decks/example", json={"mode": "owned"}, headers=auth)
    assert response.status_code == 201
    deck = response.json()
    checks = {c["rule"]: c["ok"] for c in deck["checks"]}
    assert checks["legend"] and checks["battlefields"] and checks["runes"]
    assert checks["domains"] and checks["copies"] and checks["champion"] and checks["unique"]
    # le seed de test n'a pas 40 cartes principales : le générateur remplit au mieux
    by_type = {}
    for entry in deck["cards"]:
        by_type[entry["card"]["type"]] = by_type.get(entry["card"]["type"], 0) + entry["qty"]
    assert by_type["Legend"] == 1 and by_type["Battlefield"] == 3 and by_type["Rune"] == 12
    assert deck["format"] == "tournament" and deck["name"].startswith("Exemple ·")


def test_example_deck_discover_mode_has_missing(client, auth):
    response = client.post("/api/decks/example", json={"mode": "discover"}, headers=auth)
    assert response.status_code == 201
    deck = response.json()
    missing = client.get(f"/api/decks/{deck['id']}/missing", headers=auth).json()
    assert missing["missing_total"] > 0  # collection vide : tout est à trouver

    assert client.post("/api/decks/example", json={"mode": "invalide"}, headers=auth).status_code == 422
    assert client.post("/api/decks/example", json={"mode": "owned"}).status_code == 401


def test_deck_out_includes_owned_qty(client, auth):
    client.put("/api/collection/ogn-037-298", json={"qty": 2}, headers=auth)
    deck_id = client.post("/api/decks", json=deck_payload(), headers=auth).json()["id"]
    deck = client.get(f"/api/decks/{deck_id}", headers=auth).json()
    entry = next(item for item in deck["cards"] if item["card"]["id"] == "ogn-037-298")
    assert entry["card"]["owned_qty"] == 2
    # anonyme sur un deck public : pas d'info de possession
    anonymous = client.get(f"/api/decks/{deck_id}").json()
    assert "owned_qty" not in anonymous["cards"][0]["card"]


# ---------- communauté, likes, modération ----------


def test_community_and_likes(client, auth):
    deck_id = client.post("/api/decks", json=deck_payload(), headers=auth).json()["id"]

    community = client.get("/api/community/decks").json()
    assert [d["id"] for d in community] == [deck_id]

    like = client.post(f"/api/decks/{deck_id}/like", headers=auth)
    assert like.json() == {"deck_id": deck_id, "likes": 1, "liked_by_me": True}
    unlike = client.post(f"/api/decks/{deck_id}/like", headers=auth)
    assert unlike.json()["likes"] == 0


def test_private_deck_hidden_from_community(client, auth):
    client.post("/api/decks", json=deck_payload(is_public=False), headers=auth)
    assert client.get("/api/community/decks").json() == []


def test_moderation_blocks_toxic_deck(client, auth):
    deck = client.post("/api/decks", json=deck_payload(name="deck de connard"), headers=auth).json()
    assert deck["moderation_status"] == "pending"
    # pas listé publiquement tant que non validé
    assert client.get("/api/community/decks").json() == []
    # et invisible pour les autres via l'URL directe
    assert client.get(f"/api/decks/{deck['id']}").status_code == 404


# ---------- cache & protection de la source ----------


def test_anonymous_cards_get_cache_headers(client):
    response = client.get("/api/cards")
    assert response.headers["cache-control"] == "public, max-age=300"
    assert response.headers["vary"] == "Authorization"


def test_authenticated_cards_not_marked_cacheable(client, auth):
    response = client.get("/api/cards", headers=auth)
    assert "cache-control" not in response.headers


def test_admin_sync_is_throttled(client, monkeypatch):
    import app.main as main

    monkeypatch.setattr(main, "run_sync", lambda db: {"sets": 0, "cards": 0})
    main._last_sync_fallback = 0.0

    assert client.post("/api/admin/sync").status_code == 200
    throttled = client.post("/api/admin/sync")
    assert throttled.status_code == 429
    assert "réessayez" in throttled.json()["detail"]
    main._last_sync_fallback = 0.0
