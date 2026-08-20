"""Démarrage de l'application : auto-sync sur base vide, tolérance aux pannes de la source."""

import app.db as db_module
import app.main as main_module
import pytest
from app.main import app
from fastapi.testclient import TestClient

from conftest import create_schema, seed


@pytest.fixture()
def empty_db():
    create_schema()


def test_lifespan_auto_syncs_empty_database(empty_db, monkeypatch):
    calls = []
    monkeypatch.setattr(main_module.settings, "auto_sync", True)
    monkeypatch.setattr(main_module, "run_sync", lambda db: calls.append(db) or {"sets": 1, "cards": 2})

    with TestClient(app) as client:
        assert client.get("/api/health").status_code == 200
    assert len(calls) == 1  # base vide + AUTO_SYNC : la sync initiale est lancée


def test_lifespan_skips_sync_when_database_is_populated(empty_db, monkeypatch):
    with db_module.SessionLocal() as session:
        seed(session)
    calls = []
    monkeypatch.setattr(main_module.settings, "auto_sync", True)
    monkeypatch.setattr(main_module, "run_sync", lambda db: calls.append(db))

    with TestClient(app):
        pass
    assert calls == []  # des cartes existent déjà : pas de sync au démarrage


def test_lifespan_survives_sync_source_outage(empty_db, monkeypatch):
    def _down(db):
        raise RuntimeError("Riftcodex indisponible")

    monkeypatch.setattr(main_module.settings, "auto_sync", True)
    monkeypatch.setattr(main_module, "run_sync", _down)

    with TestClient(app) as client:  # le démarrage ne doit pas échouer
        assert client.get("/api/health").json() == {"status": "ok"}


def test_lifespan_without_auto_sync_never_calls_run_sync(empty_db, monkeypatch):
    calls = []
    monkeypatch.setattr(main_module, "run_sync", lambda db: calls.append(db))
    # AUTO_SYNC=0 posé par conftest
    with TestClient(app):
        pass
    assert calls == []
