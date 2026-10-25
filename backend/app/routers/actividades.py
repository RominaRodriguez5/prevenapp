"""Actividades: listar, crear extras, programar, marcar como realizada y deshacer."""
from datetime import datetime, timezone
from decimal import ROUND_HALF_UP, Decimal

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import delete
from sqlalchemy.orm import Session

from app.core.fechas import hoy
from app.core.permisos import comprobar_actividad, comprobar_cliente, consulta_actividades_visibles
from app.database import get_db
from app.deps import usuario_actual
from app.models import (
    Actividad,
    Aviso,
    Cliente,
    EstadoActividad,
    Registro,
    Rol,
    TipoActividad,
    TipoRegistro,
    TurnoFormacion,
    Usuario,
)
from app.schemas.actividad import ActividadCrear, ActividadEditar, ActividadLeer, ActividadRealizar
from app.routers.clientes import buscar_centro
from app.services.actividades import a_leer, generar_obligatorias
from app.services.avisos import avisar_actividad_realizada

router = APIRouter(prefix="/actividades", tags=["Actividades"])


def _comprobar_tecnico(db: Session, usuario_id: int | None) -> None:
    if usuario_id is None:
        return
    tecnico = db.get(Usuario, usuario_id)
    if tecnico is None or not tecnico.activo or tecnico.rol != Rol.TECNICO:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=f"El técnico {usuario_id} no existe")


def _porcentaje(importe: Decimal, porcentaje: Decimal) -> Decimal:
    """Calcula el porcentaje de un importe, redondeado a céntimos (8 % de 1.250 € = 100,00 €)."""
    return (importe * porcentaje / 100).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)


@router.post("/generar")
def generar(db: Session = Depends(get_db), usuario: Usuario = Depends(usuario_actual)):
    """Crea las actividades del contrato del año actual (y años en plazo) que falten."""
    return {"creadas": generar_obligatorias(db, usuario, hoy().year)}


@router.get("", response_model=list[ActividadLeer])
def listar_actividades(
    cliente_id: int | None = None,
    centro_id: int | None = None,
    anio: int | None = None,
    estado: EstadoActividad | None = None,
    db: Session = Depends(get_db),
    usuario: Usuario = Depends(usuario_actual),
):
    consulta = consulta_actividades_visibles(usuario)
    if cliente_id is not None:
        consulta = consulta.where(Actividad.cliente_id == cliente_id)
    if centro_id is not None:
        consulta = consulta.where(Actividad.centro_id == centro_id)
    if anio is not None:
        consulta = consulta.where(Actividad.anio == anio)
    if estado is not None:
        consulta = consulta.where(Actividad.estado == estado)
    consulta = consulta.order_by(Actividad.anio, Cliente.nombre, Actividad.id)
    anio_actual = hoy().year
    return [a_leer(a, anio_actual) for a in db.scalars(consulta)]


@router.post("", response_model=ActividadLeer, status_code=status.HTTP_201_CREATED)
def crear_actividad(datos: ActividadCrear, db: Session = Depends(get_db), usuario: Usuario = Depends(usuario_actual)):
    """Añade una actividad extra, no incluida en el contrato."""
    cliente = comprobar_cliente(usuario, db.get(Cliente, datos.cliente_id))
    tipo = db.get(TipoActividad, datos.tipo_actividad_id)
    if tipo is None or not tipo.activo:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Tipo de actividad no encontrado")
    _comprobar_tecnico(db, datos.captador_id)
    _comprobar_tecnico(db, datos.redactor_id)
    centro = buscar_centro(db, cliente, datos.centro_id)
    actividad = Actividad(
        cliente_id=cliente.id,
        centro_id=centro.id,
        tipo_actividad_id=tipo.id,
        anio=datos.anio or hoy().year,
        obligatoria=False,
        fecha_programada=datos.fecha_programada,
        hora_programada=datos.hora_programada,
        lugar=datos.lugar,
        estado=EstadoActividad.PROGRAMADA if datos.fecha_programada else EstadoActividad.PENDIENTE,
        captador_id=datos.captador_id,
        redactor_id=datos.redactor_id,
        notas=datos.notas,
    )
    db.add(actividad)
    db.commit()
    db.refresh(actividad)
    return a_leer(actividad, hoy().year)


@router.get("/{actividad_id}", response_model=ActividadLeer)
def ver_actividad(actividad_id: int, db: Session = Depends(get_db), usuario: Usuario = Depends(usuario_actual)):
    return a_leer(comprobar_actividad(usuario, db.get(Actividad, actividad_id)), hoy().year)


@router.patch("/{actividad_id}", response_model=ActividadLeer)
def editar_actividad(
    actividad_id: int, datos: ActividadEditar, db: Session = Depends(get_db), usuario: Usuario = Depends(usuario_actual)
):
    """Programar fecha, hora, lugar y centro de la visita, indicar captador/redactor o añadir notas."""
    actividad = comprobar_actividad(usuario, db.get(Actividad, actividad_id))
    cambios = datos.model_dump(exclude_unset=True)
    if actividad.estado == EstadoActividad.REALIZADA and set(cambios) - {"notas"}:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="La actividad ya está realizada. Usa 'deshacer' si necesitas cambiarla.",
        )
    _comprobar_tecnico(db, cambios.get("captador_id"))
    _comprobar_tecnico(db, cambios.get("redactor_id"))
    if "centro_id" in cambios:
        # Solo un centro de la misma sociedad
        cambios["centro_id"] = buscar_centro(db, actividad.cliente, cambios["centro_id"]).id
    for campo, valor in cambios.items():
        setattr(actividad, campo, valor)
    if "fecha_programada" in cambios and actividad.estado != EstadoActividad.REALIZADA:
        actividad.estado = EstadoActividad.PROGRAMADA if actividad.fecha_programada else EstadoActividad.PENDIENTE
        if actividad.fecha_programada is None:
            actividad.hora_programada = None  # sin fecha no tiene sentido una hora
    db.commit()
    db.refresh(actividad)
    return a_leer(actividad, hoy().year)


