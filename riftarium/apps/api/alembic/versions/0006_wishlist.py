"""Wishlist : table wishlist_items (une ligne par carte recherchée et par joueur).

- user_id : propriétaire (suppression en cascade avec le compte) ;
- card_id : carte recherchée ;
- qty : nombre d'exemplaires visés (≥ 1) ;
- unicité (user_id, card_id) : une seule ligne par carte, la quantité s'y ajuste.

Générée par autogenerate puis relue à la main.

Revision ID: 0006
Revises: 0005
Create Date: 2026-08-20
"""

import sqlalchemy as sa
from alembic import op

# Identifiants de révision utilisés par Alembic.
revision = "0006"
down_revision = "0005"
branch_labels = None
depends_on = None


def upgrade() -> None:
    """Crée la table wishlist_items et ses index."""
    op.create_table(
        "wishlist_items",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("card_id", sa.String(length=32), nullable=False),
        sa.Column("qty", sa.Integer(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["card_id"], ["cards.id"]),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("user_id", "card_id", name="uq_wishlist_entry"),
    )
    op.create_index("ix_wishlist_items_user_id", "wishlist_items", ["user_id"], unique=False)
    op.create_index("ix_wishlist_items_card_id", "wishlist_items", ["card_id"], unique=False)


def downgrade() -> None:
    """Supprime la table wishlist_items."""
    op.drop_index("ix_wishlist_items_card_id", table_name="wishlist_items")
    op.drop_index("ix_wishlist_items_user_id", table_name="wishlist_items")
    op.drop_table("wishlist_items")
