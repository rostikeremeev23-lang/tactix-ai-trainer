import importlib.util
import uuid
from pathlib import Path

import pytest
from alembic.migration import MigrationContext
from alembic.operations import Operations
from sqlalchemy import inspect, select

from test_auth import system, _auth_headers
from app.models import (
    Base,
    ThreadCase,
    CaseEvent,
    ThreadEvidence,
    ThreadRelation,
    ThreadRelationEvent,
    StrategyAssignment,
    Organization,
    OrganizationMembership,
    User,
)


@pytest.fixture
def relations(system):
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
                StrategyAssignment.__table__,
            ],
        )
    return client, factory, ids


def rid():
    return str(uuid.uuid4())


def create_case(client, headers, title="Case"):
    body = {"id": rid(), "request_id": rid(), "title": title}
    response = client.post("/v1/thread/cases", headers=headers, json=body)
    assert response.status_code == 200, response.text
    return response.json()


def create_relation(client, headers, a, b, **extra):
    body = {
        "id": rid(),
        "request_id": rid(),
        "from_type": "CASE",
        "from_id": a,
        "to_type": "CASE",
        "to_id": b,
        "relationship_type": "RELATED_TO",
        **extra,
    }
    response = client.post("/v1/thread/relations", headers=headers, json=body)
    return response, body


def test_relation_creation_listing_history_and_idempotency(relations):
    client, _, _ = relations
    staff = _auth_headers(client, "instructor@example.test")
    a = create_case(client, staff, "A")
    b = create_case(client, staff, "B")

    response, body = create_relation(client, staff, a["id"], b["id"])
    assert response.status_code == 200, response.text
    relation = response.json()
    assert relation["relationship_type"] == "RELATED_TO"

    retry = client.post("/v1/thread/relations", headers=staff, json=body)
    assert retry.status_code == 200
    assert retry.json()["id"] == relation["id"]

    changed = {**body, "relationship_type": "REQUIRES"}
    assert client.post("/v1/thread/relations", headers=staff, json=changed).status_code == 409

    listed = client.get(f"/v1/thread/cases/{a['id']}/relations", headers=staff)
    assert listed.status_code == 200
    assert [r["id"] for r in listed.json()["items"]] == [relation["id"]]

    events = client.get(f"/v1/thread/relations/{relation['id']}/events", headers=staff)
    assert events.status_code == 200
    assert [e["type"] for e in events.json()["items"]] == ["CREATED"]


def test_relation_requires_access_to_both_endpoints_and_no_self_edge(relations):
    client, factory, ids = relations
    staff = _auth_headers(client, "instructor@example.test")
    trainee = _auth_headers(client, "trainee@example.test")
    a = create_case(client, staff, "Staff A")
    b = create_case(client, staff, "Staff B")

    response, _ = create_relation(client, trainee, a["id"], b["id"])
    assert response.status_code == 404

    self_edge, _ = create_relation(client, staff, a["id"], a["id"])
    assert self_edge.status_code == 422

    created, _ = create_relation(client, staff, a["id"], b["id"])
    relation_id = created.json()["id"]
    with factory() as db:
        other = Organization(name="Other")
        db.add(other)
        db.flush()
        membership = db.scalar(
            select(OrganizationMembership).where(
                OrganizationMembership.user_id == ids["instructor"]
            )
        )
        membership.organization_id = other.id
        db.commit()
    moved = _auth_headers(client, "instructor@example.test")
    assert client.get(f"/v1/thread/relations/{relation_id}/events", headers=moved).status_code == 404


def test_evidence_endpoint_can_participate_in_relation(relations):
    client, _, _ = relations
    learner = _auth_headers(client, "trainee@example.test")
    case = create_case(client, learner, "Evidence case")
    evidence_id = rid()
    evidence = client.post(
        f"/v1/thread/cases/{case['id']}/evidence",
        headers=learner,
        json={
            "id": evidence_id,
            "request_id": rid(),
            "base_revision": 1,
            "title": "Result",
            "description": "Supporting result",
            "source": "Local record",
        },
    )
    assert evidence.status_code == 200, evidence.text
    relation, _ = create_relation(
        client,
        learner,
        case["id"],
        evidence_id,
        to_type="EVIDENCE",
        relationship_type="SUPPORTED_BY",
    )
    assert relation.status_code == 200, relation.text
    listed = client.get(f"/v1/thread/cases/{case['id']}/relations", headers=learner).json()["items"]
    assert listed[0]["to_type"] == "EVIDENCE"


