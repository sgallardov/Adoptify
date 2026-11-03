"""add_animal_favorites

Revision ID: 0008
Revises: 0007
Create Date: 2026-11-03 10:00:00.000000

"""
from alembic import op
import sqlalchemy as sa

revision = "0008"
down_revision = "0007"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "animal_favorites",
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("animal_id", sa.Integer(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["animal_id"], ["animals.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("user_id", "animal_id"),
    )


def downgrade() -> None:
    op.drop_table("animal_favorites")
