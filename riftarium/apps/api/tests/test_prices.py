"""Prix des cartes : worker TCGCSV/BCE (app/prices.py) et contrat d'API associé."""

from datetime import UTC, datetime, timedelta

import app.db as db_module
import httpx
import pytest
import respx
from app import prices
from app.models import Card, PriceHistory
from sqlalchemy import func, select

TCGCSV = "https://tcgcsv.test"
FX = "https://fx.test"
RIFTCODEX = "https://riftcodex.test"
ADMIN = {"X-Admin-Token": "test-admin-token-ok"}


@pytest.fixture()
def prices_settings(monkeypatch):
    monkeypatch.setattr(prices.settings, "tcgcsv_base_url", TCGCSV)
    monkeypatch.setattr(prices.settings, "frankfurter_base_url", FX)
    monkeypatch.setattr(prices.settings, "riftcodex_base_url", RIFTCODEX)
    monkeypatch.setattr(prices.settings, "sync_sets", "OGN")
    monkeypatch.setattr(prices.settings, "riftcodex_page_delay", 0.0)


def price_row(product_id, market, subtype="Normal"):
    """Ligne au format réel TCGCSV (seuls productId/marketPrice/subTypeName nous servent)."""
    return {
        "productId": product_id,
        "lowPrice": market,
        "midPrice": market,
        "highPrice": market,
        "marketPrice": market,
        "directLowPrice": None,
        "subTypeName": subtype,
    }


def mock_market(rows, group_id=24344):
    respx.get(f"{TCGCSV}/tcgplayer/89/groups").mock(
        return_value=httpx.Response(200, json={"results": [{"groupId": group_id, "name": "Origins"}]})
    )
    respx.get(f"{TCGCSV}/tcgplayer/89/{group_id}/prices").mock(return_value=httpx.Response(200, json={"results": rows}))


def mock_rate(rate=0.8617, date="2026-08-19"):
    respx.get(f"{FX}/v1/latest").mock(return_value=httpx.Response(200, json={"date": date, "rates": {"EUR": rate}}))


def write_state(key, value):
    with db_module.SessionLocal() as session:
        prices.state_set(session, key, value)
        session.commit()


def read_state(key):
    with db_module.SessionLocal() as session:
        return prices.state_get(session, key)


def set_price(card_id, usd, foil=None):
    with db_module.SessionLocal() as session:
        card = session.get(Card, card_id)
        card.price_usd = usd
        card.price_foil_usd = foil
        session.commit()


def fill_tcgplayer_ids(mapping=None):
    """Mappe toutes les cartes (ids fournis + factices) : le backfill Riftcodex n'a rien à faire."""
    mapping = mapping or {}
    with db_module.SessionLocal() as session:
        for index, card in enumerate(session.scalars(select(Card)).all()):
            card.tcgplayer_id = mapping.get(card.id, f"9{index:05d}")
        session.commit()


def run_refresh():
    with db_module.SessionLocal() as session:
        return prices.refresh_prices(session)


# --- Worker : rafraîchissement complet -------------------------------------------


@respx.mock
def test_refresh_applies_normal_and_foil_prices(client, prices_settings):
    fill_tcgplayer_ids({"ogn-037-298": "1001", "ogn-200-298": "1003"})
    mock_market(
        [
            price_row(1001, 14.5, "Normal"),
            price_row(1001, 30.0, "Foil"),
            price_row(1003, 5.0, "Foil"),  # jamais vendue en « Normal » : repli sur le foil
            price_row(1004, None, "Normal"),  # marketPrice null : ignorée
        ]
    )
    mock_rate()

    summary = run_refresh()

    assert summary["status"] == "ok"
    assert summary["priced_cards"] == 2
    assert summary["history_rows"] == 2
    with db_module.SessionLocal() as session:
        phoenix = session.get(Card, "ogn-037-298")
        assert phoenix.price_usd == 14.5
        assert phoenix.price_foil_usd == 30.0
        splitter = session.get(Card, "ogn-200-298")
        assert splitter.price_usd == 5.0  # repli foil
        assert splitter.price_foil_usd == 5.0
        # Carte mappée mais absente du dump : prix inchangé (None).
        assert session.get(Card, "ogn-247-298").price_usd is None
    assert read_state("prices:rate") == "0.8617"
    assert read_state("prices:rate_date") == "2026-08-19"
    assert read_state("prices:updated_day") == datetime.now(UTC).date().isoformat()


