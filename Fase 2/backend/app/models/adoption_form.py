from datetime import datetime
from typing import Any

from sqlalchemy import JSON, Boolean, DateTime, ForeignKey, Integer, String, func
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class AdoptionFormQuestion(Base):
    """Pregunta del formulario de requisitos que cada fundación configura (HU-G3)."""

    __tablename__ = "adoption_form_questions"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    foundation_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("foundations.id", ondelete="CASCADE"), nullable=False, index=True
    )
    position: Mapped[int] = mapped_column(Integer, nullable=False)
    label: Mapped[str] = mapped_column(String(200), nullable=False)
    # text | yes_no | choice
    kind: Mapped[str] = mapped_column(String(10), nullable=False)
    # Solo para choice: las alternativas, en orden
    options: Mapped[list[str] | None] = mapped_column(JSON, nullable=True)
    required: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)


class AdoptionFormRequest(Base):
    """Formulario enviado por chat. Guarda una copia de las preguntas al enviarlo, así editar el
    formulario después no cambia lo que ya se envió, y las respuestas quedan tal como llegaron."""

    __tablename__ = "adoption_form_requests"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    conversation_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("conversations.id", ondelete="CASCADE"), nullable=False, index=True
    )
    questions: Mapped[list[dict[str, Any]]] = mapped_column(JSON, nullable=False)
    answers: Mapped[list[Any] | None] = mapped_column(JSON, nullable=True)
    answered_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)
