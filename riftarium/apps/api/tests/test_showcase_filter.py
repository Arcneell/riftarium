"""Filtre de rareté « Showcase » : la famille des impressions spéciales.

Alt-arts, overnumbered (n° ≥ 299) et signatures. Les données source ne sont pas
homogènes : les alt-arts d'OGN et SFD portent la rareté « Showcase », ceux d'UNL
et VEN gardent leur rareté de base. Sans cette règle, « Unleashed + Showcase »
ne renvoyait rien.
"""


def _seed_unleashed(session):
    from app.models import Card, CardSet

    session.add(CardSet(set_id="UNL", name="Unleashed", card_count=280))
    session.add_all(
        [
            Card(
                id="unl-022",
                riftbound_id="unl-022-240",
                name="Jhin - Murderous Artist",
                set_id="UNL",
                type="Unit",
                rarity="Rare",
                domains=["Chaos"],
                collector_number=22,
            ),
            Card(
                id="unl-022a",
                riftbound_id="unl-022-240",
                name="Jhin - Murderous Artist (Alternate Art)",
                set_id="UNL",
                type="Unit",
                rarity="Rare",
                domains=["Chaos"],
                collector_number=22,
                alternate_art=True,
            ),
            Card(
                id="unl-028",
                riftbound_id="unl-028-240",
                name="Pyke - Dockside Butcher",
                set_id="UNL",
                type="Unit",
                rarity="Epic",
                domains=["Chaos"],
                collector_number=28,
            ),
            Card(
                id="unl-241",
                riftbound_id="unl-241-240",
                name="Pouty Poro (Overnumbered)",
                set_id="UNL",
                type="Unit",
                rarity="Common",
                domains=["Colorless"],
                collector_number=241,
                overnumbered=True,
            ),
            Card(
                id="unl-241s",
                riftbound_id="unl-241*-240",
                name="Pouty Poro (Signature)",
                set_id="UNL",
                type="Unit",
                rarity="Common",
                domains=["Colorless"],
                collector_number=241,
                overnumbered=True,
                signature=True,
            ),
        ]
    )
    session.commit()


def test_showcase_filter_includes_special_prints_without_showcase_rarity(client):
    import app.db as db_module

    with db_module.SessionLocal() as session:
        _seed_unleashed(session)

    showcase = client.get("/api/cards", params={"set_id": "UNL", "rarity": "Showcase"}).json()
    assert {card["id"] for card in showcase["items"]} == {"unl-022a", "unl-241", "unl-241s"}

    # La rareté de base reste filtrable telle quelle : l'alt-art y figure aussi.
    rare = client.get("/api/cards", params={"set_id": "UNL", "rarity": "Rare"}).json()
    assert {card["id"] for card in rare["items"]} == {"unl-022", "unl-022a"}

    # Les autres raretés ne sont pas élargies.
    epic = client.get("/api/cards", params={"set_id": "UNL", "rarity": "Epic"}).json()
    assert [card["id"] for card in epic["items"]] == ["unl-028"]


def test_showcase_filter_combined_with_other_rarities(client):
    import app.db as db_module

    with db_module.SessionLocal() as session:
        _seed_unleashed(session)

    both = client.get("/api/cards", params={"set_id": "UNL", "rarity": "Epic,Showcase"}).json()
    assert {card["id"] for card in both["items"]} == {"unl-022a", "unl-028", "unl-241", "unl-241s"}
