import uuid
import pytest
from sqlalchemy import select
from test_auth import system, _auth_headers
from app.models import Base, ThreadCase, CaseEvent, ThreadEvidence, Organization, OrganizationMembership


@pytest.fixture
def thread(system):
    client, factory, ids = system
    with factory() as db:
        Base.metadata.create_all(db.get_bind(), tables=[ThreadCase.__table__, CaseEvent.__table__, ThreadEvidence.__table__])
    return client, factory, ids


def request(**kw):
    return dict(request_id=str(uuid.uuid4()), **kw)


def create(client, headers, **kw):
    data = request(id=str(uuid.uuid4()), title="Fictional training gap", **kw)
    response = client.post('/v1/thread/cases', headers=headers, json=data)
    assert response.status_code == 200, response.text
    return response.json(), data


def test_case_authorization_validation_and_isolation(thread):
    client, factory, ids = thread
    root = '/v1/thread/cases'
    assert client.get(root).status_code == 401
    trainee = _auth_headers(client, 'trainee@example.test')
    teacher = _auth_headers(client, 'instructor@example.test')
    case, body = create(client, teacher)
    assert client.get(root, headers=trainee).json()['items'] == []
    for suffix in ['', '/events']:
        assert client.get(root+'/'+case['id']+suffix, headers=trainee).status_code == 404
    assert client.post(root, headers=trainee, json=request(id=str(uuid.uuid4()), title=' ', owner_id=str(ids['admin']))).status_code == 422
    assert client.post(root, headers=trainee, json=request(id=str(uuid.uuid4()), title='Valid', owner_id=str(ids['admin']))).status_code == 403
    assert client.post(root, headers=teacher, json=request(id=str(uuid.uuid4()), title='Valid', owner_id=str(uuid.uuid4()))).status_code == 404
    with factory() as db:
        other = Organization(name='Other'); db.add(other); db.flush()
        member = db.scalar(select(OrganizationMembership).where(OrganizationMembership.user_id == ids['instructor']))
        member.organization_id = other.id; db.commit()
    teacher = _auth_headers(client, 'instructor@example.test')
    assert client.get(root+'/'+case['id'], headers=teacher).status_code == 404
    assert client.get(root+'/'+case['id']+'/events', headers=teacher).status_code == 404


def test_idempotent_creation_history_and_stale_revision(thread):
    client, factory, _ = thread
    h = _auth_headers(client, 'trainee@example.test')
    case, body = create(client, h)
    path = '/v1/thread/cases/'+case['id']
    assert client.post('/v1/thread/cases', headers=h, json=body).json()['revision'] == 1
    assert client.post('/v1/thread/cases', headers=h, json={**body, 'title':'different'}).status_code == 409
    change = request(base_revision=1, status='IN_PROGRESS', note='Accepted')
    assert client.patch(path, headers=h, json=change).json()['revision'] == 2
    assert client.patch(path, headers=h, json=change).json()['accepted_revision'] == 2
    assert client.patch(path, headers=h, json=request(base_revision=1, status='OPEN', note='Stale')).status_code == 409
    timeline = client.get(path+'/events?limit=1', headers=h).json()
    assert timeline['next'] == 1
    assert timeline['items'][0]['type'] == 'CREATED'
    assert client.get(path+'/events?after=1', headers=h).json()['items'][0]['details']['before'] == 'OPEN'
    with factory() as db:
        assert db.query(CaseEvent).count() == 2


