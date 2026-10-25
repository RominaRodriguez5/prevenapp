"""Seguridad: cifrado de contraseñas y creación/lectura de tokens JWT."""
from datetime import datetime, timedelta, timezone

import bcrypt
import jwt

from app.config import settings

ALGORITMO = "HS256"


def hashear_password(password: str) -> str:
    """Convierte la contraseña en un hash seguro para guardarlo en la base de datos."""
    return bcrypt.hashpw(password.encode(), bcrypt.gensalt()).decode()


def verificar_password(password: str, password_hash: str) -> bool:
    """Comprueba si la contraseña escrita coincide con el hash guardado."""
    return bcrypt.checkpw(password.encode(), password_hash.encode())


def crear_token(usuario_id: int) -> str:
    """Crea un token JWT: una especie de "pase" firmado que demuestra quién es el usuario."""
    expira = datetime.now(timezone.utc) + timedelta(minutes=settings.token_expira_minutos)
    datos = {"sub": str(usuario_id), "exp": expira}
    return jwt.encode(datos, settings.secret_key, algorithm=ALGORITMO)


def leer_token(token: str) -> int | None:
    """Devuelve el id del usuario si el token es válido; None si es falso o ha caducado."""
    try:
        datos = jwt.decode(token, settings.secret_key, algorithms=[ALGORITMO])
        return int(datos["sub"])
    except (jwt.PyJWTError, KeyError, ValueError):
        return None
