"""drop_plain_user_rut (HU-E, paso 2 de 2)

Borra la columna rut en texto plano de users. Aplicar solo después de 0016 y de revisar que
registro, inicio de sesión y /auth/me funcionan con el RUT cifrado.

Revision ID: 0017
Revises: 0016
"""
from alembic import op
import sqlalchemy as sa

from app.core.rut_crypto import decrypt_rut

revision = "0017"
down_revision = "0016"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.drop_index(op.f("ix_users_rut"), table_name="users")
    op.drop_column("users", "rut")


def downgrade() -> None:
    # Vuelve a crear la columna en texto descifrando cada RUT (requiere la misma RUT_ENCRYPTION_KEY)
    op.add_column("users", sa.Column("rut", sa.String(length=12), nullable=True))
    bind = op.get_bind()
    for user_id, encrypted in bind.execute(sa.text("SELECT id, rut_encrypted FROM users")).all():
        bind.execute(sa.text("UPDATE users SET rut = :rut WHERE id = :id"), {"rut": decrypt_rut(encrypted), "id": user_id})
    op.create_index(op.f("ix_users_rut"), "users", ["rut"], unique=True)
