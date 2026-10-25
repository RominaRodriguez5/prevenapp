"""Hora y lugar de las visitas, y registro de km y horas de formación

Revision ID: 0004
Revises: 0003
Create Date: 2026-10-24
"""
from alembic import op
import sqlalchemy as sa


revision = "0004"
down_revision = "0003"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table('registros',
    sa.Column('id', sa.Integer(), nullable=False),
    sa.Column('tecnico_id', sa.Integer(), nullable=False),
    sa.Column('fecha', sa.Date(), nullable=False),
    sa.Column('tipo', sa.Enum('KILOMETROS', 'FORMACION', name='tiporegistro', native_enum=False, length=20), nullable=False),
    sa.Column('cantidad', sa.Numeric(precision=8, scale=2), nullable=False),
    sa.Column('concepto', sa.String(length=255), nullable=True),
    sa.Column('creado_en', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
    sa.ForeignKeyConstraint(['tecnico_id'], ['usuarios.id'], ),
    sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_registros_fecha'), 'registros', ['fecha'], unique=False)
    op.create_index(op.f('ix_registros_tecnico_id'), 'registros', ['tecnico_id'], unique=False)
    op.add_column('actividades', sa.Column('hora_programada', sa.Time(), nullable=True))
    op.add_column('actividades', sa.Column('lugar', sa.String(length=255), nullable=True))


def downgrade() -> None:
    op.drop_column('actividades', 'lugar')
    op.drop_column('actividades', 'hora_programada')
    op.drop_index(op.f('ix_registros_tecnico_id'), table_name='registros')
    op.drop_index(op.f('ix_registros_fecha'), table_name='registros')
    op.drop_table('registros')
