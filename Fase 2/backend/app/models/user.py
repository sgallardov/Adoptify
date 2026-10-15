from datetime import datetime
from typing import Optional, Dict, Any
from sqlalchemy import String, Integer, DateTime, func, JSON
from sqlalchemy.orm import Mapped, mapped_column
from app.db.base import Base

class User(Base):
    """
    Modelo de usuario del sistema (adoptantes, administradores y personal de fundaciones).
    """
    __tablename__ = "users"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    email: Mapped[str] = mapped_column(String(255), unique=True, index=True, nullable=False)
    hashed_password: Mapped[str] = mapped_column(String(255), nullable=False)
    full_name: Mapped[str] = mapped_column(String(255), nullable=False)
    phone: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    role: Mapped[str] = mapped_column(String(50), default="adopter", nullable=False)  # 'adopter', 'admin', 'foundation'

    # Preferencias del adoptante para el motor de match (HU-05)
    preferences: Mapped[Optional[Dict[str, Any]]] = mapped_column(JSON, nullable=True, default=dict)

    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False)

    def __repr__(self) -> str:
        return f"<User(id={self.id}, email='{self.email}', role='{self.role}')>"
