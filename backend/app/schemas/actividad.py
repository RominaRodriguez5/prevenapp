"""Esquemas de tipos de actividad y actividades."""
from datetime import date, time

from pydantic import BaseModel, ConfigDict, Field

from app.models.actividad import EstadoActividad
from app.models.registro import TurnoFormacion


class TipoActividadCrear(BaseModel):
    nombre: str = Field(min_length=1, max_length=150)
    descripcion: str | None = None
    # Porcentaje del importe del presupuesto (sin IVA). Por defecto, un 8 %.
    porcentaje_captador: float = Field(default=8, ge=0, le=100)
    porcentaje_redactor: float = Field(default=8, ge=0, le=100)


class TipoActividadEditar(BaseModel):
    nombre: str | None = Field(default=None, min_length=1, max_length=150)
    descripcion: str | None = None
    porcentaje_captador: float | None = Field(default=None, ge=0, le=100)
    porcentaje_redactor: float | None = Field(default=None, ge=0, le=100)
    activo: bool | None = None


class TipoActividadLeer(BaseModel):
    id: int
    nombre: str
    descripcion: str | None
    porcentaje_captador: float
    porcentaje_redactor: float
    activo: bool

    model_config = ConfigDict(from_attributes=True)


class ActividadCrear(BaseModel):
    """Para añadir una actividad extra (no incluida en el contrato)."""

    cliente_id: int
    # Centro de trabajo; si no se indica, el primero del cliente
    centro_id: int | None = None
    tipo_actividad_id: int
    anio: int | None = None
    fecha_programada: date | None = None
    hora_programada: time | None = None
    lugar: str | None = Field(default=None, max_length=255)
    captador_id: int | None = None
    redactor_id: int | None = None
    notas: str | None = None


class ActividadEditar(BaseModel):
    # Centro de trabajo (de la misma sociedad) donde se hará la visita
    centro_id: int | None = None
    fecha_programada: date | None = None
    hora_programada: time | None = None
    lugar: str | None = Field(default=None, max_length=255)
    captador_id: int | None = None
    redactor_id: int | None = None
    notas: str | None = None


class ActividadRealizar(BaseModel):
    """Lo único que tiene que rellenar el técnico al hacer el check."""

    codigo_presupuesto: str = Field(min_length=1, max_length=50)
    fecha_realizacion: date
    # Importe del presupuesto sin IVA, para calcular el incentivo
    importe_presupuesto: float = Field(gt=0)
    # Opcionales: si no se indican, se usan los que ya tenga la actividad
    # (o, por defecto, el técnico del cliente como captador y quien hace el check como redactor)
    captador_id: int | None = None
    redactor_id: int | None = None
    # Opcionales: se apuntan en el registro del día (km recorridos y horas de formación)
    km: float | None = Field(default=None, gt=0, le=2000)
    horas_formacion: float | None = Field(default=None, gt=0, le=24)
    # Turno de la formación; si no se indica, se deduce del día (fin de semana = extra)
    turno_formacion: TurnoFormacion | None = None


class ActividadLeer(BaseModel):
    id: int
    cliente_id: int
    cliente_nombre: str
    # Dirección a la que hay que ir: la del centro (o, si no tiene, la del cliente)
    cliente_direccion: str | None
    centro_id: int | None = None
    centro_nombre: str | None = None
    centro_codigo: str | None = None
    tipo_actividad_id: int
    tipo_nombre: str
    anio: int
    obligatoria: bool
    estado: EstadoActividad
    fecha_programada: date | None
    hora_programada: time | None
    lugar: str | None
    fecha_realizacion: date | None
    codigo_presupuesto: str | None
    importe_presupuesto: float | None
    captador_id: int | None
    captador_nombre: str | None
    redactor_id: int | None
    redactor_nombre: str | None
    importe_captador: float | None
    importe_redactor: float | None
    notas: str | None
    # True si es de un año anterior y sigue sin hacerse
    atrasada: bool = False


class Pendientes(BaseModel):
    anio_actual: int
    primer_anio_en_plazo: int
    total: int
    del_anio_actual: int
    de_anios_anteriores: int
    actividades: list[ActividadLeer]
    clientes_sin_visitar_anio_anterior: list[str]
