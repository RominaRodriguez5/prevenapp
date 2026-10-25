"""Conexión con la base de datos mediante SQLAlchemy."""
from sqlalchemy import create_engine
from sqlalchemy.orm import DeclarativeBase, sessionmaker

from app.config import settings

# El "engine" es la conexión con PostgreSQL
engine = create_engine(settings.database_url)

# Cada petición a la API abrirá su propia sesión con la base de datos
SessionLocal = sessionmaker(bind=engine, autoflush=False)


class Base(DeclarativeBase):
    """Clase base de la que heredarán todas las tablas (modelos)."""


def get_db():
    """Abre una sesión para una petición y la cierra al terminar."""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
