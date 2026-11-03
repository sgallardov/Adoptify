from datetime import datetime
from sqlalchemy import Integer, ForeignKey, DateTime, func
from sqlalchemy.orm import Mapped, mapped_column
from app.db.base import Base


class AnimalFavorite(Base):
    """Animal marcado con el corazón en el match: uno por persona (clave primaria usuario-animal)."""
    __tablename__ = "animal_favorites"

    user_id: Mapped[int] = mapped_column(Integer, ForeignKey("users.id", ondelete="CASCADE"), primary_key=True)
    animal_id: Mapped[int] = mapped_column(Integer, ForeignKey("animals.id", ondelete="CASCADE"), primary_key=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)

    def __repr__(self) -> str:
        return f"<AnimalFavorite(user_id={self.user_id}, animal_id={self.animal_id})>"
