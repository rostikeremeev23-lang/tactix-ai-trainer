"""TACTIX BRANCH: deterministic three-way planning variants for Thread Cases.

Branches are staff-only planning overlays. They never mutate a Case while being
edited. Compare is deterministic and server-side. Merge applies only fields that
changed from the branch base, preserves unrelated live edits, blocks overlapping
conflicts, and records an immutable Case event plus Branch event.
"""
from __future__ import annotations

import hashlib
import json
import uuid
from datetime import datetime, timezone
from typing import Any, Literal

from fastapi import APIRouter, HTTPException, Query
from pydantic import AwareDatetime, BaseModel, ConfigDict, Field
from sqlalchemy import or_, select, update
from sqlalchemy.exc import IntegrityError

from app.auth import Current, Db
from app.models import (
    CaseEvent,
    OrganizationMembership,
    StrategyAssignment,
    ThreadBranch,
    ThreadBranchEvent,
    ThreadCase,
    ThreadRelation,
    User,
)
from app.thread import case_for, now, staff, timestamp

router = APIRouter(prefix="/v1/thread", tags=["thread-branch"])

BranchStatus = Literal["DRAFT", "MERGED", "ARCHIVED"]
CasePlanStatus = Literal[
    "OPEN",
    "IN_REVIEW",
    "ACTION_REQUIRED",
    "IN_PROGRESS",
    "WAITING_FOR_EVIDENCE",
    "TRAINING_REQUIRED",
    "WAITING_FOR_VERIFICATION",
    "RESOLVED",
]
Priority = Literal["LOW", "NORMAL", "HIGH", "URGENT"]
PlanItemKind = Literal["TASK", "TRAINING", "REVIEW"]


class Strict(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)


class PlanItem(Strict):
    id: uuid.UUID
    title: str = Field(min_length=1, max_length=240)
    kind: PlanItemKind = "TASK"
    assignee_id: uuid.UUID | None = None
    due_at: AwareDatetime | None = None
    note: str = Field(default="", max_length=2000)


class BranchDraft(Strict):
    description: str = Field(default="", max_length=8000)
    priority: Priority
    status: CasePlanStatus
    owner_id: uuid.UUID
    due_date: AwareDatetime | None = None
    plan_items: list[PlanItem] = Field(default_factory=list, max_length=40)


class CreateBranch(Strict):
    id: uuid.UUID
    request_id: uuid.UUID
    name: str = Field(min_length=1, max_length=160)
    description: str = Field(default="", max_length=2000)


class UpdateBranch(Strict):
    request_id: uuid.UUID
    base_revision: int = Field(ge=1)
    name: str = Field(min_length=1, max_length=160)
    description: str = Field(default="", max_length=2000)
    draft: BranchDraft


class MergeBranch(Strict):
    request_id: uuid.UUID
    base_revision: int = Field(ge=1)
    note: str = Field(min_length=1, max_length=2000)


def _hash(kind: str, request: BaseModel) -> str:
    body = request.model_dump(mode="json")
    return hashlib.sha256(json.dumps([kind, body], sort_keys=True).encode()).hexdigest()


def _snapshot(row: ThreadCase) -> dict[str, Any]:
    return {
        "description": row.description,
        "priority": row.priority,
        "status": row.status,
        "owner_id": str(row.owner_id),
        "due_date": timestamp(row.due_date),
        "plan_items": [],
    }


def _branch_for(db, identity, branch_id: uuid.UUID) -> ThreadBranch:
    staff(identity)
    row = db.scalar(
        select(ThreadBranch).where(
            ThreadBranch.id == branch_id,
            ThreadBranch.organization_id == identity.organization.id,
        )
    )
    if row is None:
        raise HTTPException(404, "Branch not found")
    case_for(db, identity, row.case_id)
    return row


def _event_json(row: ThreadBranchEvent) -> dict[str, Any]:
    return {
        "id": str(row.id),
        "revision": row.revision,
        "type": row.type,
        "actor_id": str(row.actor_id),
        "details": row.details,
        "created_at": timestamp(row.created_at),
    }


