"""Thread Case vertical slice: organization authorization, history and evidence.

No timeline update/delete API. Each mutation locks a Case revision and appends one
history record in the same transaction. Request IDs make lost-response retries safe.
"""
import hashlib
import json
import uuid
from datetime import datetime, timezone
from typing import Literal

from fastapi import APIRouter, HTTPException, Query
from pydantic import BaseModel, ConfigDict, Field, AwareDatetime
from sqlalchemy import select, update, or_, func
from sqlalchemy.exc import IntegrityError

from app.auth import Current, Db
from app.models import (
    ThreadCase, CaseEvent, ThreadEvidence, ThreadRelation, ThreadRelationEvent,
    StrategyAssignment, OrganizationMembership, User,
)

router = APIRouter(prefix="/v1/thread", tags=["thread"])
Status = Literal["OPEN", "IN_REVIEW", "ACTION_REQUIRED", "IN_PROGRESS", "WAITING_FOR_EVIDENCE", "TRAINING_REQUIRED", "WAITING_FOR_VERIFICATION", "RESOLVED", "CLOSED"]


class Strict(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)


class CreateCase(Strict):
    id: uuid.UUID
    request_id: uuid.UUID
    title: str = Field(min_length=1, max_length=200)
    description: str = Field(default="", max_length=8000)
    type: Literal["ISSUE", "REQUIREMENT", "IMPROVEMENT", "FINDING"] = "ISSUE"
    priority: Literal["LOW", "NORMAL", "HIGH", "URGENT"] = "NORMAL"
    owner_id: uuid.UUID | None = None
    due_date: AwareDatetime | None = None


class Mutation(Strict):
    request_id: uuid.UUID
    base_revision: int = Field(ge=1)


class ChangeCase(Mutation):
    status: Status
    note: str = Field(min_length=1, max_length=4000)


class AddEvidence(Mutation):
    id: uuid.UUID
    title: str = Field(min_length=1, max_length=200)
    description: str = Field(min_length=1, max_length=8000)
    type: Literal["NOTE", "DOCUMENT", "REPORT", "RESULT", "TRAINING_RECORD"] = "NOTE"
    source: str = Field(default="", max_length=2000)


class VerifyEvidence(Mutation):
    state: Literal["VERIFIED", "REJECTED"]
    note: str = Field(min_length=1, max_length=4000)


class ImportTrainingEvidence(Mutation):
    id: uuid.UUID


def now():
    return datetime.now(timezone.utc)


def timestamp(value):
    if value is None:
        return None
    return value.replace(tzinfo=value.tzinfo or timezone.utc).astimezone(timezone.utc).isoformat()


def scope(identity):
    conditions = [ThreadCase.organization_id == identity.organization.id]
    if identity.role == "trainee":
        conditions.append(or_(ThreadCase.created_by == identity.user.id, ThreadCase.owner_id == identity.user.id))
    return conditions


def case_for(db, identity, case_id):
    row = db.scalar(select(ThreadCase).where(ThreadCase.id == case_id, *scope(identity)))
    if row is None:
        raise HTTPException(404, "Case not found")
    return row


def staff(identity):
    if identity.role not in ("instructor", "admin"):
        raise HTTPException(403, "Instructor or administrator required")


def evidence_json(e):
    return dict(id=str(e.id), case_id=str(e.case_id), title=e.title, description=e.description,
        type=e.type, source=e.source, created_by=str(e.created_by), created_at=timestamp(e.created_at),
        verification_state=e.verification_state, verified_by=str(e.verified_by) if e.verified_by else None,
        verified_at=timestamp(e.verified_at), verification_note=e.verification_note)


def case_json(db, row):
    evidence = db.scalars(select(ThreadEvidence).where(ThreadEvidence.case_id == row.id).order_by(ThreadEvidence.created_at, ThreadEvidence.id)).all()
    verified = bool(evidence) and all(e.verification_state == "VERIFIED" for e in evidence)
    return dict(id=str(row.id), title=row.title, description=row.description, type=row.type,
        priority=row.priority, status=row.status, created_by=str(row.created_by), owner_id=str(row.owner_id),
        created_at=timestamp(row.created_at), updated_at=timestamp(row.updated_at), due_date=timestamp(row.due_date),
        revision=row.revision, closure_reason=row.closure_reason, closed_at=timestamp(row.closed_at),
        verification_state="VERIFIED" if verified else "UNVERIFIED", evidence=[evidence_json(e) for e in evidence])


