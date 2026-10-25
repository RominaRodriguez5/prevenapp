"""Rutas de inicio de sesión."""
from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.security import crear_token, verificar_password
from app.database import get_db
from app.deps import usuario_actual
from app.models import Usuario
from app.schemas.usuario import Token, UsuarioLeer

router = APIRouter(prefix="/auth", tags=["Inicio de sesión"])


@router.post("/login", response_model=Token)
def login(form: OAuth2PasswordRequestForm = Depends(), db: Session = Depends(get_db)):
    """Inicia sesión con email y contraseña y devuelve un token.

    En el formulario, el campo "username" es el email.
    """
    usuario = db.scalar(select(Usuario).where(Usuario.email == form.username.lower()))
    if usuario is None or not usuario.activo or not verificar_password(form.password, usuario.password_hash):
        # Mismo mensaje en todos los casos, para no dar pistas de qué emails existen
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Email o contraseña incorrectos")
    return Token(access_token=crear_token(usuario.id))


@router.get("/yo", response_model=UsuarioLeer)
def quien_soy(usuario: Usuario = Depends(usuario_actual)):
    """Devuelve los datos del usuario que ha iniciado sesión."""
    return usuario
