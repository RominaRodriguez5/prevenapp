"""Punto de entrada de la API de PrevenApp."""
import logging

from fastapi import Depends, FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from sqlalchemy import text
from sqlalchemy.orm import Session

from app.database import get_db
from app.routers import actividades, agenda, auth, clientes, incentivos, registros, tipos_actividad, usuarios

app = FastAPI(title="PrevenApp API", version="0.4.0")

log = logging.getLogger("prevenapp")


# Si algo falla dentro de la API, se responde con un error 500 en JSON (y con las cabeceras
# CORS). Sin esto, el navegador lo muestra como "no se puede conectar" y no se ve el problema.
@app.middleware("http")
async def errores_internos(request: Request, call_next):
    try:
        return await call_next(request)
    except Exception:
        log.exception("Error interno en %s %s", request.method, request.url.path)
        return JSONResponse(
            status_code=500,
            content={"detail": "Error interno del servidor. Revisa los logs de la API."},
        )


# CORS: permite que la app Flutter, cuando se prueba en el navegador (Chrome) desde
# localhost, pueda llamar a la API. La app instalada en el móvil no lo necesita.
app.add_middleware(
    CORSMiddleware,
    allow_origin_regex=r"http://(localhost|127\.0\.0\.1)(:\d+)?",
    allow_methods=["*"],
    allow_headers=["*"],
)

# Cada "router" agrupa las rutas de una parte de la aplicación
app.include_router(auth.router)
app.include_router(usuarios.router)
app.include_router(usuarios.router_tecnicos)
app.include_router(tipos_actividad.router)
app.include_router(clientes.router)
app.include_router(actividades.router)
app.include_router(agenda.router)
app.include_router(incentivos.router)
app.include_router(registros.router)


@app.get("/health", tags=["Estado"])
def health():
    """Comprueba que la API está funcionando."""
    return {"estado": "ok"}


@app.get("/health/db", tags=["Estado"])
def health_db(db: Session = Depends(get_db)):
    """Comprueba que la API puede hablar con la base de datos."""
    db.execute(text("SELECT 1"))
    return {"base_de_datos": "ok"}