def fingerprint(kind, request):
    payload = request.model_dump(mode="json")
    return hashlib.sha256(json.dumps([kind, payload], sort_keys=True).encode()).hexdigest()


def retry(db, identity, row, kind, request):
    previous = db.scalar(select(CaseEvent).where(CaseEvent.case_id == row.id, CaseEvent.request_id == request.request_id))
    if previous:
        if previous.actor_id != identity.user.id or previous.request_hash != fingerprint(kind, request):
            raise HTTPException(409, "Request ID reused with different content")
        return {**case_json(db, row), "accepted_revision": previous.revision}
    return None


def lock_revision(db, row, request):
    updated = db.execute(update(ThreadCase).where(ThreadCase.id == row.id, ThreadCase.revision == request.base_revision).values(
        revision=request.base_revision + 1, updated_at=now()).execution_options(synchronize_session=False))
    if updated.rowcount != 1:
        db.rollback()
        raise HTTPException(409, "Case changed on another device. Review current history before retrying.")
    db.refresh(row)


def append_event(db, identity, row, kind, request, details):
    db.add(CaseEvent(case_id=row.id, revision=row.revision, request_id=request.request_id,
        request_hash=fingerprint(kind, request), type=details.get("action", kind), actor_id=identity.user.id, details=details))
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(409, "Concurrent change; retry the original request")
    return {**case_json(db, row), "accepted_revision": row.revision}


@router.get("/cases")
def cases(identity: Current, db: Db, after: uuid.UUID | None = None, limit: int = Query(40, ge=1, le=100)):
    query = select(ThreadCase).where(*scope(identity))
    if after:
        query = query.where(ThreadCase.id > after)
    rows = db.scalars(query.order_by(ThreadCase.id).limit(limit + 1)).all()
    return dict(items=[case_json(db, r) for r in rows[:limit]], next=str(rows[limit - 1].id) if len(rows) > limit else None)


@router.post("/cases")
def create_case(request: CreateCase, identity: Current, db: Db):
    existing = db.get(ThreadCase, request.id)
    if existing:
        row = case_for(db, identity, request.id)
        result = retry(db, identity, row, "CREATED", request)
        if result:
            return result
        raise HTTPException(409, "Case ID already exists")
    owner = request.owner_id or identity.user.id
    if owner != identity.user.id:
        staff(identity)
    member = db.scalar(select(OrganizationMembership).join(User).where(
        OrganizationMembership.organization_id == identity.organization.id,
        OrganizationMembership.user_id == owner, User.is_active.is_(True)))
    if member is None:
        raise HTTPException(404, "Owner not found")
    row = ThreadCase(id=request.id, organization_id=identity.organization.id, created_by=identity.user.id,
        owner_id=owner, title=request.title, description=request.description, type=request.type,
        priority=request.priority, due_date=request.due_date, status="OPEN", revision=1,
        closure_reason="", created_at=now(), updated_at=now())
    db.add(row)
    try:
        db.flush()
    except IntegrityError:
        db.rollback()
        raise HTTPException(409, "Concurrent creation; retry the original request")
    return append_event(db, identity, row, "CREATED", request, dict(title=row.title, owner_id=str(owner), status="OPEN"))


@router.get("/cases/{case_id}")
def get_case(case_id: uuid.UUID, identity: Current, db: Db):
    return case_json(db, case_for(db, identity, case_id))


@router.get("/cases/{case_id}/events")
def events(case_id: uuid.UUID, identity: Current, db: Db, after: int = Query(0, ge=0), limit: int = Query(50, ge=1, le=100)):
    case_for(db, identity, case_id)
    rows = db.scalars(select(CaseEvent).where(CaseEvent.case_id == case_id, CaseEvent.revision > after).order_by(CaseEvent.revision).limit(limit + 1)).all()
    return dict(items=[dict(id=str(e.id), revision=e.revision, type=e.type, actor_id=str(e.actor_id),
        details=e.details, created_at=timestamp(e.created_at)) for e in rows[:limit]],
        next=rows[limit - 1].revision if len(rows) > limit else None)


