from datetime import datetime
from typing import Optional
from sqlalchemy import String, Integer, Text, ForeignKey, DateTime, func
from sqlalchemy.orm import Mapped, mapped_column
from geoalchemy2 import Geometry
from geoalchemy2.shape import to_shape
from app.db.base import Base


class AbandonedDogReport(Base):
    """
    Reporte de un perro abandonado hecho por un usuario.
    La ubicación es la del perro (no la de quien reporta) y se guarda como Geometry('POINT', srid=4326).
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
