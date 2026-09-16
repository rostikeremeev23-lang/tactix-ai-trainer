"""Invite-based authentication and organization-scoped authorization."""
from __future__ import annotations

import hashlib
import secrets
import uuid
from datetime import datetime, timedelta, timezone
from dataclasses import dataclass
from typing import Annotated, Literal

import jwt
from argon2 import PasswordHasher
from argon2.exceptions import InvalidHashError, VerifyMismatchError
from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from pydantic import BaseModel, ConfigDict, Field, field_validator
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.db import get_session_factory
from app.models import AuthSession, InviteCode, Organization, OrganizationMembership, User

router = APIRouter()
bearer = HTTPBearer(auto_error=False)
password_hasher = PasswordHasher()
_DUMMY_PASSWORD_HASH = password_hasher.hash(secrets.token_urlsafe(32))
ACCESS_TTL = timedelta(minutes=15)
REFRESH_TTL = timedelta(days=30)
GENERIC_CREDENTIAL_ERROR = "Неверные учётные данные"


def _secret() -> str:
    import os
    value = os.environ.get("JWT_SECRET_KEY", "")
    if len(value.encode("utf-8")) < 32:
        raise HTTPException(status_code=503, detail="Auth is not configured.")
    return value


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _aware(value: datetime) -> datetime:
    return value.replace(tzinfo=timezone.utc) if value.tzinfo is None else value


def _hash(value: str) -> str:
    return hashlib.sha256(value.encode("utf-8")).hexdigest()


def get_db():
    session = get_session_factory()()
    try:
        yield session
    finally:
        session.close()


Db = Annotated[Session, Depends(get_db)]


class RegisterRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")
    email: str = Field(min_length=3, max_length=320)
    password: str = Field(min_length=12, max_length=128)
    first_name: str = Field(min_length=1, max_length=120)
    callsign: str = Field(min_length=1, max_length=120)
    invite_code: str = Field(min_length=12, max_length=100)

    @field_validator("email")
    @classmethod
    def normalize_email(cls, value: str) -> str:
        value = value.strip().lower()
        if value.count("@") != 1 or "." not in value.rsplit("@", 1)[-1]:
            raise ValueError("Invalid email address")
        return value

    @field_validator("first_name", "callsign", "invite_code")
    @classmethod
    def trim_required(cls, value: str) -> str:
        value = value.strip()
        if not value:
            raise ValueError("Field cannot be blank")
        return value


class LoginRequest(BaseModel):
    email: str = Field(min_length=3, max_length=320)
    password: str = Field(min_length=1, max_length=128)

    @field_validator("email")
    @classmethod
    def normalize_email(cls, value: str) -> str:
        return value.strip().lower()


class RefreshRequest(BaseModel):
    refresh_token: str = Field(min_length=32, max_length=256)


class LogoutRequest(BaseModel):
    refresh_token: str = Field(min_length=32, max_length=256)


class InviteRequest(BaseModel):
    role: Literal["trainee", "instructor"]
    max_uses: int = Field(default=1, ge=1, le=1000)
    expires_in_days: int | None = Field(default=30, ge=1, le=365)


class UserResponse(BaseModel):
    id: uuid.UUID
    email: str
    first_name: str
    callsign: str
    organization_id: uuid.UUID
    role: str
    model_config = ConfigDict(from_attributes=True)


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: Literal["bearer"] = "bearer"
    user: UserResponse


class InviteResponse(BaseModel):
    code: str
    role: str
    organization_id: uuid.UUID
    expires_at: datetime | None
    max_uses: int


@dataclass(frozen=True)
class CurrentIdentity:
    user: User
    organization: Organization
    role: str


def _user_response(user: User, membership: OrganizationMembership) -> UserResponse:
    return UserResponse(
        id=user.id,
        email=user.email,
        first_name=user.first_name,
        callsign=user.callsign,
        organization_id=membership.organization_id,
        role=membership.role,
    )


def _membership_for_user(db: Session, user_id: uuid.UUID) -> OrganizationMembership | None:
    return db.scalar(
        select(OrganizationMembership)
        .where(OrganizationMembership.user_id == user_id)
        .order_by(OrganizationMembership.created_at, OrganizationMembership.id)
        .limit(1)
    )


