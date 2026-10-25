"""Esquemas de clientes y de sus actividades obligatorias (contrato)."""
from pydantic import BaseModel, ConfigDict, EmailStr, Field


class ClienteCrear(BaseModel):
    """Una sociedad nueva. Con ella se crea su primer centro de trabajo."""

    nombre: str = Field(min_length=1, max_length=150)
    # Datos del primer centro (si no se indica el nombre, "Centro principal")
    centro_nombre: str | None = Field(default=None, max_length=150)
    codigo: str | None = Field(default=None, max_length=30)
    cif: str | None = None
    direccion: str | None = None
    telefono: str | None = None
    email: EmailStr | None = None
    persona_contacto: str | None = None
    notas: str | None = None
    # Solo lo usa el administrador; si crea el cliente un técnico, se le asigna a él
    tecnico_id: int | None = None


class ClienteEditar(BaseModel):
    """Todos los campos son opcionales: solo se cambian los que se envían."""

    nombre: str | None = Field(default=None, min_length=1, max_length=150)
    codigo: str | None = Field(default=None, max_length=30)
    cif: str | None = None
    direccion: str | None = None
    telefono: str | None = None
    email: EmailStr | None = None
    persona_contacto: str | None = None
    notas: str | None = None
    activo: bool | None = None
    tecnico_id: int | None = None


class ClienteLeer(BaseModel):
    id: int
    nombre: str
    codigo: str | None = None
    cif: str | None
    direccion: str | None
    telefono: str | None
    email: str | None
    persona_contacto: str | None
    notas: str | None
    tecnico_id: int
    activo: bool
    # Para la carpeta del cliente: actividades que le faltan (y cuántas de años anteriores) y hechas
    faltan: int = 0
    atrasadas: int = 0
    hechas: int = 0
    num_centros: int = 0

    model_config = ConfigDict(from_attributes=True)


class ObligatoriaCrear(BaseModel):
    tipo_actividad_id: int
    # Centro de trabajo; si no se indica, el primero del cliente
    centro_id: int | None = None
    # Si no se indica, desde el año actual
    desde_anio: int | None = None


class ObligatoriaLeer(BaseModel):
    id: int
    cliente_id: int
    centro_id: int | None = None
    centro_nombre: str | None = None
    tipo_actividad_id: int
    tipo_nombre: str
    desde_anio: int
    activa: bool


# ---------- Centros de trabajo ----------

class CentroCrear(BaseModel):
    nombre: str = Field(min_length=1, max_length=150)
    codigo: str | None = Field(default=None, max_length=30)
    cif: str | None = Field(default=None, max_length=20)
    direccion: str | None = Field(default=None, max_length=255)


class CentroEditar(BaseModel):
    nombre: str | None = Field(default=None, min_length=1, max_length=150)
    codigo: str | None = Field(default=None, max_length=30)
    cif: str | None = Field(default=None, max_length=20)
    direccion: str | None = Field(default=None, max_length=255)
    activo: bool | None = None


class CentroLeer(BaseModel):
    id: int
    cliente_id: int
    nombre: str
    codigo: str | None
    cif: str | None
    direccion: str | None
    activo: bool
    # Para la subcarpeta del centro, igual que en la del cliente
    faltan: int = 0
    atrasadas: int = 0
    hechas: int = 0

    model_config = ConfigDict(from_attributes=True)
