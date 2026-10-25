"""Esquemas del registro de kilómetros y horas de formación."""
from datetime import date

from pydantic import BaseModel, ConfigDict, Field, model_validator

from app.models.registro import TipoRegistro, TurnoFormacion


class RegistroCrear(BaseModel):
    fecha: date
    tipo: TipoRegistro
    # km o horas; máximo razonable para evitar errores al escribir
    cantidad: float = Field(gt=0, le=2000)
    concepto: str | None = Field(default=None, max_length=255)
    # Obligatorio para la formación; no se usa en los km
    turno: TurnoFormacion | None = None

    @model_validator(mode="after")
    def comprobar_turno(self):
        if self.tipo == TipoRegistro.FORMACION and self.turno is None:
            raise ValueError("Indica el turno de la formación")
        if self.tipo == TipoRegistro.KILOMETROS:
            self.turno = None
        return self


class RegistroLeer(BaseModel):
    id: int
    fecha: date
    tipo: TipoRegistro
    cantidad: float
    concepto: str | None
    turno: TurnoFormacion | None = None
    actividad_id: int | None = None

    model_config = ConfigDict(from_attributes=True)


class RegistroMes(BaseModel):
    tecnico_id: int
    tecnico_nombre: str
    anio: int
    mes: int
    total_km: float
    total_horas_formacion: float
    # Horas de formación por turno: {"manana": 3, "tarde": 0, "extra_manana": 2, "extra_tarde": 0}
    horas_por_turno: dict[str, float]
    dias_con_registro: int
    registros: list[RegistroLeer]
