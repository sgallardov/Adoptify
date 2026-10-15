from datetime import datetime
from typing import Optional, Dict, Any, TYPE_CHECKING
from sqlalchemy import String, Integer, Text, ForeignKey, DateTime, func, JSON
from sqlalchemy.orm import Mapped, mapped_column, relationship
from geoalchemy2 import Geometry
from app.db.base import Base

if TYPE_CHECKING:
    from app.models.foundation import Foundation

class Animal(Base):
    """
    Modelo de Animal rescatado en adopción.
    Incluye georreferenciación con PostGIS Geometry('POINT', srid=4326) según requerimiento de HU-04.
    """
    __tablename__ = "animals"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    foundation_id: Mapped[int] = mapped_column(
        Integer,
        ForeignKey("foundations.id", ondelete="CASCADE"),
        nullable=False,
        index=True
    )

    name: Mapped[str] = mapped_column(String(100), nullable=False, index=True)
    species: Mapped[str] = mapped_column(String(50), nullable=False)  # 'perro', 'gato'
    breed: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    age_months: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    gender: Mapped[str] = mapped_column(String(20), nullable=False)  # 'macho', 'hembra'
    size: Mapped[str] = mapped_column(String(50), nullable=False)  # 'pequeño', 'mediano', 'grande'
    energy_level: Mapped[int] = mapped_column(Integer, nullable=False, default=3)  # Escala 1 a 5
    description: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    status: Mapped[str] = mapped_column(String(50), default="available", nullable=False)  # 'available', 'adopted', 'in_process'
    photo_url: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)
    tags: Mapped[Optional[Dict[str, Any]]] = mapped_column(JSON, nullable=True, default=dict)

    # Requisito explícito de HU-04:
    # "El campo location de Animal debe ser de tipo Geometry('POINT', srid=4326) usando GeoAlchemy2."
    location = mapped_column(
        Geometry(geometry_type="POINT", srid=4326),
        nullable=True
    )

    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False)

    # Relación con la Fundación que rescató al animal
    foundation: Mapped["Foundation"] = relationship(
        "Foundation",
        back_populates="animals"
    )

    def __repr__(self) -> str:
        return f"<Animal(id={self.id}, name='{self.name}', species='{self.species}', status='{self.status}')>"
