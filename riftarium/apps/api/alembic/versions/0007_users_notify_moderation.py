"""Notifications de modération : colonne users.notify_moderation.

- notify_moderation : préférence e-mail du joueur (décisions de modération sur
  ses decks). Activée par défaut — server_default true pour les comptes
  existants — et désactivable depuis le profil (PATCH /api/auth/me).

Générée par autogenerate puis relue à la main.

Revision ID: 0007
Revises: 0006
Create Date: 2026-08-20
"""

import sqlalchemy as sa
from alembic import op

# Identifiants de révision utilisés par Alembic.
revision = "0007"
down_revision = "0006"
branch_labels = None
depends_on = None


def upgrade() -> None:
    """Ajoute la préférence users.notify_moderation (activée par défaut)."""
    with op.batch_alter_table("users", schema=None) as batch_op:
        batch_op.add_column(sa.Column("notify_moderation", sa.Boolean(), nullable=False, server_default=sa.true()))


def downgrade() -> None:
    """Supprime la préférence users.notify_moderation."""
    with op.batch_alter_table("users", schema=None) as batch_op:
        batch_op.drop_column("notify_moderation")
