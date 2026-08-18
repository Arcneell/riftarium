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
    if "collection_items" in tables:
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


def get_db():
    db: Session = SessionLocal()
    try:
        yield db
    finally:
        db.close()
