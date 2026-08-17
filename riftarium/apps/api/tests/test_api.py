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
    assert response.json()["cards"] == 8


def test_cards_list_and_filters(client):
    assert client.get("/api/cards").json()["total"] == 8
    assert client.get("/api/cards", params={"type": "Unit"}).json()["total"] == 3
    assert client.get("/api/cards", params={"domain": "Fury"}).json()["total"] == 3
    hits = client.get("/api/cards", params={"q": "phoenix"}).json()
    assert hits["total"] == 1 and hits["items"][0]["id"] == "ogn-037-298"


def test_cards_random_sort(client):
    """Le tirage aléatoire rebat les cartes sans en perdre ni en inventer."""
    ordered = client.get("/api/cards", params={"size": 8}).json()["items"]
    shuffled = client.get("/api/cards", params={"sort": "random", "size": 8}).json()["items"]
    assert {c["id"] for c in shuffled} == {c["id"] for c in ordered}


def test_cards_random_preserves_filters(client):
    payload = client.get("/api/cards", params={"sort": "random", "type": "Unit", "size": 10}).json()
    assert payload["total"] == 3
    assert {card["id"] for card in payload["items"]} == {"ogn-037-298", "ogn-119-298", "ogn-078-298"}


def test_cards_unknown_sort_keeps_default_order(client):
    default = [card["id"] for card in client.get("/api/cards", params={"size": 8}).json()["items"]]
    unknown = [card["id"] for card in client.get("/api/cards", params={"sort": "name", "size": 8}).json()["items"]]
    assert unknown == default


def test_cards_random_page_meta(client):
    payload = client.get("/api/cards", params={"sort": "random", "page": 1, "size": 3}).json()
    assert payload["total"] == 8
    assert payload["page"] == 1
    assert payload["size"] == 3
    assert len(payload["items"]) == 3
    assert len({card["id"] for card in payload["items"]}) == 3


def test_cards_random_front_contract(client):
    """Le carrousel demande 40 cartes : l'API répond 200 et conserve le schéma."""
    payload = client.get("/api/cards", params={"sort": "random", "size": 40}).json()
    assert payload["total"] == 8
    assert len(payload["items"]) == 8
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
