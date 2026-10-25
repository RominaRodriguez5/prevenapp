"""Esquemas del calendario, guardias, historial e incentivos."""
from datetime import date

from pydantic import BaseModel

from app.schemas.actividad import ActividadLeer


class GuardiaMarcar(BaseModel):
    guardia: bool
    # Solo para administradores: marcar la guardia de otro técnico
    tecnico_id: int | None = None


class GuardiaLeer(BaseModel):
    tecnico_id: int
    fecha: date
    guardia: bool


class Agenda(BaseModel):
    desde: date
    hasta: date
    guardias: list[date]
    actividades: list[ActividadLeer]


class MesHistorial(BaseModel):
    mes: int
    realizadas_como_redactor: int
    captadas: int
    actividades: list[ActividadLeer]


class Historial(BaseModel):
    tecnico_id: int
    anio: int
    meses: list[MesHistorial]


class ParteIncentivo(BaseModel):
    numero: int
    total: float


class Incentivos(BaseModel):
    tecnico_id: int
    tecnico_nombre: str
    anio: int
    cuatrimestre: int
    desde: date
    hasta: date
    como_captador: ParteIncentivo
    como_redactor: ParteIncentivo
    total: float
    actividades: list[ActividadLeer]


class ResumenIncentivoTecnico(BaseModel):
    tecnico_id: int
    tecnico_nombre: str
    como_captador: ParteIncentivo
    como_redactor: ParteIncentivo
    total: float
