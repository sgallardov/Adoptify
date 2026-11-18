"""add_conversations

Chat entre una fundación y un adoptante (HU-G2). Una sola conversación por par
fundación-usuario, sin relación con un animal. Los mensajes se borran con la conversación.

Revision ID: 0021
Revises: 0020
"""
from alembic import op

revision = "0021"
down_revision = "0020"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute("""
        CREATE TABLE IF NOT EXISTS conversations (
            id SERIAL PRIMARY KEY,
            foundation_id INTEGER NOT NULL REFERENCES foundations(id) ON DELETE CASCADE,
            user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
            CONSTRAINT uq_conversation_foundation_user UNIQUE (foundation_id, user_id)
        )
    """)
    op.execute("CREATE INDEX IF NOT EXISTS ix_conversations_user_id ON conversations (user_id)")
    op.execute("""
        CREATE TABLE IF NOT EXISTS messages (
            id SERIAL PRIMARY KEY,
            conversation_id INTEGER NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
            sender_user_id INTEGER NULL REFERENCES users(id) ON DELETE SET NULL,
            body VARCHAR(1000) NOT NULL,
            created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
        )
    """)
    op.execute("CREATE INDEX IF NOT EXISTS ix_messages_conversation_id_id ON messages (conversation_id, id)")
    # La API pública de Supabase no debe exponer conversaciones ni mensajes privados.
    op.execute("ALTER TABLE conversations ENABLE ROW LEVEL SECURITY")
    op.execute("ALTER TABLE messages ENABLE ROW LEVEL SECURITY")


def downgrade() -> None:
    op.execute("DROP TABLE IF EXISTS messages")
    op.execute("DROP TABLE IF EXISTS conversations")
