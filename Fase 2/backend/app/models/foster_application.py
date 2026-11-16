from datetime import datetime
from typing import TYPE_CHECKING, Optional

from sqlalchemy import DateTime, ForeignKey, Integer, String, func
from sqlalchemy.dialects.postgresql import ARRAY
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base

if TYPE_CHECKING:
    from app.models.foundation import Foundation
    from app.models.user import User


class FosterApplication(Base):
    """
    Postulación de un adoptante para ser hogar temporal (HU-B). Es general: no va dirigida a una fundación,
    y cada cuenta tiene una sola (user_id único). La dirección es privada: solo la ven las fundaciones.
    Nombre y correo no se copian aquí: se leen de la cuenta (users), así no quedan dos versiones distintas.
    """
    __tablename__ = "foster_applications"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("users.id", ondelete="CASCADE"), unique=True, index=True, nullable=False
    )
    species: Mapped[str] = mapped_column(String(10), nullable=False)  # 'perro' | 'gato' | 'ambos'
    sizes: Mapped[list[str]] = mapped_column(ARRAY(String(20)), nullable=False)  # pequeño, mediano, grande
    space: Mapped[str] = mapped_column(String(20), nullable=False)  # casa_patio | casa_sin_patio | departamento
    # Cuántos animales puede cuidar a la vez y por cuántos días como máximo
    max_animals: Mapped[int] = mapped_column(Integer, nullable=False)
    max_days: Mapped[int] = mapped_column(Integer, nullable=False)
    availability: Mapped[str] = mapped_column(String(120), nullable=False)  # texto corto: "desde ya", "fines de semana"
    phone: Mapped[str] = mapped_column(String(30), nullable=False)
    address: Mapped[str] = mapped_column(String(255), nullable=False)  # privada: solo fundaciones

    # Estado global (decisión documentada en el README): una sola decisión, y qué fundación la tomó
    status: Mapped[str] = mapped_column(String(10), default="pending", server_default="pending", nullable=False)
    decided_by_foundation_id: Mapped[Optional[int]] = mapped_column(
        Integer, ForeignKey("foundations.id", ondelete="SET NULL"), nullable=True
    )
    decided_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)

    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False
    )

    # Para el listado de las fundaciones: nombre y correo del postulante, y quién decidió
    user: Mapped["User"] = relationship("User")
    decided_by_foundation: Mapped[Optional["Foundation"]] = relationship("Foundation")

    def __repr__(self) -> str:
        return f"<FosterApplication(id={self.id}, user_id={self.user_id}, status='{self.status}')>"
