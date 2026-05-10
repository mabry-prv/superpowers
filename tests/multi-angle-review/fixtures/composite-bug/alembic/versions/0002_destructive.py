"""rename display_name -> full_name and make NOT NULL"""
from alembic import op
import sqlalchemy as sa

revision = "0002"
down_revision = "0001"

def upgrade() -> None:
    # BUG: combines rename + NOT NULL in one shot
    # Old code reading users.display_name will crash; rows with NULL violate constraint
    op.alter_column("users", "display_name", new_column_name="full_name", nullable=False)

def downgrade() -> None:
    op.alter_column("users", "full_name", new_column_name="display_name", nullable=True)
