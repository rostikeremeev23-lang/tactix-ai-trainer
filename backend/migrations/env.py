"""Alembic environment; connection settings come only from DATABASE_URL."""
from logging.config import fileConfig
from pathlib import Path
import sys
from alembic import context
from sqlalchemy import create_engine
from sqlalchemy.pool import NullPool
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from app.config import get_database_url  # noqa: E402
from app.models import Base  # noqa: E402
config = context.config
if config.config_file_name is not None:
    fileConfig(config.config_file_name)
target_metadata = Base.metadata

def run_migrations_offline() -> None:
    context.configure(url=get_database_url(), target_metadata=target_metadata, literal_binds=True, dialect_opts={"paramstyle": "named"}, compare_type=True)
    with context.begin_transaction():
        context.run_migrations()

def run_migrations_online() -> None:
    connectable = create_engine(get_database_url(), poolclass=NullPool)
    try:
        with connectable.connect() as connection:
            context.configure(connection=connection, target_metadata=target_metadata, compare_type=True)
            with context.begin_transaction():
                context.run_migrations()
    finally:
        connectable.dispose()

if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
