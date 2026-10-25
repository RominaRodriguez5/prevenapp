"""Registro de los avisos por email enviados (para saber qué se envió y si falló)."""
from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, String, Text, func
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class Aviso(Base):
    __tablename__ = "avisos"

    id: Mapped[int] = mapped_column(primary_key=True)
    actividad_id: Mapped[int] = mapped_column(ForeignKey("actividades.id"), index=True)
    destinatarios: Mapped[str] = mapped_column(Text)
    asunto: Mapped[str] = mapped_column(String(255))
    cuerpo: Mapped[str] = mapped_column(Text)
    enviado: Mapped[bool] = mapped_column(default=False)
    error: Mapped[str | None] = mapped_column(Text)
    creado_en: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
