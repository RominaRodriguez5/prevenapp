"""Historial mensual e incentivos por cuatrimestre."""
from datetime import date
from decimal import Decimal

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import or_, select
from sqlalchemy.orm import Session

from app.core.fechas import cuatrimestre_de, hoy, rango_cuatrimestre
from app.core.permisos import ve_todo
from app.database import get_db
from app.deps import usuario_actual
from app.models import Actividad, Aviso, EstadoActividad, Rol, Usuario
from app.routers.agenda import _tecnico_objetivo
from app.schemas.agenda import Historial, Incentivos, MesHistorial, ParteIncentivo, ResumenIncentivoTecnico
from app.services.actividades import a_leer

router = APIRouter(tags=["Historial e incentivos"])


def _realizadas_de(db: Session, tecnico_id: int, desde: date, hasta: date) -> list[Actividad]:
    """Actividades realizadas entre dos fechas en las que el técnico fue captador o redactor."""
    return list(
        db.scalars(
            select(Actividad)
            .where(
                Actividad.estado == EstadoActividad.REALIZADA,
                Actividad.fecha_realizacion.between(desde, hasta),
                or_(Actividad.captador_id == tecnico_id, Actividad.redactor_id == tecnico_id),
            )
            .order_by(Actividad.fecha_realizacion, Actividad.id)
        )
    )


def _calcular(actividades: list[Actividad], tecnico_id: int) -> tuple[ParteIncentivo, ParteIncentivo, float]:
    """Suma los importes: como captador y como redactor (si fue las dos cosas, cobra las dos)."""
    captadas = [a for a in actividades if a.captador_id == tecnico_id]
    redactadas = [a for a in actividades if a.redactor_id == tecnico_id]
    total_captador = sum((a.importe_captador or Decimal(0) for a in captadas), Decimal(0))
    total_redactor = sum((a.importe_redactor or Decimal(0) for a in redactadas), Decimal(0))
    return (
        ParteIncentivo(numero=len(captadas), total=float(total_captador)),
        ParteIncentivo(numero=len(redactadas), total=float(total_redactor)),
        float(total_captador + total_redactor),
    )


@router.get("/historial", response_model=Historial)
def historial(
    anio: int = Query(default_factory=lambda: hoy().year),
    tecnico_id: int | None = None,
    db: Session = Depends(get_db),
    usuario: Usuario = Depends(usuario_actual),
):
    """Actividades realizadas mes a mes durante un año."""
    tecnico = _tecnico_objetivo(db, usuario, tecnico_id)
    actividades = _realizadas_de(db, tecnico.id, date(anio, 1, 1), date(anio, 12, 31))
    anio_actual = hoy().year
    meses = []
    for mes in range(1, 13):
        del_mes = [a for a in actividades if a.fecha_realizacion.month == mes]
        meses.append(
            MesHistorial(
                mes=mes,
                realizadas_como_redactor=sum(1 for a in del_mes if a.redactor_id == tecnico.id),
                captadas=sum(1 for a in del_mes if a.captador_id == tecnico.id),
                actividades=[a_leer(a, anio_actual) for a in del_mes],
            )
        )
    return Historial(tecnico_id=tecnico.id, anio=anio, meses=meses)


@router.get("/incentivos", response_model=Incentivos)
def incentivos(
    anio: int | None = None,
    cuatrimestre: int | None = Query(default=None, ge=1, le=3),
    tecnico_id: int | None = None,
    db: Session = Depends(get_db),
    usuario: Usuario = Depends(usuario_actual),
):
    """Incentivos de un cuatrimestre (1: ene-abr, 2: may-ago, 3: sep-dic). Por defecto, el actual."""
    tecnico = _tecnico_objetivo(db, usuario, tecnico_id)
    anio = anio or hoy().year
    cuatrimestre = cuatrimestre or cuatrimestre_de(hoy())
    desde, hasta = rango_cuatrimestre(anio, cuatrimestre)
    actividades = _realizadas_de(db, tecnico.id, desde, hasta)
    captador, redactor, total = _calcular(actividades, tecnico.id)
    anio_actual = hoy().year
    return Incentivos(
        tecnico_id=tecnico.id,
        tecnico_nombre=tecnico.nombre,
        anio=anio,
        cuatrimestre=cuatrimestre,
        desde=desde,
        hasta=hasta,
        como_captador=captador,
        como_redactor=redactor,
        total=total,
        actividades=[a_leer(a, anio_actual) for a in actividades],
    )


@router.get("/incentivos/resumen", response_model=list[ResumenIncentivoTecnico])
def resumen_incentivos(
    anio: int | None = None,
    cuatrimestre: int | None = Query(default=None, ge=1, le=3),
    db: Session = Depends(get_db),
    usuario: Usuario = Depends(usuario_actual),
):
    """Incentivos de todos los técnicos en un cuatrimestre (solo administración y presupuestos)."""
    if not ve_todo(usuario):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Solo para administración y presupuestos")
    anio = anio or hoy().year
    cuatrimestre = cuatrimestre or cuatrimestre_de(hoy())
    desde, hasta = rango_cuatrimestre(anio, cuatrimestre)
    resumen = []
    for tecnico in db.scalars(select(Usuario).where(Usuario.rol == Rol.TECNICO).order_by(Usuario.nombre)):
        captador, redactor, total = _calcular(_realizadas_de(db, tecnico.id, desde, hasta), tecnico.id)
        resumen.append(
            ResumenIncentivoTecnico(
                tecnico_id=tecnico.id,
                tecnico_nombre=tecnico.nombre,
                como_captador=captador,
                como_redactor=redactor,
                total=total,
            )
        )
    return resumen


@router.get("/avisos", tags=["Avisos"])
def listar_avisos(limite: int = Query(default=50, le=500), db: Session = Depends(get_db), usuario: Usuario = Depends(usuario_actual)):
    """Últimos avisos enviados (solo administración y presupuestos)."""
    if not ve_todo(usuario):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Solo para administración y presupuestos")
    avisos = db.scalars(select(Aviso).order_by(Aviso.id.desc()).limit(limite))
    return [
        {
            "id": a.id,
            "actividad_id": a.actividad_id,
            "destinatarios": a.destinatarios,
            "asunto": a.asunto,
            "enviado": a.enviado,
            "error": a.error,
            "creado_en": a.creado_en,
        }
        for a in avisos
    ]
