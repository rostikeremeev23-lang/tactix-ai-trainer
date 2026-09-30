"""Add typed Digital Thread relationships and immutable relation events."""
from alembic import op
import sqlalchemy as sa

revision = "0006_thread_relations"
down_revision = "0005_thread_cases"
branch_labels = depends_on = None


def upgrade():
    op.create_table(
        "thread_relations",
        sa.Column("id", sa.Uuid(), primary_key=True),
        sa.Column("organization_id", sa.Uuid(), sa.ForeignKey("organizations.id"), nullable=False),
        sa.Column("from_type", sa.String(24), nullable=False),
        sa.Column("from_id", sa.Uuid(), nullable=False),
        sa.Column("to_type", sa.String(24), nullable=False),
        sa.Column("to_id", sa.Uuid(), nullable=False),
        sa.Column("relationship_type", sa.String(40), nullable=False),
        sa.Column("created_by", sa.Uuid(), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.UniqueConstraint(
            "organization_id", "from_type", "from_id", "to_type", "to_id", "relationship_type",
            name="uq_thread_relation_edge",
        ),
    )
    op.create_index("ix_thread_relations_from", "thread_relations", ["organization_id", "from_type", "from_id"])
    op.create_index("ix_thread_relations_to", "thread_relations", ["organization_id", "to_type", "to_id"])
    op.create_table(
        "thread_relation_events",
        sa.Column("id", sa.Uuid(), primary_key=True),
        sa.Column("relation_id", sa.Uuid(), sa.ForeignKey("thread_relations.id"), nullable=False),
        sa.Column("request_id", sa.Uuid(), nullable=False),
        sa.Column("request_hash", sa.String(64), nullable=False),
        sa.Column("type", sa.String(40), nullable=False),
        sa.Column("actor_id", sa.Uuid(), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("details", sa.JSON(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.UniqueConstraint("relation_id", "request_id", name="uq_thread_relation_event_request"),
    )
    op.create_index("ix_thread_relation_events_relation_id", "thread_relation_events", ["relation_id"])


def downgrade():
    op.drop_table("thread_relation_events")
    op.drop_table("thread_relations")
