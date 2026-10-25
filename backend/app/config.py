"""Configuración de la aplicación.

Lee los valores del archivo .env, así no escribimos contraseñas dentro del código.
"""
from pydantic import field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    database_url: str
    # Clave para firmar los tokens. El valor por defecto solo sirve para desarrollo.
    secret_key: str = "clave-de-desarrollo-cambiar-en-produccion"
    # Cuánto dura una sesión antes de tener que volver a iniciar sesión (8 horas = una jornada)
    token_expira_minutos: int = 60 * 8

    # Correo para los avisos. Si smtp_host está vacío, los avisos se registran pero no se envían.
    smtp_host: str | None = None
    smtp_port: int = 587
    smtp_usuario: str | None = None
    smtp_password: str | None = None
    smtp_tls: bool = False
    avisos_remitente: str = "avisos@prevenapp.local"
    # Lista de emails separados por comas. Si está vacía, se avisa a los usuarios con rol presupuestos.
    avisos_destinatarios: str | None = None

    model_config = SettingsConfigDict(env_file=".env")

    @field_validator("database_url")
    @classmethod
    def _usar_psycopg(cls, valor: str) -> str:
        """Los servicios en la nube (Neon, Render...) dan la dirección como "postgresql://..." o
        "postgres://...". SQLAlchemy necesita saber que usamos psycopg: "postgresql+psycopg://..."."""
        for prefijo in ("postgres://", "postgresql://"):
            if valor.startswith(prefijo):
                return "postgresql+psycopg://" + valor[len(prefijo):]
        return valor


settings = Settings()
