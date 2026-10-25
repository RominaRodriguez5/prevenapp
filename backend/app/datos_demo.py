"""Carga datos de ejemplo para probar la aplicación o enseñarla en una reunión.

Uso (con Docker en marcha):
    docker compose exec api python -m app.datos_demo

Crea (si no existen) usuarios de prueba con la contraseña "demo1234",
tipos de actividad, clientes con su contrato, algunos días de guardia
y actividades ya realizadas en meses anteriores (para que el historial y
los incentivos tengan contenido).
"""
from datetime import date, datetime, time, timedelta, timezone
from decimal import Decimal

from sqlalchemy import select

from app.core.fechas import hoy
from app.core.security import hashear_password
from app.database import SessionLocal
from app.models import (
    Actividad,
    ActividadObligatoria,
    CentroTrabajo,
    Cliente,
    EstadoActividad,
    Guardia,
    Registro,
    Rol,
    TipoActividad,
    TipoRegistro,
    TurnoFormacion,
    Usuario,
)
from app.services.actividades import centro_principal, generar_obligatorias

PASSWORD = "demo1234"

USUARIOS = [
    ("Presupuestos Demo", "presupuestos@previs.es", Rol.PRESUPUESTOS),
    ("Ana Martínez", "ana@previs.es", Rol.TECNICO),
    ("Luis García", "luis@previs.es", Rol.TECNICO),
]

# (nombre, % captador, % redactor)
TIPOS = [
    ("Evaluación de riesgos", Decimal("8"), Decimal("8")),
    ("Planificación preventiva", Decimal("8"), Decimal("8")),
    ("Formación a trabajadores", Decimal("8"), Decimal("8")),
    ("Mediciones higiénicas", Decimal("8"), Decimal("8")),
]

# (nombre, técnico, actividades del contrato, desde qué año, dirección)
CLIENTES = [
    ("Panadería Sol", "ana@previs.es", ["Evaluación de riesgos", "Formación a trabajadores"], -2, "C/ del Sol 12, Palma"),
    ("Talleres Ramírez", "ana@previs.es", ["Evaluación de riesgos", "Mediciones higiénicas"], -1, "Polígono de Inca, nave 7"),
    ("Clínica Dental Mar", "ana@previs.es", ["Planificación preventiva"], 0, "Av. Joan Miró 45, Palma"),
    ("Construcciones Pons", "luis@previs.es", ["Evaluación de riesgos", "Planificación preventiva"], -1, "Manacor (obra Camí de Son Fang)"),
    ("Hotel Brisa", "luis@previs.es", ["Formación a trabajadores"], 0, "Platja de Muro"),
]

# Nº de cliente y CIF del primer centro de cada sociedad de ejemplo (inventados)
CODIGOS = {
    "Panadería Sol": ("10234", "B07000001"),
    "Talleres Ramírez": ("10457", "B07000002"),
    "Clínica Dental Mar": ("10981", "B07000003"),
    "Construcciones Pons": ("11203", "B07000004"),
    "Hotel Brisa": ("11568", "B07000005"),
}

# Centros de trabajo extra de algunas sociedades de ejemplo
# (nombre, nº de cliente, CIF, dirección, actividades de su contrato). Inventados.
CENTROS_EXTRA = {
    "Panadería Sol": [
        ("Obrador de Marratxí", "10235", "B07000011", "Polígono Can Rubiol, nave 3, Marratxí", ["Evaluación de riesgos"]),
    ],
    "Hotel Brisa": [
        ("Hotel Brisa Mar", "11569", "B07000015", "Platja de Muro, 2ª línea", ["Formación a trabajadores", "Evaluación de riesgos"]),
        ("Lavandería central", "11570", "B07000016", "Sa Pobla, C/ Industria 8", ["Evaluación de riesgos"]),
    ],
}


