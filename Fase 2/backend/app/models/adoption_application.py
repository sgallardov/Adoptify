from datetime import datetime
from typing import Any

from sqlalchemy import DateTime, ForeignKey, Integer, JSON, String, Text, UniqueConstraint, func
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class AdoptionApplication(Base):
    """Postulación privada de un adoptante a un animal concreto.

    Los datos del hogar se guardan como una copia para que una modificación
    posterior del perfil no cambie una postulación que la fundación ya revisó.
    """

    __tablename__ = "adoption_applications"
    __table_args__ = (UniqueConstraint("animal_id", "adopter_id", name="uq_adoption_application_animal_adopter"),)

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    animal_id: Mapped[int] = mapped_column(Integer, ForeignKey("animals.id", ondelete="CASCADE"), nullable=False, index=True)
    foundation_id: Mapped[int] = mapped_column(Integer, ForeignKey("foundations.id", ondelete="CASCADE"), nullable=False, index=True)
    adopter_id: Mapped[int] = mapped_column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    # submitted -> reviewing -> invited_to_chat. La adopción definitiva se gestiona aparte.
    status: Mapped[str] = mapped_column(String(30), nullable=False, default="submitted", index=True)
    profile_snapshot: Mapped[dict[str, Any]] = mapped_column(JSON, nullable=False)
    message: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False)
