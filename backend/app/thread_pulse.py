"""TACTIX PULSE: deterministic process intelligence and unified event stream.

The module derives organization-scoped administrative/training process signals from
existing THREAD data. It does not make operational recommendations and does not
persist a second analytics truth; everything is recomputed from authoritative
records already stored by TACTIX.
"""
from __future__ import annotations

import uuid
from collections import Counter, defaultdict
from datetime import datetime, timedelta, timezone
from typing import Any

from fastapi import APIRouter, Query
from sqlalchemy import select

from app.auth import Current, Db
from app.models import (
    CaseEvent,
    StrategyAssignment,
    ThreadBranch,
    ThreadBranchEvent,
    ThreadCase,
    ThreadEvidence,
    ThreadRelation,
    ThreadRelationEvent,
)
from app.thread import staff, timestamp

router = APIRouter(prefix="/v1/thread", tags=["thread-pulse"])


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _aware(value: datetime | None) -> datetime | None:
    if value is None:
        return None
    return value.replace(tzinfo=value.tzinfo or timezone.utc).astimezone(timezone.utc)


def _age_hours(value: datetime | None, now: datetime) -> float:
    value = _aware(value)
    if value is None:
        return 0.0
    return max(0.0, (now - value).total_seconds() / 3600.0)


def _round(value: float) -> float:
    return round(value, 1)


def _case_alert(row: ThreadCase, code: str, severity: str, now: datetime) -> dict[str, Any]:
    return {
        "code": code,
        "severity": severity,
        "case_id": str(row.id),
        "title": row.title,
        "status": row.status,
        "priority": row.priority,
        "age_hours": _round(_age_hours(row.updated_at, now)),
        "due_date": timestamp(row.due_date),
    }


