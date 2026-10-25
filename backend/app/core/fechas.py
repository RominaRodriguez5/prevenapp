"""Utilidades de fechas: año en curso, cuatrimestres y plazo de 5 años."""
from datetime import date, timedelta

# Una actividad obligatoria puede hacerse dentro de un margen de 5 años
# (el año que le toca y los 4 siguientes).
MARGEN_ANIOS = 5


def hoy() -> date:
    """Fecha de hoy. Está en una función para poder cambiarla en las pruebas."""
    return date.today()


def cuatrimestre_de(fecha: date) -> int:
    """1 = enero-abril, 2 = mayo-agosto, 3 = septiembre-diciembre."""
    return (fecha.month - 1) // 4 + 1


def rango_cuatrimestre(anio: int, cuatrimestre: int) -> tuple[date, date]:
    """Primer y último día de un cuatrimestre."""
    mes_inicio = (cuatrimestre - 1) * 4 + 1
    inicio = date(anio, mes_inicio, 1)
    fin = date(anio + 1, 1, 1) if cuatrimestre == 3 else date(anio, mes_inicio + 4, 1)
    return inicio, fin - timedelta(days=1)


def primer_anio_en_plazo(anio_actual: int) -> int:
    """Año más antiguo cuyas actividades todavía se pueden hacer."""
    return anio_actual - (MARGEN_ANIOS - 1)
