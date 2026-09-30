"""Add Case history and evidence without changing existing training records."""
from alembic import op
import sqlalchemy as sa

revision = "0005_thread_cases"
down_revision = "0004_instructor_center"
branch_labels = depends_on = None


def upgrade():
    op.create_table("thread_cases",
        sa.Column("id", sa.Uuid(), primary_key=True),
        sa.Column("organization_id", sa.Uuid(), sa.ForeignKey("organizations.id"), nullable=False),
        sa.Column("created_by", sa.Uuid(), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("owner_id", sa.Uuid(), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("title", sa.String(200), nullable=False),
        sa.Column("description", sa.String(8000), nullable=False),
        sa.Column("type", sa.String(40), nullable=False),
        sa.Column("priority", sa.String(16), nullable=False),
        sa.Column("status", sa.String(32), nullable=False),
        sa.Column("due_date", sa.DateTime(timezone=True)),
        sa.Column("revision", sa.Integer(), nullable=False),
        sa.Column("closure_reason", sa.String(4000), nullable=False),
        sa.Column("closed_at", sa.DateTime(timezone=True)),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False))
    for column in ("organization_id", "owner_id"):
        op.create_index("ix_thread_cases_" + column, "thread_cases", [column])
    op.create_table("thread_case_events",
        sa.Column("id", sa.Uuid(), primary_key=True),
        sa.Column("case_id", sa.Uuid(), sa.ForeignKey("thread_cases.id"), nullable=False),
        sa.Column("revision", sa.Integer(), nullable=False),
        sa.Column("request_id", sa.Uuid(), nullable=False),
        sa.Column("request_hash", sa.String(64), nullable=False),
        sa.Column("type", sa.String(40), nullable=False),
        sa.Column("actor_id", sa.Uuid(), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("details", sa.JSON(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.UniqueConstraint("case_id", "revision", name="uq_thread_event_revision"),
        sa.UniqueConstraint("case_id", "request_id", name="uq_thread_event_request"))
    op.create_index("ix_thread_case_events_case_id", "thread_case_events", ["case_id"])
    op.create_table("thread_evidence",
        sa.Column("id", sa.Uuid(), primary_key=True),
        sa.Column("case_id", sa.Uuid(), sa.ForeignKey("thread_cases.id"), nullable=False),
        sa.Column("title", sa.String(200), nullable=False),
        sa.Column("description", sa.String(8000), nullable=False),
        sa.Column("type", sa.String(32), nullable=False),
        sa.Column("source", sa.String(2000), nullable=False),
        sa.Column("created_by", sa.Uuid(), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("verification_state", sa.String(16), nullable=False),
        sa.Column("verified_by", sa.Uuid(), sa.ForeignKey("users.id")),
        sa.Column("verified_at", sa.DateTime(timezone=True)),
        sa.Column("verification_note", sa.String(4000), nullable=False))
    op.create_index("ix_thread_evidence_case_id", "thread_evidence", ["case_id"])


def downgrade():
    op.drop_table("thread_evidence")
    op.drop_table("thread_case_events")
    op.drop_table("thread_cases")
