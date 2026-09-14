"""Create TACTIX cloud database foundation."""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql
revision = "0001_database_foundation"
down_revision = None
branch_labels = None
depends_on = None

def upgrade() -> None:
    op.create_table("users", sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False), sa.Column("email", sa.String(320), nullable=False), sa.Column("password_hash", sa.String(255), nullable=False), sa.Column("first_name", sa.String(120), nullable=False), sa.Column("callsign", sa.String(120), nullable=False), sa.Column("is_active", sa.Boolean(), server_default=sa.text("true"), nullable=False), sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False), sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False), sa.PrimaryKeyConstraint("id", name="pk_users"), sa.UniqueConstraint("email", name="uq_users_email"))
    op.create_index("ix_users_email", "users", ["email"])
    op.create_table("organizations", sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False), sa.Column("name", sa.String(200), nullable=False), sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False), sa.PrimaryKeyConstraint("id", name="pk_organizations"))
    op.create_table("organization_memberships", sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False), sa.Column("organization_id", postgresql.UUID(as_uuid=True), nullable=False), sa.Column("user_id", postgresql.UUID(as_uuid=True), nullable=False), sa.Column("role", sa.String(20), server_default=sa.text("'trainee'"), nullable=False), sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False), sa.CheckConstraint("role IN ('trainee', 'instructor', 'admin')", name="ck_membership_role"), sa.ForeignKeyConstraint(["organization_id"], ["organizations.id"], name="fk_organization_memberships_organization_id_organizations"), sa.ForeignKeyConstraint(["user_id"], ["users.id"], name="fk_organization_memberships_user_id_users"), sa.PrimaryKeyConstraint("id", name="pk_organization_memberships"), sa.UniqueConstraint("organization_id", "user_id", name="uq_membership_organization_user"))
    op.create_index("ix_organization_memberships_user_id", "organization_memberships", ["user_id"])
    op.create_index("ix_organization_memberships_organization_id", "organization_memberships", ["organization_id"])
    op.create_table("training_assignments", sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False), sa.Column("organization_id", postgresql.UUID(as_uuid=True), nullable=False), sa.Column("assigned_by", postgresql.UUID(as_uuid=True), nullable=False), sa.Column("assigned_to", postgresql.UUID(as_uuid=True), nullable=False), sa.Column("status", sa.String(32), server_default=sa.text("'assigned'"), nullable=False), sa.Column("due_at", sa.DateTime(timezone=True), nullable=True), sa.Column("scenario_snapshot", postgresql.JSONB(astext_type=sa.Text()), server_default=sa.text("'{}'::jsonb"), nullable=False), sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False), sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False), sa.ForeignKeyConstraint(["assigned_by"], ["users.id"], name="fk_training_assignments_assigned_by_users"), sa.ForeignKeyConstraint(["assigned_to"], ["users.id"], name="fk_training_assignments_assigned_to_users"), sa.ForeignKeyConstraint(["organization_id"], ["organizations.id"], name="fk_training_assignments_organization_id_organizations"), sa.PrimaryKeyConstraint("id", name="pk_training_assignments"))
    op.create_index("ix_training_assignments_organization_id", "training_assignments", ["organization_id"])
    op.create_index("ix_training_assignments_assigned_by", "training_assignments", ["assigned_by"])
    op.create_index("ix_training_assignments_assigned_to", "training_assignments", ["assigned_to"])
    op.create_table("instructor_trainees", sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False), sa.Column("instructor_id", postgresql.UUID(as_uuid=True), nullable=False), sa.Column("trainee_id", postgresql.UUID(as_uuid=True), nullable=False), sa.Column("organization_id", postgresql.UUID(as_uuid=True), nullable=False), sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False), sa.ForeignKeyConstraint(["instructor_id"], ["users.id"], name="fk_instructor_trainees_instructor_id_users"), sa.ForeignKeyConstraint(["trainee_id"], ["users.id"], name="fk_instructor_trainees_trainee_id_users"), sa.ForeignKeyConstraint(["organization_id"], ["organizations.id"], name="fk_instructor_trainees_organization_id_organizations"), sa.PrimaryKeyConstraint("id", name="pk_instructor_trainees"), sa.UniqueConstraint("instructor_id", "trainee_id", "organization_id", name="uq_instructor_trainees_pair"))
    op.create_index("ix_instructor_trainees_trainee_org", "instructor_trainees", ["trainee_id", "organization_id"])
    op.create_table("training_results", sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False), sa.Column("user_id", postgresql.UUID(as_uuid=True), nullable=False), sa.Column("client_id", sa.String(255), nullable=False), sa.Column("assignment_id", postgresql.UUID(as_uuid=True), nullable=True), sa.Column("scenario_title", sa.String(300), nullable=False), sa.Column("score", sa.Integer(), nullable=False), sa.Column("completed_at", sa.DateTime(timezone=True), nullable=False), sa.Column("details", postgresql.JSONB(astext_type=sa.Text()), server_default=sa.text("'{}'::jsonb"), nullable=False), sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False), sa.ForeignKeyConstraint(["assignment_id"], ["training_assignments.id"], name="fk_training_results_assignment_id_training_assignments"), sa.ForeignKeyConstraint(["user_id"], ["users.id"], name="fk_training_results_user_id_users"), sa.PrimaryKeyConstraint("id", name="pk_training_results"), sa.UniqueConstraint("user_id", "client_id", name="uq_training_results_user_client"))
    op.create_index("ix_training_results_user_id", "training_results", ["user_id"])
    op.create_index("ix_training_results_assignment_id", "training_results", ["assignment_id"])
    op.create_index("ix_training_results_user_completed_at", "training_results", ["user_id", "completed_at"])
    op.create_table("auth_sessions", sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False), sa.Column("user_id", postgresql.UUID(as_uuid=True), nullable=False), sa.Column("refresh_token_hash", sa.String(255), nullable=False), sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False), sa.Column("revoked_at", sa.DateTime(timezone=True), nullable=True), sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False), sa.ForeignKeyConstraint(["user_id"], ["users.id"], name="fk_auth_sessions_user_id_users"), sa.PrimaryKeyConstraint("id", name="pk_auth_sessions"), sa.UniqueConstraint("refresh_token_hash", name="uq_auth_sessions_refresh_token_hash"))
    op.create_index("ix_auth_sessions_user_id", "auth_sessions", ["user_id"])

def downgrade() -> None:
    op.drop_index("ix_auth_sessions_user_id", table_name="auth_sessions")
    op.drop_table("auth_sessions")
    op.drop_index("ix_training_results_user_completed_at", table_name="training_results")
    op.drop_index("ix_training_results_assignment_id", table_name="training_results")
    op.drop_index("ix_training_results_user_id", table_name="training_results")
    op.drop_table("training_results")
    op.drop_index("ix_instructor_trainees_trainee_org", table_name="instructor_trainees")
    op.drop_table("instructor_trainees")
    op.drop_index("ix_training_assignments_assigned_to", table_name="training_assignments")
    op.drop_index("ix_training_assignments_assigned_by", table_name="training_assignments")
    op.drop_index("ix_training_assignments_organization_id", table_name="training_assignments")
    op.drop_table("training_assignments")
    op.drop_index("ix_organization_memberships_organization_id", table_name="organization_memberships")
    op.drop_index("ix_organization_memberships_user_id", table_name="organization_memberships")
    op.drop_table("organization_memberships")
    op.drop_table("organizations")
    op.drop_index("ix_users_email", table_name="users")
    op.drop_table("users")