def test_training_link_result_import_and_verification_loop(relations):
    client, factory, ids = relations
    staff = _auth_headers(client, "instructor@example.test")
    learner = _auth_headers(client, "trainee@example.test")
    case = create_case(client, staff, "Training-linked Case")
    assignment_id = uuid.uuid4()
    with factory() as db:
        db.add(StrategyAssignment(
            id=assignment_id, organization_id=ids["organization"],
            instructor_id=ids["instructor"], learner_id=ids["trainee"],
            scenario={"title": "Exercise Alpha"}, revision=3, status="submitted",
            submission={"version": 1, "assignmentId": str(assignment_id)},
            metrics={"completed": True, "score": 82, "turns": 6},
            feedback="", history=[],
        ))
        db.commit()

    relation_body = {
        "id": rid(), "request_id": rid(),
        "from_type": "CASE", "from_id": case["id"],
        "to_type": "TRAINING", "to_id": str(assignment_id),
        "relationship_type": "TRAINED_BY",
    }
    linked = client.post("/v1/thread/relations", headers=staff, json=relation_body)
    assert linked.status_code == 200, linked.text
    assert client.post("/v1/thread/relations", headers=learner, json={**relation_body, "id": rid(), "request_id": rid()}).status_code == 403

    training = client.get(f"/v1/thread/cases/{case['id']}/training", headers=staff)
    assert training.status_code == 200, training.text
    item = training.json()["items"][0]
    assert item["id"] == str(assignment_id)
    assert item["title"] == "Exercise Alpha"
    assert item["status"] == "submitted"
    assert item["evidence_attached"] is False

    imported = client.post(
        f"/v1/thread/cases/{case['id']}/training/{assignment_id}/evidence",
        headers=staff,
        json={"id": rid(), "request_id": rid(), "base_revision": 1},
    )
    assert imported.status_code == 200, imported.text
    body = imported.json()
    assert body["revision"] == 2
    assert body["status"] == "WAITING_FOR_VERIFICATION"
    assert body["evidence"][0]["type"] == "TRAINING_RECORD"
    assert body["evidence"][0]["source"] == f"strategy_assignment:{assignment_id}"
    assert body["verification_state"] == "UNVERIFIED"

    refreshed = client.get(f"/v1/thread/cases/{case['id']}/training", headers=staff).json()["items"][0]
    assert refreshed["evidence_attached"] is True
    relations_now = client.get(f"/v1/thread/cases/{case['id']}/relations", headers=staff).json()["items"]
    assert {r["relationship_type"] for r in relations_now} == {"TRAINED_BY", "PRODUCED"}
    events = client.get(f"/v1/thread/cases/{case['id']}/events", headers=staff).json()["items"]
    assert events[-1]["type"] == "TRAINING_COMPLETED"


def test_training_result_must_be_linked_and_complete(relations):
    client, factory, ids = relations
    staff = _auth_headers(client, "instructor@example.test")
    case = create_case(client, staff, "Pending training")
    assignment_id = uuid.uuid4()
    with factory() as db:
        db.add(StrategyAssignment(
            id=assignment_id, organization_id=ids["organization"],
            instructor_id=ids["instructor"], learner_id=ids["trainee"],
            scenario={"title": "Exercise Pending"}, revision=1, status="assigned",
            submission=None, metrics=None, feedback="", history=[],
        ))
        db.commit()
    payload = {"id": rid(), "request_id": rid(), "base_revision": 1}
    unlinked = client.post(
        f"/v1/thread/cases/{case['id']}/training/{assignment_id}/evidence",
        headers=staff, json=payload,
    )
    assert unlinked.status_code == 409
    linked = client.post("/v1/thread/relations", headers=staff, json={
        "id": rid(), "request_id": rid(), "from_type": "CASE", "from_id": case["id"],
        "to_type": "TRAINING", "to_id": str(assignment_id), "relationship_type": "TRAINED_BY",
    })
    assert linked.status_code == 200
    incomplete = client.post(
        f"/v1/thread/cases/{case['id']}/training/{assignment_id}/evidence",
        headers=staff, json=payload,
    )
    assert incomplete.status_code == 409


def test_thread_relation_migration_preserves_existing_schema(system):
    _, factory, _ = system
    path = Path(__file__).resolve().parents[1] / "migrations/versions/0006_thread_relations.py"
    spec = importlib.util.spec_from_file_location("thread_relation_migration", path)
    migration = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(migration)
    assert migration.down_revision == "0005_thread_cases"

    with factory() as db:
        Base.metadata.create_all(
            db.get_bind(),
            tables=[ThreadCase.__table__, CaseEvent.__table__, ThreadEvidence.__table__],
        )
        with db.get_bind().begin() as connection:
            with Operations.context(MigrationContext.configure(connection)):
                migration.upgrade()
            schema = inspect(connection)
            for model in (ThreadRelation, ThreadRelationEvent):
                assert {c["name"] for c in schema.get_columns(model.__tablename__)} == {
                    c.name for c in model.__table__.columns
                }
