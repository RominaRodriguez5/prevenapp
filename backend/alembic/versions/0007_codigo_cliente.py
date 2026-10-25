"""Código del cliente (para las carpetas de clientes)

Revision ID: 0007
Revises: 0006
Create Date: 2026-10-25
"""
from alembic import op
import sqlalchemy as sa


revision = "0007"
down_revision = "0006"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("clientes", sa.Column("codigo", sa.String(length=30), nullable=True))
    op.create_index("ix_clientes_codigo", "clientes", ["codigo"])


def downgrade() -> None:
    op.drop_index("ix_clientes_codigo", table_name="clientes")
    op.drop_column("clientes", "codigo")