def _branch_json(row: ThreadBranch) -> dict[str, Any]:
    return {
        "id": str(row.id),
        "case_id": str(row.case_id),
        "name": row.name,
        "description": row.description,
        "status": row.status,
        "base_case_revision": row.base_case_revision,
        "revision": row.revision,
        "base_snapshot": row.base_snapshot,
        "draft_snapshot": row.draft_snapshot,
        "created_by": str(row.created_by),
        "merged_by": str(row.merged_by) if row.merged_by else None,
        "merged_at": timestamp(row.merged_at),
        "created_at": timestamp(row.created_at),
        "updated_at": timestamp(row.updated_at),
    }


def _member(db, organization_id: uuid.UUID, user_id: uuid.UUID) -> OrganizationMembership | None:
    return db.scalar(
        select(OrganizationMembership)
        .join(User, User.id == OrganizationMembership.user_id)
        .where(
            OrganizationMembership.organization_id == organization_id,
            OrganizationMembership.user_id == user_id,
            User.is_active.is_(True),
        )
    )


def _validate_draft(db, identity, draft: dict[str, Any]) -> None:
    try:
        owner = uuid.UUID(str(draft["owner_id"]))
    except (KeyError, ValueError, TypeError):
        raise HTTPException(422, "Branch owner is invalid")
    if _member(db, identity.organization.id, owner) is None:
        raise HTTPException(422, "Branch owner is not an active organization member")
    seen: set[str] = set()
    for raw in draft.get("plan_items", []):
        key = str(raw.get("id", ""))
        if not key or key in seen:
            raise HTTPException(422, "Plan item IDs must be unique")
        seen.add(key)
        assignee = raw.get("assignee_id")
        if assignee and _member(db, identity.organization.id, uuid.UUID(str(assignee))) is None:
            raise HTTPException(422, "Plan item assignee is not an active organization member")


def _normalize(value: Any) -> Any:
    if isinstance(value, datetime):
        return timestamp(value)
    if isinstance(value, uuid.UUID):
        return str(value)
    return value


def _field_changes(base: dict[str, Any], other: dict[str, Any]) -> dict[str, tuple[Any, Any]]:
    fields = ("description", "priority", "status", "owner_id", "due_date")
    result: dict[str, tuple[Any, Any]] = {}
    for field in fields:
        before, after = _normalize(base.get(field)), _normalize(other.get(field))
        if before != after:
            result[field] = (before, after)
    return result


def _linked_training(db, organization_id: uuid.UUID, case_id: uuid.UUID) -> list[StrategyAssignment]:
    edges = db.scalars(
        select(ThreadRelation).where(
            ThreadRelation.organization_id == organization_id,
            ThreadRelation.relationship_type == "TRAINED_BY",
            or_(
                (ThreadRelation.from_type == "CASE") & (ThreadRelation.from_id == case_id),
                (ThreadRelation.to_type == "CASE") & (ThreadRelation.to_id == case_id),
            ),
        )
    ).all()
    result: list[StrategyAssignment] = []
    for edge in edges:
        assignment_id = edge.to_id if edge.to_type == "TRAINING" else edge.from_id
        row = db.get(StrategyAssignment, assignment_id)
        if row is not None and row.organization_id == organization_id:
            result.append(row)
    return result