@respx.mock
def test_refresh_backfills_tcgplayer_ids_from_riftcodex(client, prices_settings):
    respx.get(f"{RIFTCODEX}/cards", params={"page": "1"}).mock(
        return_value=httpx.Response(
            200,
            json={
                "items": [
                    {"id": "ogn-037-298", "tcgplayer_id": "1001"},
                    {"id": "ogn-247-298", "tcgplayer_id": None},  # pas vendue : ignorée
                ],
                "pages": 2,
            },
        )
    )
    respx.get(f"{RIFTCODEX}/cards", params={"page": "2"}).mock(
        return_value=httpx.Response(
            200,
            json={"items": [{"id": "ogn-200-298", "tcgplayer_id": "1003"}], "pages": 2},
        )
    )
    mock_market([price_row(1001, 14.5), price_row(1003, 5.0, "Foil")])
    mock_rate()

    summary = run_refresh()

    assert summary["backfilled_ids"] == 2
    assert summary["priced_cards"] == 2
    with db_module.SessionLocal() as session:
        assert session.get(Card, "ogn-037-298").tcgplayer_id == "1001"
        assert session.get(Card, "ogn-200-298").tcgplayer_id == "1003"
        assert session.get(Card, "ogn-247-298").tcgplayer_id is None
        assert session.get(Card, "ogn-037-298").price_usd == 14.5


@respx.mock
def test_price_history_upsert_is_idempotent(client, prices_settings):
    fill_tcgplayer_ids({"ogn-037-298": "1001"})
    respx.get(f"{TCGCSV}/tcgplayer/89/groups").mock(
        return_value=httpx.Response(200, json={"results": [{"groupId": 24344, "name": "Origins"}]})
    )
    respx.get(f"{TCGCSV}/tcgplayer/89/24344/prices").mock(
        side_effect=[
            httpx.Response(200, json={"results": [price_row(1001, 10.0)]}),
            httpx.Response(200, json={"results": [price_row(1001, 12.0)]}),
        ]
    )
    mock_rate()

    assert run_refresh()["history_rows"] == 1
    assert run_refresh()["history_rows"] == 1  # deuxième passage le même jour : mise à jour, pas de doublon

    with db_module.SessionLocal() as session:
        rows = session.scalars(select(PriceHistory).where(PriceHistory.card_id == "ogn-037-298")).all()
        assert len(rows) == 1
        assert rows[0].market_usd == 12.0
        assert session.scalar(select(func.count(PriceHistory.id))) == 1


@respx.mock
def test_refresh_survives_tcgcsv_outage_and_keeps_old_rate(client, prices_settings):
    fill_tcgplayer_ids()
    write_state("prices:rate", "0.9")
    write_state("prices:rate_date", "2026-08-01")
    respx.get(f"{TCGCSV}/tcgplayer/89/groups").mock(return_value=httpx.Response(503))

    summary = run_refresh()

    assert summary["status"] == "aborted"  # abandon propre : nouvelle tentative au prochain cycle
    assert read_state("prices:rate") == "0.9"  # ancien taux conservé
    assert read_state("prices:updated_day") is None  # pas de faux « à jour »
    with db_module.SessionLocal() as session:
        assert session.get(Card, "ogn-037-298").price_usd is None
        assert session.scalar(select(func.count(PriceHistory.id))) == 0


@respx.mock
def test_refresh_keeps_old_rate_when_frankfurter_is_down(client, prices_settings):
    fill_tcgplayer_ids({"ogn-037-298": "1001"})
    mock_market([price_row(1001, 10.0)])
    respx.get(f"{FX}/v1/latest").mock(return_value=httpx.Response(500))
    write_state("prices:rate", "0.9")

    summary = run_refresh()

    assert summary["status"] == "ok"
    assert summary["priced_cards"] == 1
    assert read_state("prices:rate") == "0.9"
    assert read_state("prices:updated_day") is not None


