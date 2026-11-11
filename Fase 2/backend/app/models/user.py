from datetime import datetime
from typing import Optional, Dict, Any
from sqlalchemy import Boolean, String, Integer, DateTime, ForeignKey, func, JSON, Text
from sqlalchemy.orm import Mapped, mapped_column
from app.core.rut_crypto import decrypt_rut, encrypt_rut, hash_rut
from app.db.base import Base

class User(Base):
    """
    Modelo de usuario del sistema (adoptantes, administradores y personal de fundaciones).
    """
    __tablename__ = "users"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    email: Mapped[str] = mapped_column(String(255), unique=True, index=True, nullable=False)
    # RUT cifrado (HU-E): nunca en texto plano. Se asigna y se lee con la propiedad `rut` de abajo;
    # para buscar por RUT se compara User.rut_hash con hash_rut(valor).
    rut_hash: Mapped[str] = mapped_column(String(64), unique=True, index=True, nullable=False)
    rut_encrypted: Mapped[str] = mapped_column(Text, nullable=False)
    hashed_password: Mapped[str] = mapped_column(String(255), nullable=False)
    full_name: Mapped[str] = mapped_column(String(255), nullable=False)
    phone: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    role: Mapped[str] = mapped_column(String(50), default="adopter", nullable=False)  # 'adopter', 'admin', 'foundation'

    # Fundación a la que pertenece una cuenta con rol 'foundation' (HU-12); None para adopter y admin
    foundation_id: Mapped[Optional[int]] = mapped_column(
        Integer, ForeignKey("foundations.id", ondelete="SET NULL"), nullable=True, index=True
    )

    # Preferencias del adoptante para el motor de match (HU-05)
    preferences: Mapped[Optional[Dict[str, Any]]] = mapped_column(JSON, nullable=True, default=dict)

    # Verificación en dos pasos por correo (HU-I): opcional, se activa desde el Perfil confirmando un código
    two_factor_enabled: Mapped[bool] = mapped_column(Boolean, default=False, server_default="false", nullable=False)

    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False)

    @property
    def rut(self) -> str:
        """RUT normalizado ('12345678-5'), descifrado solo cuando se lee (por ejemplo en /auth/me)."""
        return decrypt_rut(self.rut_encrypted)

    @rut.setter
    def rut(self, value: str) -> None:
        self.rut_hash = hash_rut(value)
        self.rut_encrypted = encrypt_rut(value)

    def __repr__(self) -> str:
        return f"<User(id={self.id}, email='{self.email}', role='{self.role}')>"
