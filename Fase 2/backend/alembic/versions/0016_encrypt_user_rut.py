"""encrypt_user_rut (HU-E, paso 1 de 2)

Agrega rut_hash y rut_encrypted a users, los llena desde el RUT en texto (backfill) y deja la
columna rut como opcional: el código nuevo ya no la escribe. La columna se borra en 0017,
después de revisar que el backfill quedó bien. Aplicar por separado: `alembic upgrade 0016`.

Necesita RUT_ENCRYPTION_KEY y RUT_HASH_KEY en el .env (con la BD compartida no acepta las de
desarrollo). Si la clave de cifrado se pierde, los RUT no se pueden recuperar.

Revision ID: 0016
Revises: 0015
"""
from alembic import op
import sqlalchemy as sa

from app.core.rut import normalize_rut
from app.core.rut_crypto import decrypt_rut, encrypt_rut, hash_rut

revision = "0016"
down_revision = "0015"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("users", sa.Column("rut_hash", sa.String(length=64), nullable=True))
    op.add_column("users", sa.Column("rut_encrypted", sa.Text(), nullable=True))

    bind = op.get_bind()
    rows = bind.execute(sa.text("SELECT id, rut FROM users WHERE rut IS NOT NULL")).all()
    for user_id, rut in rows:
        bind.execute(
            sa.text("UPDATE users SET rut_hash = :hash, rut_encrypted = :encrypted WHERE id = :id"),
            {"hash": hash_rut(rut), "encrypted": encrypt_rut(rut), "id": user_id},
        )

    # Comprobar el backfill antes de exigir las columnas: cada cifrado debe volver al RUT original.
    # Se compara con el RUT normalizado: alguno pudo cargarse a mano con puntos o con k minúscula
    # (12.345.678-k), y queda guardado como 12345678-K, igual que lo haría el registro.
    for user_id, rut, encrypted in bind.execute(sa.text("SELECT id, rut, rut_encrypted FROM users")).all():
        if encrypted is None or decrypt_rut(encrypted) != normalize_rut(rut):
            raise RuntimeError(f"El backfill del RUT falló en el usuario {user_id}; no se aplicó ningún cambio")

    op.alter_column("users", "rut_hash", nullable=False)
    op.alter_column("users", "rut_encrypted", nullable=False)
    op.create_index(op.f("ix_users_rut_hash"), "users", ["rut_hash"], unique=True)
    op.alter_column("users", "rut", existing_type=sa.String(length=12), nullable=True)


def downgrade() -> None:
    # Los usuarios creados después de 0016 no tienen RUT en texto: se recupera descifrando
    bind = op.get_bind()
    rows = bind.execute(sa.text("SELECT id, rut_encrypted FROM users WHERE rut IS NULL")).all()
    for user_id, encrypted in rows:
        bind.execute(sa.text("UPDATE users SET rut = :rut WHERE id = :id"), {"rut": decrypt_rut(encrypted), "id": user_id})
    op.alter_column("users", "rut", existing_type=sa.String(length=12), nullable=False)
    op.drop_index(op.f("ix_users_rut_hash"), table_name="users")
    op.drop_column("users", "rut_encrypted")
    op.drop_column("users", "rut_hash")
