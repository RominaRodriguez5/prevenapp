"""Días de guardia de cada técnico. Si existe la fila, ese día tiene guardia."""
from datetime import date

from sqlalchemy import Date, ForeignKey, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class Guardia(Base):
    __tablename__ = "guardias"
    __table_args__ = (UniqueConstraint("tecnico_id", "fecha", name="uq_guardia_tecnico_fecha"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    tecnico_id: Mapped[int] = mapped_column(ForeignKey("usuarios.id"), index=True)
    fecha: Mapped[date] = mapped_column(Date, index=True)
