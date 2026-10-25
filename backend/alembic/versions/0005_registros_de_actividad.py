"""Enlaza los registros de km y formación con la actividad del check

Revision ID: 0005
Revises: 0004
Create Date: 2026-10-24
"""
from alembic import op
import sqlalchemy as sa


revision = "0005"
down_revision = "0004"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column('registros', sa.Column('actividad_id', sa.Integer(), nullable=True))
    op.create_index(op.f('ix_registros_actividad_id'), 'registros', ['actividad_id'], unique=False)
    op.create_foreign_key("fk_registros_actividad_id", 'registros', 'actividades', ['actividad_id'], ['id'])


def downgrade() -> None:
    op.drop_constraint("fk_registros_actividad_id", 'registros', type_='foreignkey')
    op.drop_index(op.f('ix_registros_actividad_id'), table_name='registros')
    op.drop_column('registros', 'actividad_id')
