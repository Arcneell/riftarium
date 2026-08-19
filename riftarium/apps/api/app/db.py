from pathlib import Path

from sqlalchemy import create_engine, inspect
from sqlalchemy.orm import DeclarativeBase, Session, sessionmaker

from .config import settings

engine = create_engine(settings.database_url, pool_pre_ping=True)
SessionLocal = sessionmaker(bind=engine, expire_on_commit=False)

# Révision « baseline » : on tamponne les bases pré-Alembic ici pour ne pas
# rejouer les CREATE TABLE. 0001 décrit le schéma *visé* (y compris e-mails),
# pas celui réellement en place : 0002 backfill la différence.
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
    si `users` existe sans `alembic_version`, on tamponne la baseline 0001
    (évite de rejouer les CREATE TABLE) puis `upgrade head` joue les
    migrations suivantes. 0002 est idempotente : elle ajoute
    `email_verified_at` / `auth_tokens` si 0001 a été tamponnée sur un
    schéma plus ancien. Sur une base neuve, 0001 crée tout et 0002 est un
    no-op. Idempotent.
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