@router.patch("/cases/{case_id}")
def change_case(case_id: uuid.UUID, request: ChangeCase, identity: Current, db: Db):
    row = case_for(db, identity, case_id)
    # Fingerprints use the operation, independently of current state on a retry.
    result = retry(db, identity, row, "STATUS_CHANGED", request)
    if result:
        return result
    if request.status == "CLOSED" or row.status == "CLOSED":
        staff(identity)
    lock_revision(db, row, request)
    old = row.status
    if request.status == "CLOSED":
        evidence = db.scalars(select(ThreadEvidence).where(ThreadEvidence.case_id == row.id)).all()
        if not evidence or any(e.verification_state != "VERIFIED" for e in evidence):
            raise HTTPException(409, "Closure requires at least one evidence item and verification of every item")
        row.closed_at, row.closure_reason = now(), request.note
    elif old == "CLOSED":
        row.closed_at, row.closure_reason = None, ""
    row.status = request.status
    return append_event(db, identity, row, "STATUS_CHANGED", request,
        dict(before=old, after=request.status, note=request.note,
             action="CLOSED" if request.status == "CLOSED" else "REOPENED" if old == "CLOSED" else "UPDATED"))


@router.post("/cases/{case_id}/evidence")
def add_evidence(case_id: uuid.UUID, request: AddEvidence, identity: Current, db: Db):
    row = case_for(db, identity, case_id)
    result = retry(db, identity, row, "EVIDENCE_ADDED", request)
    if result:
        return result
    lock_revision(db, row, request)
    if row.status == "CLOSED":
        raise HTTPException(409, "Reopen Case before adding evidence")
    if db.scalar(select(func.count()).select_from(ThreadEvidence).where(ThreadEvidence.case_id == row.id)) >= 200:
        raise HTTPException(409, "Evidence limit reached (200 items per Case)")
    db.add(ThreadEvidence(id=request.id, case_id=row.id, title=request.title, description=request.description,
        type=request.type, source=request.source, created_by=identity.user.id, created_at=now(),
        verification_state="UNVERIFIED", verification_note=""))
    return append_event(db, identity, row, "EVIDENCE_ADDED", request,
        dict(evidence_id=str(request.id), title=request.title, source=request.source))


@router.post("/cases/{case_id}/evidence/{evidence_id}/verify")
def verify_evidence(case_id: uuid.UUID, evidence_id: uuid.UUID, request: VerifyEvidence, identity: Current, db: Db):
    staff(identity)
    row = case_for(db, identity, case_id)
    kind = "VERIFY_" + str(evidence_id)
    result = retry(db, identity, row, kind, request)
    if result:
        return result
    lock_revision(db, row, request)
    if row.status == "CLOSED":
        raise HTTPException(409, "Reopen Case before changing verification")
    evidence = db.scalar(select(ThreadEvidence).where(ThreadEvidence.id == evidence_id, ThreadEvidence.case_id == case_id))
    if evidence is None:
        raise HTTPException(404, "Evidence not found")
    evidence.verification_state = request.state
    evidence.verified_by, evidence.verified_at, evidence.verification_note = identity.user.id, now(), request.note
    # Stable operation key in the hash; human event type is stored in details.
    return append_event(db, identity, row, kind, request,
        dict(action="VERIFICATION_ACCEPTED" if request.state == "VERIFIED" else "VERIFICATION_REJECTED",
             evidence_id=str(evidence_id), title=evidence.title, note=request.note, state=request.state))

# ---------------------------------------------------------------------------
# Phase C: typed Digital Thread relationships.
# Relations are immutable. Creation is idempotent and every edge is authorized
# against both endpoints before it is returned or created.
# ---------------------------------------------------------------------------
EndpointType = Literal["CASE", "EVIDENCE", "TRAINING"]
RelationshipType = Literal[
    "CREATED_FROM", "REQUIRES", "VERIFIES", "PRODUCED", "SUPPORTED_BY",
    "TRAINED_BY", "RESULTED_IN", "SUPERSEDES", "RELATED_TO"
]


class CreateRelation(Strict):
    id: uuid.UUID
    request_id: uuid.UUID
    from_type: EndpointType
    from_id: uuid.UUID
    to_type: EndpointType
    to_id: uuid.UUID
    relationship_type: RelationshipType


