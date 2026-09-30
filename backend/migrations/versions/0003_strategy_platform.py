"""Add isolated Strategy records and assignments without changing legacy data."""
from alembic import op
import sqlalchemy as sa
revision = "0003_strategy_platform"
down_revision = "0002_invite_codes"
branch_labels = depends_on = None

def upgrade():
    op.create_table("strategy_records",
        sa.Column("owner_id", sa.Uuid(), sa.ForeignKey("users.id"), primary_key=True),
        sa.Column("client_id", sa.String(80), primary_key=True),
        sa.Column("organization_id", sa.Uuid(), sa.ForeignKey("organizations.id"), nullable=False),
        sa.Column("revision", sa.Integer(), nullable=False),
        sa.Column("deleted", sa.Boolean(), nullable=False),
        sa.Column("document", sa.JSON(), nullable=True),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False))
    op.create_index("ix_strategy_records_organization_id", "strategy_records", ["organization_id"])
    op.create_table("strategy_assignments",
        sa.Column("id", sa.Uuid(), primary_key=True),
        sa.Column("organization_id", sa.Uuid(), sa.ForeignKey("organizations.id"), nullable=False),
        sa.Column("instructor_id", sa.Uuid(), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("learner_id", sa.Uuid(), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("revision", sa.Integer(), nullable=False),
        sa.Column("scenario", sa.JSON(), nullable=False),
        sa.Column("status", sa.String(20), nullable=False),
        sa.Column("submission", sa.JSON(), nullable=True),
        sa.Column("metrics", sa.JSON(), nullable=True),
        sa.Column("feedback", sa.String(4000), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False))
    for field in ("organization_id", "instructor_id", "learner_id"):
        op.create_index("ix_strategy_assignments_"+field, "strategy_assignments", [field])

def downgrade():
    op.drop_table("strategy_assignments")
    op.drop_table("strategy_records")
