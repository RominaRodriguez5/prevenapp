"""Crea la tabla de usuarios

Revision ID: 0001
Revises:
Create Date: 2026-10-23
"""
from alembic import op
import sqlalchemy as sa

revision = "0001"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "usuarios",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("nombre", sa.String(100), nullable=False),
        sa.Column("email", sa.String(255), nullable=False),
        sa.Column("password_hash", sa.String(255), nullable=False),
        sa.Column("rol", sa.Enum("TECNICO", "PRESUPUESTOS", "ADMIN", name="rol", native_enum=False, length=20), nullable=False),
        sa.Column("activo", sa.Boolean(), nullable=False),
        sa.Column("creado_en", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )
    op.create_index("ix_usuarios_email", "usuarios", ["email"], unique=True)


def downgrade() -> None:
    op.drop_index("ix_usuarios_email", table_name="usuarios")
    op.drop_table("usuarios")
