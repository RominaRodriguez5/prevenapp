"""El incentivo pasa a ser un porcentaje del importe del presupuesto

Revision ID: 0003
Revises: 0002
Create Date: 2026-10-24
"""
from alembic import op
import sqlalchemy as sa

revision = "0003"
down_revision = "0002"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Tipos de actividad: de importe fijo a porcentaje (8 % por defecto)
    op.drop_column("tipos_actividad", "incentivo_captador")
    op.drop_column("tipos_actividad", "incentivo_redactor")
    op.add_column(
        "tipos_actividad",
        sa.Column("porcentaje_captador", sa.Numeric(precision=5, scale=2), server_default="8", nullable=False),
    )
    op.add_column(
        "tipos_actividad",
        sa.Column("porcentaje_redactor", sa.Numeric(precision=5, scale=2), server_default="8", nullable=False),
    )
    # Actividades: importe del presupuesto sin IVA
    op.add_column("actividades", sa.Column("importe_presupuesto", sa.Numeric(precision=10, scale=2), nullable=True))


def downgrade() -> None:
    op.drop_column("actividades", "importe_presupuesto")
    op.drop_column("tipos_actividad", "porcentaje_redactor")
    op.drop_column("tipos_actividad", "porcentaje_captador")
    op.add_column(
        "tipos_actividad",
        sa.Column("incentivo_redactor", sa.Numeric(precision=10, scale=2), server_default="0", nullable=False),
    )
    op.add_column(
        "tipos_actividad",
        sa.Column("incentivo_captador", sa.Numeric(precision=10, scale=2), server_default="0", nullable=False),
    )
