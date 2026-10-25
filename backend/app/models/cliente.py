"""Tabla de clientes = sociedades (las carpetas de la app). Cada una tiene asignado un técnico
y uno o varios centros de trabajo (ver centro.py), que son los que tienen nº de cliente y CIF."""
from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, String, Text, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class Cliente(Base):
    __tablename__ = "clientes"

    id: Mapped[int] = mapped_column(primary_key=True)
    nombre: Mapped[str] = mapped_column(String(150))
    # Ya no se usan: el nº de cliente y el CIF están en cada centro (se conservan por los datos antiguos)
    codigo: Mapped[str | None] = mapped_column(String(30), index=True)
    cif: Mapped[str | None] = mapped_column(String(20))
    direccion: Mapped[str | None] = mapped_column(String(255))
    telefono: Mapped[str | None] = mapped_column(String(30))
    email: Mapped[str | None] = mapped_column(String(255))
    persona_contacto: Mapped[str | None] = mapped_column(String(100))
    notas: Mapped[str | None] = mapped_column(Text)
    # Técnico que lleva a este cliente
    tecnico_id: Mapped[int] = mapped_column(ForeignKey("usuarios.id"), index=True)
    activo: Mapped[bool] = mapped_column(default=True)
    creado_en: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    tecnico = relationship("Usuario")
    obligatorias = relationship("ActividadObligatoria", back_populates="cliente")
    centros = relationship("CentroTrabajo", back_populates="cliente", order_by="CentroTrabajo.id")
