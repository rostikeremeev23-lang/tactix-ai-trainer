import uuid
from datetime import datetime, timedelta, timezone

import pytest

from test_auth import system, _auth_headers
from app.models import (
    Base,
    ThreadCase,
    CaseEvent,
    ThreadEvidence,
    ThreadRelation,
    ThreadRelationEvent,
    ThreadBranch,
    ThreadBranchEvent,
)


@pytest.fixture
def branch_thread(system):
    client, factory, ids = system
    with factory() as db:
        Base.metadata.create_all(
            db.get_bind(),
            tables=[
                ThreadCase.__table__,
                CaseEvent.__table__,
                ThreadEvidence.__table__,
                ThreadRelation.__table__,
                ThreadRelationEvent.__table__,
                ThreadBranch.__table__,
                ThreadBranchEvent.__table__,
            ],
        )
    return client, factory, ids


def uid():
    return str(uuid.uuid4())


def create_case(client, headers, title="Branch Case"):
    response = client.post(
        "/v1/thread/cases",
        headers=headers,
        json={
            "id": uid(),
            "request_id": uid(),
            "title": title,
            "description": "Base planning description",
            "priority": "NORMAL",
        },
    )
    assert response.status_code == 200, response.text
    return response.json()


def create_branch(client, headers, case_id, name="Variant A"):
    response = client.post(
        f"/v1/thread/cases/{case_id}/branches",
        headers=headers,
        json={"id": uid(), "request_id": uid(), "name": name, "description": "Alternative plan"},
    )
    assert response.status_code == 200, response.text
    return response.json()


def test_branch_compare_and_merge_preserves_unrelated_live_change(branch_thread):
    client, _, ids = branch_thread
    staff = _auth_headers(client, "admin@example.test")
    case = create_case(client, staff)
    branch = create_branch(client, staff, case["id"])

    due = (datetime.now(timezone.utc) + timedelta(days=5)).isoformat()
    plan_item = {
        "id": uid(),
        "title": "Review training record",
        "kind": "REVIEW",
        "assignee_id": str(ids["admin"]),
        "due_at": (datetime.now(timezone.utc) + timedelta(days=2)).isoformat(),
        "note": "Administrative review only",
    }
    updated = client.put(
        f"/v1/thread/branches/{branch['id']}",
        headers=staff,
        json={
            "request_id": uid(),
            "base_revision": 1,
            "name": "Variant A",
            "description": "Alternative plan",
            "draft": {
                "description": "Proposed planning description",
                "priority": "HIGH",
                "status": "OPEN",
                "owner_id": str(ids["admin"]),
                "due_date": due,
                "plan_items": [plan_item],
            },
        },
    )
    assert updated.status_code == 200, updated.text
    assert updated.json()["revision"] == 2

    # Live Case changes a different field after the Branch fork.
    live = client.patch(
        f"/v1/thread/cases/{case['id']}",
        headers=staff,
        json={
            "request_id": uid(),
            "base_revision": 1,
            "status": "IN_REVIEW",
            "note": "Independent live status review",
        },
    )
    assert live.status_code == 200, live.text
    assert live.json()["revision"] == 2

    comparison = client.get(f"/v1/thread/branches/{branch['id']}/compare", headers=staff)
    assert comparison.status_code == 200, comparison.text
    body = comparison.json()
    assert body["stale_base"] is True
    assert body["can_merge"] is True
    assert body["blocking_conflicts"] == 0
    assert {x["field"] for x in body["changes"]} >= {"description", "priority", "due_date"}
    assert body["plan_items"][0]["title"] == "Review training record"

    merged = client.post(
        f"/v1/thread/branches/{branch['id']}/merge",
        headers=staff,
        json={"request_id": uid(), "base_revision": 2, "note": "Adopt Variant A"},
    )
    assert merged.status_code == 200, merged.text
    merged_body = merged.json()
    assert merged_body["branch"]["status"] == "MERGED"
    assert merged_body["case"]["priority"] == "HIGH"
    assert merged_body["case"]["status"] == "IN_REVIEW"  # unrelated live edit preserved
    assert merged_body["case"]["revision"] == 3

    events = client.get(f"/v1/thread/cases/{case['id']}/events", headers=staff).json()["items"]
    assert events[-1]["type"] == "BRANCH_MERGED"
    assert events[-1]["details"]["plan_items"][0]["title"] == "Review training record"


def test_branch_blocks_overlapping_three_way_conflict(branch_thread):
    client, _, ids = branch_thread
    staff = _auth_headers(client, "admin@example.test")
    case = create_case(client, staff, "Conflict Case")
    branch = create_branch(client, staff, case["id"], "Conflict Variant")

    updated = client.put(
        f"/v1/thread/branches/{branch['id']}",
        headers=staff,
        json={
            "request_id": uid(),
            "base_revision": 1,
            "name": "Conflict Variant",
            "description": "",
            "draft": {
                "description": "Base planning description",
                "priority": "NORMAL",
                "status": "IN_PROGRESS",
                "owner_id": str(ids["admin"]),
                "due_date": None,
                "plan_items": [],
            },
        },
    )
    assert updated.status_code == 200, updated.text

    live = client.patch(
        f"/v1/thread/cases/{case['id']}",
        headers=staff,
        json={
            "request_id": uid(),
            "base_revision": 1,
            "status": "ACTION_REQUIRED",
            "note": "Live status diverged",
        },
    )
    assert live.status_code == 200, live.text

    comparison = client.get(f"/v1/thread/branches/{branch['id']}/compare", headers=staff).json()
    assert comparison["can_merge"] is False
    conflict = next(c for c in comparison["conflicts"] if c["code"] == "FIELD_DIVERGED")
    assert conflict["field"] == "status"
    assert conflict["severity"] == "BLOCKING"

    merge = client.post(
        f"/v1/thread/branches/{branch['id']}/merge",
        headers=staff,
        json={"request_id": uid(), "base_revision": 2, "note": "Should not merge"},
    )
    assert merge.status_code == 409
    detail = merge.json()["detail"]
    assert detail["compare"]["blocking_conflicts"] == 1


def test_branch_is_staff_only_and_owner_options_are_scoped(branch_thread):
    client, _, _ = branch_thread
    staff = _auth_headers(client, "instructor@example.test")
    trainee = _auth_headers(client, "trainee@example.test")
    case = create_case(client, staff, "Staff planning")

    denied = client.post(
        f"/v1/thread/cases/{case['id']}/branches",
        headers=trainee,
        json={"id": uid(), "request_id": uid(), "name": "Nope", "description": ""},
    )
    assert denied.status_code == 403

    options = client.get(f"/v1/thread/cases/{case['id']}/branch-options", headers=staff)
    assert options.status_code == 200, options.text
    assert options.json()["owners"]
    assert all("id" in row and "label" in row for row in options.json()["owners"])
