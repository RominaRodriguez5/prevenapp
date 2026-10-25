"""Clientes del técnico (carpetas), sus centros de trabajo (subcarpetas) y su contrato."""
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import case, func, or_, select
from sqlalchemy.orm import Session

from app.core.fechas import hoy, primer_anio_en_plazo
from app.core.permisos import comprobar_cliente, ve_todo
from app.database import get_db
from app.deps import usuario_actual
from app.models import Actividad, ActividadObligatoria, CentroTrabajo, Cliente, EstadoActividad, Rol, TipoActividad, Usuario
from app.schemas.cliente import (
    CentroCrear,
    CentroEditar,
    CentroLeer,
    ClienteCrear,
    ClienteEditar,
    ClienteLeer,
    ObligatoriaCrear,
    ObligatoriaLeer,
)
from app.services.actividades import centro_principal, generar_obligatorias

router = APIRouter(prefix="/clientes", tags=["Clientes"])


def _comprobar_tecnico(db: Session, tecnico_id: int) -> None:
    tecnico = db.get(Usuario, tecnico_id)
    if tecnico is None or not tecnico.activo or tecnico.rol != Rol.TECNICO:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="El técnico indicado no existe")


def _contadores(db: Session, columna, ids: list[int]) -> dict[int, tuple[int, int, int]]:
    """Para cada id (de cliente o de centro): (le faltan, de ellas atrasadas, hechas).

    "Le faltan" solo cuenta las que aún están en plazo (margen de 5 años).
    """
    if not ids:
        return {}
    anio = hoy().year
    hecha = Actividad.estado == EstadoActividad.REALIZADA
    en_plazo = Actividad.anio >= primer_anio_en_plazo(anio)
    filas = db.execute(
        select(
            columna,
            func.sum(case((~hecha & en_plazo, 1), else_=0)),
            func.sum(case((~hecha & en_plazo & (Actividad.anio < anio), 1), else_=0)),
            func.sum(case((hecha, 1), else_=0)),
        )
        .where(columna.in_(ids))
        .group_by(columna)
    ).all()
    return {id_: (faltan or 0, atrasadas or 0, hechas or 0) for id_, faltan, atrasadas, hechas in filas}


@router.get("", response_model=list[ClienteLeer])
def listar_clientes(
    buscar: str | None = None,
    incluir_inactivos: bool = False,
    db: Session = Depends(get_db),
    usuario: Usuario = Depends(usuario_actual),
):
    """Un técnico ve sus sociedades; administración ve todas. `buscar` filtra por nombre, nº de cliente o CIF.

    Cada cliente es una "carpeta": junto a sus datos se devuelve cuántas actividades le
    faltan (y cuántas de ellas son de años anteriores) y cuántas tiene hechas.
    """
    anio = hoy().year
    # Primero se crean las actividades del contrato de este año que aún no existan
    generar_obligatorias(db, usuario, anio)

    consulta = select(Cliente).order_by(Cliente.nombre)
    if not ve_todo(usuario):
        consulta = consulta.where(Cliente.tecnico_id == usuario.id)
    if not incluir_inactivos:
        consulta = consulta.where(Cliente.activo.is_(True))
    if buscar:
        # Por nombre de la sociedad, o por nombre, nº de cliente o CIF de cualquiera de sus centros
        texto = f"%{buscar}%"
        centros = select(CentroTrabajo.cliente_id).where(
            CentroTrabajo.activo.is_(True),
            or_(CentroTrabajo.nombre.ilike(texto), CentroTrabajo.codigo.ilike(texto), CentroTrabajo.cif.ilike(texto)),
        )
        consulta = consulta.where(or_(Cliente.nombre.ilike(texto), Cliente.id.in_(centros)))
    clientes = db.scalars(consulta).all()
    if not clientes:
        return []

    # Contadores de todas las carpetas en una sola consulta
    ids = [c.id for c in clientes]
    contadores = _contadores(db, Actividad.cliente_id, ids)
    num_centros = dict(
        db.execute(
            select(CentroTrabajo.cliente_id, func.count())
            .where(CentroTrabajo.cliente_id.in_(ids), CentroTrabajo.activo.is_(True))
            .group_by(CentroTrabajo.cliente_id)
        ).all()
    )

    resultado = []
    for cliente in clientes:
        faltan, atrasadas, hechas = contadores.get(cliente.id, (0, 0, 0))
        datos = ClienteLeer.model_validate(cliente)
        resultado.append(
            datos.model_copy(
                update={"faltan": faltan, "atrasadas": atrasadas, "hechas": hechas, "num_centros": num_centros.get(cliente.id, 0)}
            )
        )
    return resultado


