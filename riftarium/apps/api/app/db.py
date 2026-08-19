from sqlalchemy import create_engine, inspect, text
from sqlalchemy.orm import DeclarativeBase, Session, sessionmaker

from .config import settings

engine = create_engine(settings.database_url, pool_pre_ping=True)
SessionLocal = sessionmaker(bind=engine, expire_on_commit=False)


class Base(DeclarativeBase):
    pass


def ensure_schema(bind=None) -> None:
    """Ajuste une base déjà créée : colonnes récentes et contraintes (create_all ne les pose pas)."""
    target = bind or engine
    inspector = inspect(target)
    tables = inspector.get_table_names()

    if "users" in tables:
        cols = {column["name"] for column in inspector.get_columns("users")}
        extras = []
        if "bio" not in cols:
            extras.append("ALTER TABLE users ADD COLUMN bio VARCHAR(280) DEFAULT '' NOT NULL")
        if "avatar_card_id" not in cols:
            extras.append("ALTER TABLE users ADD COLUMN avatar_card_id VARCHAR(32)")
        if "token_version" not in cols:
            extras.append("ALTER TABLE users ADD COLUMN token_version INTEGER DEFAULT 1 NOT NULL")
        if "email_verified_at" not in cols:
            ts_type = "TIMESTAMPTZ" if target.dialect.name == "postgresql" else "DATETIME"
            extras.append(f"ALTER TABLE users ADD COLUMN email_verified_at {ts_type}")
            # Reprise : les comptes créés avant la vérification d'e-mail sont considérés
            # comme vérifiés. Idempotent : l'UPDATE ne part qu'avec l'ALTER (premier passage).
            extras.append("UPDATE users SET email_verified_at = COALESCE(created_at, CURRENT_TIMESTAMP)")
        if extras:
            with target.begin() as conn:
                for statement in extras:
                    conn.execute(text(statement))

    if "cards" in tables:
        cols = {column["name"] for column in inspector.get_columns("cards")}
        extras = []
        if "signature" not in cols:
            extras.append("ALTER TABLE cards ADD COLUMN signature BOOLEAN DEFAULT FALSE NOT NULL")
        if "overnumbered" not in cols:
            extras.append("ALTER TABLE cards ADD COLUMN overnumbered BOOLEAN DEFAULT FALSE NOT NULL")
        if extras:
            with target.begin() as conn:
                for statement in extras:
                    conn.execute(text(statement))

    if "decks" in tables:
        cols = {column["name"] for column in inspector.get_columns("decks")}
        if "views_count" not in cols:
            with target.begin() as conn:
                conn.execute(text("ALTER TABLE decks ADD COLUMN views_count INTEGER DEFAULT 0 NOT NULL"))

    # Collection : plusieurs lots par carte (état/langue) — l'ancienne unicité user+carte saute.
    # SQLite ne supporte pas ALTER TABLE ... DROP CONSTRAINT : uniquement pour les bases Postgres existantes.
    if "collection_items" in tables and target.dialect.name == "postgresql":
        constraints = {uc["name"] for uc in inspector.get_unique_constraints("collection_items")}
        if "uq_collection_user_card" in constraints:
            with target.begin() as conn:
                conn.execute(text("ALTER TABLE collection_items DROP CONSTRAINT uq_collection_user_card"))
                conn.execute(
                    text(
                        "ALTER TABLE collection_items "
                        "ADD CONSTRAINT uq_collection_entry UNIQUE (user_id, card_id, condition, lang)"
                    )
                )

    # Index déclarés dans models.py pour les nouvelles bases ; create_all ne les ajoute pas
    # aux tables déjà créées, d'où ces CREATE INDEX idempotents (SQLite et Postgres).
    index_statements = []
    if "decks" in tables:
        index_statements.append(
            "CREATE INDEX IF NOT EXISTS ix_decks_public_moderation ON decks (is_public, moderation_status)"
        )
    if "deck_cards" in tables:
        index_statements.append("CREATE INDEX IF NOT EXISTS ix_deck_cards_card_id ON deck_cards (card_id)")
    if index_statements:
        with target.begin() as conn:
            for statement in index_statements:
                conn.execute(text(statement))


def get_db():
    db: Session = SessionLocal()
    try:
        yield db
    finally:
        db.close()