def relation_json(row):
    return dict(
        id=str(row.id),
        from_type=row.from_type,
        from_id=str(row.from_id),
        to_type=row.to_type,
        to_id=str(row.to_id),
        relationship_type=row.relationship_type,
        created_by=str(row.created_by),
        created_at=timestamp(row.created_at),
    )


def _training_visible(db, identity, assignment_id: uuid.UUID):
    row = db.get(StrategyAssignment, assignment_id)
    if row is None or row.organization_id != identity.organization.id:
        raise HTTPException(404, "Training assignment not found")
    if identity.role == "trainee" and row.learner_id != identity.user.id:
        raise HTTPException(404, "Training assignment not found")
    if identity.role == "instructor" and row.instructor_id != identity.user.id:
        raise HTTPException(404, "Training assignment not found")
    return row


def _endpoint_case(
    db, identity, endpoint_type: str, endpoint_id: uuid.UUID, *,
    allow_missing_training: bool = False,
):
    """Authorize an endpoint or return 404 without leaking another unit's data."""
    if endpoint_type == "CASE":
        return case_for(db, identity, endpoint_id)
    if endpoint_type == "EVIDENCE":
        evidence = db.get(ThreadEvidence, endpoint_id)
        if evidence is None:
            raise HTTPException(404, "Thread endpoint not found")
        return case_for(db, identity, evidence.case_id)
    if endpoint_type == "TRAINING":
        assignment = db.get(StrategyAssignment, endpoint_id)
        if assignment is None and allow_missing_training and identity.role in ("instructor", "admin"):
            # Assignment creation and Thread linking are separate offline queues.
            # A short-lived dangling edge is allowed so both queues can survive
            # network interruption without losing the user's intent.
            return None
        return _training_visible(db, identity, endpoint_id)
    raise HTTPException(422, "Unsupported Thread endpoint type")


def _relation_visible(db, identity, row):
    if row.organization_id != identity.organization.id:
        raise HTTPException(404, "Relation not found")
    _endpoint_case(db, identity, row.from_type, row.from_id)
    _endpoint_case(db, identity, row.to_type, row.to_id)
    return row


def _relation_fingerprint(request: CreateRelation) -> str:
    payload = request.model_dump(mode="json")
    return hashlib.sha256(json.dumps(["RELATION_CREATED", payload], sort_keys=True).encode()).hexdigest()


@router.post("/relations")
def create_relation(request: CreateRelation, identity: Current, db: Db):
    if request.from_type == request.to_type and request.from_id == request.to_id:
        raise HTTPException(422, "A Thread relation cannot point to itself")

    # Training links are staff-authored and may be queued before the Strategy
    # assignment reaches the server. All other endpoints must already exist.
    if "TRAINING" in (request.from_type, request.to_type):
        staff(identity)
        if {request.from_type, request.to_type} != {"CASE", "TRAINING"} or request.relationship_type != "TRAINED_BY":
            raise HTTPException(422, "Training relations must connect CASE and TRAINING with TRAINED_BY")
        _endpoint_case(db, identity, request.from_type, request.from_id, allow_missing_training=True)
        _endpoint_case(db, identity, request.to_type, request.to_id, allow_missing_training=True)
    else:
        # Authorization is deliberately performed for BOTH endpoints.
        _endpoint_case(db, identity, request.from_type, request.from_id)
        _endpoint_case(db, identity, request.to_type, request.to_id)

    existing = db.get(ThreadRelation, request.id)
    if existing is not None:
        _relation_visible(db, identity, existing)
        event = db.scalar(select(ThreadRelationEvent).where(
            ThreadRelationEvent.relation_id == existing.id,
            ThreadRelationEvent.request_id == request.request_id,
        ))
        if event is not None and event.actor_id == identity.user.id and event.request_hash == _relation_fingerprint(request):
            return relation_json(existing)
        raise HTTPException(409, "Relation ID already exists")

    duplicate = db.scalar(select(ThreadRelation).where(
        ThreadRelation.organization_id == identity.organization.id,
        ThreadRelation.from_type == request.from_type,
        ThreadRelation.from_id == request.from_id,
        ThreadRelation.to_type == request.to_type,
        ThreadRelation.to_id == request.to_id,
        ThreadRelation.relationship_type == request.relationship_type,
    ))
    if duplicate is not None:
        _relation_visible(db, identity, duplicate)
        raise HTTPException(409, "This Thread relation already exists")

    row = ThreadRelation(
        id=request.id,
        organization_id=identity.organization.id,
        from_type=request.from_type,
        from_id=request.from_id,
        to_type=request.to_type,
        to_id=request.to_id,
        relationship_type=request.relationship_type,
        created_by=identity.user.id,
        created_at=now(),
    )
    db.add(row)
    db.add(ThreadRelationEvent(
        relation_id=request.id,
        request_id=request.request_id,
        request_hash=_relation_fingerprint(request),
        type="CREATED",
        actor_id=identity.user.id,
        details=dict(
            from_type=request.from_type,
            from_id=str(request.from_id),
            to_type=request.to_type,
            to_id=str(request.to_id),
            relationship_type=request.relationship_type,
        ),
    ))
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(409, "Concurrent relation creation; refresh and retry")
    db.refresh(row)
    return relation_json(row)