def main():
    anio = hoy().year
    with SessionLocal() as db:
        por_email = {}
        for nombre, email, rol in USUARIOS:
            usuario = db.scalar(select(Usuario).where(Usuario.email == email))
            if usuario is None:
                # Los primeros datos de ejemplo usaban @demo.es: se pasan a @previs.es
                antiguo = email.replace("@previs.es", "@demo.es")
                usuario = db.scalar(select(Usuario).where(Usuario.email == antiguo))
                if usuario is not None:
                    usuario.email = email
            if usuario is None:
                usuario = Usuario(nombre=nombre, email=email, password_hash=hashear_password(PASSWORD), rol=rol)
                db.add(usuario)
            por_email[email] = usuario

        por_tipo = {}
        for nombre, captador, redactor in TIPOS:
            tipo = db.scalar(select(TipoActividad).where(TipoActividad.nombre == nombre))
            if tipo is None:
                tipo = TipoActividad(nombre=nombre, porcentaje_captador=captador, porcentaje_redactor=redactor)
                db.add(tipo)
            por_tipo[nombre] = tipo
        db.flush()

        for nombre, email, actividades, desde, direccion in CLIENTES:
            existente = db.scalar(select(Cliente).where(Cliente.nombre == nombre))
            if existente:
                existente.direccion = existente.direccion or direccion
                principal = centro_principal(db, existente)
                codigo, cif = CODIGOS.get(nombre, (None, None))
                principal.codigo = principal.codigo or codigo
                principal.cif = principal.cif or cif
                continue
            codigo, cif = CODIGOS.get(nombre, (None, None))
            cliente = Cliente(
                nombre=nombre,
                codigo=codigo,
                cif=cif,
                tecnico_id=por_email[email].id,
                telefono="971 000 000",
                direccion=direccion,
            )
            db.add(cliente)
            db.flush()
            principal = centro_principal(db, cliente)
            for actividad in actividades:
                db.add(
                    ActividadObligatoria(
                        cliente_id=cliente.id,
                        centro_id=principal.id,
                        tipo_actividad_id=por_tipo[actividad].id,
                        desde_anio=anio + desde,
                    )
                )

        # Centros extra (solo si el cliente todavía no los tiene)
        for nombre_cliente, centros in CENTROS_EXTRA.items():
            cliente = db.scalar(select(Cliente).where(Cliente.nombre == nombre_cliente))
            if cliente is None:
                continue
            for nombre_centro, codigo, cif, direccion, actividades in centros:
                existente = db.scalar(
                    select(CentroTrabajo).where(CentroTrabajo.cliente_id == cliente.id, CentroTrabajo.nombre == nombre_centro)
                )
                if existente:
                    existente.codigo = existente.codigo or codigo
                    existente.cif = existente.cif or cif
                    continue
                centro = CentroTrabajo(
                    cliente_id=cliente.id, nombre=nombre_centro, codigo=codigo, cif=cif, direccion=direccion
                )
                db.add(centro)
                db.flush()
                for actividad in actividades:
                    db.add(
                        ActividadObligatoria(
                            cliente_id=cliente.id,
                            centro_id=centro.id,
                            tipo_actividad_id=por_tipo[actividad].id,
                            desde_anio=anio - 1,
                        )
                    )

        for dias, email in [(2, "ana@previs.es"), (9, "ana@previs.es"), (5, "luis@previs.es")]:
            fecha = hoy() + timedelta(days=dias)
            tecnico = por_email[email]
            if not db.scalar(select(Guardia).where(Guardia.tecnico_id == tecnico.id, Guardia.fecha == fecha)):
                db.add(Guardia(tecnico_id=tecnico.id, fecha=fecha))
        db.flush()

        _historial_de_ejemplo(db, por_email, anio)
        db.commit()
        _visitas_de_ejemplo(db, por_email["presupuestos@previs.es"], anio)
        _registros_de_ejemplo(db, por_email["ana@previs.es"])
        db.commit()

    print("Datos de ejemplo cargados. Usuarios (contraseña: demo1234):")
    for nombre, email, rol in USUARIOS:
        print(f"  - {email}  ({rol.value})")


# (cliente, tipo, captador, redactor, meses atrás, importe sin IVA)
HISTORIAL = [
    ("Panadería Sol", "Formación a trabajadores", "ana@previs.es", "ana@previs.es", 1, Decimal("450")),
    ("Talleres Ramírez", "Mediciones higiénicas", "ana@previs.es", "ana@previs.es", 2, Decimal("1250")),
    ("Construcciones Pons", "Evaluación de riesgos", "luis@previs.es", "ana@previs.es", 2, Decimal("980")),
    ("Hotel Brisa", "Formación a trabajadores", "ana@previs.es", "luis@previs.es", 3, Decimal("600")),
    ("Clínica Dental Mar", "Planificación preventiva", "ana@previs.es", "ana@previs.es", 5, Decimal("320")),
    ("Construcciones Pons", "Planificación preventiva", "luis@previs.es", "luis@previs.es", 4, Decimal("540")),
]


