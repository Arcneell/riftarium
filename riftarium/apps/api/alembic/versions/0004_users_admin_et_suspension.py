"""Administration : drapeau users.is_admin, suspension de compte et fréquentation.

- is_admin : accordé/retiré au démarrage selon ADMIN_EMAILS (routers/admin.py),
  jamais modifiable via l'API. server_default false pour les comptes existants.
- suspended_until / suspension_reason : suspension temporaire posée par un
  administrateur ; une valeur passée est simplement ignorée (pas de nettoyage).
- page_hits : fréquentation agrégée et anonyme (compteurs jour × section,
  aucune donnée personnelle — voir routers/metrics.py).

Générée par autogenerate puis relue à la main.

Revision ID: 0004
Revises: 0003
Create Date: 2026-08-20
"""

import sqlalchemy as sa
from alembic import op

# Identifiants de révision utilisés par Alembic.
revision = "0004"
down_revision = "0003"
branch_labels = None
depends_on = None


def upgrade() -> None:
    """Ajoute le drapeau admin, les colonnes de suspension et la table page_hits."""
    with op.batch_alter_table("users", schema=None) as batch_op:
        batch_op.add_column(sa.Column("is_admin", sa.Boolean(), nullable=False, server_default=sa.false()))
        batch_op.add_column(sa.Column("suspended_until", sa.DateTime(timezone=True), nullable=True))
        batch_op.add_column(sa.Column("suspension_reason", sa.String(length=280), nullable=True))

    op.create_table(
        "page_hits",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("day", sa.Date(), nullable=False),
        sa.Column("section", sa.String(length=32), nullable=False),
        sa.Column("hits", sa.Integer(), nullable=False),
        sa.Column("uniques", sa.Integer(), nullable=False),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("day", "section", name="uq_page_hit_day_section"),
    )
    op.create_index("ix_page_hits_day", "page_hits", ["day"], unique=False)


def downgrade() -> None:
    """Supprime la table page_hits, le drapeau admin et les colonnes de suspension."""
    op.drop_index("ix_page_hits_day", table_name="page_hits")
    op.drop_table("page_hits")
    with op.batch_alter_table("users", schema=None) as batch_op:
        batch_op.drop_column("suspension_reason")
        batch_op.drop_column("suspended_until")
        batch_op.drop_column("is_admin")
