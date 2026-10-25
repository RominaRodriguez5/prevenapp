"""Preparación común de las pruebas.

Por defecto usan una base de datos SQLite en memoria. Para probar contra PostgreSQL:
    TEST_DATABASE_URL=postgresql+psycopg://usuario@host/bd pytest
"""
import os
from datetime import date

os.environ.setdefault("DATABASE_URL", os.environ.get("TEST_DATABASE_URL", "sqlite://"))

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

import app.models  # noqa: F401
from app.core.security import hashear_password
from app.database import Base, get_db
from app.main import app as aplicacion
from app.models import Rol, Usuario

URL = os.environ.get("TEST_DATABASE_URL", "sqlite://")
engine = create_engine(URL, poolclass=StaticPool, **({"connect_args": {"check_same_thread": False}} if URL.startswith("sqlite") else {}))
Sesion = sessionmaker(bind=engine, autoflush=False)

# Fecha fija para que las pruebas den siempre el mismo resultado
HOY = date(2026, 10, 23)
MODULOS_CON_HOY = [
    "app.routers.clientes",
    "app.routers.actividades",
    "app.routers.agenda",
    "app.routers.incentivos",
    "app.routers.registros",
]


@pytest.fixture(autouse=True)
def base_de_datos(monkeypatch):
    Base.metadata.drop_all(engine)
    Base.metadata.create_all(engine)
    for modulo in MODULOS_CON_HOY:
        monkeypatch.setattr(f"{modulo}.hoy", lambda: HOY)

    def get_db_pruebas():
        db = Sesion()
        try:
            yield db
        finally:
            db.close()

    aplicacion.dependency_overrides[get_db] = get_db_pruebas
    yield
    aplicacion.dependency_overrides.clear()


@pytest.fixture
def db():
    with Sesion() as sesion:
        yield sesion


@pytest.fixture
def client():
    return TestClient(aplicacion)


def crear_usuario(nombre: str, email: str, rol: Rol) -> Usuario:
    with Sesion() as db:
        usuario = Usuario(nombre=nombre, email=email, password_hash=hashear_password("clave1234"), rol=rol)
        db.add(usuario)
        db.commit()
        db.refresh(usuario)
        return usuario


def cabeceras(client: TestClient, email: str) -> dict:
    respuesta = client.post("/auth/login", data={"username": email, "password": "clave1234"})
    assert respuesta.status_code == 200, respuesta.text
    return {"Authorization": f"Bearer {respuesta.json()['access_token']}"}


@pytest.fixture
def usuarios(client):
    """Crea un admin, una persona de presupuestos y dos técnicos, y devuelve sus cabeceras."""
    ids = {
        "admin": crear_usuario("Admin", "admin@prevenapp.es", Rol.ADMIN).id,
        "presupuestos": crear_usuario("Romina", "presupuestos@prevenapp.es", Rol.PRESUPUESTOS).id,
        "ana": crear_usuario("Ana Técnica", "ana@prevenapp.es", Rol.TECNICO).id,
        "luis": crear_usuario("Luis Técnico", "luis@prevenapp.es", Rol.TECNICO).id,
    }
    emails = {
        "admin": "admin@prevenapp.es",
        "presupuestos": "presupuestos@prevenapp.es",
        "ana": "ana@prevenapp.es",
        "luis": "luis@prevenapp.es",
    }
    return {nombre: {"id": ids[nombre], "h": cabeceras(client, emails[nombre])} for nombre in ids}
