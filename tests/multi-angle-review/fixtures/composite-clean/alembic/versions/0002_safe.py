"""add full_name column (nullable for backward-compat); backfill"""
from alembic import op
import sqlalchemy as sa

revision = "0002"
down_revision = "0001"

def upgrade() -> None:
    op.add_column("users", sa.Column("full_name", sa.String(255), nullable=True))
    op.execute("UPDATE users SET full_name = display_name WHERE full_name IS NULL")

def downgrade() -> None:
    op.drop_column("users", "full_name")
