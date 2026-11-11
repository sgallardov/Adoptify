"""drop_plain_user_rut (HU-E, paso 2 de 2)

Borra la columna rut en texto plano de users. Aplicar solo después de 0016 y de revisar que
registro, inicio de sesión y /auth/me funcionan con el RUT cifrado.

Revision ID: 0017
Revises: 0016
"""
from alembic import op
import sqlalchemy as sa

from app.core.rut import normalize_rut
from app.core.rut_crypto import decrypt_rut

revision = "0017"
down_revision = "0016"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Candado: solo se borra el RUT en texto si cada usuario ya lo tiene cifrado y se descifra igual.
    # Protege la BD compartida si la versión dice 0016 sin haber corrido el cifrado (por ejemplo,
    # si otra migración usó el mismo número): en ese caso no cambia nada y avisa.
    bind = op.get_bind()
    columns = set(bind.execute(sa.text(
        "SELECT column_name FROM information_schema.columns WHERE table_schema = current_schema() AND table_name = 'users'"
    )).scalars())
    if not {"rut", "rut_hash", "rut_encrypted"} <= columns:
        raise RuntimeError(
            "No se borra users.rut: faltan rut_hash o rut_encrypted, así que el cifrado (0016) no se aplicó. "
            "Revisar alembic_version antes de seguir."
        )
    for user_id, rut, encrypted in bind.execute(sa.text("SELECT id, rut, rut_encrypted FROM users")).all():
        if encrypted is None or (rut is not None and decrypt_rut(encrypted) != normalize_rut(rut)):
            raise RuntimeError(f"No se borra users.rut: el usuario {user_id} no tiene su RUT cifrado correctamente")

    op.drop_index(op.f("ix_users_rut"), table_name="users")
    op.drop_column("users", "rut")


def downgrade() -> None:
    # Vuelve a crear la columna en texto descifrando cada RUT (requiere la misma RUT_ENCRYPTION_KEY)
    op.add_column("users", sa.Column("rut", sa.String(length=12), nullable=True))
    bind = op.get_bind()
    for user_id, encrypted in bind.execute(sa.text("SELECT id, rut_encrypted FROM users")).all():
        bind.execute(sa.text("UPDATE users SET rut = :rut WHERE id = :id"), {"rut": decrypt_rut(encrypted), "id": user_id})
    op.create_index(op.f("ix_users_rut"), "users", ["rut"], unique=True)
