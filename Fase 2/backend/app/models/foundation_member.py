from datetime import date, datetime
from decimal import Decimal
from typing import Optional
from sqlalchemy import Boolean, Date, DateTime, ForeignKey, Integer, Numeric, String, func
from sqlalchemy.orm import Mapped, mapped_column
from app.db.base import Base


class FoundationMember(Base):
    """Socio de una fundación (HU-F). Registro interno: el aporte nunca se expone públicamente."""
    __tablename__ = "foundation_members"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    foundation_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("foundations.id", ondelete="CASCADE"), index=True, nullable=False
    )
    name: Mapped[str] = mapped_column(String(150), nullable=False)
    # Solo informativo, de uso interno: no hay pasarela ni cobros
    contribution: Mapped[Optional[Decimal]] = mapped_column(Numeric(12, 2), nullable=True)
    joined_at: Mapped[date] = mapped_column(Date, nullable=False)
    is_public: Mapped[bool] = mapped_column(Boolean, default=False, server_default="false", nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)

    def __repr__(self) -> str:
        return f"<FoundationMember(id={self.id}, foundation_id={self.foundation_id})>"
