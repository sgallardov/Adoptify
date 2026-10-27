"""add_rut_to_users

Revision ID: 74255429a3a5
Revises: 36de03be1873
Create Date: 2026-10-26 22:30:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '74255429a3a5'
down_revision: Union[str, Sequence[str], None] = '36de03be1873'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    # 1. Se crea admitiendo NULL porque puede haber usuarios previos sin RUT
    op.add_column('users', sa.Column('rut', sa.String(length=12), nullable=True))
    # 2. A los usuarios existentes se les asigna un RUT de prueba único (formato válido: 8 dígitos, guion y dígito)
    op.execute("UPDATE users SET rut = (10000000 + id)::text || '-0' WHERE rut IS NULL")
    # 3. Desde ahora el RUT es obligatorio y no puede repetirse
    op.alter_column('users', 'rut', nullable=False)
    op.create_index(op.f('ix_users_rut'), 'users', ['rut'], unique=True)


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_index(op.f('ix_users_rut'), table_name='users')
    op.drop_column('users', 'rut')
