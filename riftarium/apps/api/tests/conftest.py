import os

os.environ["DATABASE_URL"] = "sqlite://"
os.environ["AUTO_SYNC"] = "0"
os.environ["RIFTARIUM_ENV"] = "test"
os.environ["JWT_SECRET"] = "test-secret-not-for-production-use!"
os.environ["ADMIN_TOKEN"] = "test-admin-token-ok"
os.environ["AUTH_RATE_LIMIT"] = "10000"
os.environ["AUTH_ACCOUNT_RATE_LIMIT"] = "10000"
os.environ["EMAIL_RATE_LIMIT"] = "10000"
os.environ["REDIS_URL"] = ""  # les tests tournent sans cache, même si un Redis est joignable
os.environ["COOKIE_SECURE"] = "0"
os.environ["SCRYPT_N"] = "4096"  # paramètres scrypt faibles pour garder la suite rapide

import pytest
from fastapi.testclient import TestClient
from sqlalchemy.pool import StaticPool

import app.db as db_module
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

# Base SQLite en mémoire partagée entre les connexions du test
db_module.engine = create_engine("sqlite://", connect_args={"check_same_thread": False}, poolclass=StaticPool)
db_module.SessionLocal = sessionmaker(bind=db_module.engine, expire_on_commit=False)

from app.db import Base
from app.models import Card, CardSet
from app.main import app
import app.cache as cache_module
import app.main as main_module
import app.security as security_module


def seed(session):
    session.add(CardSet(set_id="OGN", name="Origins", card_count=352))
    cards = [
        Card(
            id="ogn-247-298",
            riftbound_id="ogn-247-298",
            name="Daughter of the Void",
            set_id="OGN",
            type="Legend",
            rarity="Rare",
            domains=["Fury", "Mind"],
            collector_number=247,
            tags=["Ahri"],
            image_url="https://cdn.example/ahri-legend.png",
            orientation="landscape",
        ),
        Card(
            id="ogn-275-298",
            riftbound_id="ogn-275-298",
            name="Altar to Unity",
            set_id="OGN",
            type="Battlefield",
            rarity="Uncommon",
            domains=["Colorless"],
            collector_number=275,
        ),
        Card(
            id="ogn-276-298",
            riftbound_id="ogn-276-298",
            name="Aspirant's Climb",
            set_id="OGN",
            type="Battlefield",
            rarity="Uncommon",
            domains=["Colorless"],
            collector_number=276,
        ),
        Card(
            id="ogn-277-298",
            riftbound_id="ogn-277-298",
            name="Back-Alley Bar",
            set_id="OGN",
            type="Battlefield",
            rarity="Uncommon",
            domains=["Colorless"],
            collector_number=277,
        ),
        Card(
            id="ogn-007-298",
            riftbound_id="ogn-007-298",
            name="Fury Rune",
            set_id="OGN",
            type="Rune",
            rarity="Common",
            domains=["Fury"],
            collector_number=7,
        ),
        Card(
            id="ogn-037-298",
            riftbound_id="ogn-037-298",
            name="Immortal Phoenix",
            set_id="OGN",
            type="Unit",
            rarity="Epic",
            domains=["Fury"],
            energy=4,
            might=5,
            collector_number=37,
            text_plain="Assault 2. When you kill a unit with a spell, you may play me from your trash.",
        ),
        Card(
            id="ogn-119-298",
            riftbound_id="ogn-119-298",
            name="Ahri, Inquisitive",
            set_id="OGN",
            type="Unit",
            supertype="Champion",
            rarity="Epic",
            domains=["Mind"],
            energy=3,
            might=3,
            collector_number=119,
            tags=["Ahri"],
        ),
        Card(
            id="ogn-078-298",
            riftbound_id="ogn-078-298",
            name="Lee Sin, Ascetic",
            set_id="OGN",
            type="Unit",
            rarity="Epic",
            domains=["Calm"],
            energy=3,
            might=4,
            collector_number=78,
        ),
        Card(
            id="ogn-037a-298",
            riftbound_id="ogn-037a-298",
            name="Immortal Phoenix (Alternate Art)",
            set_id="OGN",
            type="Unit",
            rarity="Showcase",
            domains=["Fury"],
            energy=4,
            might=5,
            collector_number=37,
            alternate_art=True,
            text_plain="[Assault 2] (+2 :rb_might: while I'm an attacker.)",
        ),
        Card(
            id="ogn-037*-298",
            riftbound_id="ogn-037*-298",
            name="Immortal Phoenix (Signature)",
            set_id="OGN",
            type="Unit",
            rarity="Epic",
            domains=["Fury"],
            energy=4,
            might=5,
            collector_number=37,
            signature=True,
        ),
        Card(
            id="ogn-200-298",
            riftbound_id="ogn-200-298",
            name="Sky Splitter",
            set_id="OGN",
            type="Spell",
            rarity="Rare",
            domains=["Mind"],
            energy=8,
            collector_number=200,
            text_plain="[Unique] Destroy target unit.",
        ),
    ]
    session.add_all(cards)
    session.commit()


@pytest.fixture(autouse=True)
def _reset_module_state():
    """Remet à zéro l'état module partagé entre les tests (rate limit, throttle sync, cache)."""

    def _reset():
        security_module._hits.clear()
        security_module._last_purge = 0.0
        main_module._last_sync_fallback = 0.0
        cache_module._client = None
        cache_module._disabled = not cache_module.settings.redis_url

    _reset()
    yield
    _reset()


def create_schema():
    """Schéma neuf via create_all (et non run_migrations) : bien plus rapide, et sûr
    car test_migrations.py vérifie que la chaîne Alembic produit un schéma identique
    à Base.metadata. On stampe ensuite « head » : le lifespan (TestClient) exécute
    run_migrations, qui ne doit rien rejouer sur ce schéma déjà à jour."""
    from alembic import command

    from app.db import _alembic_config

    Base.metadata.drop_all(db_module.engine)
    Base.metadata.create_all(db_module.engine)
    command.stamp(_alembic_config(db_module.engine), "head", purge=True)


@pytest.fixture()
def client():
    create_schema()
    with db_module.SessionLocal() as session:
        seed(session)
    with TestClient(app) as test_client:
        yield test_client


def bearer_headers(client):
    """Récupère le jeton depuis le cookie de session (le corps JSON ne l'expose plus)."""
    token = client.cookies.get("riftarium_session")
    client.cookies.clear()  # les tests Bearer ne doivent pas aussi envoyer le cookie HTTP-only
    return {"Authorization": f"Bearer {token}"}


@pytest.fixture()
def register_user():
    """Factory d'inscription : construit le payload complet à partir du handle."""

    def _register(client, handle, *, email=None, password="motdepasse123", headers=None, **overrides):
        payload = {
            "handle": handle,
            "email": email or f"{handle}@example.org",
            "password": password,
            "accept_terms": True,
            "confirm_age": True,
        }
        payload.update(overrides)
        return client.post("/api/auth/register", json=payload, headers=headers)

    return _register


@pytest.fixture()
def auth(client, register_user):
    response = register_user(client, "testeur")
    assert response.status_code == 201, response.text
    assert "token" not in response.json()  # le jeton ne circule que via le cookie HttpOnly
    return bearer_headers(client)
