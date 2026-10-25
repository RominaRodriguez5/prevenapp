"""Nº de cliente y CIF en cada centro; actividades enlazadas a su línea de contrato

Cada centro es un cliente en sí (con su nº de cliente, CIF y dirección); la sociedad es
la carpeta. El nº de cliente y el CIF que tenía la sociedad pasan a su primer centro.

Revision ID: 0009
Revises: 0008
Create Date: 2026-10-25
"""
from alembic import op
import sqlalchemy as sa


revision = "0009"
down_revision = "0008"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("centros_trabajo", sa.Column("codigo", sa.String(length=30), nullable=True))
    op.add_column("centros_trabajo", sa.Column("cif", sa.String(length=20), nullable=True))
    op.create_index("ix_centros_trabajo_codigo", "centros_trabajo", ["codigo"])
    # El nº de cliente y el CIF de la sociedad pasan a su primer centro
    op.execute(
        "UPDATE centros_trabajo SET codigo = (SELECT c.codigo FROM clientes c WHERE c.id = centros_trabajo.cliente_id), "
        "cif = (SELECT c.cif FROM clientes c WHERE c.id = centros_trabajo.cliente_id) "
        "WHERE id IN (SELECT MIN(id) FROM centros_trabajo GROUP BY cliente_id)"
    )

    op.add_column(
        "actividades",
        sa.Column("linea_id", sa.Integer(), sa.ForeignKey("actividades_obligatorias.id"), nullable=True),
    )
    op.create_index("ix_actividades_linea_id", "actividades", ["linea_id"])
    # Las obligatorias que ya existen se enlazan con su línea de contrato (mismo centro y tipo)
    op.execute(
        "UPDATE actividades SET linea_id = (SELECT o.id FROM actividades_obligatorias o "
        "WHERE o.centro_id = actividades.centro_id AND o.tipo_actividad_id = actividades.tipo_actividad_id) "
        "WHERE obligatoria = true"
    )


def downgrade() -> None:
    op.drop_index("ix_actividades_linea_id", table_name="actividades")
    op.drop_column("actividades", "linea_id")
    op.drop_index("ix_centros_trabajo_codigo", table_name="centros_trabajo")
    op.drop_column("centros_trabajo", "cif")
    op.drop_column("centros_trabajo", "codigo")
