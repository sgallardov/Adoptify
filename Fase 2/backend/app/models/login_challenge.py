from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, Integer, String, func
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class LoginChallenge(Base):
    """
    Código de verificación enviado al correo (HU-I). Sirve para iniciar sesión con la verificación en
    dos pasos activa ('login') o para confirmar que el correo recibe códigos antes de activarla ('enable').
    El código nunca se guarda: solo su HMAC-SHA256 (services/two_factor.py). Se borra al usarse, al
    vencer o al agotar los intentos.
    """
    __tablename__ = "login_challenges"

    # UUID aleatorio: es lo único que conoce el cliente entre el login y el código
    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    user_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    purpose: Mapped[str] = mapped_column(String(20), nullable=False)  # 'login' | 'enable'
    code_hash: Mapped[str] = mapped_column(String(64), nullable=False)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    attempts: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    # Para limitar "Reenviar código" a uno cada LOGIN_CODE_RESEND_SECONDS
    last_sent_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)

    def __repr__(self) -> str:
        return f"<LoginChallenge(id={self.id}, user_id={self.user_id}, purpose='{self.purpose}')>"
