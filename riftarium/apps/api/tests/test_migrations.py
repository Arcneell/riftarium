"""ensure_schema : mise à niveau d'une base « ancienne » (colonnes et index récents)."""

import pytest
from app.db import ensure_schema
from sqlalchemy import create_engine, inspect, text
from sqlalchemy.pool import StaticPool

OLD_SCHEMA = [
    # users sans bio / avatar_card_id / token_version
    """
    CREATE TABLE users (
        id INTEGER PRIMARY KEY,
        handle VARCHAR(32) NOT NULL,
        email VARCHAR(255) NOT NULL,
        password_hash VARCHAR(255) NOT NULL,
        created_at DATETIME
    )
    """,
    # cards sans signature / overnumbered
    """
    CREATE TABLE cards (
        id VARCHAR(32) PRIMARY KEY,
        riftbound_id VARCHAR(32),
        name VARCHAR(128),
        set_id VARCHAR(8),
        type VARCHAR(24),
        alternate_art BOOLEAN DEFAULT 0 NOT NULL
    )
    """,
    # decks sans views_count (et sans l'index composite déclaré dans models.py)
    """
    CREATE TABLE decks (
        id INTEGER PRIMARY KEY,
        owner_id INTEGER,
        name VARCHAR(80),
        is_public BOOLEAN DEFAULT 0 NOT NULL,
        moderation_status VARCHAR(16) DEFAULT 'published' NOT NULL,
        likes_count INTEGER DEFAULT 0 NOT NULL
    )
    """,
    # deck_cards sans index sur card_id
    """
    CREATE TABLE deck_cards (
        id INTEGER PRIMARY KEY,
        deck_id INTEGER,
        card_id VARCHAR(32),
        qty INTEGER DEFAULT 1 NOT NULL
    )
    """,
    # ancienne unicité user+carte (remplacée côté Postgres uniquement)
    """
    CREATE TABLE collection_items (
        id INTEGER PRIMARY KEY,
        user_id INTEGER,
        card_id VARCHAR(32),
        qty INTEGER DEFAULT 1 NOT NULL,
        CONSTRAINT uq_collection_user_card UNIQUE (user_id, card_id)
    )
    """,
]


@pytest.fixture()
def old_engine():
    engine = create_engine("sqlite://", connect_args={"check_same_thread": False}, poolclass=StaticPool)
    with engine.begin() as conn:
        for statement in OLD_SCHEMA:
            conn.execute(text(statement))
        conn.execute(
            text(
                "INSERT INTO users (id, handle, email, password_hash) "
                "VALUES (1, 'ancien', 'ancien@example.org', 'hash')"
            )
        )
        conn.execute(text("INSERT INTO cards (id, riftbound_id, name) VALUES ('ogn-001-298', 'ogn-001-298', 'Test')"))
        conn.execute(text("INSERT INTO decks (id, owner_id, name) VALUES (1, 1, 'Vieux deck')"))
    yield engine
    engine.dispose()


def _columns(engine, table):
    return {column["name"] for column in inspect(engine).get_columns(table)}


def _indexes(engine, table):
    return {index["name"] for index in inspect(engine).get_indexes(table)}


def test_ensure_schema_adds_missing_columns(old_engine):
    ensure_schema(bind=old_engine)

    assert {"bio", "avatar_card_id", "token_version"} <= _columns(old_engine, "users")
    assert {"signature", "overnumbered"} <= _columns(old_engine, "cards")
    assert "views_count" in _columns(old_engine, "decks")

    # Les lignes existantes reçoivent les valeurs par défaut.
    with old_engine.connect() as conn:
        user = conn.execute(text("SELECT bio, avatar_card_id, token_version FROM users WHERE id = 1")).one()
        assert user.bio == "" and user.avatar_card_id is None and user.token_version == 1
        card = conn.execute(text("SELECT signature, overnumbered FROM cards WHERE id = 'ogn-001-298'")).one()
        assert not card.signature and not card.overnumbered
        deck = conn.execute(text("SELECT views_count FROM decks WHERE id = 1")).one()
        assert deck.views_count == 0


def test_ensure_schema_grandfathers_email_verification(old_engine):
    ensure_schema(bind=old_engine)
    assert "email_verified_at" in _columns(old_engine, "users")
    with old_engine.connect() as conn:
        # Compte créé avant la fonctionnalité : marqué vérifié (reprise).
        verified = conn.execute(text("SELECT email_verified_at FROM users WHERE id = 1")).scalar_one()
        assert verified is not None

    # Idempotence : un compte créé APRÈS la migration (non vérifié) ne doit pas
    # être marqué vérifié par un passage ultérieur d'ensure_schema.
    with old_engine.begin() as conn:
        conn.execute(
            text(
                "INSERT INTO users (id, handle, email, password_hash) "
                "VALUES (2, 'recent', 'recent@example.org', 'hash')"
            )
        )
    ensure_schema(bind=old_engine)
    with old_engine.connect() as conn:
        assert conn.execute(text("SELECT email_verified_at FROM users WHERE id = 2")).scalar_one() is None
        assert conn.execute(text("SELECT email_verified_at FROM users WHERE id = 1")).scalar_one() is not None


def test_ensure_schema_creates_missing_indexes(old_engine):
    ensure_schema(bind=old_engine)
    assert "ix_decks_public_moderation" in _indexes(old_engine, "decks")
    assert "ix_deck_cards_card_id" in _indexes(old_engine, "deck_cards")


def test_ensure_schema_skips_postgresql_only_constraint_swap_on_sqlite(old_engine):
    ensure_schema(bind=old_engine)  # SQLite ne sait pas DROP CONSTRAINT : le bloc doit être sauté sans erreur
    constraints = {uc["name"] for uc in inspect(old_engine).get_unique_constraints("collection_items")}
    assert "uq_collection_user_card" in constraints
    assert "uq_collection_entry" not in constraints


def test_ensure_schema_is_idempotent(old_engine):
    ensure_schema(bind=old_engine)
    before_cols = _columns(old_engine, "users")
    ensure_schema(bind=old_engine)  # deuxième passage : colonnes présentes, CREATE INDEX IF NOT EXISTS re-exécutés
    assert _columns(old_engine, "users") == before_cols
    assert "ix_decks_public_moderation" in _indexes(old_engine, "decks")


def test_ensure_schema_on_empty_database_is_a_noop():
    engine = create_engine("sqlite://", connect_args={"check_same_thread": False}, poolclass=StaticPool)
    try:
        ensure_schema(bind=engine)  # aucune table : rien à faire, aucune erreur
        assert inspect(engine).get_table_names() == []
    finally:
        engine.dispose()