def _compare(db, identity, branch: ThreadBranch) -> dict[str, Any]:
    live = case_for(db, identity, branch.case_id)
    base = dict(branch.base_snapshot or {})
    draft = dict(branch.draft_snapshot or {})
    live_snapshot = _snapshot(live)
    branch_changes = _field_changes(base, draft)
    live_changes = _field_changes(base, live_snapshot)

    conflicts: list[dict[str, Any]] = []
    for field, (_, proposed) in branch_changes.items():
        if field in live_changes:
            live_value = live_changes[field][1]
            if _normalize(live_value) != _normalize(proposed):
                conflicts.append({
                    "code": "FIELD_DIVERGED",
                    "severity": "BLOCKING",
                    "field": field,
                    "message": f"Live Case and Branch both changed {field} differently.",
                    "live": live_value,
                    "branch": proposed,
                })

    if live.status == "CLOSED":
        conflicts.append({
            "code": "CASE_CLOSED",
            "severity": "BLOCKING",
            "field": "status",
            "message": "A closed Case cannot receive a Branch merge. Reopen it through the normal verification flow first.",
        })

    owner_id = draft.get("owner_id")
    try:
        owner_uuid = uuid.UUID(str(owner_id))
    except (ValueError, TypeError):
        owner_uuid = None
    if owner_uuid is None or _member(db, identity.organization.id, owner_uuid) is None:
        conflicts.append({
            "code": "OWNER_UNAVAILABLE",
            "severity": "BLOCKING",
            "field": "owner_id",
            "message": "The proposed Case owner is not an active organization member.",
        })

    now_utc = datetime.now(timezone.utc)
    due_raw = draft.get("due_date")
    due = None
    if due_raw:
        try:
            due = datetime.fromisoformat(str(due_raw).replace("Z", "+00:00"))
            if due.tzinfo is None:
                due = due.replace(tzinfo=timezone.utc)
        except ValueError:
            conflicts.append({
                "code": "INVALID_DUE_DATE",
                "severity": "BLOCKING",
                "field": "due_date",
                "message": "The proposed due date cannot be parsed.",
            })
    if due and due < now_utc:
        conflicts.append({
            "code": "CASE_DUE_IN_PAST",
            "severity": "WARNING",
            "field": "due_date",
            "message": "The proposed Case due date is already in the past.",
        })

    titles: set[str] = set()
    for item in draft.get("plan_items", []):
        title = str(item.get("title", "")).strip()
        folded = title.casefold()
        if folded in titles:
            conflicts.append({
                "code": "DUPLICATE_PLAN_ITEM",
                "severity": "WARNING",
                "field": "plan_items",
                "message": f"Plan contains duplicate item title: {title}",
            })
        titles.add(folded)
        item_due_raw = item.get("due_at")
        if item_due_raw and due:
            try:
                item_due = datetime.fromisoformat(str(item_due_raw).replace("Z", "+00:00"))
                if item_due.tzinfo is None:
                    item_due = item_due.replace(tzinfo=timezone.utc)
                if item_due > due:
                    conflicts.append({
                        "code": "PLAN_ITEM_AFTER_CASE_DUE",
                        "severity": "WARNING",
                        "field": "plan_items",
                        "message": f"Plan item '{title}' is due after the proposed Case due date.",
                    })
            except ValueError:
                conflicts.append({
                    "code": "INVALID_PLAN_ITEM_DUE",
                    "severity": "BLOCKING",
                    "field": "plan_items",
                    "message": f"Plan item '{title}' has an invalid due date.",
                })

    if due:
        for assignment in _linked_training(db, identity.organization.id, branch.case_id):
            if assignment.due_at is not None:
                training_due = assignment.due_at
                if training_due.tzinfo is None:
                    training_due = training_due.replace(tzinfo=timezone.utc)
                if training_due > due:
                    conflicts.append({
                        "code": "TRAINING_AFTER_CASE_DUE",
                        "severity": "WARNING",
                        "field": "due_date",
                        "message": "Linked training is scheduled after the proposed Case due date.",
                        "training_id": str(assignment.id),
                        "training_due_at": timestamp(assignment.due_at),
                    })

    changes = [
        {"field": field, "before": before, "after": after}
        for field, (before, after) in branch_changes.items()
    ]
    return {
        "branch_id": str(branch.id),
        "case_id": str(branch.case_id),
        "branch_revision": branch.revision,
        "base_case_revision": branch.base_case_revision,
        "live_case_revision": live.revision,
        "stale_base": live.revision != branch.base_case_revision,
        "changes": changes,
        "plan_items": draft.get("plan_items", []),
        "conflicts": conflicts,
        "blocking_conflicts": sum(1 for c in conflicts if c["severity"] == "BLOCKING"),
        "warnings": sum(1 for c in conflicts if c["severity"] == "WARNING"),
        "can_merge": branch.status == "DRAFT" and not any(c["severity"] == "BLOCKING" for c in conflicts),
        "live_case": live_snapshot,
        "draft": draft,
    }


def _append_branch_event(db, identity, branch: ThreadBranch, kind: str, request: BaseModel, details: dict[str, Any]) -> None:
    db.add(ThreadBranchEvent(
        branch_id=branch.id,
        revision=branch.revision,
        request_id=request.request_id,
        request_hash=_hash(kind, request),
        type=kind,
        actor_id=identity.user.id,
        details=details,
    ))


