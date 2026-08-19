"""Environnement Alembic : branché sur la config et les modèles de l'application.

- L'URL de la base vient de `app.config.settings.database_url` (DATABASE_URL),
  jamais d'alembic.ini : une seule source de vérité.
- `run_migrations()` (app/db.py) fournit son propre moteur via
  `config.attributes["engine"]` — indispensable pour les bases SQLite en mémoire
  des tests, où recréer un moteur ouvrirait une base vide différente.
- `render_as_batch` est activé sous SQLite : les futurs ALTER (colonnes,
  contraintes) passent par des tables temporaires, seule voie possible en SQLite.
"""

from logging.config import fileConfig

import app.models  # noqa: F401 — enregistre toutes les tables sur Base.metadata
from alembic import context
from app.config import settings
from app.db import Base
from sqlalchemy import create_engine, pool

config = context.config

# Journalisation configurée depuis alembic.ini (uniquement en CLI : l'appel
# programmatique de run_migrations() garde la config logging de l'application).
if config.config_file_name is not None and config.attributes.get("configure_logger", True):
    fileConfig(config.config_file_name, disable_existing_loggers=False)

target_metadata = Base.metadata


def run_migrations_offline() -> None:
    """Mode « offline » : génère le SQL sans se connecter (alembic upgrade --sql)."""
    context.configure(
        url=settings.database_url,
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
    )
    with context.begin_transaction():
        context.run_migrations()


def run_migrations_online() -> None:
    """Mode « online » : applique les migrations sur la base connectée."""
    engine = config.attributes.get("engine")  # fourni par app.db.run_migrations()
    dispose = engine is None
    if engine is None:  # CLI (alembic upgrade/revision) : moteur créé ici
        engine = create_engine(settings.database_url, poolclass=pool.NullPool)

    try:
        with engine.connect() as connection:
            context.configure(
                connection=connection,
                target_metadata=target_metadata,
                # SQLite ne sait pas modifier une table en place : les migrations
                # sont rejouées via une table temporaire (mode « batch »).
                render_as_batch=connection.dialect.name == "sqlite",
            )
            with context.begin_transaction():
                context.run_migrations()
    finally:
        if dispose:
            engine.dispose()


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