def _issue_access(user: User, membership: OrganizationMembership, session_id: uuid.UUID) -> str:
    now = _now()
    return jwt.encode(
        {
            "sub": str(user.id),
            "org": str(membership.organization_id),
            "role": membership.role,
            "sid": str(session_id),
            "iat": now,
            "exp": now + ACCESS_TTL,
        },
        _secret(),
        algorithm="HS256",
    )


def _new_refresh_token() -> str:
    return secrets.token_urlsafe(48)


def _token_response(user: User, membership: OrganizationMembership, session: AuthSession, refresh: str) -> TokenResponse:
    return TokenResponse(
        access_token=_issue_access(user, membership, session.id),
        refresh_token=refresh,
        user=_user_response(user, membership),
    )


def _invalid_auth() -> HTTPException:
    return HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=GENERIC_CREDENTIAL_ERROR, headers={"WWW-Authenticate": "Bearer"})


def get_current_user(
    credentials: Annotated[HTTPAuthorizationCredentials | None, Depends(bearer)],
    db: Db,
) -> CurrentIdentity:
    if credentials is None:
        raise _invalid_auth()
    try:
        claims = jwt.decode(credentials.credentials, _secret(), algorithms=["HS256"])
        user_id = uuid.UUID(claims["sub"])
        organization_id = uuid.UUID(claims["org"])
        session_id = uuid.UUID(claims["sid"])
    except (jwt.PyJWTError, KeyError, ValueError, TypeError):
        raise _invalid_auth()

    session = db.get(AuthSession, session_id)
    if session is None or session.revoked_at is not None or _aware(session.expires_at) <= _now():
        raise _invalid_auth()
    user = db.get(User, user_id)
    if user is None or not user.is_active or session.user_id != user.id:
        raise _invalid_auth()
    membership = db.scalar(
        select(OrganizationMembership).where(
            OrganizationMembership.user_id == user.id,
            OrganizationMembership.organization_id == organization_id,
        )
    )
    organization = db.get(Organization, organization_id)
    if membership is None or organization is None:
        raise _invalid_auth()
    return CurrentIdentity(user=user, organization=organization, role=membership.role)


def require_role(*roles: str):
    allowed = frozenset(roles)

    def dependency(identity: Annotated[CurrentIdentity, Depends(get_current_user)]) -> CurrentIdentity:
        if identity.role not in allowed:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Недостаточно прав.")
        return identity

    return dependency


Current = Annotated[CurrentIdentity, Depends(get_current_user)]


@router.post("/v1/auth/register", response_model=TokenResponse, status_code=status.HTTP_201_CREATED)
def register(request: RegisterRequest, db: Db) -> TokenResponse:
    now = _now()
    _secret()
    password_hash = password_hasher.hash(request.password)
    code_hash = _hash(request.invite_code.strip().upper())
    try:
        invite = db.scalar(select(InviteCode).where(InviteCode.code_hash == code_hash).with_for_update())
        if invite is None or not invite.is_active or invite.used_count >= invite.max_uses:
            raise HTTPException(status_code=400, detail="Недействительный код приглашения.")
        if invite.expires_at is not None and _aware(invite.expires_at) <= now:
            raise HTTPException(status_code=400, detail="Недействительный код приглашения.")
        if db.scalar(select(User.id).where(User.email == request.email)) is not None:
            raise HTTPException(status_code=409, detail="Не удалось зарегистрировать пользователя с указанными данными.")
        organization = db.get(Organization, invite.organization_id)
        if organization is None:
            raise HTTPException(status_code=400, detail="Недействительный код приглашения.")

        user = User(id=uuid.uuid4(), email=request.email, password_hash=password_hash, first_name=request.first_name, callsign=request.callsign)
        db.add(user)
        # These dependent objects only carry user_id values and have no ORM
        # relationship to `user`, so persist the parent before adding them.
        db.flush()

        membership = OrganizationMembership(organization_id=invite.organization_id, user_id=user.id, role=invite.role)
        db.add(membership)
        invite.used_count += 1
        refresh = _new_refresh_token()
        session = AuthSession(user_id=user.id, refresh_token_hash=_hash(refresh), expires_at=now + REFRESH_TTL)
        db.add(session)
        db.flush()
        response = _token_response(user, membership, session, refresh)
        db.commit()
        return response
    except HTTPException:
        db.rollback()
        raise
    except IntegrityError:
        db.rollback()
        raise HTTPException(
            status_code=409,
            detail="Не удалось зарегистрировать пользователя с указанными данными.",
        )