@respx.mock
def test_refresh_ignores_a_failing_group(client, prices_settings):
    fill_tcgplayer_ids({"ogn-037-298": "1001"})
    respx.get(f"{TCGCSV}/tcgplayer/89/groups").mock(
        return_value=httpx.Response(
            200, json={"results": [{"groupId": 1, "name": "Origins"}, {"groupId": 2, "name": "Proving"}]}
        )
    )
    respx.get(f"{TCGCSV}/tcgplayer/89/1/prices").mock(
        return_value=httpx.Response(200, json={"results": [price_row(1001, 10.0)]})
    )
    respx.get(f"{TCGCSV}/tcgplayer/89/2/prices").mock(return_value=httpx.Response(503))
    mock_rate()

    summary = run_refresh()

    assert summary["status"] == "ok"
    assert summary["priced_cards"] == 1


@respx.mock
def test_refresh_continues_when_backfill_fails(client, prices_settings):
    with db_module.SessionLocal() as session:
        session.get(Card, "ogn-037-298").tcgplayer_id = "1001"
        session.commit()
    respx.get(f"{RIFTCODEX}/cards").mock(side_effect=httpx.ConnectError("Riftcodex injoignable"))
    mock_market([price_row(1001, 10.0)])
    mock_rate()

    summary = run_refresh()

    assert summary["status"] == "ok"
    assert summary["backfilled_ids"] == 0
    assert summary["priced_cards"] == 1  # les cartes déjà mappées restent rafraîchies


def test_sync_upsert_captures_tcgplayer_id(client):
    from app.sync import _upsert_card

    payload = {
        "id": "ogn-901-298",
        "riftbound_id": "ogn-901-298",
        "name": "Carte pricée",
        "tcgplayer_id": "653002",
        "collector_number": 901,
        "attributes": {},
        "classification": {"type": "Unit"},
        "text": {},
        "media": {},
        "set": {"set_id": "ogn"},
        "metadata": {},
    }
    with db_module.SessionLocal() as session:
        _upsert_card(session, payload)
        session.commit()
        assert session.get(Card, "ogn-901-298").tcgplayer_id == "653002"

        # Payload sans tcgplayer_id (variation de la source) : l'identifiant connu est conservé.
        payload.pop("tcgplayer_id")
        _upsert_card(session, payload)
        session.commit()
        assert session.get(Card, "ogn-901-298").tcgplayer_id == "653002"


# --- Orchestration sans cron ------------------------------------------------------


def test_price_refresh_worker_calls_refresh_once(client, monkeypatch):
    calls = []
    monkeypatch.setattr(prices, "refresh_prices", lambda db: calls.append(1) or {"status": "ok"})
    prices._price_refresh_worker()
    assert calls == [1]


def test_price_refresh_worker_skips_when_already_running(client, monkeypatch):
    calls = []
    monkeypatch.setattr(prices, "refresh_prices", lambda db: calls.append(1))
    assert prices._price_refresh_lock.acquire(blocking=False)
    try:
        prices._price_refresh_worker()
    finally:
        prices._price_refresh_lock.release()
    assert calls == []


def test_price_refresh_worker_swallows_errors(client, monkeypatch):
    def _boom(db):
        raise RuntimeError("boom")

    monkeypatch.setattr(prices, "refresh_prices", _boom)
    prices._price_refresh_worker()  # ne lève jamais (thread d'arrière-plan)
    assert not prices._price_refresh_lock.locked()


def test_refresh_due_logic(client):
    assert prices._refresh_due() is True  # aucun refresh encore effectué
    write_state(prices.UPDATED_AT_KEY, datetime.now(UTC).isoformat())
    assert prices._refresh_due() is False
    write_state(prices.UPDATED_AT_KEY, (datetime.now(UTC) - timedelta(hours=21)).isoformat())
    assert prices._refresh_due() is True  # plus vieux que PRICE_MAX_AGE_HOURS
    write_state(prices.UPDATED_AT_KEY, "pas-une-date")
    assert prices._refresh_due() is True


def test_start_price_watch_respects_autorefresh(monkeypatch):
    started = []
    monkeypatch.setattr(
        prices.threading, "Thread", lambda **kw: started.append(kw) or type("T", (), {"start": lambda s: None})()
    )
    prices._watch_started.clear()
    try:
        prices.start_price_watch()  # PRICES_AUTOREFRESH=0 posé par conftest
        assert started == []

        monkeypatch.setattr(prices.settings, "prices_autorefresh", True)
        prices.start_price_watch()
        prices.start_price_watch()  # une seule veille par processus
        assert len(started) == 1
        assert started[0]["daemon"] is True
    finally:
        prices._watch_started.clear()


