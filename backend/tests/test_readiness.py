from __future__ import annotations

from fastapi.testclient import TestClient

import app.readiness as readiness_module
from app.config import get_cors_origins
from server import app


class _OkSession:
    def execute(self, _statement):
        return None

    def close(self):
        return None


class _BrokenSession:
    def execute(self, _statement):
        raise RuntimeError("database unavailable")

    def close(self):
        return None


def test_ready_reports_core_components_without_secrets(monkeypatch):
    monkeypatch.setenv("JWT_SECRET_KEY", "test-only-secret-key-at-least-32-bytes-long")
    monkeypatch.setenv("TACTIX_RELEASE_ID", "phase-i-test")
    monkeypatch.setattr(readiness_module, "get_session_factory", lambda: lambda: _OkSession())

    response = TestClient(app).get("/ready")

    assert response.status_code == 200
    body = response.json()
    assert body["status"] == "ready"
    assert body["release"] == "phase-i-test"
    assert body["components"]["database"] == "available"
    assert body["components"]["authentication"] == "configured"
    assert "DATABASE_URL" not in response.text
    assert "JWT_SECRET_KEY" not in response.text
    assert response.headers["X-Content-Type-Options"] == "nosniff"


def test_ready_is_503_when_database_or_auth_is_not_ready(monkeypatch):
    monkeypatch.delenv("JWT_SECRET_KEY", raising=False)
    monkeypatch.setattr(readiness_module, "get_session_factory", lambda: lambda: _BrokenSession())

    response = TestClient(app).get("/ready")

    assert response.status_code == 503
    body = response.json()
    assert body["status"] == "not_ready"
    assert body["components"]["database"] == "unavailable"
    assert body["components"]["authentication"] == "not_configured"


def test_production_cors_requires_explicit_origins(monkeypatch):
    monkeypatch.setenv("TACTIX_ENV", "production")
    monkeypatch.delenv("CORS_ORIGINS", raising=False)
    assert get_cors_origins() == []

    monkeypatch.setenv("CORS_ORIGINS", "https://one.example, https://two.example,https://one.example")
    assert get_cors_origins() == ["https://one.example", "https://two.example"]
