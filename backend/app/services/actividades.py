"""Lógica de las actividades que usan varias rutas."""
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.fechas import primer_anio_en_plazo
from app.core.permisos import ve_todo
from app.models import Actividad, ActividadObligatoria, CentroTrabajo, Cliente, EstadoActividad, Usuario
from app.schemas.actividad import ActividadLeer


def centro_principal(db: Session, cliente: Cliente) -> CentroTrabajo:
    """Primer centro activo del cliente. Si no tiene ninguno, se crea el "Centro principal"."""
    centro = db.scalar(
        select(CentroTrabajo)
        .where(CentroTrabajo.cliente_id == cliente.id, CentroTrabajo.activo.is_(True))
        .order_by(CentroTrabajo.id)
    )
    if centro is None:
        centro = CentroTrabajo(
            cliente_id=cliente.id,
            nombre="Centro principal",
            codigo=cliente.codigo,
            cif=cliente.cif,
            direccion=cliente.direccion,
        )
        db.add(centro)
        db.flush()
    return centro


def a_leer(actividad: Actividad, anio_actual: int) -> ActividadLeer:
    """Convierte una actividad de la base de datos en la respuesta de la API."""
    return ActividadLeer(
        id=actividad.id,
        cliente_id=actividad.cliente_id,
        cliente_nombre=actividad.cliente.nombre,
        cliente_direccion=(actividad.centro.direccion if actividad.centro else None) or actividad.cliente.direccion,
        centro_id=actividad.centro_id,
        centro_nombre=actividad.centro.nombre if actividad.centro else None,
        centro_codigo=actividad.centro.codigo if actividad.centro else None,
        tipo_actividad_id=actividad.tipo_actividad_id,
        tipo_nombre=actividad.tipo.nombre,
        anio=actividad.anio,
        obligatoria=actividad.obligatoria,
        estado=actividad.estado,
        fecha_programada=actividad.fecha_programada,
        hora_programada=actividad.hora_programada,
        lugar=actividad.lugar,
        fecha_realizacion=actividad.fecha_realizacion,
        codigo_presupuesto=actividad.codigo_presupuesto,
        importe_presupuesto=actividad.importe_presupuesto,
        captador_id=actividad.captador_id,
        captador_nombre=actividad.captador.nombre if actividad.captador else None,
        redactor_id=actividad.redactor_id,
        redactor_nombre=actividad.redactor.nombre if actividad.redactor else None,
        importe_captador=actividad.importe_captador,
        importe_redactor=actividad.importe_redactor,
        notas=actividad.notas,
        atrasada=actividad.anio < anio_actual and actividad.estado != EstadoActividad.REALIZADA,
    )


def generar_obligatorias(db: Session, usuario: Usuario, anio_actual: int) -> int:
    """Crea las actividades del contrato que todavía no existen.

    Para cada línea de contrato activa se crea una actividad por año, desde el año en que
    empezó el contrato (o el primer año aún en plazo) hasta el año actual. Se puede llamar
    tantas veces como se quiera: nunca crea duplicados. Devuelve cuántas ha creado.
    """
    consulta = (
        select(ActividadObligatoria)
        .join(Cliente)
        .where(ActividadObligatoria.activa.is_(True), Cliente.activo.is_(True))
    )
    if not ve_todo(usuario):
        consulta = consulta.where(Cliente.tecnico_id == usuario.id)

    creadas = 0
    for linea in db.scalars(consulta).all():
        if linea.centro_id is None:  # líneas antiguas sin centro: al centro principal
            linea.centro_id = centro_principal(db, linea.cliente).id
        desde = max(linea.desde_anio, primer_anio_en_plazo(anio_actual))
        anios_existentes = set(db.scalars(select(Actividad.anio).where(Actividad.linea_id == linea.id)))
        for anio in range(desde, anio_actual + 1):
            if anio not in anios_existentes:
                db.add(
                    Actividad(
                        cliente_id=linea.cliente_id,
                        centro_id=linea.centro_id,
                        linea_id=linea.id,
                        tipo_actividad_id=linea.tipo_actividad_id,
                        anio=anio,
                        obligatoria=True,
                        estado=EstadoActividad.PENDIENTE,
                    )
                )
                creadas += 1
    db.commit()
    return creadas
