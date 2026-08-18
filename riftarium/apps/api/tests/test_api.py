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
    from app.routers.cards import variant_family

    assert variant_family("ogn-037-298") == "ogn-037-298"
    assert variant_family("OGN-037A-298") == "ogn-037-298"
    assert variant_family("ogn-037*-298") == "ogn-037-298"
    assert variant_family("ven-004-166") == "ven-004-166"
    assert variant_family("ven-004a-166") == "ven-004-166"
    assert variant_family("ven-sp4-006") == "ven-sp4-006"
    assert variant_family("ven-r04") == "ven-r04"


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
    ranks = {"Common": 0, "Uncommon": 1, "Rare": 2, "Epic": 3, "Showcase": 4, "Promo": 5}
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
    creds = {"handle": "maelle", "email": "maelle@example.org", "password": "supersecret1"}
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
    put = client.put("/api/collection/ogn-037-298", json={"qty": 3, "condition": "NM", "lang": "FR"}, headers=auth)
    assert put.status_code == 200 and put.json()["qty"] == 3

    coll = client.get("/api/collection", headers=auth).json()
    assert coll["total_cards"] == 3 and coll["unique_cards"] == 1
    assert coll["items"][0]["card"]["name"] == "Immortal Phoenix"

    client.put("/api/collection/ogn-037-298", json={"qty": 0}, headers=auth)
    assert client.get("/api/collection", headers=auth).json()["unique_cards"] == 0

    assert client.put("/api/collection/xxx-000-000", json={"qty": 1}, headers=auth).status_code == 404


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
        json={"handle": "intrus", "email": "intrus@example.org", "password": "motdepasse123"},
    ).json()["token"]
    other_auth = {"Authorization": f"Bearer {other}"}
    assert client.put(f"/api/decks/{deck_id}", json=deck_payload(), headers=other_auth).status_code == 404
    assert client.delete(f"/api/decks/{deck_id}", headers=other_auth).status_code == 404

    assert client.delete(f"/api/decks/{deck_id}", headers=auth).status_code == 204


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