@router.get("/pulse")
def pulse(
    identity: Current,
    db: Db,
    stale_hours: int = Query(72, ge=24, le=720),
    due_hours: int = Query(48, ge=6, le=168),
):
    """Return deterministic organization-level process health for staff users."""
    staff(identity)
    now = _now()
    org = identity.organization.id
    cases = db.scalars(
        select(ThreadCase)
        .where(ThreadCase.organization_id == org)
        .order_by(ThreadCase.updated_at.desc(), ThreadCase.id)
    ).all()
    case_ids = [row.id for row in cases]

    evidence = []
    if case_ids:
        evidence = db.scalars(
            select(ThreadEvidence).where(ThreadEvidence.case_id.in_(case_ids))
        ).all()
    branches = db.scalars(
        select(ThreadBranch).where(ThreadBranch.organization_id == org)
    ).all()
    training = db.scalars(
        select(StrategyAssignment).where(StrategyAssignment.organization_id == org)
    ).all()

    active = [row for row in cases if row.status != "CLOSED"]
    closed = [row for row in cases if row.status == "CLOSED"]
    status_counts = Counter(row.status for row in active)
    priority_counts = Counter(row.priority for row in active)

    overdue = [
        row for row in active
        if _aware(row.due_date) is not None and _aware(row.due_date) < now
    ]
    due_soon_cutoff = now + timedelta(hours=due_hours)
    due_soon = [
        row for row in active
        if _aware(row.due_date) is not None and now <= _aware(row.due_date) <= due_soon_cutoff
    ]
    stale = [row for row in active if _age_hours(row.updated_at, now) >= stale_hours]
    waiting_verification = [row for row in active if row.status == "WAITING_FOR_VERIFICATION"]
    unverified_evidence = [row for row in evidence if row.verification_state == "UNVERIFIED"]
    rejected_evidence = [row for row in evidence if row.verification_state == "REJECTED"]
    draft_branches = [row for row in branches if row.status == "DRAFT"]
    training_pending = [row for row in training if row.status not in ("submitted", "reviewed", "completed")]

    seven_days_ago = now - timedelta(days=7)
    created_7d = [row for row in cases if _aware(row.created_at) and _aware(row.created_at) >= seven_days_ago]
    closed_7d = [row for row in closed if _aware(row.closed_at) and _aware(row.closed_at) >= seven_days_ago]

    age_buckets = {"0_24h": 0, "24_72h": 0, "3_7d": 0, "7d_plus": 0}
    status_ages: dict[str, list[float]] = defaultdict(list)
    for row in active:
        age = _age_hours(row.updated_at, now)
        status_ages[row.status].append(age)
        if age < 24:
            age_buckets["0_24h"] += 1
        elif age < 72:
            age_buckets["24_72h"] += 1
        elif age < 168:
            age_buckets["3_7d"] += 1
        else:
            age_buckets["7d_plus"] += 1

    bottlenecks = []
    for status, ages in status_ages.items():
        bottlenecks.append({
            "status": status,
            "count": len(ages),
            "avg_age_hours": _round(sum(ages) / len(ages)),
            "max_age_hours": _round(max(ages)),
        })
    bottlenecks.sort(key=lambda x: (-x["count"], -x["avg_age_hours"], x["status"]))

    alerts: list[dict[str, Any]] = []
    for row in sorted(overdue, key=lambda c: (_aware(c.due_date) or now, c.title))[:20]:
        alerts.append(_case_alert(row, "OVERDUE", "HIGH", now))
    for row in sorted(waiting_verification, key=lambda c: (_aware(c.updated_at) or now, c.title))[:20]:
        alerts.append(_case_alert(row, "WAITING_FOR_VERIFICATION", "MEDIUM", now))
    seen = {(a["case_id"], a["code"]) for a in alerts}
    for row in sorted(stale, key=lambda c: (-_age_hours(c.updated_at, now), c.title))[:20]:
        key = (str(row.id), "STALE")
        if key not in seen:
            alerts.append(_case_alert(row, "STALE", "MEDIUM", now))
            seen.add(key)

    return {
        "generated_at": timestamp(now),
        "window": {"stale_hours": stale_hours, "due_hours": due_hours, "throughput_days": 7},
        "metrics": {
            "active_cases": len(active),
            "closed_cases": len(closed),
            "overdue_cases": len(overdue),
            "due_soon_cases": len(due_soon),
            "stale_cases": len(stale),
            "waiting_for_verification": len(waiting_verification),
            "unverified_evidence": len(unverified_evidence),
            "rejected_evidence": len(rejected_evidence),
            "draft_branches": len(draft_branches),
            "training_pending": len(training_pending),
            "created_last_7d": len(created_7d),
            "closed_last_7d": len(closed_7d),
        },
        "status_counts": dict(sorted(status_counts.items())),
        "priority_counts": dict(sorted(priority_counts.items())),
        "age_buckets": age_buckets,
        "bottlenecks": bottlenecks,
        "alerts": alerts[:40],
        "method": {
            "engine": "deterministic",
            "ai_used": False,
            "source": "authoritative THREAD, evidence, branch and training records",
        },
    }


def _event(
    *,
    id: uuid.UUID | str,
    kind: str,
    type: str,
    entity_id: uuid.UUID | str,
    created_at: datetime,
    actor_id: uuid.UUID | str | None,
    title: str,
    details: dict[str, Any] | None = None,
    case_id: uuid.UUID | str | None = None,
) -> dict[str, Any]:
    return {
        "id": str(id),
        "kind": kind,
        "type": type,
        "entity_id": str(entity_id),
        "case_id": str(case_id) if case_id else None,
        "actor_id": str(actor_id) if actor_id else None,
        "title": title,
        "details": details or {},
        "created_at": timestamp(created_at),
    }


