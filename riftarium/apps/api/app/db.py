from pathlib import Path

from sqlalchemy import create_engine, inspect
from sqlalchemy.orm import DeclarativeBase, Session, sessionmaker

from .config import settings

engine = create_engine(settings.database_url, pool_pre_ping=True)
SessionLocal = sessionmaker(bind=engine, expire_on_commit=False)

# Révision « baseline » : schéma complet au moment de l'adoption d'Alembic.
# Les bases créées avant (create_all + ensure_schema) sont stampées dessus.
BASELINE_REVISION = "0001"


class Base(DeclarativeBase):
    pass


def _alembic_config(target):
    """Config Alembic pointant sur les fichiers du paquet (local : apps/api ; conteneur : /srv)."""
    from alembic.config import Config

    base_dir = Path(__file__).resolve().parent.parent  # dossier contenant alembic.ini et alembic/
    config = Config(str(base_dir / "alembic.ini"))
    config.attributes["engine"] = target  # env.py réutilise ce moteur (bases de test en mémoire)
    config.attributes["configure_logger"] = False  # on garde la config logging de l'application
    return config


def run_migrations(bind=None) -> None:
    """Amène la base au dernier schéma via Alembic (appelé au démarrage de l'API).

    Reprise des instances créées avant Alembic (create_all + ensure_schema) :
    si des tables applicatives existent sans table alembic_version, leur schéma
    correspond déjà à la baseline — on la marque appliquée (stamp) sans la
    rejouer, puis upgrade applique les migrations suivantes. Sur une base
    neuve, upgrade joue la baseline qui crée tout. Idempotent.
    """
    from alembic import command

    target = bind or engine
    config = _alembic_config(target)

    tables = set(inspect(target).get_table_names())
    if "alembic_version" not in tables and "users" in tables:
        command.stamp(config, BASELINE_REVISION)
    command.upgrade(config, "head")


def get_db():
    db: Session = SessionLocal()
    try:
        yield db
    finally:
        db.close()
