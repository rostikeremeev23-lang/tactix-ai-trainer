import copy
import uuid
import pytest
from test_auth import system, _auth_headers
from app.models import Base, StrategyRecord, StrategyAssignment, InstructorTrainee, Organization, OrganizationMembership, User
from app.strategy_domain import Document, replay
from pydantic import ValidationError

@pytest.fixture
def platform(system):
    client, factory, ids = system
    with factory() as db:
        Base.metadata.create_all(db.get_bind(), tables=[StrategyRecord.__table__, StrategyAssignment.__table__, InstructorTrainee.__table__])
    return client, factory, ids

def document():
    s = dict(name="Учебный город", briefing="Вымышленный сценарий", kind=3, duration=40, resources=100,
        objects=[dict(id="team", name="Команда", kind=0, position=[.5,.5], readiness=100),
                 dict(id="goal", name="Цель", kind=3, position=[.5,.5], readiness=100)], injects=[])
    return dict(version=1, scenario=s, run=dict(version=1, scenario=copy.deepcopy(s), commands=[dict(action="tick")]*40))

def test_contract_replays_and_rejects_fabricated_results():
    doc = Document.model_validate(document())
    assert replay(doc.run)["score"] == 100
    fake = document(); fake["run"]["score"] = 999
    with pytest.raises(ValidationError): Document.model_validate(fake)
    fake = document(); fake["run"]["commands"].append(dict(action="tick"))
    with pytest.raises(ValidationError): Document.model_validate(fake)
    fake = document(); fake["scenario"]["objects"][0]["position"] = [float("nan"), .5]
    with pytest.raises(ValidationError): Document.model_validate(fake)

def test_records_auth_owner_idempotency_conflict_and_tombstone(platform):
    client, _, _ = platform
    a = _auth_headers(client, "trainee@example.test")
    b = _auth_headers(client, "instructor@example.test")
    body = dict(base_revision=0, document=document())
    assert client.put("/v1/strategy/records/current", json=body).status_code == 401
    first = client.put("/v1/strategy/records/current", json=body, headers=a)
    assert first.status_code == 200, first.text
    assert first.json()["revision"] == 1
    assert client.put("/v1/strategy/records/current", json=body, headers=a).json()["revision"] == 1
    assert client.get("/v1/strategy/records", headers=b).json()["items"] == []
    body["document"]["run"] = None
    assert client.put("/v1/strategy/records/current", json=body, headers=a).status_code == 409
    body["base_revision"] = 1
    assert client.put("/v1/strategy/records/current", json=body, headers=a).json()["revision"] == 2
    deleted = client.put("/v1/strategy/records/current", json=dict(base_revision=2, deleted=True), headers=a)
    assert deleted.json()["document"] is None
    assert client.put("/v1/strategy/records/current", json=body, headers=a).status_code == 409

def test_instructor_assignment_submission_feedback_and_isolation(platform):
    client, factory, ids = platform
    teacher = _auth_headers(client, "instructor@example.test")
    learner = _auth_headers(client, "trainee@example.test")
    path = "/v1/strategy/assignments"
    aid = str(uuid.uuid4())
    doc = document()
    request = dict(id=aid, learner_id=str(ids["trainee"]), scenario=doc["scenario"])
    assert client.post(path, json=request, headers=learner).status_code == 403
    assert client.post(path, json=request, headers=teacher).status_code == 403
    assert client.put('/v1/strategy/participants/'+str(ids["trainee"]), headers=teacher).status_code == 200
    assignment = client.post(path, json=request, headers=teacher)
    assert assignment.status_code == 200, assignment.text
    assert client.post(path, json=request, headers=teacher).json()["id"] == aid
    assert client.get(path, headers=learner).json()["items"][0]["status"] == "assigned"
    doc["assignmentId"] = aid
    bad = copy.deepcopy(doc)
    bad["scenario"]["resources"] = bad["run"]["scenario"]["resources"] = 99
    assert client.post(path+'/'+aid+'/submit', headers=learner, json=dict(base_revision=1, document=bad)).status_code == 422
    submission = dict(base_revision=1, document=doc)
    assert client.post(path+'/'+aid+'/submit', headers=teacher, json=submission).status_code == 403
    result = client.post(path+'/'+aid+'/submit', headers=learner, json=submission)
    assert result.status_code == 200, result.text
    assert result.json()["metrics"]["score"] == 100
    assert result.json()["status"] == "submitted"
    assert client.post(path+'/'+aid+'/submit', headers=learner, json=submission).json()["revision"] == 2
    feedback = dict(base_revision=2, feedback="Объясните распределение ресурсов")
    assert client.patch(path+'/'+aid+'/feedback', headers=learner, json=feedback).status_code == 403
    assert client.patch(path+'/'+aid+'/feedback', headers=teacher, json=feedback).status_code == 200
    assert client.patch(path+'/'+aid+'/feedback', headers=teacher, json=feedback).status_code == 409
    # Existing JWT is rechecked against current membership, not trusted claims.
    with factory() as db:
        member = db.query(OrganizationMembership).filter_by(user_id=ids["instructor"]).one()
        other = Organization(name="Other"); db.add(other); db.flush(); member.organization_id=other.id; db.commit()
    assert client.get(path, headers=teacher).status_code == 401
    teacher = _auth_headers(client, "instructor@example.test")
    assert client.get(path, headers=teacher).json()["items"] == []
    assert client.patch(path+'/'+aid+'/feedback', headers=teacher, json=dict(base_revision=3, feedback="x")).status_code == 404
    assert client.put('/v1/strategy/participants/'+str(ids["trainee"]), headers=teacher).status_code == 404