def _retry_branch_event(db, identity, branch: ThreadBranch, kind: str, request: BaseModel) -> dict[str, Any] | None:
    previous = db.scalar(
        select(ThreadBranchEvent).where(
            ThreadBranchEvent.branch_id == branch.id,
            ThreadBranchEvent.request_id == request.request_id,
        )
    )
    if previous is None:
        return None
    if previous.actor_id != identity.user.id or previous.request_hash != _hash(kind, request):
        raise HTTPException(409, "Branch request ID reused with different content")
    return _branch_json(branch)


@router.get("/cases/{case_id}/branch-options")
def branch_options(case_id: uuid.UUID, identity: Current, db: Db):
    staff(identity)
    case_for(db, identity, case_id)
    rows = db.execute(
        select(OrganizationMembership, User)
        .join(User, User.id == OrganizationMembership.user_id)
        .where(
            OrganizationMembership.organization_id == identity.organization.id,
            User.is_active.is_(True),
        )
        .order_by(User.callsign, User.first_name)
    ).all()
    return {
        "owners": [
            {
                "id": str(member.user_id),
                "role": member.role,
                "callsign": user.callsign,
                "first_name": user.first_name,
                "label": user.callsign or user.first_name or user.email,
            }
            for member, user in rows
        ]
    }


@router.get("/cases/{case_id}/branches")
def list_branches(case_id: uuid.UUID, identity: Current, db: Db, limit: int = Query(30, ge=1, le=100)):
    staff(identity)
    case_for(db, identity, case_id)
    rows = db.scalars(
        select(ThreadBranch)
        .where(
            ThreadBranch.case_id == case_id,
            ThreadBranch.organization_id == identity.organization.id,
        )
        .order_by(ThreadBranch.created_at.desc())
        .limit(limit)
    ).all()
    return {"items": [_branch_json(row) for row in rows]}


@router.post("/cases/{case_id}/branches")
def create_branch(case_id: uuid.UUID, request: CreateBranch, identity: Current, db: Db):
    staff(identity)
    case = case_for(db, identity, case_id)
    existing = db.get(ThreadBranch, request.id)
    if existing is not None:
        branch = _branch_for(db, identity, request.id)
        result = _retry_branch_event(db, identity, branch, "CREATED", request)
        if result is not None:
            return result
        raise HTTPException(409, "Branch ID already exists")
    if case.status == "CLOSED":
        raise HTTPException(409, "Reopen Case before creating a planning Branch")
    snapshot = _snapshot(case)
    branch = ThreadBranch(
        id=request.id,
        organization_id=identity.organization.id,
        case_id=case.id,
        created_by=identity.user.id,
        name=request.name,
        description=request.description,
        status="DRAFT",
        base_case_revision=case.revision,
        revision=1,
        base_snapshot=snapshot,
        draft_snapshot=snapshot,
        created_at=now(),
        updated_at=now(),
    )
    db.add(branch)
    _append_branch_event(db, identity, branch, "CREATED", request, {"base_case_revision": case.revision})
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(409, "Concurrent Branch creation; retry the original request")
    db.refresh(branch)
    return _branch_json(branch)


@router.get("/branches/{branch_id}")
def get_branch(branch_id: uuid.UUID, identity: Current, db: Db):
    return _branch_json(_branch_for(db, identity, branch_id))


@router.get("/branches/{branch_id}/events")
def branch_events(branch_id: uuid.UUID, identity: Current, db: Db):
    branch = _branch_for(db, identity, branch_id)
    rows = db.scalars(
        select(ThreadBranchEvent)
        .where(ThreadBranchEvent.branch_id == branch.id)
        .order_by(ThreadBranchEvent.revision, ThreadBranchEvent.created_at)
    ).all()
    return {"items": [_event_json(row) for row in rows]}


