"""Modelos (tablas) de la base de datos.

Importarlos aquí permite que Alembic los encuentre todos.
"""
from app.models.actividad import Actividad, ActividadObligatoria, EstadoActividad, TipoActividad
from app.models.aviso import Aviso
from app.models.centro import CentroTrabajo
from app.models.cliente import Cliente
from app.models.guardia import Guardia
from app.models.registro import Registro, TipoRegistro, TurnoFormacion
from app.models.usuario import Rol, Usuario

__all__ = [
    "Actividad",
    "ActividadObligatoria",
    "Aviso",
    "CentroTrabajo",
    "Cliente",
    "EstadoActividad",
    "Guardia",
    "Registro",
    "Rol",
    "TipoActividad",
    "TipoRegistro",
    "TurnoFormacion",
    "Usuario",
]