def test_record_pagination_includes_deletions_and_keeps_owner_isolation(platform):
    client, factory, ids = platform
    with factory() as db:
        db.add_all([
            StrategyRecord(owner_id=ids["trainee"], client_id=f"record_{i:03}",
                           organization_id=ids["organization"], revision=1,
                           deleted=True, document=None)
            for i in range(101)
        ])
        db.commit()
    headers = _auth_headers(client, "trainee@example.test")
    first = client.get("/v1/strategy/records", headers=headers).json()
    second = client.get("/v1/strategy/records",
                        params={"after": first["next"]}, headers=headers).json()
    assert len(first["items"]) == 100
    assert len(second["items"]) == 1
    assert second["next"] is None
    assert all(row["deleted"] for row in first["items"] + second["items"])
    teacher = _auth_headers(client, "instructor@example.test")
    assert client.get("/v1/strategy/records", headers=teacher).json()["items"] == []


def test_strategy_migration_preserves_existing_users(system):
    import importlib.util
    from pathlib import Path
    from alembic.migration import MigrationContext
    from alembic.operations import Operations
    from sqlalchemy import inspect, select

    _, factory, ids = system
    path = Path(__file__).resolve().parents[1] / "migrations/versions/0003_strategy_platform.py"
    spec = importlib.util.spec_from_file_location("strategy_migration", path)
    migration = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(migration)
    assert migration.down_revision == "0002_invite_codes"
    with factory() as db:
        with db.get_bind().begin() as connection:
            with Operations.context(MigrationContext.configure(connection)):
                migration.upgrade()
                # Existing assignment content must survive the additive revision.
                import json
                from sqlalchemy import text
                saved = document()
                connection.execute(text("INSERT INTO strategy_assignments (id, organization_id, instructor_id, learner_id, revision, scenario, status, feedback) VALUES (:id, :org, :teacher, :learner, 1, :scenario, 'assigned', 'preserved')"),
                    dict(id=uuid.uuid4().hex, org=ids["organization"].hex,
                         teacher=ids["instructor"].hex, learner=ids["trainee"].hex,
                         scenario=json.dumps(saved["scenario"])))
                next_spec = importlib.util.spec_from_file_location("instructor_migration", path.with_name("0004_instructor_center.py"))
                next_migration = importlib.util.module_from_spec(next_spec)
                next_spec.loader.exec_module(next_migration)
                assert next_migration.down_revision == migration.revision
                next_migration.upgrade()
                old = connection.execute(text("SELECT feedback, due_at, history FROM strategy_assignments")).one()
                assert old == ("preserved", None, None)
            schema = inspect(connection)
            assert {"strategy_records", "strategy_assignments"}.issubset(schema.get_table_names())
            assert {c["name"] for c in schema.get_columns("strategy_records")} == {
                c.name for c in StrategyRecord.__table__.columns
            }
            assert {c["name"] for c in schema.get_columns("strategy_assignments")} == {
                c.name for c in StrategyAssignment.__table__.columns
            }
        assert set(db.scalars(select(User.id))) == {ids["admin"], ids["instructor"], ids["trainee"]}


