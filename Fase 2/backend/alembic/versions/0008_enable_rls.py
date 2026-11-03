"""enable_rls

Revision ID: 0008
Revises: 0007
Create Date: 2026-11-03 10:00:00.000000

Supabase publica las tablas del schema public en su API REST (PostgREST) para los roles anon y
authenticated, usando la llave publishable, que es pública. Con RLS activado y sin políticas, esa API
no puede leer ni escribir nada. El backend no cambia: se conecta como dueño de las tablas y el dueño
no queda sujeto a RLS. En el Postgres local de Docker no tiene efecto visible.
"""
from typing import Sequence, Union

from alembic import op


# revision identifiers, used by Alembic.
revision: str = '0008'
down_revision: Union[str, Sequence[str], None] = '0007'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

TABLES = (
    'users', 'foundations', 'animals', 'abandoned_dog_reports',
    'report_comments', 'report_likes', 'alembic_version',
)


def upgrade() -> None:
    """Upgrade schema."""
    for table in TABLES:
        op.execute(f'ALTER TABLE {table} ENABLE ROW LEVEL SECURITY')


def downgrade() -> None:
    """Downgrade schema."""
    for table in TABLES:
        op.execute(f'ALTER TABLE {table} DISABLE ROW LEVEL SECURITY')
