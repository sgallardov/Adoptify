from datetime import datetime
from typing import Optional

from geoalchemy2 import Geometry
from geoalchemy2.shape import to_shape
from sqlalchemy import Boolean, DateTime, Integer, String, func
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class VeterinaryClinic(Base):
    """
    Clínica veterinaria para emergencias, importada de OpenStreetMap (amenity=veterinary) con
    app/db/import_vet_clinics.py. osm_id permite volver a importar sin duplicar.
    """
    __tablename__ = "veterinary_clinics"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    # "node/123" o "way/456": identifica el elemento en OpenStreetMap
    osm_id: Mapped[str] = mapped_column(String(40), unique=True, nullable=False)
    name: Mapped[str] = mapped_column(String(255), nullable=False)
    address: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    commune: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    phone: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    opening_hours: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    # Atiende urgencias o está abierta las 24 horas (emergency=yes u opening_hours=24/7)
    emergency: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    location = mapped_column(Geometry(geometry_type="POINT", srid=4326), nullable=False)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False
    )

    @property
    def latitude(self) -> float:
        return to_shape(self.location).y

    @property
    def longitude(self) -> float:
        return to_shape(self.location).x

    def __repr__(self) -> str:
        return f"<VeterinaryClinic(id={self.id}, name='{self.name}')>"
