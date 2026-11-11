"""add_two_factor

Verificación en dos pasos por correo (HU-I): users.two_factor_enabled y tabla login_challenges con el
hash del código, su vencimiento y los intentos.

Revision ID: 0016
Revises: 0015
"""
from alembic import op
import sqlalchemy as sa

revision = "0016"
down_revision = "0015"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "users",
        sa.Column("two_factor_enabled", sa.Boolean(), server_default=sa.text("false"), nullable=False),
    )
    op.create_table(
        "login_challenges",
        sa.Column("id", sa.String(length=36), nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("purpose", sa.String(length=20), nullable=False),
        sa.Column("code_hash", sa.String(length=64), nullable=False),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("attempts", sa.Integer(), server_default=sa.text("0"), nullable=False),
        sa.Column("last_sent_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_login_challenges_user_id"), "login_challenges", ["user_id"], unique=False)
    # Sin RLS, la API pública de Supabase expondría los hashes de los códigos (ver 0009)
    op.execute("ALTER TABLE login_challenges ENABLE ROW LEVEL SECURITY")


def downgrade() -> None:
    op.drop_index(op.f("ix_login_challenges_user_id"), table_name="login_challenges")
    op.drop_table("login_challenges")
    op.drop_column("users", "two_factor_enabled")
