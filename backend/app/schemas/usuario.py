"""Esquemas: definen qué datos entran y salen de la API (validación con Pydantic).

Son distintos de los modelos: por ejemplo, la contraseña entra al crear un usuario,
pero nunca sale en ninguna respuesta.
"""
from pydantic import BaseModel, ConfigDict, EmailStr, Field

from app.models.usuario import Rol


class UsuarioCrear(BaseModel):
    nombre: str = Field(min_length=1, max_length=100)
    email: EmailStr
    password: str = Field(min_length=8)
    rol: Rol = Rol.TECNICO


class UsuarioLeer(BaseModel):
    id: int
    nombre: str
    email: EmailStr
    rol: Rol
    activo: bool

    model_config = ConfigDict(from_attributes=True)


class TecnicoLeer(BaseModel):
    id: int
    nombre: str

    model_config = ConfigDict(from_attributes=True)


class Token(BaseModel):
    access_token: str
    token_type: str = "bearer"
