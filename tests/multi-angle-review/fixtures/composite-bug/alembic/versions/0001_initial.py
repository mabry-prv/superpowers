"""initial users table"""
from alembic import op
import sqlalchemy as sa

revision = "0001"
down_revision = None

def upgrade() -> None:
    op.create_table(
        "users",
        sa.Column("id", sa.Integer, primary_key=True),
        sa.Column("email", sa.String(255), nullable=False, unique=True),
        sa.Column("display_name", sa.String(255), nullable=True),
    )

def downgrade() -> None:
    op.drop_table("users")
