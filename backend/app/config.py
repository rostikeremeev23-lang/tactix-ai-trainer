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

def get_runtime_environment() -> str:
    value = os.environ.get("TACTIX_ENV", "development").strip().lower()
    return value or "development"


def get_cors_origins() -> list[str]:
    """Return explicit CORS origins for release builds.

    Development keeps the historical permissive behavior. Production requires
    CORS_ORIGINS to be set explicitly, preventing an accidental wildcard.
    """
    raw = os.environ.get("CORS_ORIGINS", "").strip()
    if raw:
        values = [item.strip() for item in raw.split(",") if item.strip()]
        return list(dict.fromkeys(values))
    if get_runtime_environment() == "production":
        return []
    return ["*"]
