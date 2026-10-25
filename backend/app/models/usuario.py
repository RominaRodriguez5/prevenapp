"""Tabla de usuarios: técnicos, personal de presupuestos y administradores."""
import enum
from datetime import datetime

from sqlalchemy import DateTime, Enum, String, func
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class Rol(str, enum.Enum):
    TECNICO = "tecnico"            # usa la app móvil
    PRESUPUESTOS = "presupuestos"  # recibe los avisos de actividades realizadas
    ADMIN = "admin"                # da de alta usuarios


class Usuario(Base):
    __tablename__ = "usuarios"

    id: Mapped[int] = mapped_column(primary_key=True)
    nombre: Mapped[str] = mapped_column(String(100))
    email: Mapped[str] = mapped_column(String(255), unique=True, index=True)
    # Nunca guardamos la contraseña tal cual, solo su "hash" (una versión cifrada que no se puede revertir)
    password_hash: Mapped[str] = mapped_column(String(255))
    rol: Mapped[Rol] = mapped_column(Enum(Rol, native_enum=False, length=20), default=Rol.TECNICO)
    activo: Mapped[bool] = mapped_column(default=True)
    creado_en: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
