"""add_abandoned_dog_reports

Revision ID: 0003
Revises: 74255429a3a5
Create Date: 2026-10-27 12:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
import geoalchemy2


# revision identifiers, used by Alembic.
revision: str = '0003'
down_revision: Union[str, Sequence[str], None] = '74255429a3a5'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    # GeoAlchemy2 crea automáticamente el índice espacial GiST idx_abandoned_dog_reports_location
    op.create_table('abandoned_dog_reports',
    sa.Column('id', sa.Integer(), autoincrement=True, nullable=False),
    sa.Column('reporter_id', sa.Integer(), nullable=True),
    sa.Column('description', sa.Text(), nullable=False),
    sa.Column('photo_url', sa.String(length=500), nullable=True),
    sa.Column('status', sa.String(length=50), nullable=False),
    sa.Column('location', geoalchemy2.types.Geometry(geometry_type='POINT', srid=4326, dimension=2, from_text='ST_GeomFromEWKT', name='geometry'), nullable=False),
    sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
    sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
    sa.ForeignKeyConstraint(['reporter_id'], ['users.id'], ondelete='SET NULL'),
    sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_abandoned_dog_reports_reporter_id'), 'abandoned_dog_reports', ['reporter_id'], unique=False)


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_index(op.f('ix_abandoned_dog_reports_reporter_id'), table_name='abandoned_dog_reports')
    op.drop_table('abandoned_dog_reports')
