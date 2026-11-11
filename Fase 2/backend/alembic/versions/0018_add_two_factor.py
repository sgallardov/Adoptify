"""add_two_factor

Verificación en dos pasos por correo (HU-I): users.two_factor_enabled y tabla login_challenges con el
hash del código, su vencimiento y los intentos.

Idempotente (IF NOT EXISTS): en la BD compartida estas tablas ya se crearon cuando esta migración se
llamaba 0016, antes de renombrarla para ir después del RUT cifrado (0016 y 0017, HU-E).

Revision ID: 0018
Revises: 0017
"""
from alembic import op

revision = "0018"
down_revision = "0017"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute("ALTER TABLE users ADD COLUMN IF NOT EXISTS two_factor_enabled BOOLEAN NOT NULL DEFAULT false")
    op.execute(
        """
        CREATE TABLE IF NOT EXISTS login_challenges (
            id VARCHAR(36) PRIMARY KEY,
            user_id INTEGER NOT NULL REFERENCES users (id) ON DELETE CASCADE,
            purpose VARCHAR(20) NOT NULL,
            code_hash VARCHAR(64) NOT NULL,
            expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
            attempts INTEGER NOT NULL DEFAULT 0,
            last_sent_at TIMESTAMP WITH TIME ZONE NOT NULL,
            created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
        )
        """
    )
    op.execute("CREATE INDEX IF NOT EXISTS ix_login_challenges_user_id ON login_challenges (user_id)")
    # Sin RLS, la API pública de Supabase expondría los hashes de los códigos (ver 0009)
    op.execute("ALTER TABLE login_challenges ENABLE ROW LEVEL SECURITY")


def downgrade() -> None:
    op.execute("DROP TABLE IF EXISTS login_challenges")
    op.execute("ALTER TABLE users DROP COLUMN IF EXISTS two_factor_enabled")
