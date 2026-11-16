"""add_foster_applications

Postulaciones a hogar temporal (HU-B): una por cuenta de adoptante, general (sin fundación) y con estado
global. La dirección es privada: la ven solo las fundaciones.

Revision ID: 0019
Revises: 0018
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import ARRAY

revision = "0019"
down_revision = "0018"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "foster_applications",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("species", sa.String(length=10), nullable=False),
        sa.Column("sizes", ARRAY(sa.String(length=20)), nullable=False),
        sa.Column("space", sa.String(length=20), nullable=False),
        sa.Column("max_animals", sa.Integer(), nullable=False),
        sa.Column("max_days", sa.Integer(), nullable=False),
        sa.Column("availability", sa.String(length=120), nullable=False),
        sa.Column("phone", sa.String(length=30), nullable=False),
        sa.Column("address", sa.String(length=255), nullable=False),
        sa.Column("status", sa.String(length=10), server_default="pending", nullable=False),
        sa.Column("decided_by_foundation_id", sa.Integer(), nullable=True),
        sa.Column("decided_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["decided_by_foundation_id"], ["foundations.id"], ondelete="SET NULL"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_foster_applications_user_id", "foster_applications", ["user_id"], unique=True)
    # Sin RLS, la API pública de Supabase expondría direcciones y teléfonos (ver 0009)
    op.execute("ALTER TABLE foster_applications ENABLE ROW LEVEL SECURITY")


def downgrade() -> None:
    op.drop_index("ix_foster_applications_user_id", table_name="foster_applications")
    op.drop_table("foster_applications")
