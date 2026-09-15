from __future__ import annotations

import hashlib
import os
import uuid
from datetime import datetime, timedelta, timezone

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.models import AuthSession, Base, InviteCode, Organization, OrganizationMembership, User
from app.auth import password_hasher, get_db
from server import app


AUTH_TABLES = [
    User.__table__,
    Organization.__table__,
    OrganizationMembership.__table__,
    AuthSession.__table__,
    InviteCode.__table__,
]


@pytest.fixture
def system(monkeypatch):
    monkeypatch.setenv("JWT_SECRET_KEY", "test-only-secret-key-at-least-32-bytes-long")
    engine = create_engine(
        "sqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine, tables=AUTH_TABLES)
    factory = sessionmaker(bind=engine, expire_on_commit=False)
    def override_db():
        yield from _session(factory)
    app.dependency_overrides[get_db] = override_db
    with factory() as db:
        organization = Organization(name="Training")
        admin = User(
            email="admin@example.test",
            password_hash=password_hasher.hash("test-password-123"),
            first_name="Admin",
            callsign="ADMIN",
        )
        instructor = User(
            email="instructor@example.test",
            password_hash=password_hasher.hash("test-password-123"),
            first_name="Instructor",
            callsign="INS",
        )
        trainee = User(
            email="trainee@example.test",
            password_hash=password_hasher.hash("test-password-123"),
            first_name="Trainee",
            callsign="TRN",
        )
        db.add_all([organization, admin, instructor, trainee])
        db.flush()
        db.add_all([
            OrganizationMembership(organization_id=organization.id, user_id=admin.id, role="admin"),
            OrganizationMembership(organization_id=organization.id, user_id=instructor.id, role="instructor"),
            OrganizationMembership(organization_id=organization.id, user_id=trainee.id, role="trainee"),
        ])
        db.commit()
        ids = {"organization": organization.id, "admin": admin.id, "instructor": instructor.id, "trainee": trainee.id}
    try:
        yield TestClient(app), factory, ids
    finally:
        app.dependency_overrides.clear()
        engine.dispose()


def _session(factory):
    with factory() as session:
        yield session


def _invite(factory, organization_id, created_by, *, role="trainee", uses=1, expires=None, active=True):
    raw = f"test-invite-{uuid.uuid4()}"
    with factory() as db:
        db.add(InviteCode(
            code_hash=hashlib.sha256(raw.upper().encode()).hexdigest(),
            organization_id=organization_id,
            created_by=created_by,
            role=role,
            max_uses=uses,
            expires_at=expires,
            is_active=active,
        ))
        db.commit()
    return raw


def _register(client, code, email="new@example.test"):
    return client.post("/v1/auth/register", json={
        "email": email,
        "password": "new-user-password-123",
        "first_name": "New",
        "callsign": "NEW",
        "invite_code": code,
    })


def _login(client, email, password="test-password-123"):
    return client.post("/v1/auth/login", json={"email": email, "password": password})


def _auth_headers(client, email):
    response = _login(client, email)
    assert response.status_code == 200
    return {"Authorization": f"Bearer {response.json()['access_token']}"}


def test_valid_registration_creates_membership_and_consumes_invite(system):
    client, factory, ids = system
    code = _invite(factory, ids["organization"], ids["admin"], role="instructor", uses=2)
    response = _register(client, code)
    assert response.status_code == 201
    body = response.json()
    assert body["user"]["role"] == "instructor"
    assert body["user"]["organization_id"] == str(ids["organization"])
    with factory() as db:
        user = db.query(User).filter_by(email="new@example.test").one()
        membership = db.query(OrganizationMembership).filter_by(user_id=user.id).one()
        invite = db.query(InviteCode).one()
        session = db.query(AuthSession).filter_by(user_id=user.id).one()
        assert membership.role == invite.role
        assert invite.used_count == 1
        assert session.refresh_token_hash != body["refresh_token"]
        assert session.refresh_token_hash == hashlib.sha256(body["refresh_token"].encode()).hexdigest()


def test_invalid_invite(system):
    response = _register(system[0], "TACTIX-TRN-unknown-code")
    assert response.status_code == 400


@pytest.mark.parametrize("expires", [datetime.now(timezone.utc) - timedelta(seconds=5)])
def test_expired_invite(system, expires):
    client, factory, ids = system
    code = _invite(factory, ids["organization"], ids["admin"], expires=expires)
    assert _register(client, code).status_code == 400


def test_exhausted_invite(system):
    client, factory, ids = system
    code = _invite(factory, ids["organization"], ids["admin"], uses=1)
    assert _register(client, code).status_code == 201
    assert _register(client, code, "second@example.test").status_code == 400


def test_duplicate_email(system):
    client, factory, ids = system
    code = _invite(factory, ids["organization"], ids["admin"], uses=2)
    response = _register(client, code, "ADMIN@example.test")
    assert response.status_code == 409
    with factory() as db:
        assert db.query(InviteCode).one().used_count == 0


def test_login_success_and_me(system):
    client, _, _ = system
    response = _login(client, "admin@example.test")
    assert response.status_code == 200
    assert response.json()["user"]["role"] == "admin"
    me = client.get("/v1/auth/me", headers={"Authorization": f"Bearer {response.json()['access_token']}"})
    assert me.status_code == 200
    assert me.json()["email"] == "admin@example.test"


def test_login_failure_is_neutral_for_unknown_and_wrong_password(system):
    client, _, _ = system
    unknown = _login(client, "absent@example.test", "incorrect-password")
    wrong = _login(client, "admin@example.test", "incorrect-password")
    assert unknown.status_code == wrong.status_code == 401
    assert unknown.json()["detail"] == wrong.json()["detail"] == "Неверные учётные данные"


def test_refresh_rotates_token_and_rejects_old_token(system):
    client, factory, _ = system
    original = _login(client, "admin@example.test").json()
    response = client.post("/v1/auth/refresh", json={"refresh_token": original["refresh_token"]})
    assert response.status_code == 200
    rotated = response.json()
    assert rotated["refresh_token"] != original["refresh_token"]
    old = client.post("/v1/auth/refresh", json={"refresh_token": original["refresh_token"]})
    assert old.status_code == 401
    with factory() as db:
        session = db.query(AuthSession).one()
        assert session.refresh_token_hash == hashlib.sha256(rotated["refresh_token"].encode()).hexdigest()


def test_logout_revokes_session_and_access_token(system):
    client, factory, _ = system
    tokens = _login(client, "admin@example.test").json()
    assert client.post("/v1/auth/logout", json={"refresh_token": tokens["refresh_token"]}).status_code == 204
    assert client.get("/v1/auth/me", headers={"Authorization": f"Bearer {tokens['access_token']}"}).status_code == 401
    with factory() as db:
        assert db.query(AuthSession).one().revoked_at is not None


def test_trainee_cannot_create_invite(system):
    client, _, _ = system
    response = client.post("/v1/invites", headers=_auth_headers(client, "trainee@example.test"), json={"role": "trainee"})
    assert response.status_code == 403


def test_instructor_can_create_trainee_invite_but_not_instructor(system):
    client, factory, ids = system
    headers = _auth_headers(client, "instructor@example.test")
    allowed = client.post("/v1/invites", headers=headers, json={"role": "trainee", "max_uses": 3})
    assert allowed.status_code == 201
    assert allowed.json()["code"].startswith("TACTIX-TRN-")
    with factory() as db:
        row = db.query(InviteCode).filter_by(code_hash=hashlib.sha256(allowed.json()["code"].encode()).hexdigest()).one()
        assert row.created_by == ids["instructor"]
    forbidden = client.post("/v1/invites", headers=headers, json={"role": "instructor"})
    assert forbidden.status_code == 403


def test_admin_can_create_instructor_invite(system):
    client, factory, ids = system
    response = client.post("/v1/invites", headers=_auth_headers(client, "admin@example.test"), json={"role": "instructor"})
    assert response.status_code == 201
    assert response.json()["role"] == "instructor"
    with factory() as db:
        invite = db.query(InviteCode).one()
        assert invite.organization_id == ids["organization"]
        assert invite.code_hash != response.json()["code"]


def test_register_does_not_accept_client_role(system):
    client, factory, ids = system
    code = _invite(factory, ids["organization"], ids["admin"])
    response = client.post("/v1/auth/register", json={
        "email": "role@example.test", "password": "new-user-password-123",
        "first_name": "Role", "callsign": "R", "invite_code": code, "role": "admin",
    })
    assert response.status_code == 422
