from datetime import datetime
from typing import Optional
from sqlalchemy import String, Integer, ForeignKey, DateTime, Index, func
from sqlalchemy.orm import Mapped, mapped_column
from app.db.base import Base


class ReportComment(Base):
    """
    Comentario anónimo en un reporte: los vecinos se avisan si lo vieron, si alguien va en camino, etc.
    Se guarda el autor solo para saber cuáles son "tuyos"; la API nunca lo expone.
    Si se borra el reporte, se borran sus comentarios.
    """
    __tablename__ = "report_comments"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    report_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("abandoned_dog_reports.id", ondelete="CASCADE"), nullable=False
    )
    # Si se elimina la cuenta, el comentario queda sin autor
    author_id: Mapped[Optional[int]] = mapped_column(
        Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    # Texto corto (máx. 500): así cada comentario pesa menos de 1 KB en la BD
    body: Mapped[str] = mapped_column(String(500), nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)

    # Los comentarios se leen siempre por reporte y en orden de llegada
    __table_args__ = (Index("ix_report_comments_report_id_created_at", "report_id", "created_at"),)

    def __repr__(self) -> str:
        return f"<ReportComment(id={self.id}, report_id={self.report_id})>"


class ReportLike(Base):
    """
    "Me enteré" de un usuario en un reporte: uno por persona (la clave primaria es el par reporte-usuario).
    """
    __tablename__ = "report_likes"

    report_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("abandoned_dog_reports.id", ondelete="CASCADE"), primary_key=True
    )
    user_id: Mapped[int] = mapped_column(Integer, ForeignKey("users.id", ondelete="CASCADE"), primary_key=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)

    def __repr__(self) -> str:
        return f"<ReportLike(report_id={self.report_id}, user_id={self.user_id})>"
