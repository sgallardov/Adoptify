"""add_adoption_applications

Postulaciones privadas de adoptantes. Los favoritos permanecen como interés
general; solo una postulación se entrega a la fundación como candidatura.

Revision ID: 0020
Revises: 0019
"""
from alembic import op

revision = "0020"
down_revision = "0019"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute("""
        CREATE TABLE IF NOT EXISTS adoption_applications (
            id SERIAL PRIMARY KEY,
            animal_id INTEGER NOT NULL REFERENCES animals(id) ON DELETE CASCADE,
            foundation_id INTEGER NOT NULL REFERENCES foundations(id) ON DELETE CASCADE,
            adopter_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            status VARCHAR(30) NOT NULL DEFAULT 'submitted',
            profile_snapshot JSON NOT NULL,
            message TEXT NULL,
            created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
            updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
            CONSTRAINT uq_adoption_application_animal_adopter UNIQUE (animal_id, adopter_id),
            CONSTRAINT ck_adoption_application_status CHECK (status IN ('submitted', 'reviewing', 'invited_to_chat', 'rejected', 'withdrawn', 'approved'))
        )
    """)
    op.execute("CREATE INDEX IF NOT EXISTS ix_adoption_applications_foundation_id ON adoption_applications (foundation_id)")
    op.execute("CREATE INDEX IF NOT EXISTS ix_adoption_applications_adopter_id ON adoption_applications (adopter_id)")
    op.execute("CREATE INDEX IF NOT EXISTS ix_adoption_applications_animal_id ON adoption_applications (animal_id)")
    # La API pública de Supabase no debe exponer perfiles ni mensajes de postulaciones.
    op.execute("ALTER TABLE adoption_applications ENABLE ROW LEVEL SECURITY")


def downgrade() -> None:
    op.execute("DROP TABLE IF EXISTS adoption_applications")
