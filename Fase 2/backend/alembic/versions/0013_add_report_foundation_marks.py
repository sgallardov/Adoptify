"""add_report_foundation_marks

Marcas de una fundación para ver y tomar reportes. La tabla existente conserva
RLS; se reafirma para que la API pública de Supabase no exponga datos directos.
"""
from alembic import op
import sqlalchemy as sa

revision = "0013"
down_revision = "0012"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("abandoned_dog_reports", sa.Column("seen_by_foundation_id", sa.Integer(), nullable=True))
    op.add_column("abandoned_dog_reports", sa.Column("seen_at", sa.DateTime(timezone=True), nullable=True))
    op.add_column("abandoned_dog_reports", sa.Column("taken_by_foundation_id", sa.Integer(), nullable=True))
    op.add_column("abandoned_dog_reports", sa.Column("taken_at", sa.DateTime(timezone=True), nullable=True))
    op.create_foreign_key("fk_reports_seen_foundation", "abandoned_dog_reports", "foundations", ["seen_by_foundation_id"], ["id"], ondelete="SET NULL")
    op.create_foreign_key("fk_reports_taken_foundation", "abandoned_dog_reports", "foundations", ["taken_by_foundation_id"], ["id"], ondelete="SET NULL")
    op.create_index("ix_reports_seen_by_foundation", "abandoned_dog_reports", ["seen_by_foundation_id"])
    op.create_index("ix_reports_taken_by_foundation", "abandoned_dog_reports", ["taken_by_foundation_id"])
    op.execute("ALTER TABLE abandoned_dog_reports ENABLE ROW LEVEL SECURITY")


def downgrade() -> None:
    op.drop_index("ix_reports_taken_by_foundation", table_name="abandoned_dog_reports")
    op.drop_index("ix_reports_seen_by_foundation", table_name="abandoned_dog_reports")
    op.drop_constraint("fk_reports_taken_foundation", "abandoned_dog_reports", type_="foreignkey")
    op.drop_constraint("fk_reports_seen_foundation", "abandoned_dog_reports", type_="foreignkey")
    op.drop_column("abandoned_dog_reports", "taken_at")
    op.drop_column("abandoned_dog_reports", "taken_by_foundation_id")
    op.drop_column("abandoned_dog_reports", "seen_at")
    op.drop_column("abandoned_dog_reports", "seen_by_foundation_id")
