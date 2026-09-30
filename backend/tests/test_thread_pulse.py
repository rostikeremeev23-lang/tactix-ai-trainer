import uuid
from datetime import datetime, timedelta, timezone

import pytest

from test_auth import system, _auth_headers
from app.models import (
    Base,
    ThreadCase,
    CaseEvent,
    ThreadEvidence,
    ThreadBranch,
    ThreadBranchEvent,
    ThreadRelation,
    ThreadRelationEvent,
    StrategyAssignment,
)


@pytest.fixture
def pulse_thread(system):
    client, factory, ids = system
    with factory() as db:
        Base.metadata.create_all(
            db.get_bind(),
            tables=[
                ThreadCase.__table__,
                CaseEvent.__table__,
                ThreadEvidence.__table__,
                ThreadBranch.__table__,
                ThreadBranchEvent.__table__,
                ThreadRelation.__table__,
                ThreadRelationEvent.__table__,
                StrategyAssignment.__table__,
            ],
        )
    return client, factory, ids


def uid():
    return str(uuid.uuid4())


def create_case(client, headers, title="Pulse Case"):
    response = client.post(
        "/v1/thread/cases",
        headers=headers,
        json={
            "id": uid(),
            "request_id": uid(),
            "title": title,
            "description": "Administrative training follow-up",
            "priority": "HIGH",
        },
    )
    assert response.status_code == 200, response.text
    return response.json()


def test_pulse_is_staff_only_and_reports_deterministic_backlog(pulse_thread):
    client, factory, _ = pulse_thread
    staff = _auth_headers(client, "admin@example.test")
    trainee = _auth_headers(client, "trainee@example.test")
    case = create_case(client, staff)

    evidence_id = uid()
    added = client.post(
        f"/v1/thread/cases/{case['id']}/evidence",
        headers=staff,
        json={
            "id": evidence_id,
            "request_id": uid(),
            "base_revision": 1,
            "title": "Completion note",
            "description": "Awaiting verification",
            "source": "demo-record",
        },
    )
    assert added.status_code == 200, added.text

    with factory() as db:
        row = db.get(ThreadCase, uuid.UUID(case["id"]))
        row.status = "WAITING_FOR_VERIFICATION"
        row.updated_at = datetime.now(timezone.utc) - timedelta(days=5)
        row.due_date = datetime.now(timezone.utc) - timedelta(days=1)
        db.commit()

    denied = client.get("/v1/thread/pulse", headers=trainee)
    assert denied.status_code == 403

    response = client.get("/v1/thread/pulse?stale_hours=72&due_hours=48", headers=staff)
    assert response.status_code == 200, response.text
    body = response.json()
    assert body["method"]["engine"] == "deterministic"
    assert body["method"]["ai_used"] is False
    assert body["metrics"]["active_cases"] == 1
    assert body["metrics"]["overdue_cases"] == 1
    assert body["metrics"]["stale_cases"] == 1
    assert body["metrics"]["waiting_for_verification"] == 1
    assert body["metrics"]["unverified_evidence"] == 1
    assert body["status_counts"]["WAITING_FOR_VERIFICATION"] == 1
    codes = {item["code"] for item in body["alerts"]}
    assert {"OVERDUE", "WAITING_FOR_VERIFICATION", "STALE"}.issubset(codes)


def test_event_stream_unifies_case_branch_and_training_activity(pulse_thread):
    client, factory, ids = pulse_thread
    staff = _auth_headers(client, "instructor@example.test")
    case = create_case(client, staff, "Unified activity")

    branch = client.post(
        f"/v1/thread/cases/{case['id']}/branches",
        headers=staff,
        json={
            "id": uid(),
            "request_id": uid(),
            "name": "Review option",
            "description": "Alternative administrative plan",
        },
    )
    assert branch.status_code == 200, branch.text

    assignment_id = uuid.uuid4()
    now = datetime.now(timezone.utc)
    with factory() as db:
        db.add(
            StrategyAssignment(
                id=assignment_id,
                organization_id=ids["organization"],
                instructor_id=ids["instructor"],
                learner_id=ids["trainee"],
                due_at=now + timedelta(days=2),
                submitted_at=now,
                feedback_at=None,
                history=[],
                revision=2,
                scenario={"title": "Administrative exercise"},
                status="submitted",
                submission={"version": 1},
                metrics={"completed": True},
                feedback="",
                created_at=now - timedelta(hours=1),
                updated_at=now,
            )
        )
        db.commit()

    response = client.get("/v1/thread/event-stream?hours=24&limit=100", headers=staff)
    assert response.status_code == 200, response.text
    body = response.json()
    kinds = {item["kind"] for item in body["items"]}
    assert "CASE" in kinds
    assert "BRANCH" in kinds
    assert "TRAINING" in kinds
    event_types = {item["type"] for item in body["items"]}
    assert "CREATED" in event_types
    assert "TRAINING_ASSIGNED" in event_types
    assert "TRAINING_SUBMITTED" in event_types
    timestamps = [item["created_at"] for item in body["items"]]
    assert timestamps == sorted(timestamps, reverse=True)
