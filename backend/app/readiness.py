"""Release-readiness probes for TACTIX.

The public endpoint intentionally returns only coarse component state. It never
returns database URLs, credentials, tokens, internal hostnames, or AI keys.
"""
from __future__ import annotations

import os
from datetime import datetime, timezone

from fastapi import APIRouter, Response, status
from sqlalchemy import text

from app.db import get_session_factory

router = APIRouter()


def _secret_ready() -> bool:
    value = os.environ.get("JWT_SECRET_KEY", "")
    return len(value.encode("utf-8")) >= 32


def _database_ready() -> tuple[bool, str]:
    try:
        db = get_session_factory()()
        try:
            db.execute(text("SELECT 1"))
        finally:
            db.close()
        return True, "available"
    except Exception:
        return False, "unavailable"


def _release_id() -> str:
    value = os.environ.get("TACTIX_RELEASE_ID", "dev").strip()
    return value or "dev"


def _environment() -> str:
    value = os.environ.get("TACTIX_ENV", "development").strip().lower()
    return value or "development"


@router.get("/ready")
def readiness(response: Response) -> dict:
    """Return core release-readiness without exposing infrastructure secrets."""
    database_ok, database_state = _database_ready()
    auth_ok = _secret_ready()
    ready = database_ok and auth_ok

    if not ready:
        response.status_code = status.HTTP_503_SERVICE_UNAVAILABLE

    gemini_configured = bool(os.environ.get("GEMINI_API_KEY", "").strip())
    ollama_configured = bool(os.environ.get("OLLAMA_URL", "").strip())

    return {
        "status": "ready" if ready else "not_ready",
        "checked_at": datetime.now(timezone.utc).isoformat(),
        "release": _release_id(),
        "environment": _environment(),
        "components": {
            "database": database_state,
            "authentication": "configured" if auth_ok else "not_configured",
            "ai": "configured" if (gemini_configured or ollama_configured) else "optional_offline",
        },
        "capabilities": {
            "digital_thread": True,
            "training": True,
            "simulation_lab": True,
            "ask_tactix": True,
            "branches": True,
            "pulse": True,
        },
    }
