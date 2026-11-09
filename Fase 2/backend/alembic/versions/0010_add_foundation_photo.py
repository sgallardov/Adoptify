"""add_foundation_photo

Foto de perfil de la fundación (se muestra al tocar su pin en el mapa).

Revision ID: 0010
Revises: 0009
Create Date: 2026-11-09 10:00:00.000000

"""
from alembic import op
import sqlalchemy as sa

revision = "0010"
down_revision = "0009"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("foundations", sa.Column("photo_url", sa.String(length=500), nullable=True))


def downgrade() -> None:
    op.drop_column("foundations", "photo_url")
