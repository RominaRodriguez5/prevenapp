"""Agenda del técnico: pendientes, calendario y guardias."""
from datetime import date, timedelta

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import and_, delete, or_, select
from sqlalchemy.orm import Session

from app.core.fechas import hoy, primer_anio_en_plazo
from app.core.permisos import consulta_actividades_visibles, ve_todo
from app.database import get_db
from app.deps import usuario_actual
from app.models import Actividad, Cliente, EstadoActividad, Guardia, Rol, Usuario
from app.schemas.agenda import Agenda, GuardiaLeer, GuardiaMarcar
from app.schemas.actividad import Pendientes
from app.schemas.usuario import UsuarioLeer
from app.services.actividades import a_leer, generar_obligatorias

router = APIRouter(tags=["Agenda"])


def _tecnico_objetivo(db: Session, usuario: Usuario, tecnico_id: int | None) -> Usuario:
    """El técnico del que se piden datos: uno mismo o, si eres administración, el que indiques."""
    if tecnico_id is None or tecnico_id == usuario.id:
        return usuario
    if not ve_todo(usuario):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Solo puedes ver tus propios datos")
    tecnico = db.get(Usuario, tecnico_id)
    if tecnico is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Técnico no encontrado")
    return tecnico


@router.get("/agenda/pendientes", response_model=Pendientes)
def pendientes(db: Session = Depends(get_db), usuario: Usuario = Depends(usuario_actual)):
    """Lo que el técnico tiene por hacer: las del año actual y las atrasadas aún en plazo (5 años).

    Antes de responder, crea las actividades del contrato que falten.
    """
    anio = hoy().year
    generar_obligatorias(db, usuario, anio)
    desde = primer_anio_en_plazo(anio)
    consulta = (
        consulta_actividades_visibles(usuario)
        .where(Actividad.estado != EstadoActividad.REALIZADA, Actividad.anio >= desde, Actividad.anio <= anio)
        .order_by(Actividad.anio, Cliente.nombre, Actividad.id)
    )
    actividades = [a_leer(a, anio) for a in db.scalars(consulta)]
    sin_visitar = sorted({a.cliente_nombre for a in actividades if a.obligatoria and a.anio == anio - 1})
    anteriores = sum(1 for a in actividades if a.anio < anio)
    return Pendientes(
        anio_actual=anio,
        primer_anio_en_plazo=desde,
        total=len(actividades),
        del_anio_actual=len(actividades) - anteriores,
        de_anios_anteriores=anteriores,
        actividades=actividades,
        clientes_sin_visitar_anio_anterior=sin_visitar,
    )


@router.get("/agenda", response_model=Agenda)
def agenda(
    desde: date | None = None,
    hasta: date | None = None,
    tecnico_id: int | None = None,
    db: Session = Depends(get_db),
    usuario: Usuario = Depends(usuario_actual),
):
    """Calendario: actividades programadas o realizadas entre dos fechas y días de guardia.

    Por defecto, el mes actual.
    """
    tecnico = _tecnico_objetivo(db, usuario, tecnico_id)
    if desde is None:
        desde = hoy().replace(day=1)
    if hasta is None:
        hasta = (desde.replace(day=28) + timedelta(days=4)).replace(day=1) - timedelta(days=1)
    if hasta < desde:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="'hasta' debe ser posterior a 'desde'")

    consulta = (
        select(Actividad)
        .join(Cliente, Actividad.cliente_id == Cliente.id)
        .where(
            or_(
                Cliente.tecnico_id == tecnico.id,
                Actividad.captador_id == tecnico.id,
                Actividad.redactor_id == tecnico.id,
            ),
            or_(
                and_(Actividad.estado != EstadoActividad.REALIZADA, Actividad.fecha_programada.between(desde, hasta)),
                and_(Actividad.estado == EstadoActividad.REALIZADA, Actividad.fecha_realizacion.between(desde, hasta)),
            ),
        )
        .order_by(Actividad.fecha_programada, Actividad.hora_programada, Actividad.fecha_realizacion)
    )
    guardias = db.scalars(
        select(Guardia.fecha).where(Guardia.tecnico_id == tecnico.id, Guardia.fecha.between(desde, hasta)).order_by(Guardia.fecha)
    )
    anio = hoy().year
    return Agenda(
        desde=desde,
        hasta=hasta,
        guardias=list(guardias),
        actividades=[a_leer(a, anio) for a in db.scalars(consulta)],
    )


@router.put("/guardias/{fecha}", response_model=GuardiaLeer)
def marcar_guardia(
    fecha: date, datos: GuardiaMarcar, db: Session = Depends(get_db), usuario: Usuario = Depends(usuario_actual)
):
    """Guardia sí / no para un día. Es el "desplegable" del calendario."""
    if datos.tecnico_id not in (None, usuario.id) and usuario.rol != Rol.ADMIN:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Solo puedes marcar tus propias guardias")
    tecnico = _tecnico_objetivo(db, usuario, datos.tecnico_id)
    existente = db.scalar(select(Guardia).where(Guardia.tecnico_id == tecnico.id, Guardia.fecha == fecha))
    if datos.guardia and existente is None:
        db.add(Guardia(tecnico_id=tecnico.id, fecha=fecha))
    elif not datos.guardia and existente is not None:
        db.execute(delete(Guardia).where(Guardia.id == existente.id))
    db.commit()
    return GuardiaLeer(tecnico_id=tecnico.id, fecha=fecha, guardia=datos.guardia)


@router.get("/guardias/dia/{fecha}", response_model=list[UsuarioLeer])
def quien_esta_de_guardia(fecha: date, db: Session = Depends(get_db), _: Usuario = Depends(usuario_actual)):
    """¿Quién está de guardia este día? Lo puede consultar cualquier usuario."""
    return db.scalars(
        select(Usuario).join(Guardia, Guardia.tecnico_id == Usuario.id).where(Guardia.fecha == fecha).order_by(Usuario.nombre)
    ).all()


@router.get("/guardias", response_model=list[date])
def mis_guardias(
    anio: int = Query(default_factory=lambda: hoy().year),
    tecnico_id: int | None = None,
    db: Session = Depends(get_db),
    usuario: Usuario = Depends(usuario_actual),
):
    """Todos los días de guardia de un año."""
    tecnico = _tecnico_objetivo(db, usuario, tecnico_id)
    return list(
        db.scalars(
            select(Guardia.fecha)
            .where(Guardia.tecnico_id == tecnico.id, Guardia.fecha.between(date(anio, 1, 1), date(anio, 12, 31)))
            .order_by(Guardia.fecha)
        )
    )
