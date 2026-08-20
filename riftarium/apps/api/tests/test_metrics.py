"""Fréquentation anonyme : ping public, normalisation, uniques via Redis, stats admin."""

from datetime import UTC, datetime, timedelta

import app.cache as cache_module
import app.db as db_module
import fakeredis
import pytest
from app.config import settings
from app.models import PageHit, User
from sqlalchemy import inspect, select

from conftest import bearer_headers


@pytest.fixture()
def fake_redis(monkeypatch):
    server = fakeredis.FakeRedis()
    monkeypatch.setattr(cache_module, "_client", server)
    monkeypatch.setattr(cache_module, "_disabled", False)
    return server


def page_hits():
    with db_module.SessionLocal() as session:
        rows = session.scalars(select(PageHit)).all()
        return {(row.day.isoformat(), row.section): (row.hits, row.uniques) for row in rows}


def today():
    return datetime.now(UTC).date()


def test_hit_increments_and_normalizes_sections(client):
    assert client.post("/api/metrics/hit", json={"section": " Cartes "}).status_code == 204
    assert client.post("/api/metrics/hit", json={"section": "cartes"}).status_code == 204
    assert client.post("/api/metrics/hit", json={"section": "/nimporte/quoi"}).status_code == 204
    assert client.post("/api/metrics/hit", json={"section": "site"}).status_code == 204  # réservé → autre

    rows = page_hits()
    day = today().isoformat()
    assert rows[(day, "cartes")] == (2, 0)
    assert rows[(day, "autre")] == (2, 0)  # section inconnue et « site » rabattues sur l'allow-list
    # Sans Redis (conftest), aucune déduplication possible : pas de ligne « site », uniques à 0.
    assert (day, "site") not in rows
    assert client.post("/api/metrics/hit", json={"section": ""}).status_code == 422


def test_hit_counts_uniques_with_redis(client, fake_redis):
    client.post("/api/metrics/hit", json={"section": "home"})
    client.post("/api/metrics/hit", json={"section": "decks"})  # même visiteur : pas de nouvel unique
    client.post("/api/metrics/hit", json={"section": "home"}, headers={"X-Real-IP": "203.0.113.7"})

    rows = page_hits()
    day = today().isoformat()
    assert rows[(day, "home")] == (2, 0)
    assert rows[(day, "decks")] == (1, 0)
    assert rows[(day, "site")] == (0, 2)  # deux visiteurs distincts, dédupliqués par empreinte
    # L'empreinte ne vit que dans Redis, avec une durée de vie bornée (48 h).
    key = f"riftarium:metrics:uniq:{day}"
    assert fake_redis.scard(key) == 2
    assert 0 < fake_redis.ttl(key) <= 48 * 3600


def test_hit_rate_limit_silently_drops_spam(client, monkeypatch):
    monkeypatch.setattr(settings, "metrics_rate_limit", 2)
    for _ in range(5):
        assert client.post("/api/metrics/hit", json={"section": "home"}).status_code == 204
    assert page_hits()[(today().isoformat(), "home")] == (2, 0)  # au-delà de la limite : ignoré


def test_page_hits_schema_stores_no_pii(client):
    columns = {column["name"] for column in inspect(db_module.engine).get_columns("page_hits")}
    assert columns == {"id", "day", "section", "hits", "uniques"}  # ni IP, ni identifiant, ni user-agent


def test_admin_stats_visits_aggregates(client, register_user):
    register_user(client, "superviseur")
    headers = bearer_headers(client)
    with db_module.SessionLocal() as session:
        admin = session.scalar(select(User).where(User.handle == "superviseur"))
        admin.is_admin = True
        now = today()
        session.add_all(
            [
                PageHit(day=now, section="home", hits=5, uniques=0),
                PageHit(day=now, section="cartes", hits=2, uniques=0),
                PageHit(day=now, section="site", hits=0, uniques=3),
                PageHit(day=now - timedelta(days=3), section="home", hits=10, uniques=0),
                PageHit(day=now - timedelta(days=3), section="site", hits=0, uniques=4),
                PageHit(day=now - timedelta(days=20), section="decks", hits=8, uniques=0),
                PageHit(day=now - timedelta(days=40), section="home", hits=100, uniques=50),  # hors fenêtre
            ]
        )
        session.commit()

    visits = client.get("/api/admin/stats", headers=headers).json()["visits"]
    assert visits["today_hits"] == 7
    assert visits["uniques_today"] == 3
    assert visits["hits_7d"] == 17
    assert visits["uniques_7d"] == 7
    assert visits["hits_30d"] == 25
    assert [entry["day"] for entry in visits["daily"]] == sorted(entry["day"] for entry in visits["daily"])
    assert len(visits["daily"]) == 3  # le jour vieux de 40 jours est exclu
    assert visits["sections_7d"] == [{"section": "home", "hits": 15}, {"section": "cartes", "hits": 2}]
