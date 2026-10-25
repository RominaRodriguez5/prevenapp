"""Tablas de actividades.

- TipoActividad: catálogo (p. ej. "Evaluación de riesgos") con el % de incentivo de cada rol.
- ActividadObligatoria: qué actividades incluye el contrato de un cliente cada año.
- Actividad: cada actividad concreta que hay que hacer (o se ha hecho) en un año.
"""
import enum
from datetime import date, datetime, time
from decimal import Decimal

from sqlalchemy import Date, DateTime, Enum, ForeignKey, Numeric, String, Text, Time, UniqueConstraint, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class TipoActividad(Base):
    __tablename__ = "tipos_actividad"

    id: Mapped[int] = mapped_column(primary_key=True)
    nombre: Mapped[str] = mapped_column(String(150), unique=True)
    descripcion: Mapped[str | None] = mapped_column(Text)
    # Porcentaje del importe del presupuesto (sin IVA) que cobra cada técnico
    porcentaje_captador: Mapped[Decimal] = mapped_column(Numeric(5, 2), default=Decimal("8"))
    porcentaje_redactor: Mapped[Decimal] = mapped_column(Numeric(5, 2), default=Decimal("8"))
    activo: Mapped[bool] = mapped_column(default=True)


class ActividadObligatoria(Base):
    """Una línea del contrato: "este cliente necesita esta actividad cada año"."""

    __tablename__ = "actividades_obligatorias"
    # Cada centro de trabajo tiene su propio contrato: la misma actividad puede estar en varios centros
    __table_args__ = (UniqueConstraint("centro_id", "tipo_actividad_id", name="uq_obligatoria_centro_tipo"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    cliente_id: Mapped[int] = mapped_column(ForeignKey("clientes.id"), index=True)
    centro_id: Mapped[int | None] = mapped_column(ForeignKey("centros_trabajo.id"), index=True)
    tipo_actividad_id: Mapped[int] = mapped_column(ForeignKey("tipos_actividad.id"))
    # Desde qué año entra en el contrato
    desde_anio: Mapped[int]
    activa: Mapped[bool] = mapped_column(default=True)

    cliente = relationship("Cliente", back_populates="obligatorias")
    centro = relationship("CentroTrabajo")
    tipo = relationship("TipoActividad")


class EstadoActividad(str, enum.Enum):
    PENDIENTE = "pendiente"      # hay que hacerla y aún no tiene fecha
    PROGRAMADA = "programada"    # tiene fecha en el calendario
    REALIZADA = "realizada"      # el técnico ha hecho el check


class Actividad(Base):
    __tablename__ = "actividades"

    id: Mapped[int] = mapped_column(primary_key=True)
    cliente_id: Mapped[int] = mapped_column(ForeignKey("clientes.id"), index=True)
    # Centro de trabajo del cliente donde se hace la actividad (se puede cambiar al programar la visita)
    centro_id: Mapped[int | None] = mapped_column(ForeignKey("centros_trabajo.id"), index=True)
    # Línea del contrato de la que sale (solo las obligatorias). Así, aunque se cambie el centro,
    # se sabe que la actividad de ese año ya existe y no se vuelve a crear.
    linea_id: Mapped[int | None] = mapped_column(ForeignKey("actividades_obligatorias.id"), index=True)
    tipo_actividad_id: Mapped[int] = mapped_column(ForeignKey("tipos_actividad.id"))
    # Año al que corresponde la actividad (importante para saber si está pendiente de años anteriores)
    anio: Mapped[int] = mapped_column(index=True)
    # True si viene del contrato; False si es una actividad extra
    obligatoria: Mapped[bool] = mapped_column(default=False)
    estado: Mapped[EstadoActividad] = mapped_column(
        Enum(EstadoActividad, native_enum=False, length=20), default=EstadoActividad.PENDIENTE, index=True
    )
    fecha_programada: Mapped[date | None] = mapped_column(Date)
    hora_programada: Mapped[time | None] = mapped_column(Time)
    # Dirección o zona a la que tiene que desplazarse el técnico (por defecto, la del cliente)
    lugar: Mapped[str | None] = mapped_column(String(255))
    fecha_realizacion: Mapped[date | None] = mapped_column(Date, index=True)
    codigo_presupuesto: Mapped[str | None] = mapped_column(String(50))
    # Importe del presupuesto sin IVA: sobre él se calculan los incentivos
    importe_presupuesto: Mapped[Decimal | None] = mapped_column(Numeric(10, 2))
    # Captador: quien consigue la actividad. Redactor: quien la realiza.
    captador_id: Mapped[int | None] = mapped_column(ForeignKey("usuarios.id"))
    redactor_id: Mapped[int | None] = mapped_column(ForeignKey("usuarios.id"))
    # Importes del incentivo calculados al marcarla como realizada, para que el histórico
    # no cambie aunque más adelante se modifique el porcentaje del tipo de actividad.
    importe_captador: Mapped[Decimal | None] = mapped_column(Numeric(10, 2))
    importe_redactor: Mapped[Decimal | None] = mapped_column(Numeric(10, 2))
    notas: Mapped[str | None] = mapped_column(Text)
    realizada_en: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    creado_en: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    cliente = relationship("Cliente")
    centro = relationship("CentroTrabajo")
    tipo = relationship("TipoActividad")
    captador = relationship("Usuario", foreign_keys=[captador_id])
    redactor = relationship("Usuario", foreign_keys=[redactor_id])
