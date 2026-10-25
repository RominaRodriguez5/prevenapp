"""Registro mensual de kilómetros y horas de formación de cada técnico."""
import csv
import io
from datetime import date, timedelta
from decimal import Decimal

from fastapi import APIRouter, Depends, HTTPException, Query, status
from fastapi.responses import StreamingResponse
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.fechas import hoy
from app.core.permisos import ve_todo
from app.database import get_db
from app.deps import usuario_actual
from app.models import Registro, TipoRegistro, TurnoFormacion, Usuario
from app.routers.agenda import _tecnico_objetivo
from app.schemas.registro import RegistroCrear, RegistroLeer, RegistroMes

router = APIRouter(prefix="/registros", tags=["Registro de km y formación"])

NOMBRE_TURNO = {
    TurnoFormacion.MANANA: "Mañana",
    TurnoFormacion.TARDE: "Tarde",
    TurnoFormacion.EXTRA_MANANA: "Extra mañana",
    TurnoFormacion.EXTRA_TARDE: "Extra tarde",
}


def _rango_mes(anio: int, mes: int) -> tuple[date, date]:
    inicio = date(anio, mes, 1)
    siguiente = date(anio + 1, 1, 1) if mes == 12 else date(anio, mes + 1, 1)
    return inicio, siguiente - timedelta(days=1)


def _del_mes(db: Session, tecnico_id: int, anio: int, mes: int) -> list[Registro]:
    inicio, fin = _rango_mes(anio, mes)
    return list(
        db.scalars(
            select(Registro)
            .where(Registro.tecnico_id == tecnico_id, Registro.fecha.between(inicio, fin))
            .order_by(Registro.fecha, Registro.id)
        )
    )


def _total(registros: list[Registro], tipo: TipoRegistro) -> float:
    return float(sum((r.cantidad for r in registros if r.tipo == tipo), Decimal(0)))


@router.get("", response_model=RegistroMes)
def registros_del_mes(
    anio: int = Query(default_factory=lambda: hoy().year),
    mes: int = Query(default_factory=lambda: hoy().month, ge=1, le=12),
    tecnico_id: int | None = None,
    db: Session = Depends(get_db),
    usuario: Usuario = Depends(usuario_actual),
):
    """Registros de un mes con los totales de km y horas de formación."""
    tecnico = _tecnico_objetivo(db, usuario, tecnico_id)
    registros = _del_mes(db, tecnico.id, anio, mes)
    return RegistroMes(
        tecnico_id=tecnico.id,
        tecnico_nombre=tecnico.nombre,
        anio=anio,
        mes=mes,
        total_km=_total(registros, TipoRegistro.KILOMETROS),
        total_horas_formacion=_total(registros, TipoRegistro.FORMACION),
        horas_por_turno={
            turno.value: float(sum((r.cantidad for r in registros if r.turno == turno), Decimal(0)))
            for turno in TurnoFormacion
        },
        dias_con_registro=len({r.fecha for r in registros}),
        registros=registros,
    )


@router.post("", response_model=RegistroLeer, status_code=status.HTTP_201_CREATED)
def crear_registro(datos: RegistroCrear, db: Session = Depends(get_db), usuario: Usuario = Depends(usuario_actual)):
    if datos.fecha > hoy():
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="No se pueden registrar días futuros")
    registro = Registro(
        tecnico_id=usuario.id,
        fecha=datos.fecha,
        tipo=datos.tipo,
        cantidad=Decimal(str(datos.cantidad)),
        concepto=(datos.concepto or "").strip() or None,
        turno=datos.turno,
    )
    db.add(registro)
    db.commit()
    db.refresh(registro)
    return registro


@router.delete("/{registro_id}", status_code=status.HTTP_204_NO_CONTENT)
def borrar_registro(registro_id: int, db: Session = Depends(get_db), usuario: Usuario = Depends(usuario_actual)):
    registro = db.get(Registro, registro_id)
    if registro is None or (registro.tecnico_id != usuario.id and not ve_todo(usuario)):
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Registro no encontrado")
    db.delete(registro)
    db.commit()


@router.get("/exportar")
def exportar_csv(
    anio: int = Query(default_factory=lambda: hoy().year),
    mes: int = Query(default_factory=lambda: hoy().month, ge=1, le=12),
    tecnico_id: int | None = None,
    db: Session = Depends(get_db),
    usuario: Usuario = Depends(usuario_actual),
):
    """Descarga el registro del mes en CSV (se abre con Excel) para entregarlo.

    Usa punto y coma y coma decimal, que es lo que espera Excel en español.
    """
    tecnico = _tecnico_objetivo(db, usuario, tecnico_id)
    registros = _del_mes(db, tecnico.id, anio, mes)
    salida = io.StringIO()
    salida.write("﻿")  # para que Excel reconozca las tildes
    escritor = csv.writer(salida, delimiter=";")
    escritor.writerow(["Técnico", "Fecha", "Tipo", "Turno", "Cantidad", "Unidad", "Concepto"])
    for r in registros:
        es_km = r.tipo == TipoRegistro.KILOMETROS
        escritor.writerow([
            tecnico.nombre,
            r.fecha.strftime("%d/%m/%Y"),
            "Kilómetros" if es_km else "Formación",
            NOMBRE_TURNO.get(r.turno, ""),
            f"{r.cantidad:.2f}".replace(".", ","),
            "km" if es_km else "horas",
            r.concepto or "",
        ])
    escritor.writerow([])
    escritor.writerow(["TOTAL KM", "", "", "", f"{_total(registros, TipoRegistro.KILOMETROS):.2f}".replace(".", ","), "km", ""])
    for turno in TurnoFormacion:
        horas = sum((r.cantidad for r in registros if r.turno == turno), Decimal(0))
        escritor.writerow(["TOTAL FORMACIÓN", "", "", NOMBRE_TURNO[turno], f"{horas:.2f}".replace(".", ","), "horas", ""])
    escritor.writerow(["TOTAL FORMACIÓN", "", "", "Todas", f"{_total(registros, TipoRegistro.FORMACION):.2f}".replace(".", ","), "horas", ""])
    nombre = f"registro_{tecnico.nombre.split()[0].lower()}_{anio}_{mes:02d}.csv"
    return StreamingResponse(
        iter([salida.getvalue()]),
        media_type="text/csv; charset=utf-8",
        headers={"Content-Disposition": f'attachment; filename="{nombre}"'},
    )