def test_evidence_verification_closure_and_reopen_loop(thread):
    client, factory, _ = thread
    learner = _auth_headers(client, 'trainee@example.test')
    staff = _auth_headers(client, 'instructor@example.test')
    case, _ = create(client, learner)
    path = '/v1/thread/cases/'+case['id']
    close = request(base_revision=1, status='CLOSED', note='Reviewed')
    assert client.patch(path, headers=learner, json=close).status_code == 403
    assert client.patch(path, headers=staff, json=close).status_code == 409
    # A rejected transaction must not consume a revision.
    assert client.get(path, headers=staff).json()['revision'] == 1
    evidence = request(base_revision=1, id=str(uuid.uuid4()), title='Result', description='Observed completion', source='Manual observation')
    result = client.post(path+'/evidence', headers=learner, json=evidence)
    assert result.status_code == 200, result.text
    assert result.json()['verification_state'] == 'UNVERIFIED'
    assert client.post(path+'/evidence', headers=learner, json=evidence).json()['revision'] == 2
    verify_path = path+'/evidence/'+evidence['id']+'/verify'
    verify = request(base_revision=2, state='VERIFIED', note='Checked supporting record')
    assert client.post(verify_path, headers=learner, json=verify).status_code == 403
    assert client.patch(path, headers=staff, json={**close, 'base_revision':2}).status_code == 409
    accepted = client.post(verify_path, headers=staff, json=verify)
    assert accepted.status_code == 200, accepted.text
    assert accepted.json()['verification_state'] == 'VERIFIED'
    assert client.post(verify_path, headers=staff, json=verify).json()['revision'] == 3
    closed = client.patch(path, headers=staff, json={**close, 'base_revision':3})
    assert closed.json()['status'] == 'CLOSED'
    assert closed.json()['closed_at'].endswith('+00:00')
    assert client.post(verify_path, headers=staff, json=request(base_revision=4, state='REJECTED', note='Reconsider')).status_code == 409
    assert client.post(path+'/evidence', headers=learner, json={**evidence, 'id':str(uuid.uuid4()), 'request_id':str(uuid.uuid4()), 'base_revision':4}).status_code == 409
    reopened = client.patch(path, headers=staff, json=request(base_revision=4, status='IN_REVIEW', note='New information'))
    assert reopened.json()['closed_at'] is None
    rejected = client.post(verify_path, headers=staff, json=request(base_revision=5, state='REJECTED', note='Record incomplete'))
    assert rejected.json()['verification_state'] == 'UNVERIFIED'
    events = client.get(path+'/events', headers=staff).json()['items']
    assert [e['type'] for e in events] == ['CREATED','EVIDENCE_ADDED','VERIFICATION_ACCEPTED','CLOSED','REOPENED','VERIFICATION_REJECTED']
    assert [e['revision'] for e in events] == list(range(1,7))
    with factory() as db:
        assert db.query(ThreadEvidence).count() == 1


def test_all_evidence_must_be_verified_and_cross_case_evidence_rejected(thread):
    client, _, _ = thread
    h = _auth_headers(client, 'admin@example.test')
    a,_ = create(client,h); b,_ = create(client,h)
    path='/v1/thread/cases/'+a['id']
    for revision in (1,2):
        response=client.post(path+'/evidence', headers=h, json=request(base_revision=revision,id=str(uuid.uuid4()),title='Note',description='Observed'))
        assert response.status_code == 200
    eid=response.json()['evidence'][0]['id']
    assert client.post('/v1/thread/cases/'+b['id']+'/evidence/'+eid+'/verify',headers=h,json=request(base_revision=1,state='VERIFIED',note='Review')).status_code==404
    assert client.post(path+'/evidence/'+eid+'/verify',headers=h,json=request(base_revision=3,state='VERIFIED',note='Review')).status_code==200
    assert client.patch(path,headers=h,json=request(base_revision=4,status='CLOSED',note='Close')).status_code==409
    assert client.get(path,headers=h).json()['revision']==4


def test_case_pagination(thread):
    client, _, _ = thread
    h = _auth_headers(client,'admin@example.test')
    ids={create(client,h)[0]['id'] for _ in range(3)}
    first=client.get('/v1/thread/cases?limit=2',headers=h).json()
    second=client.get('/v1/thread/cases?after='+first['next']+'&limit=2',headers=h).json()
    assert {i['id'] for i in first['items']+second['items']} == ids
    assert second['next'] is None


def test_thread_migration_preserves_users_and_model_columns(system):
    import importlib.util
    from pathlib import Path
    from alembic.migration import MigrationContext
    from alembic.operations import Operations
    from sqlalchemy import inspect
    from app.models import User
    _, factory, ids = system
    path = Path(__file__).resolve().parents[1] / 'migrations/versions/0005_thread_cases.py'
    spec = importlib.util.spec_from_file_location('thread_migration', path)
    migration = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(migration)
    assert migration.down_revision == '0004_instructor_center'
    with factory() as db:
        with db.get_bind().begin() as connection:
            with Operations.context(MigrationContext.configure(connection)):
                migration.upgrade()
            schema = inspect(connection)
            for model in (ThreadCase, CaseEvent, ThreadEvidence):
                assert {c['name'] for c in schema.get_columns(model.__tablename__)} == {c.name for c in model.__table__.columns}
        assert set(db.scalars(select(User.id))) == {ids['admin'],ids['instructor'],ids['trainee']}
