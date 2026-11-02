"""add_details_to_reports

Revision ID: 0005
Revises: 0004
Create Date: 2026-11-02 12:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '0005'
down_revision: Union[str, Sequence[str], None] = '0004'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

COLUMNS = (
    ('species', sa.String(length=20)),
    ('size', sa.String(length=20)),
    ('weight_kg', sa.Float()),
    ('color', sa.String(length=60)),
    ('features', sa.String(length=300)),
    ('condition', sa.String(length=20)),
    ('behavior', sa.String(length=20)),
)


def upgrade() -> None:
    """Upgrade schema."""
    # Opcionales en la BD: los reportes existentes no tienen estos datos
    for name, type_ in COLUMNS:
        op.add_column('abandoned_dog_reports', sa.Column(name, type_, nullable=True))


def downgrade() -> None:
    """Downgrade schema."""
    for name, _ in reversed(COLUMNS):
        op.drop_column('abandoned_dog_reports', name)