@router.get("/cases/{case_id}/relations")
def case_relations(case_id: uuid.UUID, identity: Current, db: Db, limit: int = Query(100, ge=1, le=200)):
    root = case_for(db, identity, case_id)
    evidence_ids = list(db.scalars(select(ThreadEvidence.id).where(ThreadEvidence.case_id == root.id)))
    endpoint_filters = [
        (ThreadRelation.from_type == "CASE") & (ThreadRelation.from_id == root.id),
        (ThreadRelation.to_type == "CASE") & (ThreadRelation.to_id == root.id),
    ]
    if evidence_ids:
        endpoint_filters.extend([
            (ThreadRelation.from_type == "EVIDENCE") & (ThreadRelation.from_id.in_(evidence_ids)),
            (ThreadRelation.to_type == "EVIDENCE") & (ThreadRelation.to_id.in_(evidence_ids)),
        ])
    rows = db.scalars(
        select(ThreadRelation)
        .where(ThreadRelation.organization_id == identity.organization.id, or_(*endpoint_filters))
        .order_by(ThreadRelation.created_at, ThreadRelation.id)
        .limit(limit)
    ).all()
    visible = []
    for row in rows:
        try:
            _relation_visible(db, identity, row)
        except HTTPException:
            continue
        visible.append(relation_json(row))
    return {"items": visible}


def _training_json(row, *, relation_id: uuid.UUID | None = None, evidence_attached: bool = False):
    scenario = row.scenario or {}
    return dict(
        id=str(row.id),
        relation_id=str(relation_id) if relation_id else None,
        learner_id=str(row.learner_id),
        instructor_id=str(row.instructor_id),
        title=str(scenario.get("title") or "Simulation Lab training"),
        status=row.status,
        revision=row.revision,
        due_at=timestamp(row.due_at),
        submitted_at=timestamp(row.submitted_at),
        metrics=row.metrics,
        feedback=row.feedback,
        has_submission=row.submission is not None,
        evidence_attached=evidence_attached,
    )


def _case_training_relations(db, identity, case_id: uuid.UUID):
    case_for(db, identity, case_id)
    return db.scalars(
        select(ThreadRelation).where(
            ThreadRelation.organization_id == identity.organization.id,
            ThreadRelation.relationship_type == "TRAINED_BY",
            or_(
                (ThreadRelation.from_type == "CASE") & (ThreadRelation.from_id == case_id) & (ThreadRelation.to_type == "TRAINING"),
                (ThreadRelation.to_type == "CASE") & (ThreadRelation.to_id == case_id) & (ThreadRelation.from_type == "TRAINING"),
            ),
        ).order_by(ThreadRelation.created_at, ThreadRelation.id)
    ).all()


@router.get("/cases/{case_id}/training")
def case_training(case_id: uuid.UUID, identity: Current, db: Db):
    rows = []
    for relation in _case_training_relations(db, identity, case_id):
        assignment_id = relation.to_id if relation.to_type == "TRAINING" else relation.from_id
        try:
            assignment = _training_visible(db, identity, assignment_id)
        except HTTPException:
            # Preserve the edge while a separately queued assignment is still
            # offline, but never expose data the current identity cannot read.
            continue
        source = f"strategy_assignment:{assignment.id}"
        attached = db.scalar(select(func.count()).select_from(ThreadEvidence).where(
            ThreadEvidence.case_id == case_id, ThreadEvidence.source == source
        )) > 0
        rows.append(_training_json(assignment, relation_id=relation.id, evidence_attached=attached))
    return {"items": rows}


