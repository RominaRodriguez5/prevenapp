"""Registro de la jornada: kilómetros recorridos y horas de formación.

Son datos que los técnicos entregan cada mes. Un día puede tener varios registros
(por ejemplo, dos desplazamientos distintos). Se pueden apuntar a mano o al hacer
el check de una actividad; en ese caso quedan enlazados a la actividad.
"""
import enum
from datetime import date, datetime
from decimal import Decimal

from sqlalchemy import Date, DateTime, Enum, ForeignKey, Numeric, String, func
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class TipoRegistro(str, enum.Enum):
    KILOMETROS = "kilometros"   # cantidad = km recorridos
    FORMACION = "formacion"     # cantidad = horas de formación


class TurnoFormacion(str, enum.Enum):
    """Turno de la formación. Los "extra" son los que se hacen fuera de lunes a viernes."""

    MANANA = "manana"
    TARDE = "tarde"
    EXTRA_MANANA = "extra_manana"
    EXTRA_TARDE = "extra_tarde"


class Registro(Base):
    __tablename__ = "registros"

    id: Mapped[int] = mapped_column(primary_key=True)
    tecnico_id: Mapped[int] = mapped_column(ForeignKey("usuarios.id"), index=True)
    fecha: Mapped[date] = mapped_column(Date, index=True)
    tipo: Mapped[TipoRegistro] = mapped_column(Enum(TipoRegistro, native_enum=False, length=20))
    cantidad: Mapped[Decimal] = mapped_column(Numeric(8, 2))
    # Por ejemplo: "Palma → Inca (Talleres Ramírez)" o "Curso de primeros auxilios"
    concepto: Mapped[str | None] = mapped_column(String(255))
    # Solo para la formación
    turno: Mapped[TurnoFormacion | None] = mapped_column(Enum(TurnoFormacion, native_enum=False, length=20))
    # Si se apuntó al hacer el check, la actividad de la que viene (si se deshace el check, se borra)
    actividad_id: Mapped[int | None] = mapped_column(ForeignKey("actividades.id"), index=True)
    creado_en: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
