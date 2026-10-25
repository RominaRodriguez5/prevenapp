# PrevenApp

Agenda inteligente para técnicos de prevención de riesgos laborales.

- **Backend:** Python + FastAPI, PostgreSQL (SQLAlchemy + Alembic), JWT, Docker.
- **App móvil:** Flutter (próxima fase).

📖 La explicación de cada fase está en [`docs/GUIA.md`](docs/GUIA.md).

## Arrancar el proyecto

Necesitas **Docker Desktop** abierto y el archivo `backend/.env` (copia de `backend/.env.example`).

```bash
docker compose up --build
```

| Dirección | Qué es |
|---|---|
| http://localhost:8000/docs | Documentación y pruebas de la API |
| http://localhost:8000/health | Estado de la API |
| http://localhost:8025 | Buzón de pruebas (Mailpit) con los avisos enviados |

## Comandos útiles

```bash
# Crear el primer administrador
docker compose exec api python -m app.crear_admin

# Cargar datos de ejemplo (usuarios con contraseña demo1234)
docker compose exec api python -m app.datos_demo

# Pruebas automáticas (con el .venv activado)
pip install -r backend/requirements-dev.txt
cd backend && pytest
```

Para pararlo: `Ctrl + C` y después `docker compose down`.