@router.post("/cases/{case_id}/training/{assignment_id}/evidence")
def import_training_evidence(
    case_id: uuid.UUID, assignment_id: uuid.UUID, request: ImportTrainingEvidence,
    identity: Current, db: Db,
):
    row = case_for(db, identity, case_id)
    assignment = _training_visible(db, identity, assignment_id)
    linked = any(
        (r.from_type == "CASE" and r.from_id == case_id and r.to_type == "TRAINING" and r.to_id == assignment_id) or
        (r.to_type == "CASE" and r.to_id == case_id and r.from_type == "TRAINING" and r.from_id == assignment_id)
        for r in _case_training_relations(db, identity, case_id)
    )
    if not linked:
        raise HTTPException(409, "Training assignment is not linked to this Case")
    if assignment.status != "submitted" or assignment.submission is None or assignment.metrics is None:
        raise HTTPException(409, "Training result is not complete yet")

    kind = f"TRAINING_RESULT_{assignment_id}"
    result = retry(db, identity, row, kind, request)
    if result:
        return result
    source = f"strategy_assignment:{assignment.id}"
    existing = db.scalar(select(ThreadEvidence).where(
        ThreadEvidence.case_id == case_id, ThreadEvidence.source == source
    ))
    if existing is not None:
        raise HTTPException(409, "Training result is already attached as evidence")

    lock_revision(db, row, request)
    if row.status == "CLOSED":
        raise HTTPException(409, "Reopen Case before attaching a training result")

    scenario = assignment.scenario or {}
    title = str(scenario.get("title") or "Simulation Lab training")
    metrics = assignment.metrics or {}
    summary_parts = [f"Training: {title}", f"Status: {assignment.status}"]
    for key in ("score", "completed", "turns", "control", "stability", "intel"):
        if key in metrics:
            summary_parts.append(f"{key}: {metrics[key]}")
    evidence = ThreadEvidence(
        id=request.id, case_id=row.id, title=f"Training result · {title}",
        description=" · ".join(summary_parts), type="TRAINING_RECORD", source=source,
        created_by=identity.user.id, created_at=now(), verification_state="UNVERIFIED",
        verification_note="",
    )
    db.add(evidence)
    relation = ThreadRelation(
        id=uuid.uuid4(), organization_id=identity.organization.id,
        from_type="TRAINING", from_id=assignment.id, to_type="EVIDENCE", to_id=evidence.id,
        relationship_type="PRODUCED", created_by=identity.user.id, created_at=now(),
    )
    db.add(relation)
    db.add(ThreadRelationEvent(
        relation_id=relation.id, request_id=request.request_id,
        request_hash=fingerprint(kind + "_RELATION", request), type="CREATED", actor_id=identity.user.id,
        details=dict(from_type="TRAINING", from_id=str(assignment.id), to_type="EVIDENCE",
                     to_id=str(evidence.id), relationship_type="PRODUCED"),
    ))
    row.status = "WAITING_FOR_VERIFICATION"
    return append_event(
        db, identity, row, kind, request,
        dict(action="TRAINING_COMPLETED", assignment_id=str(assignment.id), evidence_id=str(evidence.id),
             title=title, status=row.status),
    )


@router.get("/relations/{relation_id}/events")
def relation_events(relation_id: uuid.UUID, identity: Current, db: Db):
    row = db.get(ThreadRelation, relation_id)
    if row is None:
        raise HTTPException(404, "Relation not found")
    _relation_visible(db, identity, row)
    events = db.scalars(
        select(ThreadRelationEvent)
        .where(ThreadRelationEvent.relation_id == relation_id)
        .order_by(ThreadRelationEvent.created_at, ThreadRelationEvent.id)
    ).all()
    return {"items": [dict(
        id=str(e.id),
        type=e.type,
        actor_id=str(e.actor_id),
        details=e.details,
        created_at=timestamp(e.created_at),
    ) for e in events]}

