"""Comuna pública opcional, independiente de la ubicación privada del animal."""
from alembic import op
import sqlalchemy as sa

revision = "0007"
down_revision = "0006"
branch_labels = None
depends_on = None


def upgrade():
    op.add_column("animals", sa.Column("public_commune", sa.String(100), nullable=True))


def downgrade():
    op.drop_column("animals", "public_commune")
