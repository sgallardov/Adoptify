"""add_report_comments_and_likes

Revision ID: 0006
Revises: 0005
Create Date: 2026-11-02 21:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '0006'
down_revision: Union[str, Sequence[str], None] = '0005'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.create_table('report_comments',
    sa.Column('id', sa.Integer(), autoincrement=True, nullable=False),
    sa.Column('report_id', sa.Integer(), nullable=False),
    sa.Column('author_id', sa.Integer(), nullable=True),
    sa.Column('body', sa.String(length=500), nullable=False),
    sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
    sa.ForeignKeyConstraint(['report_id'], ['abandoned_dog_reports.id'], ondelete='CASCADE'),
    sa.ForeignKeyConstraint(['author_id'], ['users.id'], ondelete='SET NULL'),
    sa.PrimaryKeyConstraint('id')
    )
    op.create_index('ix_report_comments_report_id_created_at', 'report_comments', ['report_id', 'created_at'], unique=False)

    # Un "me enteré" por persona y reporte
    op.create_table('report_likes',
    sa.Column('report_id', sa.Integer(), nullable=False),
    sa.Column('user_id', sa.Integer(), nullable=False),
    sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
    sa.ForeignKeyConstraint(['report_id'], ['abandoned_dog_reports.id'], ondelete='CASCADE'),
    sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
    sa.PrimaryKeyConstraint('report_id', 'user_id')
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_table('report_likes')
    op.drop_index('ix_report_comments_report_id_created_at', table_name='report_comments')
    op.drop_table('report_comments')
