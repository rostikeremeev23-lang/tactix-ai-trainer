"""Add TACTIX BRANCH planning variants and immutable branch events."""
from alembic import op
import sqlalchemy as sa

revision = "0007_thread_branches"
down_revision = "0006_thread_relations"
branch_labels = depends_on = None


def upgrade():
    op.create_table(
        "thread_branches",
        sa.Column("id", sa.Uuid(), primary_key=True),
        sa.Column("organization_id", sa.Uuid(), sa.ForeignKey("organizations.id"), nullable=False),
        sa.Column("case_id", sa.Uuid(), sa.ForeignKey("thread_cases.id"), nullable=False),
        sa.Column("created_by", sa.Uuid(), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("name", sa.String(160), nullable=False),
        sa.Column("description", sa.String(2000), nullable=False, server_default=""),
        sa.Column("status", sa.String(16), nullable=False, server_default="DRAFT"),
        sa.Column("base_case_revision", sa.Integer(), nullable=False),
        sa.Column("revision", sa.Integer(), nullable=False, server_default="1"),
        sa.Column("base_snapshot", sa.JSON(), nullable=False),
        sa.Column("draft_snapshot", sa.JSON(), nullable=False),
        sa.Column("merged_by", sa.Uuid(), sa.ForeignKey("users.id"), nullable=True),
        sa.Column("merged_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )
    op.create_index("ix_thread_branches_case", "thread_branches", ["organization_id", "case_id"])
    op.create_index("ix_thread_branches_status", "thread_branches", ["organization_id", "status"])
    op.create_table(
        "thread_branch_events",
        sa.Column("id", sa.Uuid(), primary_key=True),
        sa.Column("branch_id", sa.Uuid(), sa.ForeignKey("thread_branches.id"), nullable=False),
        sa.Column("revision", sa.Integer(), nullable=False),
        sa.Column("request_id", sa.Uuid(), nullable=False),
        sa.Column("request_hash", sa.String(64), nullable=False),
        sa.Column("type", sa.String(32), nullable=False),
        sa.Column("actor_id", sa.Uuid(), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("details", sa.JSON(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.UniqueConstraint("branch_id", "revision", name="uq_thread_branch_event_revision"),
        sa.UniqueConstraint("branch_id", "request_id", name="uq_thread_branch_event_request"),
    )
    op.create_index("ix_thread_branch_events_branch_id", "thread_branch_events", ["branch_id"])


def downgrade():
    op.drop_table("thread_branch_events")
    op.drop_table("thread_branches")
