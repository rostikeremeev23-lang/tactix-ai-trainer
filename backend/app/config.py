"""Environment-backed backend configuration."""

import os


def get_database_url() -> str:
    value = os.environ.get("DATABASE_URL", "").strip()

    if not value:
        raise RuntimeError(
            "DATABASE_URL is required for database operations. "
            "Set it in the environment."
        )

    return value