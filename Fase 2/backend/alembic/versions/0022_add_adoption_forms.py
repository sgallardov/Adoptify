"""add_adoption_forms

Formulario de requisitos configurable por fundación y enviado por chat (HU-G3).
Cada envío guarda una copia de las preguntas y las respuestas tal como llegaron.

Revision ID: 0022
Revises: 0021
"""
from alembic import op

revision = "0022"
down_revision = "0021"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute("""
        CREATE TABLE IF NOT EXISTS adoption_form_questions (
            id SERIAL PRIMARY KEY,
            foundation_id INTEGER NOT NULL REFERENCES foundations(id) ON DELETE CASCADE,
            position INTEGER NOT NULL,
            label VARCHAR(200) NOT NULL,
            kind VARCHAR(10) NOT NULL,
            options JSON NULL,
            required BOOLEAN NOT NULL DEFAULT true,
            CONSTRAINT ck_adoption_form_question_kind CHECK (kind IN ('text', 'yes_no', 'choice'))
        )
    """)
    op.execute("CREATE INDEX IF NOT EXISTS ix_adoption_form_questions_foundation_id ON adoption_form_questions (foundation_id)")
    op.execute("""
        CREATE TABLE IF NOT EXISTS adoption_form_requests (
            id SERIAL PRIMARY KEY,
            conversation_id INTEGER NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
            questions JSON NOT NULL,
            answers JSON NULL,
            answered_at TIMESTAMP WITH TIME ZONE NULL,
            created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
        )
    """)
    op.execute("CREATE INDEX IF NOT EXISTS ix_adoption_form_requests_conversation_id ON adoption_form_requests (conversation_id)")
    op.execute("ALTER TABLE messages ADD COLUMN IF NOT EXISTS kind VARCHAR(20) NOT NULL DEFAULT 'text'")
    op.execute(
        "ALTER TABLE messages ADD COLUMN IF NOT EXISTS form_request_id INTEGER NULL "
        "REFERENCES adoption_form_requests(id) ON DELETE CASCADE"
    )
    op.execute("""
        DO $$ BEGIN
            ALTER TABLE messages ADD CONSTRAINT ck_message_kind CHECK (kind IN ('text', 'form', 'form_answers'));
        EXCEPTION WHEN duplicate_object THEN NULL;
        END $$
    """)
    # La API pública de Supabase no debe exponer preguntas ni respuestas privadas.
    op.execute("ALTER TABLE adoption_form_questions ENABLE ROW LEVEL SECURITY")
    op.execute("ALTER TABLE adoption_form_requests ENABLE ROW LEVEL SECURITY")


def downgrade() -> None:
    op.execute("ALTER TABLE messages DROP CONSTRAINT IF EXISTS ck_message_kind")
    op.execute("ALTER TABLE messages DROP COLUMN IF EXISTS form_request_id")
    op.execute("ALTER TABLE messages DROP COLUMN IF EXISTS kind")
    op.execute("DROP TABLE IF EXISTS adoption_form_requests")
    op.execute("DROP TABLE IF EXISTS adoption_form_questions")
