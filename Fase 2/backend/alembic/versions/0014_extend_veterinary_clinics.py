"""extend veterinary clinics for HU-D

Revision ID: 0014
Revises: 0013
Create Date: 2026-11-10 00:00:00.000000
"""

from alembic import op
import sqlalchemy as sa


revision = "0014"
down_revision = "0013"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Las filas existentes vienen del importador de OpenStreetMap.
    op.alter_column("veterinary_clinics", "osm_id", existing_type=sa.String(length=40), nullable=True)
    op.add_column(
        "veterinary_clinics",
        sa.Column("source", sa.String(length=20), nullable=False, server_default="manual"),
    )
    op.add_column(
        "veterinary_clinics",
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.true()),
    )
    op.add_column(
        "veterinary_clinics",
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("now()")),
    )
    op.execute("UPDATE veterinary_clinics SET source = 'importacion'")
    op.create_check_constraint(
        "ck_veterinary_clinics_source",
        "veterinary_clinics",
        "source IN ('manual', 'importacion', 'fundacion')",
    )
    # La tabla ya tenía RLS desde 0011; se declara de nuevo para que la migración sea autónoma.
    op.execute("ALTER TABLE veterinary_clinics ENABLE ROW LEVEL SECURITY")


def downgrade() -> None:
    op.drop_constraint("ck_veterinary_clinics_source", "veterinary_clinics", type_="check")
    op.drop_column("veterinary_clinics", "created_at")
    op.drop_column("veterinary_clinics", "is_active")
    op.drop_column("veterinary_clinics", "source")
    op.alter_column("veterinary_clinics", "osm_id", existing_type=sa.String(length=40), nullable=False)
