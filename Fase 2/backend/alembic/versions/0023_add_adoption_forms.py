"""add_adoption_forms

Cuestionario de adopción (HU-G3): cada fundación tiene sus preguntas (o las sugeridas por
Adoptify) y, al abrir el chat con un interesado desde "Conversar", la persona las responde
una a una en el chat. Las respuestas quedan en una postulación que la fundación acepta o rechaza.

Idempotente: la primera versión de HU-G3 (enviar el formulario completo por el chat) ya se
aplicó en la BD compartida, así que aquí se crean las tablas si faltan y se agregan las
columnas nuevas si no están.

Revision ID: 0023
Revises: 0022
"""
from alembic import op

revision = "0023"
down_revision = "0022"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # La fundación pasa a usar sus propias preguntas cuando guarda el editor; antes usa las sugeridas
    op.execute(
        "ALTER TABLE foundations ADD COLUMN IF NOT EXISTS adoption_form_customized BOOLEAN NOT NULL DEFAULT false"
    )

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
    # Respuestas que se marcan como "No cumple" en la postulación (por ejemplo, "No" en "¿Eres mayor de 18?")
    op.execute("ALTER TABLE adoption_form_questions ADD COLUMN IF NOT EXISTS flagged_answers JSON NULL")

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

    # Formularios de la primera versión (sin mascota): sus mensajes quedan como texto y se descartan
    op.execute("ALTER TABLE messages DROP CONSTRAINT IF EXISTS ck_message_kind")
    op.execute("""
        DO $$ BEGIN
            IF EXISTS (SELECT 1 FROM information_schema.columns
                       WHERE table_name = 'adoption_form_requests' AND column_name = 'animal_id') THEN
                RETURN;
            END IF;
            UPDATE messages SET kind = 'text', form_request_id = NULL WHERE form_request_id IS NOT NULL;
            DELETE FROM adoption_form_requests;
        END $$
    """)

    # Una postulación por persona y mascota: "Conversar" no repite el cuestionario
    op.execute("ALTER TABLE adoption_form_requests ADD COLUMN IF NOT EXISTS animal_id INTEGER REFERENCES animals(id) ON DELETE CASCADE")
    op.execute("ALTER TABLE adoption_form_requests ALTER COLUMN animal_id SET NOT NULL")
    op.execute("UPDATE adoption_form_requests SET answers = '[]' WHERE answers IS NULL")
    op.execute("ALTER TABLE adoption_form_requests ALTER COLUMN answers SET DEFAULT '[]'")
    op.execute("ALTER TABLE adoption_form_requests ALTER COLUMN answers SET NOT NULL")
    op.execute("ALTER TABLE adoption_form_requests ADD COLUMN IF NOT EXISTS decision VARCHAR(10) NULL")
    op.execute("ALTER TABLE adoption_form_requests ADD COLUMN IF NOT EXISTS decided_at TIMESTAMP WITH TIME ZONE NULL")
    op.execute("""
        DO $$ BEGIN
            ALTER TABLE adoption_form_requests
                ADD CONSTRAINT ck_adoption_form_request_decision CHECK (decision IN ('accepted', 'rejected'));
        EXCEPTION WHEN duplicate_object THEN NULL;
        END $$
    """)
    op.execute("""
        DO $$ BEGIN
            ALTER TABLE adoption_form_requests
                ADD CONSTRAINT uq_adoption_form_request_conversation_animal UNIQUE (conversation_id, animal_id);
        EXCEPTION WHEN duplicate_table OR duplicate_object THEN NULL;
        END $$
    """)
    op.execute("CREATE INDEX IF NOT EXISTS ix_adoption_form_requests_animal_id ON adoption_form_requests (animal_id)")

    # question: pregunta automática; answer: respuesta del adoptante a esa pregunta
    op.execute("ALTER TABLE messages ADD CONSTRAINT ck_message_kind CHECK (kind IN ('text', 'question', 'answer'))")

    # La API pública de Supabase no debe exponer preguntas ni respuestas privadas.
    op.execute("ALTER TABLE adoption_form_questions ENABLE ROW LEVEL SECURITY")
    op.execute("ALTER TABLE adoption_form_requests ENABLE ROW LEVEL SECURITY")


def downgrade() -> None:
    op.execute("ALTER TABLE messages DROP CONSTRAINT IF EXISTS ck_message_kind")
    op.execute("ALTER TABLE messages DROP COLUMN IF EXISTS form_request_id")
    op.execute("ALTER TABLE messages DROP COLUMN IF EXISTS kind")
    op.execute("DROP TABLE IF EXISTS adoption_form_requests")
    op.execute("DROP TABLE IF EXISTS adoption_form_questions")
    op.execute("ALTER TABLE foundations DROP COLUMN IF EXISTS adoption_form_customized")
