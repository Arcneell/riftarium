"""Échanges entre joueurs (docs/echanges.md).

- users : opt-in aux échanges (faux par défaut), zone de La Réunion, contact
  externe et préférence e-mail (vraie par défaut, comme notify_moderation).
- trade_offers : un lot de collection proposé à l'échange, une offre par lot,
  supprimée avec le lot ou le compte.
- trade_requests : demande d'un joueur sur une offre ; carte, état et langue
  copiés pour survivre à l'offre (SET NULL). Index unique partiel : une seule
  demande « pending » par couple (demandeur, offre).

Écrite à la main (pas d'autogenerate).

Revision ID: 0011
Revises: 0010
Create Date: 2026-10-08
"""

import sqlalchemy as sa
from alembic import op

# Identifiants de révision utilisés par Alembic.
revision = "0011"
down_revision = "0010"
branch_labels = None
depends_on = None

PENDING = sa.text("status = 'pending'")


def upgrade() -> None:
    """Ajoute les réglages d'échange et les tables trade_offers / trade_requests."""
    with op.batch_alter_table("users", schema=None) as batch_op:
        batch_op.add_column(sa.Column("trade_enabled", sa.Boolean(), nullable=False, server_default=sa.false()))
        batch_op.add_column(sa.Column("trade_zone", sa.String(length=8), nullable=True))
        batch_op.add_column(sa.Column("trade_contact", sa.String(length=80), nullable=True))
        batch_op.add_column(sa.Column("notify_trades", sa.Boolean(), nullable=False, server_default=sa.true()))

    op.create_table(
        "trade_offers",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("collection_item_id", sa.Integer(), nullable=False),
        sa.Column("qty", sa.Integer(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["collection_item_id"], ["collection_items.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("collection_item_id"),
    )
    op.create_index("ix_trade_offers_user_id", "trade_offers", ["user_id"], unique=False)

    op.create_table(
        "trade_requests",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("requester_id", sa.Integer(), nullable=False),
        sa.Column("owner_id", sa.Integer(), nullable=False),
        sa.Column("trade_offer_id", sa.Integer(), nullable=True),
        sa.Column("card_id", sa.String(length=32), nullable=False),
        sa.Column("condition", sa.String(length=8), nullable=False),
        sa.Column("lang", sa.String(length=8), nullable=False),
        sa.Column("message", sa.String(length=280), nullable=False),
        sa.Column("status", sa.String(length=16), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("responded_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("done_at", sa.DateTime(timezone=True), nullable=True),
        sa.ForeignKeyConstraint(["requester_id"], ["users.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["owner_id"], ["users.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["trade_offer_id"], ["trade_offers.id"], ondelete="SET NULL"),
        sa.ForeignKeyConstraint(["card_id"], ["cards.id"]),
        sa.PrimaryKeyConstraint("id"),
        sa.CheckConstraint("requester_id <> owner_id", name="ck_trade_request_not_self"),
    )
    op.create_index("ix_trade_requests_requester_id", "trade_requests", ["requester_id"], unique=False)
    op.create_index("ix_trade_requests_owner_id", "trade_requests", ["owner_id"], unique=False)
    op.create_index("ix_trade_requests_trade_offer_id", "trade_requests", ["trade_offer_id"], unique=False)
    op.create_index("ix_trade_requests_status", "trade_requests", ["status"], unique=False)
    op.create_index(
        "uq_trade_request_pending",
        "trade_requests",
        ["requester_id", "trade_offer_id"],
        unique=True,
        sqlite_where=PENDING,
        postgresql_where=PENDING,
    )


def downgrade() -> None:
    """Supprime les tables d'échange et les réglages associés."""
    op.drop_index("uq_trade_request_pending", table_name="trade_requests")
    op.drop_index("ix_trade_requests_status", table_name="trade_requests")
    op.drop_index("ix_trade_requests_trade_offer_id", table_name="trade_requests")
    op.drop_index("ix_trade_requests_owner_id", table_name="trade_requests")
    op.drop_index("ix_trade_requests_requester_id", table_name="trade_requests")
    op.drop_table("trade_requests")
    op.drop_index("ix_trade_offers_user_id", table_name="trade_offers")
    op.drop_table("trade_offers")
    with op.batch_alter_table("users", schema=None) as batch_op:
        batch_op.drop_column("notify_trades")
        batch_op.drop_column("trade_contact")
        batch_op.drop_column("trade_zone")
        batch_op.drop_column("trade_enabled")