def _historial_de_ejemplo(db, por_email, anio):
    """Actividades extra ya realizadas, solo si todavía no hay ninguna realizada."""
    if db.scalar(select(Actividad).where(Actividad.estado == EstadoActividad.REALIZADA)):
        return
    hoy_ = hoy()
    for numero, (cliente_nombre, tipo_nombre, captador, redactor, meses_atras, importe) in enumerate(HISTORIAL, 1):
        cliente = db.scalar(select(Cliente).where(Cliente.nombre == cliente_nombre))
        tipo = db.scalar(select(TipoActividad).where(TipoActividad.nombre == tipo_nombre))
        if cliente is None or tipo is None:
            continue
        mes = hoy_.month - meses_atras
        anio_actividad = anio if mes > 0 else anio - 1
        fecha = date(anio_actividad, mes if mes > 0 else mes + 12, min(10 + numero, 28))
        db.add(
            Actividad(
                cliente_id=cliente.id,
                centro_id=centro_principal(db, cliente).id,
                tipo_actividad_id=tipo.id,
                anio=anio_actividad,
                obligatoria=False,
                estado=EstadoActividad.REALIZADA,
                fecha_programada=fecha,
                fecha_realizacion=fecha,
                codigo_presupuesto=f"P-{anio_actividad}-{100 + numero:04d}",
                importe_presupuesto=importe,
                captador_id=por_email[captador].id,
                redactor_id=por_email[redactor].id,
                importe_captador=(importe * tipo.porcentaje_captador / 100).quantize(Decimal("0.01")),
                importe_redactor=(importe * tipo.porcentaje_redactor / 100).quantize(Decimal("0.01")),
                realizada_en=datetime.now(timezone.utc),
            )
        )


def _visitas_de_ejemplo(db, alguien_que_ve_todo, anio):
    """Programa algunas visitas en los próximos días, con hora y lugar."""
    generar_obligatorias(db, alguien_que_ve_todo, anio)
    if db.scalar(select(Actividad).where(Actividad.hora_programada.is_not(None))):
        return
    pendientes = db.scalars(
        select(Actividad)
        .where(Actividad.anio == anio, Actividad.estado == EstadoActividad.PENDIENTE)
        .order_by(Actividad.id)
        .limit(4)
    ).all()
    horas = [time(9, 30), time(12, 0), time(10, 0), time(16, 30)]
    for dias, (actividad, hora) in enumerate(zip(pendientes, horas), 1):
        actividad.fecha_programada = hoy() + timedelta(days=dias)
        actividad.hora_programada = hora
        actividad.lugar = (actividad.centro.direccion if actividad.centro else None) or actividad.cliente.direccion
        actividad.estado = EstadoActividad.PROGRAMADA


def _registros_de_ejemplo(db, tecnico):
    """Unos cuantos km y horas de formación del mes actual."""
    if db.scalar(select(Registro).where(Registro.tecnico_id == tecnico.id)):
        return
    ejemplos = [
        (TipoRegistro.KILOMETROS, Decimal("38"), "Palma → Inca (Talleres Ramírez)"),
        (TipoRegistro.KILOMETROS, Decimal("38"), "Inca → Palma"),
        (TipoRegistro.FORMACION, Decimal("2.5"), "Formación a trabajadores en Panadería Sol"),
        (TipoRegistro.KILOMETROS, Decimal("12.4"), "Visita Clínica Dental Mar"),
    ]
    for dias_atras, (tipo, cantidad, concepto) in zip([3, 3, 2, 1], ejemplos):
        fecha = hoy() - timedelta(days=dias_atras)
        if fecha.month != hoy().month:
            fecha = hoy()
        turno = None
        if tipo == TipoRegistro.FORMACION:
            turno = TurnoFormacion.EXTRA_MANANA if fecha.weekday() >= 5 else TurnoFormacion.MANANA
        db.add(Registro(tecnico_id=tecnico.id, fecha=fecha, tipo=tipo, cantidad=cantidad, concepto=concepto, turno=turno))


if __name__ == "__main__":
    main()
