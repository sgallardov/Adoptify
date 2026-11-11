"""add_foundation_members

Socios de la fundación (HU-F): registro interno con aporte privado y marca de visibilidad pública.

Revision ID: 0015
Revises: 0014
"""
from alembic import op
import sqlalchemy as sa

revision = "0015"
down_revision = "0014"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "foundation_members",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("foundation_id", sa.Integer(), nullable=False),
        sa.Column("name", sa.String(length=150), nullable=False),
        sa.Column("contribution", sa.Numeric(12, 2), nullable=True),
        sa.Column("joined_at", sa.Date(), nullable=False),
        sa.Column("is_public", sa.Boolean(), server_default="false", nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.ForeignKeyConstraint(["foundation_id"], ["foundations.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_foundation_members_foundation_id", "foundation_members", ["foundation_id"])
    # Sin RLS, la API pública de Supabase expondría el aporte (ver 0009)
    op.execute("ALTER TABLE foundation_members ENABLE ROW LEVEL SECURITY")


def downgrade() -> None:
    op.drop_index("ix_foundation_members_foundation_id", table_name="foundation_members")
    op.drop_table("foundation_members")
