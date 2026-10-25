"""Reglas de quién puede ver o modificar cada cosa.

- Administradores y presupuestos ven todo.
- Un técnico ve sus clientes y las actividades en las que participa (como captador o redactor).
"""
from fastapi import HTTPException, status
from sqlalchemy import or_, select

from app.models import Actividad, Cliente, Rol, Usuario


def ve_todo(usuario: Usuario) -> bool:
    return usuario.rol in (Rol.ADMIN, Rol.PRESUPUESTOS)


def comprobar_cliente(usuario: Usuario, cliente: Cliente | None) -> Cliente:
    """Devuelve el cliente si existe y el usuario puede verlo; si no, error 404."""
    if cliente is None or (not ve_todo(usuario) and cliente.tecnico_id != usuario.id):
        # 404 y no 403: así un técnico no puede averiguar qué clientes tienen los demás
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Cliente no encontrado")
    return cliente


def puede_ver_actividad(usuario: Usuario, actividad: Actividad) -> bool:
    return (
        ve_todo(usuario)
        or actividad.cliente.tecnico_id == usuario.id
        or usuario.id in (actividad.captador_id, actividad.redactor_id)
    )


def comprobar_actividad(usuario: Usuario, actividad: Actividad | None) -> Actividad:
    if actividad is None or not puede_ver_actividad(usuario, actividad):
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Actividad no encontrada")
    return actividad


def consulta_actividades_visibles(usuario: Usuario):
    """SELECT de las actividades que el usuario puede ver (para añadirle más filtros)."""
    consulta = select(Actividad).join(Cliente, Actividad.cliente_id == Cliente.id)
    if not ve_todo(usuario):
        consulta = consulta.where(
            or_(
                Cliente.tecnico_id == usuario.id,
                Actividad.captador_id == usuario.id,
                Actividad.redactor_id == usuario.id,
            )
        )
    return consulta
