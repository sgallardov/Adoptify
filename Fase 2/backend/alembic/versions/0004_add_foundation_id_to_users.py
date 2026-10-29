"""add_foundation_id_to_users

Revision ID: 0004
Revises: 0003
Create Date: 2026-10-28 12:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '0004'
down_revision: Union[str, Sequence[str], None] = '0003'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.add_column('users', sa.Column('foundation_id', sa.Integer(), nullable=True))
    op.create_index(op.f('ix_users_foundation_id'), 'users', ['foundation_id'], unique=False)
    op.create_foreign_key(
        'fk_users_foundation_id_foundations', 'users', 'foundations', ['foundation_id'], ['id'], ondelete='SET NULL'
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_constraint('fk_users_foundation_id_foundations', 'users', type_='foreignkey')
    op.drop_index(op.f('ix_users_foundation_id'), table_name='users')
    op.drop_column('users', 'foundation_id')