@router.post("/v1/auth/login", response_model=TokenResponse)
def login(request: LoginRequest, db: Db) -> TokenResponse:
    _secret()
    user = db.scalar(select(User).where(User.email == request.email))
    valid = False
    encoded_hash = user.password_hash if user is not None else _DUMMY_PASSWORD_HASH
    try:
        valid = password_hasher.verify(encoded_hash, request.password)
    except (VerifyMismatchError, InvalidHashError, ValueError):
        valid = False
    if not valid or user is None or not user.is_active:
        raise _invalid_auth()
    membership = _membership_for_user(db, user.id)
    if membership is None:
        raise _invalid_auth()
    refresh = _new_refresh_token()
    session = AuthSession(user_id=user.id, refresh_token_hash=_hash(refresh), expires_at=_now() + REFRESH_TTL)
    db.add(session)
    db.flush()
    response = _token_response(user, membership, session, refresh)
    db.commit()
    return response


@router.post("/v1/auth/refresh", response_model=TokenResponse)
def refresh_tokens(request: RefreshRequest, db: Db) -> TokenResponse:
    _secret()
    now = _now()
    session = db.scalar(
        select(AuthSession).where(AuthSession.refresh_token_hash == _hash(request.refresh_token)).with_for_update()
    )
    if session is None or session.revoked_at is not None or _aware(session.expires_at) <= now:
        db.rollback()
        raise _invalid_auth()
    user = db.get(User, session.user_id)
    membership = _membership_for_user(db, session.user_id)
    if user is None or not user.is_active or membership is None:
        db.rollback()
        raise _invalid_auth()
    refresh = _new_refresh_token()
    session.refresh_token_hash = _hash(refresh)
    response = _token_response(user, membership, session, refresh)
    db.commit()
    return response


@router.post("/v1/auth/logout", status_code=status.HTTP_204_NO_CONTENT)
def logout(request: LogoutRequest, db: Db) -> None:
    session = db.scalar(select(AuthSession).where(AuthSession.refresh_token_hash == _hash(request.refresh_token)))
    if session is not None and session.revoked_at is None:
        session.revoked_at = _now()
        db.commit()
    else:
        db.rollback()
    return None


@router.get("/v1/auth/me", response_model=UserResponse)
def me(identity: Current) -> UserResponse:
    membership = OrganizationMembership(
        organization_id=identity.organization.id,
        user_id=identity.user.id,
        role=identity.role,
    )
    return _user_response(identity.user, membership)


@router.post("/v1/invites", response_model=InviteResponse, status_code=status.HTTP_201_CREATED)
def create_invite(
    request: InviteRequest,
    db: Db,
    identity: Annotated[CurrentIdentity, Depends(require_role("admin", "instructor"))],
) -> InviteResponse:
    if identity.role == "instructor" and request.role != "trainee":
        raise HTTPException(status_code=403, detail="Инструктор может приглашать только обучаемых.")
    raw = secrets.token_hex(24).upper()
    prefix = "TRN" if request.role == "trainee" else "INS"
    code = f"TACTIX-{prefix}-{raw}"
    expires_at = _now() + timedelta(days=request.expires_in_days) if request.expires_in_days is not None else None
    invite = InviteCode(
        code_hash=_hash(code),
        organization_id=identity.organization.id,
        role=request.role,
        created_by=identity.user.id,
        expires_at=expires_at,
        max_uses=request.max_uses,
    )
    db.add(invite)
    db.commit()
    return InviteResponse(
        code=code,
        role=invite.role,
        organization_id=invite.organization_id,
        expires_at=invite.expires_at,
        max_uses=invite.max_uses,
    )
