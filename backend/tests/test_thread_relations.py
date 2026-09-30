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
