"""Crea las tablas de clientes, tipos de actividad, actividades, contrato, guardias y avisos

Revision ID: 0002
Revises: 0001
Create Date: 2026-10-23
"""
from alembic import op
import sqlalchemy as sa


revision = "0002"
down_revision = "0001"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table('tipos_actividad',
    sa.Column('id', sa.Integer(), nullable=False),
    sa.Column('nombre', sa.String(length=150), nullable=False),
    sa.Column('descripcion', sa.Text(), nullable=True),
    sa.Column('incentivo_captador', sa.Numeric(precision=10, scale=2), nullable=False),
    sa.Column('incentivo_redactor', sa.Numeric(precision=10, scale=2), nullable=False),
    sa.Column('activo', sa.Boolean(), nullable=False),
    sa.PrimaryKeyConstraint('id'),
    sa.UniqueConstraint('nombre')
    )
    op.create_table('clientes',
    sa.Column('id', sa.Integer(), nullable=False),
    sa.Column('nombre', sa.String(length=150), nullable=False),
    sa.Column('cif', sa.String(length=20), nullable=True),
    sa.Column('direccion', sa.String(length=255), nullable=True),
    sa.Column('telefono', sa.String(length=30), nullable=True),
    sa.Column('email', sa.String(length=255), nullable=True),
    sa.Column('persona_contacto', sa.String(length=100), nullable=True),
    sa.Column('notas', sa.Text(), nullable=True),
    sa.Column('tecnico_id', sa.Integer(), nullable=False),
    sa.Column('activo', sa.Boolean(), nullable=False),
    sa.Column('creado_en', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
    sa.ForeignKeyConstraint(['tecnico_id'], ['usuarios.id'], ),
    sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_clientes_tecnico_id'), 'clientes', ['tecnico_id'], unique=False)
    op.create_table('guardias',
    sa.Column('id', sa.Integer(), nullable=False),
    sa.Column('tecnico_id', sa.Integer(), nullable=False),
    sa.Column('fecha', sa.Date(), nullable=False),
    sa.ForeignKeyConstraint(['tecnico_id'], ['usuarios.id'], ),
    sa.PrimaryKeyConstraint('id'),
    sa.UniqueConstraint('tecnico_id', 'fecha', name='uq_guardia_tecnico_fecha')
    )
    op.create_index(op.f('ix_guardias_fecha'), 'guardias', ['fecha'], unique=False)
    op.create_index(op.f('ix_guardias_tecnico_id'), 'guardias', ['tecnico_id'], unique=False)
    op.create_table('actividades',
    sa.Column('id', sa.Integer(), nullable=False),
    sa.Column('cliente_id', sa.Integer(), nullable=False),
    sa.Column('tipo_actividad_id', sa.Integer(), nullable=False),
    sa.Column('anio', sa.Integer(), nullable=False),
    sa.Column('obligatoria', sa.Boolean(), nullable=False),
    sa.Column('estado', sa.Enum('PENDIENTE', 'PROGRAMADA', 'REALIZADA', name='estadoactividad', native_enum=False, length=20), nullable=False),
    sa.Column('fecha_programada', sa.Date(), nullable=True),
    sa.Column('fecha_realizacion', sa.Date(), nullable=True),
    sa.Column('codigo_presupuesto', sa.String(length=50), nullable=True),
    sa.Column('captador_id', sa.Integer(), nullable=True),
    sa.Column('redactor_id', sa.Integer(), nullable=True),
    sa.Column('importe_captador', sa.Numeric(precision=10, scale=2), nullable=True),
    sa.Column('importe_redactor', sa.Numeric(precision=10, scale=2), nullable=True),
    sa.Column('notas', sa.Text(), nullable=True),
    sa.Column('realizada_en', sa.DateTime(timezone=True), nullable=True),
    sa.Column('creado_en', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
    sa.ForeignKeyConstraint(['captador_id'], ['usuarios.id'], ),
    sa.ForeignKeyConstraint(['cliente_id'], ['clientes.id'], ),
    sa.ForeignKeyConstraint(['redactor_id'], ['usuarios.id'], ),
    sa.ForeignKeyConstraint(['tipo_actividad_id'], ['tipos_actividad.id'], ),
    sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_actividades_anio'), 'actividades', ['anio'], unique=False)
    op.create_index(op.f('ix_actividades_cliente_id'), 'actividades', ['cliente_id'], unique=False)
    op.create_index(op.f('ix_actividades_estado'), 'actividades', ['estado'], unique=False)
    op.create_index(op.f('ix_actividades_fecha_realizacion'), 'actividades', ['fecha_realizacion'], unique=False)
    op.create_table('actividades_obligatorias',
    sa.Column('id', sa.Integer(), nullable=False),
    sa.Column('cliente_id', sa.Integer(), nullable=False),
    sa.Column('tipo_actividad_id', sa.Integer(), nullable=False),
    sa.Column('desde_anio', sa.Integer(), nullable=False),
    sa.Column('activa', sa.Boolean(), nullable=False),
    sa.ForeignKeyConstraint(['cliente_id'], ['clientes.id'], ),
    sa.ForeignKeyConstraint(['tipo_actividad_id'], ['tipos_actividad.id'], ),
    sa.PrimaryKeyConstraint('id'),
    sa.UniqueConstraint('cliente_id', 'tipo_actividad_id', name='uq_obligatoria_cliente_tipo')
    )
    op.create_index(op.f('ix_actividades_obligatorias_cliente_id'), 'actividades_obligatorias', ['cliente_id'], unique=False)
    op.create_table('avisos',
    sa.Column('id', sa.Integer(), nullable=False),
    sa.Column('actividad_id', sa.Integer(), nullable=False),
    sa.Column('destinatarios', sa.Text(), nullable=False),
    sa.Column('asunto', sa.String(length=255), nullable=False),
    sa.Column('cuerpo', sa.Text(), nullable=False),
    sa.Column('enviado', sa.Boolean(), nullable=False),
    sa.Column('error', sa.Text(), nullable=True),
    sa.Column('creado_en', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
    sa.ForeignKeyConstraint(['actividad_id'], ['actividades.id'], ),
    sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_avisos_actividad_id'), 'avisos', ['actividad_id'], unique=False)


def downgrade() -> None:
    op.drop_index(op.f('ix_avisos_actividad_id'), table_name='avisos')
    op.drop_table('avisos')
    op.drop_index(op.f('ix_actividades_obligatorias_cliente_id'), table_name='actividades_obligatorias')
    op.drop_table('actividades_obligatorias')
    op.drop_index(op.f('ix_actividades_fecha_realizacion'), table_name='actividades')
    op.drop_index(op.f('ix_actividades_estado'), table_name='actividades')
    op.drop_index(op.f('ix_actividades_cliente_id'), table_name='actividades')
    op.drop_index(op.f('ix_actividades_anio'), table_name='actividades')
    op.drop_table('actividades')
    op.drop_index(op.f('ix_guardias_tecnico_id'), table_name='guardias')
    op.drop_index(op.f('ix_guardias_fecha'), table_name='guardias')
    op.drop_table('guardias')
    op.drop_index(op.f('ix_clientes_tecnico_id'), table_name='clientes')
    op.drop_table('clientes')
    op.drop_table('tipos_actividad')
