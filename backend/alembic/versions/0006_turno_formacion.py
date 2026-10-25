"""Turno de la formación (mañana, tarde, extra mañana, extra tarde)

Revision ID: 0006
Revises: 0005
Create Date: 2026-10-24
"""
from alembic import op
import sqlalchemy as sa


revision = "0006"
down_revision = "0005"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column('registros', sa.Column('turno', sa.Enum('MANANA', 'TARDE', 'EXTRA_MANANA', 'EXTRA_TARDE', name='turnoformacion', native_enum=False, length=20), nullable=True))
    # La formación que ya estaba apuntada: mañana entre semana y extra mañana en fin de semana
    op.execute(
        "UPDATE registros SET turno = CASE WHEN EXTRACT(ISODOW FROM fecha) >= 6 "
        "THEN 'EXTRA_MANANA' ELSE 'MANANA' END WHERE tipo = 'FORMACION'"
    )


def downgrade() -> None:
    op.drop_column('registros', 'turno')
