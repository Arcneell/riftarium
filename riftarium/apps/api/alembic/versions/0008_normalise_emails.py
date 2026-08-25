"""Normalise les adresses e-mail existantes en minuscules.

L'unicité des comptes et l'attribution du drapeau admin comparent désormais les
e-mails en minuscules (schemas.NormEmail). Les lignes créées avant cette bascule
peuvent contenir des majuscules : on les aligne pour éviter deux comptes distincts
« Foo@x.com » / « foo@x.com », dont l'un pourrait hériter des droits admin.

Un conflit (deux comptes ne différant que par la casse) ferait échouer la mise à
jour sur la contrainte d'unicité : c'est volontaire — il doit être tranché à la
main avant de rejouer la migration.

Revision ID: 0008
Revises: 0007
Create Date: 2026-08-25
"""

from alembic import op

# Identifiants de révision utilisés par Alembic.
revision = "0008"
down_revision = "0007"
branch_labels = None
depends_on = None


def upgrade() -> None:
    """Passe en minuscules toute adresse e-mail qui n'y est pas déjà."""
    op.execute("UPDATE users SET email = lower(email) WHERE email <> lower(email)")


def downgrade() -> None:
    """La casse d'origine est perdue : rien à restaurer (no-op)."""
