"""Prix des cartes : mapping TCGplayer, prix du marché, historique et app_state.

- cards.tcgplayer_id : identifiant produit TCGplayer exposé par Riftcodex
  (rempli à la sync, ou backfillé par le worker de prix pour l'existant).
- cards.price_usd / price_foil_usd : marketPrice TCGplayer (voir app/prices.py).
- price_history : une ligne (jour, carte) → prix du marché USD, pour tracer
  l'évolution des cours.
- app_state : stockage clé/valeur applicatif (taux USD→EUR de la BCE, jour du
  dernier rafraîchissement des prix).

Générée par autogenerate puis relue à la main.

Revision ID: 0005
Revises: 0004
Create Date: 2026-08-20
"""

import sqlalchemy as sa
from alembic import op

# Identifiants de révision utilisés par Alembic.
revision = "0005"
down_revision = "0004"
branch_labels = None
depends_on = None


def upgrade() -> None:
    """Ajoute les colonnes de prix aux cartes et les tables price_history / app_state."""
    with op.batch_alter_table("cards", schema=None) as batch_op:
        batch_op.add_column(sa.Column("tcgplayer_id", sa.String(length=16), nullable=True))
        batch_op.add_column(sa.Column("price_usd", sa.Float(), nullable=True))
        batch_op.add_column(sa.Column("price_foil_usd", sa.Float(), nullable=True))
    op.create_index("ix_cards_tcgplayer_id", "cards", ["tcgplayer_id"], unique=False)

    op.create_table(
        "price_history",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("day", sa.Date(), nullable=False),
        sa.Column("card_id", sa.String(length=32), nullable=False),
        sa.Column("market_usd", sa.Float(), nullable=False),
        sa.ForeignKeyConstraint(["card_id"], ["cards.id"]),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("day", "card_id", name="uq_price_history_day_card"),
    )
    op.create_index("ix_price_history_day", "price_history", ["day"], unique=False)
    op.create_index("ix_price_history_card_id", "price_history", ["card_id"], unique=False)

    op.create_table(
        "app_state",
        sa.Column("key", sa.String(length=64), nullable=False),
        sa.Column("value", sa.String(length=255), nullable=False),
        sa.PrimaryKeyConstraint("key"),
    )


def downgrade() -> None:
    """Supprime les tables app_state / price_history et les colonnes de prix."""
    op.drop_table("app_state")
    op.drop_index("ix_price_history_card_id", table_name="price_history")
    op.drop_index("ix_price_history_day", table_name="price_history")
    op.drop_table("price_history")
    op.drop_index("ix_cards_tcgplayer_id", table_name="cards")
    with op.batch_alter_table("cards", schema=None) as batch_op:
        batch_op.drop_column("price_foil_usd")
        batch_op.drop_column("price_usd")
        batch_op.drop_column("tcgplayer_id")
