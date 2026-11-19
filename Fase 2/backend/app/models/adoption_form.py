from datetime import datetime
from typing import Any

from sqlalchemy import JSON, Boolean, DateTime, ForeignKey, Integer, String, UniqueConstraint, func
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class AdoptionFormQuestion(Base):
    """Pregunta del cuestionario de adopción que una fundación configuró (HU-G3).

    Mientras la fundación no guarde el editor, se usan las preguntas sugeridas
    (services/adoption_questionnaire.py) y esta tabla no tiene filas suyas.
    """

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
    # Respuestas que se marcan como "No cumple" al revisar la postulación (false, o una alternativa)
    flagged_answers: Mapped[list[Any] | None] = mapped_column(JSON, nullable=True)


class AdoptionFormRequest(Base):
    """Postulación por cuestionario: una por persona y mascota, dentro de su conversación.

    Guarda una copia de las preguntas al empezar (editar el cuestionario después no la cambia).
    El adoptante responde una pregunta a la vez en el chat; answers crece hasta tener una por
    pregunta (answered_at marca que terminó). Después la fundación la acepta o la rechaza.
    """

    __tablename__ = "adoption_form_requests"
    __table_args__ = (
        UniqueConstraint("conversation_id", "animal_id", name="uq_adoption_form_request_conversation_animal"),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    conversation_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("conversations.id", ondelete="CASCADE"), nullable=False, index=True
    )
    animal_id: Mapped[int] = mapped_column(Integer, ForeignKey("animals.id", ondelete="CASCADE"), nullable=False, index=True)
    questions: Mapped[list[dict[str, Any]]] = mapped_column(JSON, nullable=False)
    answers: Mapped[list[Any]] = mapped_column(JSON, nullable=False, default=list)
    answered_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    # accepted | rejected; null mientras la fundación no decide
    decision: Mapped[str | None] = mapped_column(String(10), nullable=True)
    decided_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)

    @property
    def completed(self) -> bool:
        return self.answered_at is not None
