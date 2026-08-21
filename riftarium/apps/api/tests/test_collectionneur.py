"""Pack collectionneur : complétion de sets, decks constructibles, wishlist et export CSV."""

import app.db as db_module
from app import prices
from app.models import Card, CardSet, WishlistItem
from sqlalchemy import select


def write_state(key, value):
    with db_module.SessionLocal() as session:
        prices.state_set(session, key, value)
        session.commit()


def set_price(card_id, usd):
    with db_module.SessionLocal() as session:
        session.get(Card, card_id).price_usd = usd
        session.commit()


def seed_second_set():
    """Un deuxième set (2 cartes, une pricée) pour vérifier le groupement par set."""
    with db_module.SessionLocal() as session:
        session.add(CardSet(set_id="OGS", name="Origins Proving", card_count=2))
        session.add_all(
            [
                Card(
                    id="ogs-001-002",
                    riftbound_id="ogs-001-002",
                    name="Proving Ground",
                    set_id="OGS",
                    type="Battlefield",
                    collector_number=1,
                    price_usd=4.0,
                ),
                Card(
                    id="ogs-002-002",
                    riftbound_id="ogs-002-002",
                    name="Proving Rune",
                    set_id="OGS",
                    type="Rune",
                    collector_number=2,
                ),
            ]
        )
        session.commit()


def deck_payload(**overrides):
    payload = {
        "name": "Deck collectionneur",
        "description": "",
        "format": "tournament",
        "is_public": True,
        "cards": [{"card_id": "ogn-037-298", "qty": 2}, {"card_id": "ogn-007-298", "qty": 1}],
    }
    payload.update(overrides)
    return payload


def other_auth(client, register_user, handle="visiteur"):
    token = register_user(client, handle).cookies.get("riftarium_session")
    return {"Authorization": f"Bearer {token}"}


# --- Complétion de sets -----------------------------------------------------------


def test_collection_sets_requires_auth(client):
    assert client.get("/api/collection/sets").status_code == 401


def test_collection_sets_counts_and_costs(client, auth):
    seed_second_set()
    write_state("prices:rate", "0.5")
    set_price("ogn-037-298", 10.0)  # possédée
    set_price("ogn-275-298", 2.0)  # manquante

    # Deux lots (langues) de la même carte : une seule carte distincte possédée.
    client.put("/api/collection/ogn-037-298", json={"qty": 2}, headers=auth)
    client.put("/api/collection/ogn-037-298", json={"qty": 1, "lang": "FR"}, headers=auth)
    client.put("/api/collection/ogn-007-298", json={"qty": 1}, headers=auth)  # sans prix connu

    data = client.get("/api/collection/sets", headers=auth).json()
    by_set = {entry["set_id"]: entry for entry in data["sets"]}

    ogn = by_set["OGN"]
    assert ogn["name"] == "Origins"
    assert ogn["total"] == 11  # variantes incluses (art alternatif + signature)
    assert ogn["owned"] == 2
    assert ogn["missing"] == 9
    assert ogn["missing_cost_eur"] == 1.0  # seule ogn-275-298 (2 $ × 0.5) est pricée parmi les manquantes
    assert ogn["owned_value_eur"] == 5.0  # un exemplaire par carte : 10 $ × 0.5

    ogs = by_set["OGS"]
    assert (ogs["total"], ogs["owned"], ogs["missing"]) == (2, 0, 2)
    assert ogs["missing_cost_eur"] == 2.0
    assert ogs["owned_value_eur"] is None  # rien de possédé dans ce set

    overall = data["overall"]
    assert (overall["total"], overall["owned"], overall["missing"]) == (13, 2, 11)
    assert overall["missing_cost_eur"] == 3.0
    assert overall["owned_value_eur"] == 5.0


