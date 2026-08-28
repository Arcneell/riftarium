"""Profils publics, hauts faits et amis.

- users : quatre réglages de confidentialité du profil public. Stats et
  collection masquées par défaut (server_default false), decks publics et hauts
  faits visibles (server_default true) — c'est le comportement décrit dans
  docs/profils-et-hauts-faits.md pour les comptes existants comme pour les neufs.
- achievements : un haut fait débloqué (clé du catalogue, date, valeur atteinte),
  unique par (compte, clé) et supprimé avec le compte.
- follows : suivi unilatéral, unique par paire, avec un contrôle SQL interdisant
  de se suivre soi-même (l'API répond 409 avant d'en arriver là).

Écrite à la main (pas d'autogenerate).

Revision ID: 0010
Revises: 0009
Create Date: 2026-08-28
"""

import sqlalchemy as sa
from alembic import op

# Identifiants de révision utilisés par Alembic.
revision = "0010"
down_revision = "0009"
branch_labels = None
depends_on = None


def upgrade() -> None:
    """Ajoute les réglages de confidentialité et les tables achievements / follows."""
    with op.batch_alter_table("users", schema=None) as batch_op:
        batch_op.add_column(sa.Column("show_stats", sa.Boolean(), nullable=False, server_default=sa.false()))
        batch_op.add_column(sa.Column("show_collection", sa.Boolean(), nullable=False, server_default=sa.false()))
        batch_op.add_column(sa.Column("show_decks", sa.Boolean(), nullable=False, server_default=sa.true()))
        batch_op.add_column(sa.Column("show_achievements", sa.Boolean(), nullable=False, server_default=sa.true()))

    op.create_table(
        "achievements",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("key", sa.String(length=64), nullable=False),
        sa.Column("unlocked_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("progress", sa.Integer(), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("user_id", "key", name="uq_achievement_user_key"),
    )
    op.create_index("ix_achievements_user_id", "achievements", ["user_id"], unique=False)
    op.create_index("ix_achievements_key", "achievements", ["key"], unique=False)

    op.create_table(
        "follows",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("follower_id", sa.Integer(), nullable=False),
        sa.Column("followed_id", sa.Integer(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["follower_id"], ["users.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["followed_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("follower_id", "followed_id", name="uq_follow_pair"),
        sa.CheckConstraint("follower_id <> followed_id", name="ck_follow_not_self"),
    )
    op.create_index("ix_follows_follower_id", "follows", ["follower_id"], unique=False)
    op.create_index("ix_follows_followed_id", "follows", ["followed_id"], unique=False)


def downgrade() -> None:
    """Supprime les tables follows / achievements et les réglages de confidentialité."""
    op.drop_index("ix_follows_followed_id", table_name="follows")
    op.drop_index("ix_follows_follower_id", table_name="follows")
    op.drop_table("follows")
    op.drop_index("ix_achievements_key", table_name="achievements")
    op.drop_index("ix_achievements_user_id", table_name="achievements")
    op.drop_table("achievements")
    with op.batch_alter_table("users", schema=None) as batch_op:
        batch_op.drop_column("show_achievements")
        batch_op.drop_column("show_decks")
        batch_op.drop_column("show_collection")
        batch_op.drop_column("show_stats")
