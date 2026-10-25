"""Centros de trabajo de cada cliente

Cada cliente existente recibe un "Centro principal" (con su dirección) y sus líneas de
contrato y actividades pasan a ese centro, para no perder nada.

Revision ID: 0008
Revises: 0007
Create Date: 2026-10-25
"""
from alembic import op
import sqlalchemy as sa


revision = "0008"
down_revision = "0007"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "centros_trabajo",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("cliente_id", sa.Integer(), sa.ForeignKey("clientes.id"), nullable=False),
        sa.Column("nombre", sa.String(length=150), nullable=False),
        sa.Column("direccion", sa.String(length=255), nullable=True),
        sa.Column("activo", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column("creado_en", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )
    op.create_index("ix_centros_trabajo_cliente_id", "centros_trabajo", ["cliente_id"])

    op.add_column("actividades_obligatorias", sa.Column("centro_id", sa.Integer(), sa.ForeignKey("centros_trabajo.id"), nullable=True))
    op.create_index("ix_actividades_obligatorias_centro_id", "actividades_obligatorias", ["centro_id"])
    op.add_column("actividades", sa.Column("centro_id", sa.Integer(), sa.ForeignKey("centros_trabajo.id"), nullable=True))
    op.create_index("ix_actividades_centro_id", "actividades", ["centro_id"])

    # Un "Centro principal" por cliente, y todo lo que ya había pasa a ese centro
    op.execute(
        "INSERT INTO centros_trabajo (cliente_id, nombre, direccion, activo) "
        "SELECT id, 'Centro principal', direccion, true FROM clientes"
    )
    for tabla in ("actividades_obligatorias", "actividades"):
        op.execute(
            f"UPDATE {tabla} SET centro_id = (SELECT MIN(c.id) FROM centros_trabajo c "
            f"WHERE c.cliente_id = {tabla}.cliente_id)"
        )

    # El contrato ahora va por centro: la misma actividad puede estar en varios centros
    op.drop_constraint("uq_obligatoria_cliente_tipo", "actividades_obligatorias", type_="unique")
    op.create_unique_constraint("uq_obligatoria_centro_tipo", "actividades_obligatorias", ["centro_id", "tipo_actividad_id"])


def downgrade() -> None:
    op.drop_constraint("uq_obligatoria_centro_tipo", "actividades_obligatorias", type_="unique")
    op.create_unique_constraint("uq_obligatoria_cliente_tipo", "actividades_obligatorias", ["cliente_id", "tipo_actividad_id"])
    op.drop_index("ix_actividades_centro_id", table_name="actividades")
    op.drop_column("actividades", "centro_id")
    op.drop_index("ix_actividades_obligatorias_centro_id", table_name="actividades_obligatorias")
    op.drop_column("actividades_obligatorias", "centro_id")
    op.drop_index("ix_centros_trabajo_cliente_id", table_name="centros_trabajo")
    op.drop_table("centros_trabajo")