def test_collection_sets_costs_null_without_prices_or_rate(client, auth):
    client.put("/api/collection/ogn-037-298", json={"qty": 1}, headers=auth)

    # Aucune carte pricée : coûts null, comptages corrects.
    data = client.get("/api/collection/sets", headers=auth).json()
    ogn = data["sets"][0]
    assert (ogn["total"], ogn["owned"], ogn["missing"]) == (11, 1, 10)
    assert ogn["missing_cost_eur"] is None
    assert ogn["owned_value_eur"] is None
    assert data["overall"]["missing_cost_eur"] is None

    # Cartes pricées mais aucun taux stocké : pas de conversion hasardeuse.
    set_price("ogn-037-298", 10.0)
    set_price("ogn-275-298", 2.0)
    data = client.get("/api/collection/sets", headers=auth).json()
    assert data["sets"][0]["missing_cost_eur"] is None
    assert data["sets"][0]["owned_value_eur"] is None


def test_collection_sets_complete_set_has_no_missing_cost(client, auth):
    seed_second_set()
    write_state("prices:rate", "0.5")
    client.put("/api/collection/ogs-001-002", json={"qty": 1}, headers=auth)
    client.put("/api/collection/ogs-002-002", json={"qty": 3}, headers=auth)

    ogs = {entry["set_id"]: entry for entry in client.get("/api/collection/sets", headers=auth).json()["sets"]}["OGS"]
    assert (ogs["owned"], ogs["missing"]) == (2, 0)
    assert ogs["missing_cost_eur"] is None  # set complet : plus rien à acheter
    assert ogs["owned_value_eur"] == 2.0


# --- Decks constructibles et manque par deck --------------------------------------


def test_community_buildable_filters_covered_decks(client, auth):
    covered = client.post("/api/decks", json=deck_payload(name="Couvert"), headers=auth).json()["id"]
    partial = client.post(
        "/api/decks",
        json=deck_payload(name="Partiel", cards=[{"card_id": "ogn-200-298", "qty": 2}]),
        headers=auth,
    ).json()["id"]

    client.put("/api/collection/ogn-037-298", json={"qty": 2}, headers=auth)
    client.put("/api/collection/ogn-007-298", json={"qty": 5}, headers=auth)
    client.put("/api/collection/ogn-200-298", json={"qty": 1}, headers=auth)  # quantité partielle : 1 < 2

    everything = client.get("/api/community/decks", headers=auth).json()
    assert everything["total"] == 2

    buildable = client.get("/api/community/decks", params={"buildable": "1"}, headers=auth).json()
    assert buildable["total"] == 1
    assert [deck["id"] for deck in buildable["items"]] == [covered]

    # Le déficit comblé rend le deck constructible.
    client.put("/api/collection/ogn-200-298", json={"qty": 2}, headers=auth)
    buildable = client.get("/api/community/decks", params={"buildable": "1"}, headers=auth).json()
    assert buildable["total"] == 2
    assert partial in {deck["id"] for deck in buildable["items"]}

    # Anonyme : le paramètre est ignoré (comme « liked »).
    anonymous = client.get("/api/community/decks", params={"buildable": "1"}).json()
    assert anonymous["total"] == 2


def test_community_listing_exposes_missing_cards_and_cost(client, auth):
    write_state("prices:rate", "0.5")
    set_price("ogn-037-298", 10.0)
    client.post("/api/decks", json=deck_payload(name="Presque"), headers=auth)
    client.post(
        "/api/decks",
        json=deck_payload(name="Sans prix", cards=[{"card_id": "ogn-275-298", "qty": 3}]),
        headers=auth,
    )
    client.put("/api/collection/ogn-037-298", json={"qty": 1}, headers=auth)
    client.put("/api/collection/ogn-007-298", json={"qty": 1}, headers=auth)

    listed = {deck["name"]: deck for deck in client.get("/api/community/decks", headers=auth).json()["items"]}
    # « Presque » : il manque 1 × ogn-037-298 (pricée 5 €) — la rune sans prix ne compte pas dans le coût.
    assert listed["Presque"]["missing_cards"] == 1
    assert listed["Presque"]["missing_cost_eur"] == 5.0
    # « Sans prix » : 3 exemplaires manquants, aucune carte pricée → coût null.
    assert listed["Sans prix"]["missing_cards"] == 3
    assert listed["Sans prix"]["missing_cost_eur"] is None

    # Deck entièrement couvert : manque 0, coût 0.0 (des cartes sont pricées).
    client.put("/api/collection/ogn-037-298", json={"qty": 2}, headers=auth)
    listed = {deck["name"]: deck for deck in client.get("/api/community/decks", headers=auth).json()["items"]}
    assert listed["Presque"]["missing_cards"] == 0
    assert listed["Presque"]["missing_cost_eur"] == 0.0

    # Anonyme : le manque est incalculable (collection inconnue).
    anonymous = client.get("/api/community/decks").json()["items"][0]
    assert anonymous["missing_cards"] is None
    assert anonymous["missing_cost_eur"] is None


