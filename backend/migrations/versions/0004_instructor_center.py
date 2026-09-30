"""Add optional instructor metadata; preserve all existing assignments."""
from alembic import op
import sqlalchemy as sa

revision = "0004_instructor_center"
down_revision = "0003_strategy_platform"
branch_labels = depends_on = None


def upgrade():
    for name in ("due_at", "submitted_at", "feedback_at"):
        op.add_column("strategy_assignments", sa.Column(name, sa.DateTime(timezone=True), nullable=True))
    op.add_column("strategy_assignments", sa.Column("history", sa.JSON(), nullable=True))


def downgrade():
    for name in ("history", "feedback_at", "submitted_at", "due_at"):
        op.drop_column("strategy_assignments", name)
