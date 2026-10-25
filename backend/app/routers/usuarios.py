"""Rutas para gestionar usuarios (solo administradores)."""
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.security import hashear_password
from app.database import get_db
from app.deps import solo_admin, usuario_actual
from app.models import Rol, Usuario
from app.schemas.usuario import TecnicoLeer, UsuarioCrear, UsuarioLeer

router = APIRouter(prefix="/usuarios", tags=["Usuarios"], dependencies=[Depends(solo_admin)])


@router.get("", response_model=list[UsuarioLeer])
def listar_usuarios(db: Session = Depends(get_db)):
    """Lista todos los usuarios."""
    return db.scalars(select(Usuario).order_by(Usuario.nombre)).all()


@router.post("", response_model=UsuarioLeer, status_code=status.HTTP_201_CREATED)
def crear_usuario(datos: UsuarioCrear, db: Session = Depends(get_db)):
    """Da de alta un usuario nuevo (técnico, presupuestos o admin)."""
    email = datos.email.lower()
    if db.scalar(select(Usuario).where(Usuario.email == email)):
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Ya existe un usuario con ese email")
    usuario = Usuario(
        nombre=datos.nombre,
        email=email,
        password_hash=hashear_password(datos.password),
        rol=datos.rol,
    )
    db.add(usuario)
    db.commit()
    db.refresh(usuario)
    return usuario


# Lista de técnicos para elegir captador y redactor: la puede ver cualquier usuario
router_tecnicos = APIRouter(prefix="/tecnicos", tags=["Usuarios"], dependencies=[Depends(usuario_actual)])


@router_tecnicos.get("", response_model=list[TecnicoLeer])
def listar_tecnicos(db: Session = Depends(get_db)):
    """Técnicos activos (solo id y nombre)."""
    return db.scalars(
        select(Usuario).where(Usuario.rol == Rol.TECNICO, Usuario.activo.is_(True)).order_by(Usuario.nombre)
    ).all()
