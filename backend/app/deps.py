"""Dependencias reutilizables: saber quién hace la petición y si tiene permiso."""
from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy.orm import Session

from app.core.security import leer_token
from app.database import get_db
from app.models import Rol, Usuario

# Indica a FastAPI dónde se consigue el token (lo usa también la página /docs)
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/auth/login")


def usuario_actual(token: str = Depends(oauth2_scheme), db: Session = Depends(get_db)) -> Usuario:
    """Lee el token de la petición y devuelve el usuario que ha iniciado sesión."""
    no_autorizado = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Sesión no válida o caducada",
        headers={"WWW-Authenticate": "Bearer"},
    )
    usuario_id = leer_token(token)
    if usuario_id is None:
        raise no_autorizado
    usuario = db.get(Usuario, usuario_id)
    if usuario is None or not usuario.activo:
        raise no_autorizado
    return usuario


def solo_admin(usuario: Usuario = Depends(usuario_actual)) -> Usuario:
    """Solo deja pasar a los administradores."""
    if usuario.rol != Rol.ADMIN:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Solo para administradores")
    return usuario
