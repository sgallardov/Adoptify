from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, Index, Integer, String, UniqueConstraint, func
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class Conversation(Base):
    """Chat entre una fundación y un adoptante (HU-G2).

    Hay una sola por par fundación-usuario y no depende de ningún animal: si la persona
    se interesa en otro animal de la misma fundación, se sigue en la misma conversación.
    """

    __tablename__ = "conversations"
    __table_args__ = (UniqueConstraint("foundation_id", "user_id", name="uq_conversation_foundation_user"),)

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    foundation_id: Mapped[int] = mapped_column(Integer, ForeignKey("foundations.id", ondelete="CASCADE"), nullable=False)
    user_id: Mapped[int] = mapped_column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)


class Message(Base):
    """Mensaje de una conversación. Si se borra la cuenta que lo envió, el mensaje queda sin remitente."""

    __tablename__ = "messages"
    __table_args__ = (Index("ix_messages_conversation_id_id", "conversation_id", "id"),)

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    conversation_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("conversations.id", ondelete="CASCADE"), nullable=False
    )
    sender_user_id: Mapped[int | None] = mapped_column(Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    body: Mapped[str] = mapped_column(String(1000), nullable=False)
    # text | question (pregunta automática del cuestionario) | answer (respuesta del adoptante) (HU-G3).
    # Las preguntas automáticas no tienen remitente: se muestran como de la fundación.
    kind: Mapped[str] = mapped_column(String(20), nullable=False, default="text", server_default="text")
    form_request_id: Mapped[int | None] = mapped_column(
        Integer, ForeignKey("adoption_form_requests.id", ondelete="CASCADE"), nullable=True
    )
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)
