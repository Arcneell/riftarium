"""Schéma initial (baseline).

Schéma complet au moment de l'adoption d'Alembic : reflète exactement
app/models.py de l'époque. Les bases créées avant Alembic (create_all +
ensure_schema) ont déjà ce schéma : run_migrations() les « stampe » à cette
révision sans la rejouer.

Revision ID: 0001
Revises:
Create Date: 2026-08-19
"""

import sqlalchemy as sa
from alembic import op

# Identifiants de révision utilisés par Alembic.
revision = "0001"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    """Crée toutes les tables, index et contraintes (SQLite et Postgres)."""
    op.create_table(
        "sets",
        sa.Column("set_id", sa.String(length=8), nullable=False),
        sa.Column("name", sa.String(length=64), nullable=False),
        sa.Column("card_count", sa.Integer(), nullable=False),
        sa.Column("published_on", sa.String(length=32), nullable=True),
        sa.PrimaryKeyConstraint("set_id"),
    )

    op.create_table(
        "users",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("handle", sa.String(length=32), nullable=False),
        sa.Column("email", sa.String(length=255), nullable=False),
        sa.Column("password_hash", sa.String(length=255), nullable=False),
        sa.Column("bio", sa.String(length=280), nullable=False),
        sa.Column("avatar_card_id", sa.String(length=32), nullable=True),
        sa.Column("token_version", sa.Integer(), nullable=False),
        sa.Column("email_verified_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_users_email", "users", ["email"], unique=True)
    op.create_index("ix_users_handle", "users", ["handle"], unique=True)

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

    op.create_table(
        "cards",
        sa.Column("id", sa.String(length=32), nullable=False),
        sa.Column("riftbound_id", sa.String(length=32), nullable=False),
        sa.Column("name", sa.String(length=128), nullable=False),
        sa.Column("collector_number", sa.Integer(), nullable=True),
        sa.Column("set_id", sa.String(length=8), nullable=False),
        sa.Column("type", sa.String(length=24), nullable=False),
        sa.Column("supertype", sa.String(length=24), nullable=True),
        sa.Column("rarity", sa.String(length=24), nullable=True),
        sa.Column("domains", sa.JSON(), nullable=False),
        sa.Column("energy", sa.Integer(), nullable=True),
        sa.Column("might", sa.Integer(), nullable=True),
        sa.Column("power", sa.Integer(), nullable=True),
        sa.Column("text_plain", sa.Text(), nullable=True),
        sa.Column("text_flavour", sa.Text(), nullable=True),
        sa.Column("image_url", sa.String(length=512), nullable=True),
        sa.Column("artist", sa.String(length=128), nullable=True),
        sa.Column("orientation", sa.String(length=16), nullable=True),
        sa.Column("tags", sa.JSON(), nullable=False),
        sa.Column("alternate_art", sa.Boolean(), nullable=False),
        sa.Column("signature", sa.Boolean(), nullable=False),
        sa.Column("overnumbered", sa.Boolean(), nullable=False),
        sa.Column("updated_on", sa.String(length=40), nullable=True),
        sa.ForeignKeyConstraint(["set_id"], ["sets.set_id"]),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_cards_name", "cards", ["name"], unique=False)
    op.create_index("ix_cards_rarity", "cards", ["rarity"], unique=False)
    op.create_index("ix_cards_riftbound_id", "cards", ["riftbound_id"], unique=False)
    op.create_index("ix_cards_set_id", "cards", ["set_id"], unique=False)
    op.create_index("ix_cards_type", "cards", ["type"], unique=False)

    op.create_table(
        "decks",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("owner_id", sa.Integer(), nullable=False),
        sa.Column("name", sa.String(length=80), nullable=False),
        sa.Column("description", sa.Text(), nullable=False),
        sa.Column("format", sa.String(length=16), nullable=False),
        sa.Column("is_public", sa.Boolean(), nullable=False),
        sa.Column("moderation_status", sa.String(length=16), nullable=False),
        sa.Column("likes_count", sa.Integer(), nullable=False),
        sa.Column("views_count", sa.Integer(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["owner_id"], ["users.id"]),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_decks_owner_id", "decks", ["owner_id"], unique=False)
    op.create_index("ix_decks_public_moderation", "decks", ["is_public", "moderation_status"], unique=False)

    op.create_table(
        "collection_items",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("card_id", sa.String(length=32), nullable=False),
        sa.Column("qty", sa.Integer(), nullable=False),
        sa.Column("condition", sa.String(length=8), nullable=False),
        sa.Column("lang", sa.String(length=8), nullable=False),
        sa.ForeignKeyConstraint(["card_id"], ["cards.id"]),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"]),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("user_id", "card_id", "condition", "lang", name="uq_collection_entry"),
    )
    op.create_index("ix_collection_items_card_id", "collection_items", ["card_id"], unique=False)
    op.create_index("ix_collection_items_user_id", "collection_items", ["user_id"], unique=False)

    op.create_table(
        "deck_cards",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("deck_id", sa.Integer(), nullable=False),
        sa.Column("card_id", sa.String(length=32), nullable=False),
        sa.Column("qty", sa.Integer(), nullable=False),
        sa.ForeignKeyConstraint(["card_id"], ["cards.id"]),
        sa.ForeignKeyConstraint(["deck_id"], ["decks.id"]),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("deck_id", "card_id", name="uq_deck_card"),
    )
    op.create_index("ix_deck_cards_card_id", "deck_cards", ["card_id"], unique=False)
    op.create_index("ix_deck_cards_deck_id", "deck_cards", ["deck_id"], unique=False)

    op.create_table(
        "deck_likes",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("deck_id", sa.Integer(), nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.ForeignKeyConstraint(["deck_id"], ["decks.id"]),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"]),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("deck_id", "user_id", name="uq_deck_like"),
    )
    op.create_index("ix_deck_likes_deck_id", "deck_likes", ["deck_id"], unique=False)
    op.create_index("ix_deck_likes_user_id", "deck_likes", ["user_id"], unique=False)

    op.create_table(
        "deck_views",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("deck_id", sa.Integer(), nullable=False),
        sa.Column("visitor_key", sa.String(length=40), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["deck_id"], ["decks.id"]),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("deck_id", "visitor_key", name="uq_deck_view"),
    )
    op.create_index("ix_deck_views_deck_id", "deck_views", ["deck_id"], unique=False)
    op.create_index("ix_deck_views_visitor_key", "deck_views", ["visitor_key"], unique=False)


def downgrade() -> None:
    """Supprime tout le schéma (les index partent avec leurs tables)."""
    op.drop_table("deck_views")
    op.drop_table("deck_likes")
    op.drop_table("deck_cards")
    op.drop_table("collection_items")
    op.drop_table("decks")
    op.drop_table("cards")
    op.drop_table("auth_tokens")
    op.drop_table("users")
    op.drop_table("sets")