def test_deadline_submission_review_restart_and_idempotent_feedback(platform):
    client, factory, ids = platform
    teacher = _auth_headers(client, "instructor@example.test")
    learner = _auth_headers(client, "trainee@example.test")
    client.put("/v1/strategy/participants/" + str(ids["trainee"]), headers=teacher)
    aid = str(uuid.uuid4())
    doc = document()
    body = dict(id=aid, learner_id=str(ids["trainee"]), scenario=doc["scenario"],
                due_at="2026-01-01T18:00:00+03:00")
    created = client.post("/v1/strategy/assignments", json=body, headers=teacher)
    assert created.status_code == 200, created.text
    assert created.json()["due_at"] == "2026-01-01T15:00:00+00:00"
    assert client.post("/v1/strategy/assignments", json=body, headers=teacher).json()["revision"] == 1
    path = "/v1/strategy/assignments/" + aid
    change = dict(base_revision=1, due_at="2026-01-02T15:00:00Z", request_id=str(uuid.uuid4()))
    assert client.patch(path + "/deadline", json=change, headers=learner).status_code == 403
    assert client.patch(path + "/deadline", json=change, headers=teacher).json()["revision"] == 2
    assert client.patch(path + "/deadline", json=change, headers=teacher).json()["revision"] == 2
    stale = dict(change, request_id=str(uuid.uuid4()))
    assert client.patch(path + "/deadline", json=stale, headers=teacher).status_code == 409
    doc["assignmentId"] = aid
    # Late submission is accepted: deadlines are educational reminders.
    submitted = client.post(path + "/submit", headers=learner, json=dict(base_revision=2, document=doc))
    assert submitted.status_code == 200, submitted.text
    assert submitted.json()["submitted_at"] is not None
    review = dict(base_revision=3, feedback="Explain the resource choices", request_id=str(uuid.uuid4()))
    assert client.patch(path + "/feedback", headers=teacher, json=review).json()["revision"] == 4
    assert client.patch(path + "/feedback", headers=teacher, json=review).json()["revision"] == 4
    wrong_retry = dict(review, feedback="Different content")
    assert client.patch(path + "/feedback", headers=teacher, json=wrong_retry).status_code == 409
    # Fresh login/read simulates a new authenticated application session.
    learner = _auth_headers(client, "trainee@example.test")
    restored = client.get("/v1/strategy/assignments", headers=learner).json()["items"][0]
    assert restored["feedback"] == review["feedback"]
    assert restored["status"] == "submitted"
    assert restored["metrics"]["score"] == 100
    assert restored["feedback_at"] is not None
    assert [e["kind"] for e in restored["history"]] == ["assigned", "deadline", "submitted", "feedback"]
    with factory() as db:
        row = db.get(StrategyAssignment, uuid.UUID(aid))
        assert row.revision == 4 and row.feedback == review["feedback"]


def test_deadline_validation_and_other_instructor_access(platform):
    client, factory, ids = platform
    teacher = _auth_headers(client, "instructor@example.test")
    client.put("/v1/strategy/participants/" + str(ids["trainee"]), headers=teacher)
    body = dict(id=str(uuid.uuid4()), learner_id=str(ids["trainee"]), scenario=document()["scenario"])
    invalid = client.post("/v1/strategy/assignments", headers=teacher,
                          json=dict(body, due_at="2026-01-02T15:00:00"))
    assert invalid.status_code == 422  # timezone is mandatory
    assert client.post("/v1/strategy/assignments", headers=teacher, json=body).status_code == 200
    # A learner becoming an instructor does not acquire rights to edit their former teacher's assignment.
    with factory() as db:
        member = db.query(OrganizationMembership).filter_by(user_id=ids["trainee"]).one()
        member.role = "instructor"
        db.commit()
    other = _auth_headers(client, "trainee@example.test")
    path = "/v1/strategy/assignments/" + body["id"]
    assert client.get("/v1/strategy/assignments", headers=other).json()["items"] == []
    assert client.patch(path + "/deadline", headers=other,
                        json=dict(base_revision=1, due_at=None)).status_code == 403
    assert client.patch(path + "/feedback", headers=other,
                        json=dict(base_revision=1, feedback="x")).status_code == 403
    admin = _auth_headers(client, "admin@example.test")
    assert client.patch(path + "/deadline", headers=admin,
                        json=dict(base_revision=1, due_at=None)).status_code == 200


def test_postgresql_migration_sql_compiles_without_live_database(monkeypatch):
    import io
    from pathlib import Path
    from alembic import command
    from alembic.config import Config
    monkeypatch.setenv("DATABASE_URL", "postgresql+psycopg://migration_check@localhost/example")
    output = io.StringIO()
    config = Config(str(Path(__file__).resolve().parents[1] / "alembic.ini"), output_buffer=output)
    command.upgrade(config, "head", sql=True)
    sql = output.getvalue()
    assert "ALTER TABLE strategy_assignments ADD COLUMN due_at" in sql
    assert "ALTER TABLE strategy_assignments ADD COLUMN history" in sql
    assert "DROP TABLE" not in sql