# --- Wishlist ----------------------------------------------------------------------


def test_wishlist_requires_auth(client):
    assert client.get("/api/wishlist").status_code == 401
    assert client.put("/api/wishlist/ogn-037-298", json={"qty": 1}).status_code == 401
    assert client.delete("/api/wishlist/ogn-037-298").status_code == 401
    assert client.post("/api/wishlist/from-deck/1").status_code == 401


def test_wishlist_crud_and_unicity(client, auth):
    write_state("prices:rate", "0.5")
    set_price("ogn-037-298", 10.0)

    assert client.put("/api/wishlist/ogn-037-298", json={"qty": 2}, headers=auth).status_code == 204
    data = client.get("/api/wishlist", headers=auth).json()
    assert data["total"] == 1
    assert data["value_eur"] == 10.0  # 2 × 5 €
    item = data["items"][0]
    assert item["qty"] == 2
    assert item["created_at"] is not None
    assert item["card"]["id"] == "ogn-037-298"
    assert item["card"]["price_eur"] == 5.0
    assert item["card"]["wished_qty"] == 2
    assert item["card"]["owned_qty"] == 0

    # Upsert : la quantité est écrasée, pas de doublon (unicité user/carte).
    assert client.put("/api/wishlist/ogn-037-298", json={"qty": 5}, headers=auth).status_code == 204
    data = client.get("/api/wishlist", headers=auth).json()
    assert data["total"] == 1
    assert data["items"][0]["qty"] == 5
    with db_module.SessionLocal() as session:
        assert len(session.scalars(select(WishlistItem)).all()) == 1

    # Bornes du contrat : 1 ≤ qty ≤ 99.
    assert client.put("/api/wishlist/ogn-037-298", json={"qty": 0}, headers=auth).status_code == 422
    assert client.put("/api/wishlist/ogn-037-298", json={"qty": 100}, headers=auth).status_code == 422
    assert client.put("/api/wishlist/xxx-000-000", json={"qty": 1}, headers=auth).status_code == 404

    assert client.delete("/api/wishlist/ogn-037-298", headers=auth).status_code == 204
    assert client.delete("/api/wishlist/ogn-037-298", headers=auth).status_code == 204  # déjà retirée : sans erreur
    assert client.delete("/api/wishlist/xxx-000-000", headers=auth).status_code == 404
    empty = client.get("/api/wishlist", headers=auth).json()
    assert empty == {"total": 0, "value_eur": None, "items": []}


def test_wishlist_sorted_recent_first_and_value_ignores_unpriced(client, auth):
    write_state("prices:rate", "0.5")
    set_price("ogn-037-298", 10.0)
    client.put("/api/wishlist/ogn-037-298", json={"qty": 1}, headers=auth)
    client.put("/api/wishlist/ogn-275-298", json={"qty": 4}, headers=auth)  # sans prix connu

    data = client.get("/api/wishlist", headers=auth).json()
    assert [item["card"]["id"] for item in data["items"]] == ["ogn-275-298", "ogn-037-298"]
    assert data["value_eur"] == 5.0  # la carte sans prix ne compte pas
    assert data["items"][0]["card"]["price_eur"] is None


