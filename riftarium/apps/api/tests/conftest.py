import os

os.environ["DATABASE_URL"] = "sqlite://"
os.environ["AUTO_SYNC"] = "0"
os.environ["JWT_SECRET"] = "test-secret"

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
            rarity="Epic",
            domains=["Mind"],
            energy=3,
            might=3,
            collector_number=119,
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
        ),
    ]
    session.add_all(cards)
    session.commit()


@pytest.fixture()
def client():
    Base.metadata.drop_all(db_module.engine)
    Base.metadata.create_all(db_module.engine)
    with db_module.SessionLocal() as session:
        seed(session)
    with TestClient(app) as test_client:
        yield test_client


@pytest.fixture()
def auth(client):
    response = client.post(
        "/api/auth/register",
        json={"handle": "testeur", "email": "testeur@example.org", "password": "motdepasse123"},
    )
    assert response.status_code == 201, response.text
    token = response.json()["token"]
    return {"Authorization": f"Bearer {token}"}