def test_schedule_price_refresh_spawns_daemon_thread(monkeypatch):
    started = []
    monkeypatch.setattr(
        prices.threading, "Thread", lambda **kw: started.append(kw) or type("T", (), {"start": lambda s: None})()
    )
    prices.schedule_price_refresh()
    assert len(started) == 1
    assert started[0]["daemon"] is True


def test_price_watch_loop_schedules_when_due(monkeypatch):
    calls = []
    monkeypatch.setattr(prices, "_refresh_due", lambda: True)
    monkeypatch.setattr(prices, "schedule_price_refresh", lambda: calls.append(1))

    def _stop(_seconds):
        raise TimeoutError("fin du test")

    monkeypatch.setattr(prices.time, "sleep", _stop)
    with pytest.raises(TimeoutError):
        prices._price_watch_loop()
    assert calls == [1]


def test_price_watch_loop_survives_errors(monkeypatch):
    def _boom():
        raise RuntimeError("base indisponible")

    def _stop(_seconds):
        raise TimeoutError("fin du test")

    monkeypatch.setattr(prices, "_refresh_due", _boom)
    monkeypatch.setattr(prices.time, "sleep", _stop)
    with pytest.raises(TimeoutError):  # l'erreur interne est avalée, la boucle continue
        prices._price_watch_loop()


# --- Contrat d'API ----------------------------------------------------------------


def test_cards_list_and_detail_include_price_eur(client):
    set_price("ogn-037-298", 14.5, foil=30.0)
    write_state("prices:rate", "0.8617")

    data = client.get("/api/cards", params={"q": "Immortal Phoenix"}).json()
    by_id = {item["id"]: item for item in data["items"]}
    assert by_id["ogn-037-298"]["price_eur"] == 12.49  # 14.5 × 0.8617 arrondi au centime
    assert by_id["ogn-037a-298"]["price_eur"] is None  # variante sans prix connu

    detail = client.get("/api/cards/ogn-037-298").json()
    assert detail["price_eur"] == 12.49
    assert detail["price_usd"] == 14.5
    assert detail["price_foil_eur"] == 25.85
    assert any(variant["price_eur"] == 12.49 for variant in detail["variants"])


def test_price_eur_is_null_without_stored_rate(client):
    set_price("ogn-037-298", 14.5)
    detail = client.get("/api/cards/ogn-037-298").json()
    assert detail["price_eur"] is None  # pas de taux stocké : pas de conversion hasardeuse
    assert detail["price_usd"] == 14.5
    assert detail["price_foil_eur"] is None


def test_price_eur_is_null_with_corrupted_rate(client):
    set_price("ogn-037-298", 14.5)
    write_state("prices:rate", "pas-un-nombre")
    assert client.get("/api/cards/ogn-037-298").json()["price_eur"] is None


def test_prices_meta_empty_then_populated(client):
    response = client.get("/api/prices/meta")
    assert response.status_code == 200
    assert response.headers["cache-control"] == "public, max-age=3600"
    assert response.json() == {
        "updated_day": None,
        "rate": None,
        "rate_date": None,
        "priced_cards": 0,
        "source": "tcgplayer",
        "currency_note": prices.CURRENCY_NOTE,
    }

    set_price("ogn-037-298", 14.5)
    write_state("prices:rate", "0.8617")
    write_state("prices:rate_date", "2026-08-19")
    write_state("prices:updated_day", "2026-08-20")
    meta = client.get("/api/prices/meta").json()
    assert meta["updated_day"] == "2026-08-20"
    assert meta["rate"] == 0.8617
    assert meta["rate_date"] == "2026-08-19"
    assert meta["priced_cards"] == 1
    assert meta["source"] == "tcgplayer"


def test_collection_prices_and_total_value(client, auth):
    set_price("ogn-037-298", 10.0)
    set_price("ogn-275-298", 2.0)
    write_state("prices:rate", "0.5")
    client.put("/api/collection/ogn-037-298", json={"qty": 2}, headers=auth)
    client.put("/api/collection/ogn-275-298", json={"qty": 1}, headers=auth)
    client.put("/api/collection/ogn-276-298", json={"qty": 4}, headers=auth)  # sans prix connu

    data = client.get("/api/collection", headers=auth).json()
    assert data["value_eur"] == 11.0  # 2×5.00 + 1×1.00 (les cartes sans prix ne comptent pas)
    items = {item["card"]["id"]: item for item in data["items"]}
    assert items["ogn-037-298"]["price_eur"] == 5.0
    assert items["ogn-037-298"]["value_eur"] == 10.0
    assert items["ogn-037-298"]["card"]["price_eur"] == 5.0
    assert items["ogn-276-298"]["price_eur"] is None
    assert items["ogn-276-298"]["value_eur"] is None


