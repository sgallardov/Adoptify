from datetime import datetime
from typing import Optional
from sqlalchemy import String, Integer, Float, Text, ForeignKey, DateTime, func
from sqlalchemy.dialects.postgresql import ARRAY
from sqlalchemy.orm import Mapped, mapped_column
from geoalchemy2 import Geometry
from geoalchemy2.shape import to_shape
from app.db.base import Base


class AbandonedDogReport(Base):
    """
    Reporte de una mascota abandonada hecho por un usuario (la tabla conserva su nombre original).
    La ubicación es la del animal (no la de quien reporta) y se guarda como Geometry('POINT', srid=4326).
    """
    __tablename__ = "abandoned_dog_reports"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    # Si se elimina la cuenta del usuario, el reporte se mantiene sin autor
    reporter_id: Mapped[Optional[int]] = mapped_column(
        Integer,
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
        index=True
    )

    # Ficha del animal. Son opcionales en la BD porque los reportes anteriores no los tenían;
    # la API los exige al crear (ver ReportCreate)
    species: Mapped[Optional[str]] = mapped_column(String(20), nullable=True)  # 'perro', 'gato', 'otro'
    size: Mapped[Optional[str]] = mapped_column(String(20), nullable=True)  # 'pequeño', 'mediano', 'grande'
    weight_kg: Mapped[Optional[float]] = mapped_column(Float, nullable=True)  # Peso aproximado
    color: Mapped[Optional[str]] = mapped_column(String(60), nullable=True)
    features: Mapped[Optional[str]] = mapped_column(String(300), nullable=True)  # Collar, manchas, raza aparente...
    # Puede tener varios: 'bien' (solo), 'desnutrido', 'herido', 'enfermo', 'deplorable'
    conditions: Mapped[Optional[list[str]]] = mapped_column(ARRAY(String(20)), nullable=True)
    # Puede tener varios: 'tranquilo', 'asustado', 'agresivo'
    behaviors: Mapped[Optional[list[str]]] = mapped_column(ARRAY(String(20)), nullable=True)

    # Comentarios de quien reporta sobre la situación
    description: Mapped[str] = mapped_column(Text, nullable=False)
    photo_url: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)
    status: Mapped[str] = mapped_column(String(50), default="reported", nullable=False)  # 'reported', 'in_rescue', 'resolved'

    location = mapped_column(
        Geometry(geometry_type="POINT", srid=4326),
        nullable=False
    )

    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False)

    # Coordenadas legibles para la API y el mapa (PostGIS guarda el punto como (longitud, latitud))
    @property
    def latitude(self) -> float:
        return to_shape(self.location).y

    @property
    def longitude(self) -> float:
        return to_shape(self.location).x

    def __repr__(self) -> str:
        return f"<AbandonedDogReport(id={self.id}, status='{self.status}')>"