def test_wishlist_from_deck_adds_only_missing_copies(client, auth):
    cards = [
        {"card_id": "ogn-037-298", "qty": 3},
        {"card_id": "ogn-007-298", "qty": 1},
        {"card_id": "ogn-275-298", "qty": 2},
    ]
    deck_id = client.post("/api/decks", json=deck_payload(cards=cards), headers=auth).json()["id"]
    client.put("/api/collection/ogn-037-298", json={"qty": 1}, headers=auth)  # besoin 3 → manque 2
    client.put("/api/collection/ogn-007-298", json={"qty": 5}, headers=auth)  # entièrement couverte
    client.put("/api/wishlist/ogn-037-298", json={"qty": 1}, headers=auth)  # déjà 1 exemplaire visé

    first = client.post(f"/api/wishlist/from-deck/{deck_id}", headers=auth).json()
    # Le Phénix passe de 1 à 2 (incrément jusqu'au besoin), la rune couverte est ignorée,
    # les 2 autels manquants sont créés : 1 + 2 exemplaires ajoutés.
    assert first["added"] == 3
    wishes = {item["card"]["id"]: item["qty"] for item in client.get("/api/wishlist", headers=auth).json()["items"]}
    assert wishes == {"ogn-037-298": 2, "ogn-275-298": 2}

    # Second appel : le besoin est déjà couvert par la wishlist, rien n'est ajouté.
    assert client.post(f"/api/wishlist/from-deck/{deck_id}", headers=auth).json()["added"] == 0

    # Une quantité déjà supérieure au besoin n'est jamais réduite.
    client.put("/api/wishlist/ogn-037-298", json={"qty": 9}, headers=auth)
    assert client.post(f"/api/wishlist/from-deck/{deck_id}", headers=auth).json()["added"] == 0
    wishes = {item["card"]["id"]: item["qty"] for item in client.get("/api/wishlist", headers=auth).json()["items"]}
    assert wishes["ogn-037-298"] == 9


def test_wishlist_from_deck_access_rules(client, auth, register_user):
    private_id = client.post("/api/decks", json=deck_payload(is_public=False), headers=auth).json()["id"]
    visitor = other_auth(client, register_user)

    # Son propre deck privé : accessible ; celui d'un autre : introuvable.
    assert client.post(f"/api/wishlist/from-deck/{private_id}", headers=auth).status_code == 200
    assert client.post(f"/api/wishlist/from-deck/{private_id}", headers=visitor).status_code == 404
    assert client.post("/api/wishlist/from-deck/999999", headers=visitor).status_code == 404

    # Deck public publié : accessible à tout compte connecté.
    public_id = client.post("/api/decks", json=deck_payload(), headers=auth).json()["id"]
    response = client.post(f"/api/wishlist/from-deck/{public_id}", headers=visitor)
    assert response.status_code == 200
    assert response.json()["added"] == 3


def test_card_out_exposes_wished_qty(client, auth):
    client.put("/api/wishlist/ogn-037-298", json={"qty": 3}, headers=auth)

    listed = {card["id"]: card for card in client.get("/api/cards", headers=auth).json()["items"]}
    assert listed["ogn-037-298"]["wished_qty"] == 3
    assert listed["ogn-275-298"]["wished_qty"] == 0  # absente de la wishlist

    detail = client.get("/api/cards/ogn-037-298", headers=auth).json()
    assert detail["wished_qty"] == 3
    assert {variant["id"]: variant["wished_qty"] for variant in detail["variants"]}["ogn-037a-298"] == 0
    variants = client.get("/api/cards/ogn-037-298/variants", headers=auth).json()
    assert {variant["id"]: variant["wished_qty"] for variant in variants}["ogn-037-298"] == 3

    deck = client.post("/api/decks", json=deck_payload(), headers=auth).json()
    deck_cards = {entry["card"]["id"]: entry["card"] for entry in deck["cards"]}
    assert deck_cards["ogn-037-298"]["wished_qty"] == 3
    assert deck_cards["ogn-007-298"]["wished_qty"] == 0

    # Anonyme : pas de wished_qty (comme owned_qty).
    anonymous = client.get("/api/cards").json()["items"][0]
    assert "wished_qty" not in anonymous
    assert "wished_qty" not in client.get("/api/cards/ogn-037-298").json()