@router.post("", response_model=ClienteLeer, status_code=status.HTTP_201_CREATED)
def crear_cliente(datos: ClienteCrear, db: Session = Depends(get_db), usuario: Usuario = Depends(usuario_actual)):
    if usuario.rol == Rol.TECNICO:
        tecnico_id = usuario.id  # un técnico solo puede crear clientes para sí mismo
    elif datos.tecnico_id is None:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Indica el técnico (tecnico_id)")
    else:
        tecnico_id = datos.tecnico_id
        _comprobar_tecnico(db, tecnico_id)
    del_centro = {"centro_nombre", "codigo", "cif", "direccion"}
    cliente = Cliente(**datos.model_dump(exclude={"tecnico_id"} | del_centro), tecnico_id=tecnico_id)
    db.add(cliente)
    db.flush()
    # Toda sociedad empieza con un centro de trabajo, con su nº de cliente, CIF y dirección
    db.add(
        CentroTrabajo(
            cliente_id=cliente.id,
            nombre=(datos.centro_nombre or "").strip() or "Centro principal",
            codigo=datos.codigo,
            cif=datos.cif,
            direccion=datos.direccion,
        )
    )
    db.commit()
    db.refresh(cliente)
    return cliente


@router.get("/{cliente_id}", response_model=ClienteLeer)
def ver_cliente(cliente_id: int, db: Session = Depends(get_db), usuario: Usuario = Depends(usuario_actual)):
    return comprobar_cliente(usuario, db.get(Cliente, cliente_id))


@router.patch("/{cliente_id}", response_model=ClienteLeer)
def editar_cliente(
    cliente_id: int, datos: ClienteEditar, db: Session = Depends(get_db), usuario: Usuario = Depends(usuario_actual)
):
    cliente = comprobar_cliente(usuario, db.get(Cliente, cliente_id))
    cambios = datos.model_dump(exclude_unset=True)
    if "tecnico_id" in cambios:
        if usuario.rol != Rol.ADMIN:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Solo un administrador puede reasignar clientes")
        _comprobar_tecnico(db, cambios["tecnico_id"])
    for campo, valor in cambios.items():
        setattr(cliente, campo, valor)
    db.commit()
    db.refresh(cliente)
    return cliente


# ---------- Actividades obligatorias del contrato ----------

def _obligatoria_leer(linea: ActividadObligatoria) -> ObligatoriaLeer:
    return ObligatoriaLeer(
        id=linea.id,
        cliente_id=linea.cliente_id,
        centro_id=linea.centro_id,
        centro_nombre=linea.centro.nombre if linea.centro else None,
        tipo_actividad_id=linea.tipo_actividad_id,
        tipo_nombre=linea.tipo.nombre,
        desde_anio=linea.desde_anio,
        activa=linea.activa,
    )


@router.get("/{cliente_id}/obligatorias", response_model=list[ObligatoriaLeer])
def listar_obligatorias(
    cliente_id: int,
    centro_id: int | None = None,
    db: Session = Depends(get_db),
    usuario: Usuario = Depends(usuario_actual),
):
    """Contrato del cliente; con `centro_id`, solo el de ese centro."""
    cliente = comprobar_cliente(usuario, db.get(Cliente, cliente_id))
    return [
        _obligatoria_leer(linea)
        for linea in cliente.obligatorias
        if centro_id is None or linea.centro_id == centro_id
    ]


@router.post("/{cliente_id}/obligatorias", response_model=ObligatoriaLeer, status_code=status.HTTP_201_CREATED)
def anadir_obligatoria(
    cliente_id: int, datos: ObligatoriaCrear, db: Session = Depends(get_db), usuario: Usuario = Depends(usuario_actual)
):
    """Añade al contrato de un centro una actividad que necesita cada año."""
    cliente = comprobar_cliente(usuario, db.get(Cliente, cliente_id))
    tipo = db.get(TipoActividad, datos.tipo_actividad_id)
    if tipo is None or not tipo.activo:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Tipo de actividad no encontrado")
    centro = buscar_centro(db, cliente, datos.centro_id)
    linea = db.scalar(
        select(ActividadObligatoria).where(
            ActividadObligatoria.centro_id == centro.id,
            ActividadObligatoria.tipo_actividad_id == tipo.id,
        )
    )
    if linea and linea.activa:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Esta actividad ya está en el contrato de este centro")
    desde = datos.desde_anio or hoy().year
    if linea:  # estaba desactivada: se vuelve a activar
        linea.activa = True
        linea.desde_anio = desde
    else:
        linea = ActividadObligatoria(
            cliente_id=cliente.id, centro_id=centro.id, tipo_actividad_id=tipo.id, desde_anio=desde
        )
        db.add(linea)
    db.commit()
    db.refresh(linea)
    return _obligatoria_leer(linea)


