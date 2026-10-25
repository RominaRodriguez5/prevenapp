"""Centros de trabajo de una sociedad (una empresa puede tener varios: oficina, nave, tienda...).

En la app, cada sociedad es una carpeta (tabla `clientes`) y sus centros son las subcarpetas.
Cada centro es un cliente en sí: tiene su número de cliente, su CIF y su dirección.
Las actividades se hacen en un centro concreto.
"""
from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, String, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class CentroTrabajo(Base):
    __tablename__ = "centros_trabajo"

    id: Mapped[int] = mapped_column(primary_key=True)
    cliente_id: Mapped[int] = mapped_column(ForeignKey("clientes.id"), index=True)
    nombre: Mapped[str] = mapped_column(String(150))
    # Número de cliente del centro en la empresa
    codigo: Mapped[str | None] = mapped_column(String(30), index=True)
    cif: Mapped[str | None] = mapped_column(String(20))
    direccion: Mapped[str | None] = mapped_column(String(255))
    activo: Mapped[bool] = mapped_column(default=True)
    creado_en: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    cliente = relationship("Cliente", back_populates="centros")
