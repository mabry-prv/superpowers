"""drop display_name; make full_name NOT NULL (after code stops reading display_name)"""
from alembic import op
import sqlalchemy as sa

revision = "0003"
down_revision = "0002"

def upgrade() -> None:
    op.alter_column("users", "full_name", nullable=False)
    op.drop_column("users", "display_name")

def downgrade() -> None:
    op.add_column("users", sa.Column("display_name", sa.String(255), nullable=True))
    op.alter_column("users", "full_name", nullable=True)
    op.execute("UPDATE users SET display_name = full_name WHERE display_name IS NULL")