@router.put("/branches/{branch_id}")
def update_branch(branch_id: uuid.UUID, request: UpdateBranch, identity: Current, db: Db):
    branch = _branch_for(db, identity, branch_id)
    result = _retry_branch_event(db, identity, branch, "UPDATED", request)
    if result is not None:
        return result
    if branch.status != "DRAFT":
        raise HTTPException(409, "Only a draft Branch can be edited")
    if branch.revision != request.base_revision:
        raise HTTPException(409, "Branch changed on another device. Refresh before editing.")
    draft = request.draft.model_dump(mode="json")
    _validate_draft(db, identity, draft)
    old_revision = branch.revision
    updated = db.execute(
        update(ThreadBranch)
        .where(ThreadBranch.id == branch.id, ThreadBranch.revision == old_revision)
        .values(
            revision=old_revision + 1,
            name=request.name,
            description=request.description,
            draft_snapshot=draft,
            updated_at=now(),
        )
        .execution_options(synchronize_session=False)
    )
    if updated.rowcount != 1:
        db.rollback()
        raise HTTPException(409, "Concurrent Branch update; refresh before retrying")
    db.refresh(branch)
    _append_branch_event(db, identity, branch, "UPDATED", request, {"draft": draft})
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(409, "Concurrent Branch update; retry the original request")
    db.refresh(branch)
    return _branch_json(branch)


@router.get("/branches/{branch_id}/compare")
def compare_branch(branch_id: uuid.UUID, identity: Current, db: Db):
    branch = _branch_for(db, identity, branch_id)
    return _compare(db, identity, branch)


@router.post("/branches/{branch_id}/merge")
def merge_branch(branch_id: uuid.UUID, request: MergeBranch, identity: Current, db: Db):
    branch = _branch_for(db, identity, branch_id)
    result = _retry_branch_event(db, identity, branch, "MERGED", request)
    if result is not None:
        return {"branch": result, "case": _snapshot(case_for(db, identity, branch.case_id)), "compare": _compare(db, identity, branch)}
    if branch.status != "DRAFT":
        raise HTTPException(409, "Only a draft Branch can be merged")
    if branch.revision != request.base_revision:
        raise HTTPException(409, "Branch changed on another device. Refresh before merging.")

    comparison = _compare(db, identity, branch)
    blocking = [c for c in comparison["conflicts"] if c["severity"] == "BLOCKING"]
    if blocking:
        raise HTTPException(409, {"message": "Branch merge blocked by conflicts", "compare": comparison})

    case = case_for(db, identity, branch.case_id)
    base = dict(branch.base_snapshot or {})
    draft = dict(branch.draft_snapshot or {})
    changes = _field_changes(base, draft)
    values: dict[str, Any] = {"revision": case.revision + 1, "updated_at": now()}
    for field, (_, after) in changes.items():
        if field == "owner_id":
            values[field] = uuid.UUID(str(after))
        elif field == "due_date":
            if after is None:
                values[field] = None
            else:
                parsed = datetime.fromisoformat(str(after).replace("Z", "+00:00"))
                values[field] = parsed if parsed.tzinfo else parsed.replace(tzinfo=timezone.utc)
        else:
            values[field] = after

    current_revision = case.revision
    updated = db.execute(
        update(ThreadCase)
        .where(ThreadCase.id == case.id, ThreadCase.revision == current_revision)
        .values(**values)
        .execution_options(synchronize_session=False)
    )
    if updated.rowcount != 1:
        db.rollback()
        raise HTTPException(409, "Case changed during merge. Compare the Branch again.")
    db.refresh(case)

    case_request_hash = hashlib.sha256(
        json.dumps(["BRANCH_MERGED", request.model_dump(mode="json"), str(branch.id)], sort_keys=True).encode()
    ).hexdigest()
    db.add(CaseEvent(
        case_id=case.id,
        revision=case.revision,
        request_id=request.request_id,
        request_hash=case_request_hash,
        type="BRANCH_MERGED",
        actor_id=identity.user.id,
        details={
            "branch_id": str(branch.id),
            "branch_name": branch.name,
            "note": request.note,
            "changes": comparison["changes"],
            "plan_items": draft.get("plan_items", []),
            "warnings": [c for c in comparison["conflicts"] if c["severity"] == "WARNING"],
        },
    ))

    branch.status = "MERGED"
    branch.revision += 1
    branch.merged_by = identity.user.id
    branch.merged_at = now()
    branch.updated_at = now()
    _append_branch_event(db, identity, branch, "MERGED", request, {
        "case_revision": case.revision,
        "changes": comparison["changes"],
        "plan_items": draft.get("plan_items", []),
    })
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(409, "Concurrent Branch merge; refresh current state")
    db.refresh(branch)
    db.refresh(case)
    return {
        "branch": _branch_json(branch),
        "case": {
            "id": str(case.id),
            "revision": case.revision,
            **_snapshot(case),
        },
        "compare": _compare(db, identity, branch),
    }
