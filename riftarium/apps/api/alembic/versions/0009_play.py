"""Suivi des matchs : salons, sièges, matchs et participations.

- rooms : salon de partie suivie (code à 6 caractères, hôte, mode, statut,
  expiration à 2 h, version pour le polling). `match_id` et `host_id` sont de
  simples entiers : le premier éviterait sinon un cycle avec `matches.room_id`,
  le second doit survivre à la suppression du compte hôte.
- room_players : les deux sièges (0 hôte, 1 invité) avec légende, deck et « prêt ».
- matches : le match lui-même, son instantané de compteur (`state`), son
  résultat (`result`) et sa version.
- match_players : la participation d'un joueur (légende, deck, score, manches,
  confirmation). Supprimée avec le compte, le match restant anonymisé.

Écrite à la main (pas d'autogenerate).

Revision ID: 0009
Revises: 0008
Create Date: 2026-08-28
"""

import sqlalchemy as sa
from alembic import op

# Identifiants de révision utilisés par Alembic.
revision = "0009"
down_revision = "0008"
branch_labels = None
depends_on = None


def upgrade() -> None:
    """Crée les quatre tables du suivi des matchs et leurs index."""
    op.create_table(
        "rooms",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("code", sa.String(length=8), nullable=False),
        sa.Column("host_id", sa.Integer(), nullable=False),
        sa.Column("mode", sa.String(length=8), nullable=False),
        sa.Column("status", sa.String(length=16), nullable=False),
        sa.Column("match_id", sa.Integer(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("version", sa.Integer(), nullable=False),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_rooms_code", "rooms", ["code"], unique=True)
    op.create_index("ix_rooms_host_id", "rooms", ["host_id"], unique=False)

    op.create_table(
        "room_players",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("room_id", sa.Integer(), nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("seat", sa.Integer(), nullable=False),
        sa.Column("legend_card_id", sa.String(length=32), nullable=True),
        sa.Column("deck_id", sa.Integer(), nullable=True),
        sa.Column("ready", sa.Boolean(), nullable=False),
        sa.ForeignKeyConstraint(["room_id"], ["rooms.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["legend_card_id"], ["cards.id"]),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("room_id", "user_id", name="uq_room_player"),
        sa.UniqueConstraint("room_id", "seat", name="uq_room_seat"),
    )
    op.create_index("ix_room_players_room_id", "room_players", ["room_id"], unique=False)
    op.create_index("ix_room_players_user_id", "room_players", ["user_id"], unique=False)

    op.create_table(
        "matches",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("room_id", sa.Integer(), nullable=True),
        sa.Column("mode", sa.String(length=8), nullable=False),
        sa.Column("status", sa.String(length=24), nullable=False),
        sa.Column("host_id", sa.Integer(), nullable=False),
        sa.Column("first_player_id", sa.Integer(), nullable=False),
        sa.Column("started_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("ended_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("winner_user_id", sa.Integer(), nullable=True),
        sa.Column("state", sa.JSON(), nullable=False),
        sa.Column("version", sa.Integer(), nullable=False),
        sa.Column("result", sa.JSON(), nullable=True),
        sa.ForeignKeyConstraint(["room_id"], ["rooms.id"]),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_matches_room_id", "matches", ["room_id"], unique=False)
    op.create_index("ix_matches_status", "matches", ["status"], unique=False)
    op.create_index("ix_matches_host_id", "matches", ["host_id"], unique=False)

    op.create_table(
        "match_players",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("match_id", sa.Integer(), nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("seat", sa.Integer(), nullable=False),
        sa.Column("legend_card_id", sa.String(length=32), nullable=True),
        sa.Column("deck_id", sa.Integer(), nullable=True),
        sa.Column("score", sa.Integer(), nullable=False),
        sa.Column("rounds_won", sa.Integer(), nullable=False),
        sa.Column("confirmed_at", sa.DateTime(timezone=True), nullable=True),
        sa.ForeignKeyConstraint(["match_id"], ["matches.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["legend_card_id"], ["cards.id"]),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("match_id", "user_id", name="uq_match_player"),
    )
    op.create_index("ix_match_players_match_id", "match_players", ["match_id"], unique=False)
    op.create_index("ix_match_players_user_id", "match_players", ["user_id"], unique=False)


def downgrade() -> None:
    """Supprime les tables du suivi des matchs (ordre inverse des dépendances)."""
    op.drop_index("ix_match_players_user_id", table_name="match_players")
    op.drop_index("ix_match_players_match_id", table_name="match_players")
    op.drop_table("match_players")
    op.drop_index("ix_matches_host_id", table_name="matches")
    op.drop_index("ix_matches_status", table_name="matches")
    op.drop_index("ix_matches_room_id", table_name="matches")
    op.drop_table("matches")
    op.drop_index("ix_room_players_user_id", table_name="room_players")
    op.drop_index("ix_room_players_room_id", table_name="room_players")
    op.drop_table("room_players")
    op.drop_index("ix_rooms_host_id", table_name="rooms")
    op.drop_index("ix_rooms_code", table_name="rooms")
    op.drop_table("rooms")