@router.post("/{actividad_id}/realizar", response_model=ActividadLeer)
def realizar_actividad(
    actividad_id: int, datos: ActividadRealizar, db: Session = Depends(get_db), usuario: Usuario = Depends(usuario_actual)
):
    """El check: marca la actividad como realizada y avisa a presupuestos por email.

    - Se puede indicar el captador y el redactor en el mismo check.
    - Si no tiene redactor, el redactor es quien hace el check.
    - Si no tiene captador, se toma el técnico asignado al cliente.
    - Se calcula el incentivo (porcentaje del importe del presupuesto) y se guarda.
    - Si se indican km u horas de formación, se apuntan en el registro de ese día.
    """
    actividad = comprobar_actividad(usuario, db.get(Actividad, actividad_id))
    if actividad.estado == EstadoActividad.REALIZADA:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="La actividad ya estaba realizada")
    if datos.fecha_realizacion > hoy():
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="La fecha de realización no puede ser futura")

    _comprobar_tecnico(db, datos.captador_id)
    _comprobar_tecnico(db, datos.redactor_id)
    if datos.captador_id is not None:
        actividad.captador_id = datos.captador_id
    if datos.redactor_id is not None:
        actividad.redactor_id = datos.redactor_id
    if actividad.redactor_id is None and usuario.rol == Rol.TECNICO:
        actividad.redactor_id = usuario.id
    if actividad.captador_id is None:
        actividad.captador_id = actividad.cliente.tecnico_id
    actividad.estado = EstadoActividad.REALIZADA
    actividad.codigo_presupuesto = datos.codigo_presupuesto.strip()
    actividad.importe_presupuesto = Decimal(str(datos.importe_presupuesto))
    actividad.fecha_realizacion = datos.fecha_realizacion
    actividad.realizada_en = datetime.now(timezone.utc)
    actividad.importe_captador = (
        _porcentaje(actividad.importe_presupuesto, actividad.tipo.porcentaje_captador) if actividad.captador_id else None
    )
    actividad.importe_redactor = (
        _porcentaje(actividad.importe_presupuesto, actividad.tipo.porcentaje_redactor) if actividad.redactor_id else None
    )
    # Km y formación de esta visita, enlazados a la actividad
    concepto = f"{actividad.cliente.nombre} · {actividad.tipo.nombre}"[:255]
    # Turno de la formación: el indicado o, si no, mañana (entre semana) o extra mañana (fin de semana)
    turno = datos.turno_formacion or (
        TurnoFormacion.EXTRA_MANANA if datos.fecha_realizacion.weekday() >= 5 else TurnoFormacion.MANANA
    )
    for tipo, cantidad in ((TipoRegistro.KILOMETROS, datos.km), (TipoRegistro.FORMACION, datos.horas_formacion)):
        if cantidad:
            db.add(
                Registro(
                    tecnico_id=usuario.id,
                    fecha=datos.fecha_realizacion,
                    tipo=tipo,
                    cantidad=Decimal(str(cantidad)),
                    concepto=concepto,
                    turno=turno if tipo == TipoRegistro.FORMACION else None,
                    actividad_id=actividad.id,
                )
            )
    db.commit()
    db.refresh(actividad)

    avisar_actividad_realizada(db, actividad, usuario)
    db.refresh(actividad)
    return a_leer(actividad, hoy().year)


@router.post("/{actividad_id}/deshacer", response_model=ActividadLeer)
def deshacer_realizada(actividad_id: int, db: Session = Depends(get_db), usuario: Usuario = Depends(usuario_actual)):
    """Quita el check si se marcó por error. La actividad vuelve a estar pendiente o programada."""
    actividad = comprobar_actividad(usuario, db.get(Actividad, actividad_id))
    if actividad.estado != EstadoActividad.REALIZADA:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="La actividad no está realizada")
    actividad.estado = EstadoActividad.PROGRAMADA if actividad.fecha_programada else EstadoActividad.PENDIENTE
    actividad.fecha_realizacion = None
    actividad.codigo_presupuesto = None
    actividad.importe_presupuesto = None
    actividad.realizada_en = None
    actividad.importe_captador = None
    actividad.importe_redactor = None
    # También se quitan los km y la formación que se apuntaron con el check
    db.execute(delete(Registro).where(Registro.actividad_id == actividad.id))
    db.commit()
    db.refresh(actividad)
    return a_leer(actividad, hoy().year)


@router.delete("/{actividad_id}", status_code=status.HTTP_204_NO_CONTENT)
def borrar_actividad(actividad_id: int, db: Session = Depends(get_db), usuario: Usuario = Depends(usuario_actual)):
    """Solo se pueden borrar actividades extra que no estén realizadas."""
    actividad = comprobar_actividad(usuario, db.get(Actividad, actividad_id))
    if actividad.obligatoria or actividad.estado == EstadoActividad.REALIZADA:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="No se pueden borrar actividades del contrato ni actividades realizadas",
        )
    db.execute(delete(Aviso).where(Aviso.actividad_id == actividad.id))
    db.execute(delete(Registro).where(Registro.actividad_id == actividad.id))
    db.delete(actividad)
    db.commit()
