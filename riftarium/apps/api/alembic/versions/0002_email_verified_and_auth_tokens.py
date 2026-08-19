"""Backfill e-mail : colonne users.email_verified_at et table auth_tokens.

0001 a été écrite comme le schéma *cible* (models.py de la PR e-mails), pas
comme le schéma réel des bases pré-Alembic (create_all + ensure_schema).
run_migrations() tamponne ces bases à 0001 sans la rejouer : la colonne et
la table n'existent alors jamais. Cette migration est idempotente — inspect
avant chaque CREATE/ADD — pour réparer la prod déjà stampée et rester un
no-op sur une base neuve où 0001 a tout créé.

Revision ID: 0002
Revises: 0001
Create Date: 2026-08-19
"""

import sqlalchemy as sa
from alembic import op

# Identifiants de révision utilisés par Alembic.
revision = "0002"
down_revision = "0001"
branch_labels = None
depends_on = None


def upgrade() -> None:
    """Ajoute ce que 0001 n'a pas joué sur les bases héritées."""
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    tables = set(inspector.get_table_names())

    if "users" in tables:
        columns = {column["name"] for column in inspector.get_columns("users")}
        if "email_verified_at" not in columns:
            with op.batch_alter_table("users") as batch:
                batch.add_column(sa.Column("email_verified_at", sa.DateTime(timezone=True), nullable=True))

    if "auth_tokens" not in tables:
        op.create_table(
            "auth_tokens",
            sa.Column("id", sa.Integer(), nullable=False),
            sa.Column("user_id", sa.Integer(), nullable=False),
            sa.Column("purpose", sa.String(length=8), nullable=False),
            sa.Column("token_hash", sa.String(length=64), nullable=False),
            sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
            sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
            sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
            sa.PrimaryKeyConstraint("id"),
            sa.UniqueConstraint("token_hash"),
        )
        op.create_index("ix_auth_tokens_user_id", "auth_tokens", ["user_id"], unique=False)


def downgrade() -> None:
    """Retire uniquement ce que cette révision a pu ajouter."""
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    tables = set(inspector.get_table_names())

    if "auth_tokens" in tables:
        op.drop_index("ix_auth_tokens_user_id", table_name="auth_tokens")
        op.drop_table("auth_tokens")

    if "users" in tables:
        columns = {column["name"] for column in inspector.get_columns("users")}
        if "email_verified_at" in columns:
            with op.batch_alter_table("users") as batch:
                batch.drop_column("email_verified_at")