def test_collection_total_value_is_null_without_rate(client, auth):
    set_price("ogn-037-298", 10.0)
    client.put("/api/collection/ogn-037-298", json={"qty": 2}, headers=auth)
    data = client.get("/api/collection", headers=auth).json()
    assert data["value_eur"] is None
    assert data["items"][0]["price_eur"] is None


def test_collection_sort_by_price_nulls_last(client, auth):
    set_price("ogn-037-298", 10.0)
    set_price("ogn-275-298", 2.0)
    write_state("prices:rate", "0.5")
    for card_id in ("ogn-037-298", "ogn-275-298", "ogn-276-298"):
        client.put(f"/api/collection/{card_id}", json={"qty": 1}, headers=auth)

    desc = client.get("/api/collection", params={"sort": "price_desc"}, headers=auth).json()
    assert [item["card"]["id"] for item in desc["items"]] == ["ogn-037-298", "ogn-275-298", "ogn-276-298"]

    asc = client.get("/api/collection", params={"sort": "price_asc"}, headers=auth).json()
    assert [item["card"]["id"] for item in asc["items"]] == ["ogn-275-298", "ogn-037-298", "ogn-276-298"]


def test_deck_prices_total_and_missing(client, auth):
    set_price("ogn-037-298", 10.0)
    write_state("prices:rate", "0.5")
    client.put("/api/collection/ogn-037-298", json={"qty": 1}, headers=auth)

    created = client.post(
        "/api/decks",
        json={
            "name": "Deck pricé",
            "is_public": True,
            "cards": [{"card_id": "ogn-037-298", "qty": 3}, {"card_id": "ogn-275-298", "qty": 1}],
        },
        headers=auth,
    )
    assert created.status_code == 201
    deck = created.json()
    # total = 3 × 5.00 € (la carte sans prix ne compte pas) ; il manque 2 exemplaires.
    assert deck["prices"] == {"total_eur": 15.0, "missing_eur": 10.0}
    cards = {entry["card"]["id"]: entry for entry in deck["cards"]}
    assert cards["ogn-037-298"]["card"]["price_eur"] == 5.0
    assert cards["ogn-275-298"]["card"]["price_eur"] is None

    # Visiteur anonyme : total affichable, mais missing_eur incalculable (owned_qty inconnu).
    anonymous = client.get(f"/api/decks/{deck['id']}").json()
    assert anonymous["prices"] == {"total_eur": 15.0, "missing_eur": None}


def test_deck_prices_null_when_no_card_is_priced(client, auth):
    write_state("prices:rate", "0.5")
    created = client.post(
        "/api/decks",
        json={"name": "Deck sans prix", "cards": [{"card_id": "ogn-275-298", "qty": 2}]},
        headers=auth,
    )
    assert created.json()["prices"] == {"total_eur": None, "missing_eur": None}


# --- Endpoint admin de secours ----------------------------------------------------


def test_admin_prices_refresh_requires_token(client):
    assert client.post("/api/admin/prices/refresh").status_code == 403
    assert client.post("/api/admin/prices/refresh", headers={"X-Admin-Token": "nope"}).status_code == 403


@respx.mock
def test_admin_prices_refresh_runs_the_pipeline(client, prices_settings):
    fill_tcgplayer_ids({"ogn-037-298": "1001"})
    mock_market([price_row(1001, 14.5)])
    mock_rate()

    response = client.post("/api/admin/prices/refresh", headers=ADMIN)
    assert response.status_code == 200
    body = response.json()
    assert body["status"] == "ok"
    assert body["priced_cards"] == 1

    detail = client.get("/api/cards/ogn-037-298").json()
    assert detail["price_eur"] == 12.49


def test_admin_prices_refresh_conflicts_when_already_running(client):
    assert prices._price_refresh_lock.acquire(blocking=False)
    try:
        response = client.post("/api/admin/prices/refresh", headers=ADMIN)
    finally:
        prices._price_refresh_lock.release()
    assert response.status_code == 409
