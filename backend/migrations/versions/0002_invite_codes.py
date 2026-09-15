"""Add hashed, organization-scoped registration invites."""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision = "0002_invite_codes"
down_revision = "0001_database_foundation"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "invite_codes",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("code_hash", sa.String(length=64), nullable=False),
        sa.Column("organization_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("role", sa.String(length=20), nullable=False),
        sa.Column("created_by", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("max_uses", sa.Integer(), nullable=False),
        sa.Column("used_count", sa.Integer(), server_default=sa.text("0"), nullable=False),
        sa.Column("is_active", sa.Boolean(), server_default=sa.text("true"), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.CheckConstraint("role IN ('trainee', 'instructor')", name="ck_invite_codes_role"),
        sa.CheckConstraint("max_uses > 0", name="ck_invite_codes_max_uses"),
        sa.CheckConstraint("used_count >= 0 AND used_count <= max_uses", name="ck_invite_codes_used_count"),
        sa.ForeignKeyConstraint(["organization_id"], ["organizations.id"], name="fk_invite_codes_organization_id_organizations"),
        sa.ForeignKeyConstraint(["created_by"], ["users.id"], name="fk_invite_codes_created_by_users"),
        sa.PrimaryKeyConstraint("id", name="pk_invite_codes"),
        sa.UniqueConstraint("code_hash", name="uq_invite_codes_code_hash"),
    )
    op.create_index("ix_invite_codes_organization_id", "invite_codes", ["organization_id"])
    op.create_index("ix_invite_codes_created_by", "invite_codes", ["created_by"])


def downgrade() -> None:
    op.drop_index("ix_invite_codes_created_by", table_name="invite_codes")
    op.drop_index("ix_invite_codes_organization_id", table_name="invite_codes")
    op.drop_table("invite_codes")
