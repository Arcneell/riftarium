from sqlalchemy import create_engine, inspect, text
from sqlalchemy.orm import DeclarativeBase, Session, sessionmaker

from .config import settings

engine = create_engine(settings.database_url, pool_pre_ping=True)
SessionLocal = sessionmaker(bind=engine, expire_on_commit=False)


class Base(DeclarativeBase):
    pass


def ensure_schema(bind=None) -> None:
    """Ajoute les colonnes récentes sur une base déjà créée (create_all ne les pose pas)."""
    target = bind or engine
    inspector = inspect(target)
    if "cards" not in inspector.get_table_names():
        return
    cols = {column["name"] for column in inspector.get_columns("cards")}
    extras = []
    if "signature" not in cols:
        extras.append("ALTER TABLE cards ADD COLUMN signature BOOLEAN DEFAULT FALSE NOT NULL")
    if "overnumbered" not in cols:
        extras.append("ALTER TABLE cards ADD COLUMN overnumbered BOOLEAN DEFAULT FALSE NOT NULL")
    if not extras:
        return
    with target.begin() as conn:
        for statement in extras:
            conn.execute(text(statement))


def get_db():
    db: Session = SessionLocal()
    try:
        yield db
    finally:
        db.close()