def test_wishlist_purged_on_account_delete(client, auth):
    client.put("/api/wishlist/ogn-037-298", json={"qty": 2}, headers=auth)
    with db_module.SessionLocal() as session:
        assert len(session.scalars(select(WishlistItem)).all()) == 1

    deleted = client.request(
        "DELETE", "/api/auth/me", json={"password": "motdepasse123", "handle": "testeur"}, headers=auth
    )
    assert deleted.status_code == 204
    with db_module.SessionLocal() as session:
        assert session.scalars(select(WishlistItem)).all() == []


# --- Export CSV ---------------------------------------------------------------------


def test_collection_export_requires_auth(client):
    assert client.get("/api/collection/export.csv").status_code == 401


def test_collection_export_csv_format_and_values(client, auth):
    write_state("prices:rate", "0.5")
    set_price("ogn-037-298", 10.0)
    with db_module.SessionLocal() as session:  # nom piégeux : point-virgule et guillemets
        session.add(
            Card(
                id="ogn-299-298",
                riftbound_id="ogn-299-298",
                name='Vex; l\'ombre "morose"',
                set_id="OGN",
                type="Unit",
                collector_number=299,
            )
        )
        session.commit()

    client.put("/api/collection/ogn-037-298", json={"qty": 2}, headers=auth)
    client.put("/api/collection/ogn-037-298", json={"qty": 1, "lang": "FR", "condition": "EX"}, headers=auth)
    client.put("/api/collection/ogn-299-298", json={"qty": 3}, headers=auth)

    response = client.get("/api/collection/export.csv", headers=auth)
    assert response.status_code == 200
    assert response.headers["content-type"].startswith("text/csv")
    disposition = response.headers["content-disposition"]
    assert disposition.startswith('attachment; filename="riftarium-collection-')
    assert disposition.endswith('.csv"')

    body = response.content.decode("utf-8-sig")  # utf-8-sig ne décode que si le BOM est présent
    assert response.content.startswith(b"\xef\xbb\xbf")
    lines = body.strip().splitlines()
    assert lines[0] == "card_id;riftbound_id;name;set;condition;lang;qty;price_eur;value_eur"
    assert len(lines) == 4  # une ligne par LOT : 2 lots du Phénix + 1 lot de Vex

    # Lots du Phénix : prix 5 €, valeur = qty × prix.
    assert "ogn-037-298;ogn-037-298;Immortal Phoenix;OGN;EX;FR;1;5.0;5.0" in lines
    assert "ogn-037-298;ogn-037-298;Immortal Phoenix;OGN;NM;EN;2;5.0;10.0" in lines
    # Nom contenant ; et guillemets : encadré et guillemets doublés ; prix inconnu → champs vides.
    assert 'ogn-299-298;ogn-299-298;"Vex; l\'ombre ""morose""";OGN;NM;EN;3;;' in lines


def test_collection_export_csv_neutralises_formula_injection(client, auth):
    """Une cellule commençant par = + - @ s'exécute à l'ouverture dans Excel et
    LibreOffice : le module csv échappe les séparateurs, pas les formules."""
    import app.db as db_module
    from app.models import Card

    with db_module.SessionLocal() as session:
        session.add(
            Card(
                id="ogn-298-298",
                riftbound_id="ogn-298-298",
                name='=HYPERLINK("http://evil.example";"gagné")',
                set_id="OGN",
                type="Unit",
                collector_number=298,
            )
        )
        session.commit()

    client.put("/api/collection/ogn-298-298", json={"qty": 1}, headers=auth)
    body = client.get("/api/collection/export.csv", headers=auth).content.decode("utf-8-sig")

    ligne = next(line for line in body.splitlines() if "HYPERLINK" in line)
    assert "'=HYPERLINK" in ligne  # apostrophe de tête : le tableur lit du texte
    assert ";=HYPERLINK" not in ligne  # jamais une cellule qui démarre par =
