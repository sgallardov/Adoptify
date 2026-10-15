from datetime import datetime
from typing import Optional, List, TYPE_CHECKING
from sqlalchemy import String, Integer, Text, Boolean, DateTime, func
from sqlalchemy.orm import Mapped, mapped_column, relationship
from geoalchemy2 import Geometry
from app.db.base import Base

if TYPE_CHECKING:
    from app.models.animal import Animal

class Foundation(Base):
    """
    Modelo de Fundación / Refugio de rescate animal.
    """
    __tablename__ = "foundations"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    name: Mapped[str] = mapped_column(String(255), nullable=False)
    rut: Mapped[str] = mapped_column(String(20), unique=True, index=True, nullable=False)
    email: Mapped[str] = mapped_column(String(255), unique=True, nullable=False)
    phone: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    address: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    commune: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    city: Mapped[str] = mapped_column(String(100), default="Santiago", nullable=False)
    description: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    is_verified: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)

    # Ubicación geográfica de la sede de la fundación (SRID 4326: WGS84 GPS estándar)
    location = mapped_column(
        Geometry(geometry_type="POINT", srid=4326),
        nullable=True
    )

    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False)

    # Relación uno-a-muchos con Animales
    animals: Mapped[List["Animal"]] = relationship(
        "Animal",
        back_populates="foundation",
        cascade="all, delete-orphan",
        lazy="selectin"
    )

    def __repr__(self) -> str:
        return f"<Foundation(id={self.id}, name='{self.name}', rut='{self.rut}')>"