@router.get("/event-stream")
def event_stream(
    identity: Current,
    db: Db,
    hours: int = Query(168, ge=1, le=2160),
    limit: int = Query(100, ge=1, le=300),
):
    """Return a unified, organization-scoped event stream for process review."""
    staff(identity)
    org = identity.organization.id
    cutoff = _now() - timedelta(hours=hours)
    cases = db.scalars(select(ThreadCase).where(ThreadCase.organization_id == org)).all()
    case_map = {row.id: row for row in cases}
    case_ids = list(case_map)
    items: list[dict[str, Any]] = []

    if case_ids:
        case_events = db.scalars(
            select(CaseEvent)
            .where(CaseEvent.case_id.in_(case_ids), CaseEvent.created_at >= cutoff)
        ).all()
        for row in case_events:
            case = case_map[row.case_id]
            items.append(_event(
                id=row.id,
                kind="CASE",
                type=row.type,
                entity_id=row.case_id,
                case_id=row.case_id,
                actor_id=row.actor_id,
                created_at=row.created_at,
                title=case.title,
                details=row.details,
            ))

    branches = db.scalars(select(ThreadBranch).where(ThreadBranch.organization_id == org)).all()
    branch_map = {row.id: row for row in branches}
    if branch_map:
        branch_events = db.scalars(
            select(ThreadBranchEvent).where(
                ThreadBranchEvent.branch_id.in_(list(branch_map)),
                ThreadBranchEvent.created_at >= cutoff,
            )
        ).all()
        for row in branch_events:
            branch = branch_map[row.branch_id]
            case = case_map.get(branch.case_id)
            items.append(_event(
                id=row.id,
                kind="BRANCH",
                type=row.type,
                entity_id=row.branch_id,
                case_id=branch.case_id,
                actor_id=row.actor_id,
                created_at=row.created_at,
                title=f"{branch.name} · {case.title if case else 'Case'}",
                details=row.details,
            ))

    relations = db.scalars(select(ThreadRelation).where(ThreadRelation.organization_id == org)).all()
    relation_map = {row.id: row for row in relations}
    if relation_map:
        relation_events = db.scalars(
            select(ThreadRelationEvent).where(
                ThreadRelationEvent.relation_id.in_(list(relation_map)),
                ThreadRelationEvent.created_at >= cutoff,
            )
        ).all()
        for row in relation_events:
            relation = relation_map[row.relation_id]
            linked_case_id = None
            if relation.from_type == "CASE":
                linked_case_id = relation.from_id
            elif relation.to_type == "CASE":
                linked_case_id = relation.to_id
            items.append(_event(
                id=row.id,
                kind="RELATION",
                type=row.type,
                entity_id=row.relation_id,
                case_id=linked_case_id,
                actor_id=row.actor_id,
                created_at=row.created_at,
                title=relation.relationship_type.replace("_", " "),
                details={
                    **(row.details or {}),
                    "from_type": relation.from_type,
                    "from_id": str(relation.from_id),
                    "to_type": relation.to_type,
                    "to_id": str(relation.to_id),
                },
            ))

    assignments = db.scalars(
        select(StrategyAssignment).where(StrategyAssignment.organization_id == org)
    ).all()
    for row in assignments:
        scenario = row.scenario if isinstance(row.scenario, dict) else {}
        title = str(scenario.get("title") or "Simulation Lab assignment")
        created = _aware(row.created_at)
        if created and created >= cutoff:
            items.append(_event(
                id=f"{row.id}:created",
                kind="TRAINING",
                type="TRAINING_ASSIGNED",
                entity_id=row.id,
                actor_id=row.instructor_id,
                created_at=created,
                title=title,
                details={"status": row.status, "learner_id": str(row.learner_id)},
            ))
        submitted = _aware(row.submitted_at)
        if submitted and submitted >= cutoff:
            items.append(_event(
                id=f"{row.id}:submitted",
                kind="TRAINING",
                type="TRAINING_SUBMITTED",
                entity_id=row.id,
                actor_id=row.learner_id,
                created_at=submitted,
                title=title,
                details={"status": row.status},
            ))
        feedback_at = _aware(row.feedback_at)
        if feedback_at and feedback_at >= cutoff:
            items.append(_event(
                id=f"{row.id}:feedback",
                kind="TRAINING",
                type="TRAINING_REVIEWED",
                entity_id=row.id,
                actor_id=row.instructor_id,
                created_at=feedback_at,
                title=title,
                details={"status": row.status},
            ))

    items.sort(key=lambda item: (item["created_at"], item["id"]), reverse=True)
    return {
        "generated_at": timestamp(_now()),
        "hours": hours,
        "items": items[:limit],
        "next": None if len(items) <= limit else limit,
    }