@router.delete("/{cliente_id}/obligatorias/{obligatoria_id}", status_code=status.HTTP_204_NO_CONTENT)
def quitar_obligatoria(
    cliente_id: int, obligatoria_id: int, db: Session = Depends(get_db), usuario: Usuario = Depends(usuario_actual)
):
    """Quita la actividad del contrato. No borra las actividades de años anteriores."""
    comprobar_cliente(usuario, db.get(Cliente, cliente_id))
    linea = db.get(ActividadObligatoria, obligatoria_id)
    if linea is None or linea.cliente_id != cliente_id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Línea de contrato no encontrada")
    linea.activa = False
    db.commit()


# ---------- Centros de trabajo (las subcarpetas del cliente) ----------

def buscar_centro(db: Session, cliente: Cliente, centro_id: int | None) -> CentroTrabajo:
    """El centro indicado (si es de este cliente) o, si no se indica, el primero del cliente."""
    if centro_id is None:
        return centro_principal(db, cliente)
    centro = db.get(CentroTrabajo, centro_id)
    if centro is None or centro.cliente_id != cliente.id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Centro de trabajo no encontrado")
    return centro


def _centro_leer(centro: CentroTrabajo, contadores: dict) -> CentroLeer:
    faltan, atrasadas, hechas = contadores.get(centro.id, (0, 0, 0))
    datos = CentroLeer.model_validate(centro)
    return datos.model_copy(update={"faltan": faltan, "atrasadas": atrasadas, "hechas": hechas})


@router.get("/{cliente_id}/centros", response_model=list[CentroLeer])
def listar_centros(cliente_id: int, db: Session = Depends(get_db), usuario: Usuario = Depends(usuario_actual)):
    """Centros del cliente, cada uno con lo que le falta y lo que tiene hecho."""
    cliente = comprobar_cliente(usuario, db.get(Cliente, cliente_id))
    centro_principal(db, cliente)  # por si es un cliente antiguo sin centros
    generar_obligatorias(db, usuario, hoy().year)
    centros = [c for c in cliente.centros if c.activo]
    contadores = _contadores(db, Actividad.centro_id, [c.id for c in centros])
    return [_centro_leer(c, contadores) for c in centros]


@router.post("/{cliente_id}/centros", response_model=CentroLeer, status_code=status.HTTP_201_CREATED)
def crear_centro(
    cliente_id: int, datos: CentroCrear, db: Session = Depends(get_db), usuario: Usuario = Depends(usuario_actual)
):
    cliente = comprobar_cliente(usuario, db.get(Cliente, cliente_id))
    centro = CentroTrabajo(
        cliente_id=cliente.id,
        nombre=datos.nombre.strip(),
        codigo=datos.codigo,
        cif=datos.cif,
        direccion=datos.direccion,
    )
    db.add(centro)
    db.commit()
    db.refresh(centro)
    return _centro_leer(centro, {})


@router.patch("/{cliente_id}/centros/{centro_id}", response_model=CentroLeer)
def editar_centro(
    cliente_id: int,
    centro_id: int,
    datos: CentroEditar,
    db: Session = Depends(get_db),
    usuario: Usuario = Depends(usuario_actual),
):
    """Cambia el nombre o la dirección. Con `activo: false` el centro deja de mostrarse."""
    cliente = comprobar_cliente(usuario, db.get(Cliente, cliente_id))
    centro = buscar_centro(db, cliente, centro_id)
    for campo, valor in datos.model_dump(exclude_unset=True).items():
        setattr(centro, campo, valor)
    db.commit()
    db.refresh(centro)
    return _centro_leer(centro, _contadores(db, Actividad.centro_id, [centro.id]))
