"""Empreinte perceptuelle des visuels (cards.image_hash).

dHash 512 bits en hexadécimal (128 caractères), calculé depuis le CDN Riot via
POST /api/admin/cards/hashes et exposé par GET /api/cards/hashes (scan mobile).
NULL tant que l'empreinte n'a pas été calculée ou après un changement de visuel.

Générée par autogenerate puis relue à la main.

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
    """Ajoute la colonne d'empreinte (nullable : remplie à la demande)."""
    with op.batch_alter_table("cards", schema=None) as batch_op:
        batch_op.add_column(sa.Column("image_hash", sa.String(length=128), nullable=True))


def downgrade() -> None:
    """Supprime la colonne d'empreinte."""
    with op.batch_alter_table("cards", schema=None) as batch_op:
        batch_op.drop_column("image_hash")
