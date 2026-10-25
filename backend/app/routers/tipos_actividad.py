"""Catálogo de tipos de actividad y porcentaje de incentivo de cada uno."""
from decimal import Decimal

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.database import get_db
from app.deps import solo_admin, usuario_actual
from app.models import TipoActividad
from app.schemas.actividad import TipoActividadCrear, TipoActividadEditar, TipoActividadLeer

router = APIRouter(prefix="/tipos-actividad", tags=["Tipos de actividad"])


@router.get("", response_model=list[TipoActividadLeer], dependencies=[Depends(usuario_actual)])
def listar_tipos(incluir_inactivos: bool = False, db: Session = Depends(get_db)):
    consulta = select(TipoActividad).order_by(TipoActividad.nombre)
    if not incluir_inactivos:
        consulta = consulta.where(TipoActividad.activo.is_(True))
    return db.scalars(consulta).all()


@router.post("", response_model=TipoActividadLeer, status_code=status.HTTP_201_CREATED, dependencies=[Depends(solo_admin)])
def crear_tipo(datos: TipoActividadCrear, db: Session = Depends(get_db)):
    if db.scalar(select(TipoActividad).where(TipoActividad.nombre == datos.nombre)):
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Ya existe un tipo de actividad con ese nombre")
    tipo = TipoActividad(
        nombre=datos.nombre,
        descripcion=datos.descripcion,
        porcentaje_captador=Decimal(str(datos.porcentaje_captador)),
        porcentaje_redactor=Decimal(str(datos.porcentaje_redactor)),
    )
    db.add(tipo)
    db.commit()
    db.refresh(tipo)
    return tipo


@router.patch("/{tipo_id}", response_model=TipoActividadLeer, dependencies=[Depends(solo_admin)])
def editar_tipo(tipo_id: int, datos: TipoActividadEditar, db: Session = Depends(get_db)):
    """Cambiar el porcentaje solo afecta a las actividades que se realicen a partir de ahora."""
    tipo = db.get(TipoActividad, tipo_id)
    if tipo is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Tipo de actividad no encontrado")
    for campo, valor in datos.model_dump(exclude_unset=True).items():
        if campo.startswith("porcentaje_") and valor is not None:
            valor = Decimal(str(valor))
        setattr(tipo, campo, valor)
    db.commit()
    db.refresh(tipo)
    return tipo
