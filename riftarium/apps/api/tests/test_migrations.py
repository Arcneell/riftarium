"""run_migrations : création du schéma via Alembic et reprise des bases pré-Alembic.

Note : le conftest garde `Base.metadata.create_all` pour préparer la base des
autres tests (plus rapide qu'un passage Alembic par test). C'est sûr car le
test ci-dessous vérifie que la chaîne de migrations produit un schéma
strictement identique à Base.metadata.
"""

import pytest
from alembic import command
from alembic.script import ScriptDirectory
from app.db import Base, _alembic_config, run_migrations
from sqlalchemy import create_engine, inspect, text
from sqlalchemy.pool import StaticPool


def _head_revision():
    """Dernière révision de la chaîne de migrations (fichiers alembic/versions)."""
    return ScriptDirectory.from_config(_alembic_config(None)).get_current_head()


@pytest.fixture()
def empty_engine():
    engine = create_engine("sqlite://", connect_args={"check_same_thread": False}, poolclass=StaticPool)
    yield engine
    engine.dispose()


def _schema_snapshot(engine):
    """Tables applicatives → colonnes, index et contraintes uniques (via l'inspector)."""
    inspector = inspect(engine)
    snapshot = {}
    for table in inspector.get_table_names():
        if table == "alembic_version":
            continue
        snapshot[table] = {
            "columns": {column["name"] for column in inspector.get_columns(table)},
            "indexes": {index["name"] for index in inspector.get_indexes(table)},
            "uniques": {uc["name"] for uc in inspector.get_unique_constraints(table) if uc["name"]},
        }
    return snapshot


def _alembic_revision(engine):
    with engine.connect() as conn:
        return conn.execute(text("SELECT version_num FROM alembic_version")).scalar_one()


def _create_pre_alembic_users(engine) -> None:
    """Schéma users tel qu'en prod avant la PR e-mails (create_all + ensure_schema).

    Pas de email_verified_at, pas de table auth_tokens : c'est exactement ce
    que le stamp 0001 a marqué « déjà appliqué » sans le jouer.
    """
    with engine.begin() as conn:
        conn.execute(
            text(
                """
                CREATE TABLE users (
                    id INTEGER NOT NULL PRIMARY KEY,
                    handle VARCHAR(32) NOT NULL,
                    email VARCHAR(255) NOT NULL,
                    password_hash VARCHAR(255) NOT NULL,
                    bio VARCHAR(280) DEFAULT '' NOT NULL,
                    avatar_card_id VARCHAR(32),
                    token_version INTEGER DEFAULT 1 NOT NULL,
                    created_at DATETIME NOT NULL
                )
                """
            )
        )
        conn.execute(
            text(
                "INSERT INTO users (id, handle, email, password_hash, bio, token_version, created_at) "
                "VALUES (1, 'ancien', 'ancien@example.org', 'hash', '', 1, CURRENT_TIMESTAMP)"
            )
        )


def _assert_email_schema(engine) -> None:
    snapshot = _schema_snapshot(engine)
    assert "email_verified_at" in snapshot["users"]["columns"]
    assert "auth_tokens" in snapshot
    assert {"user_id", "purpose", "token_hash", "expires_at"} <= snapshot["auth_tokens"]["columns"]
    with engine.connect() as conn:
        user = conn.execute(text("SELECT handle, email, email_verified_at FROM users WHERE id = 1")).one()
        assert (user.handle, user.email, user.email_verified_at) == ("ancien", "ancien@example.org", None)


def test_run_migrations_on_empty_database_matches_models(empty_engine):
    """Base neuve : la chaîne de migrations reconstruit exactement Base.metadata."""
    run_migrations(bind=empty_engine)

    reference = create_engine("sqlite://", connect_args={"check_same_thread": False}, poolclass=StaticPool)
    try:
        Base.metadata.create_all(reference)
        assert _schema_snapshot(empty_engine) == _schema_snapshot(reference)
    finally:
        reference.dispose()

    # Garde-fous explicites sur les ajouts historiques d'ensure_schema.
    snapshot = _schema_snapshot(empty_engine)
    assert {"bio", "avatar_card_id", "token_version", "email_verified_at"} <= snapshot["users"]["columns"]
    assert "views_count" in snapshot["decks"]["columns"]
    assert "ix_decks_public_moderation" in snapshot["decks"]["indexes"]
    assert "ix_deck_cards_card_id" in snapshot["deck_cards"]["indexes"]
    assert "uq_collection_entry" in snapshot["collection_items"]["uniques"]
    assert "uq_deck_like" in snapshot["deck_likes"]["uniques"]
    assert "auth_tokens" in snapshot


def test_run_migrations_stamps_legacy_database_without_data_loss(empty_engine):
    """Base pré-Alembic réelle (users sans email_verified_at) : stamp 0001 puis 0002 backfill."""
    _create_pre_alembic_users(empty_engine)

    run_migrations(bind=empty_engine)

    assert _alembic_revision(empty_engine) == _head_revision()
    _assert_email_schema(empty_engine)


def test_run_migrations_backfills_when_0001_was_stamped_on_legacy_schema(empty_engine):
    """Prod actuelle : 0001 tamponnée, schéma ancien, upgrade head doit réparer."""
    _create_pre_alembic_users(empty_engine)
    command.stamp(_alembic_config(empty_engine), "0001")
    assert _alembic_revision(empty_engine) == "0001"
    assert "email_verified_at" not in _schema_snapshot(empty_engine)["users"]["columns"]
    assert "auth_tokens" not in _schema_snapshot(empty_engine)

    run_migrations(bind=empty_engine)

    assert _alembic_revision(empty_engine) == _head_revision()
    _assert_email_schema(empty_engine)


def test_run_migrations_is_idempotent(empty_engine):
    """Deuxième appel : aucun changement de schéma, aucune erreur."""
    run_migrations(bind=empty_engine)
    before = _schema_snapshot(empty_engine)
    revision = _alembic_revision(empty_engine)

    run_migrations(bind=empty_engine)

    assert _schema_snapshot(empty_engine) == before
    assert _alembic_revision(empty_engine) == revision
