"""Authenticated, organization-scoped Strategy sync and instructor workflow."""
import uuid
from datetime import datetime, timezone
from typing import Annotated
from fastapi import APIRouter, Depends, HTTPException, Path, Query
from pydantic import AwareDatetime, Field, field_validator, model_validator
from sqlalchemy import select, update, func
from sqlalchemy.exc import IntegrityError
from app.auth import Current, Db, CurrentIdentity, require_role
from app.models import StrategyRecord, StrategyAssignment, OrganizationMembership, InstructorTrainee, User
from app.strategy_domain import Strict, Scenario, Document, replay, assignment_rules

router = APIRouter(prefix="/v1/strategy", tags=["strategy"])
Staff = Annotated[CurrentIdentity, Depends(require_role("instructor", "admin"))]
RecordId = Annotated[str, Path(pattern=r"^[a-zA-Z0-9_-]{1,80}$")]
class RecordWrite(Strict):
    base_revision: int = Field(ge=0)
    deleted: bool = False
    document: Document | None = None
    @model_validator(mode="after")
    def content(self):
        if self.deleted == (self.document is not None):
            raise ValueError("Ожидается документ или отметка удаления")
        return self

def record_json(row):
    return dict(id=row.client_id, revision=row.revision, deleted=row.deleted,
                document=row.document, updated_at=row.updated_at.isoformat())

@router.get("/records")
def records(identity: Current, db: Db, after: str = Query(default="", max_length=80)):
    rows = db.scalars(select(StrategyRecord).where(StrategyRecord.owner_id==identity.user.id,
        StrategyRecord.organization_id==identity.organization.id, StrategyRecord.client_id > after).order_by(StrategyRecord.client_id).limit(100)).all()
    return {"items": [record_json(r) for r in rows], "next": rows[-1].client_id if len(rows)==100 else None}

@router.put("/records/{record_id}")
def put_record(record_id: RecordId, request: RecordWrite, identity: Current, db: Db):
    row = db.get(StrategyRecord, (identity.user.id, record_id))
    doc = request.document.model_dump() if request.document else None
    if row and row.organization_id != identity.organization.id:
        raise HTTPException(404, "Запись не найдена")
    if row and row.document == doc and row.deleted == request.deleted:
        return record_json(row)  # retry after a lost response is idempotent
    if row is None:
        if request.base_revision != 0: raise HTTPException(409, "Версия записи изменилась")
        count = db.scalar(select(func.count()).select_from(StrategyRecord).where(StrategyRecord.owner_id==identity.user.id))
        if count >= 500: raise HTTPException(409, "Лимит серверных записей: 500")
        row = StrategyRecord(owner_id=identity.user.id, client_id=record_id,
            organization_id=identity.organization.id, revision=1, deleted=request.deleted, document=doc)
        db.add(row)
        try: db.commit()
        except IntegrityError:
            db.rollback()
            raise HTTPException(409, "Версия записи изменилась")
    else:
        result = db.execute(update(StrategyRecord).where(StrategyRecord.owner_id==identity.user.id,
            StrategyRecord.client_id==record_id, StrategyRecord.revision==request.base_revision).values(
            document=doc, deleted=request.deleted, revision=request.base_revision+1,
            updated_at=datetime.now(timezone.utc)))
        if result.rowcount != 1:
            db.rollback()
            raise HTTPException(409, detail={"message":"Конфликт версий", "remote":record_json(row)})
        db.commit()
        db.refresh(row)
    return record_json(row)

@router.get("/participants")
def participants(identity: Staff, db: Db):
    users = db.scalars(select(User).join(OrganizationMembership).where(
        OrganizationMembership.organization_id==identity.organization.id,
        OrganizationMembership.role=="trainee", User.is_active.is_(True)).order_by(User.callsign)).all()
    managed = set(db.scalars(select(InstructorTrainee.trainee_id).where(
        InstructorTrainee.organization_id==identity.organization.id, InstructorTrainee.instructor_id==identity.user.id)))
    return {"items":[dict(id=str(u.id), name=u.first_name, callsign=u.callsign, managed=u.id in managed) for u in users]}

def learner_in_org(db, learner_id, identity):
    member = db.scalar(select(OrganizationMembership).join(User).where(
        OrganizationMembership.organization_id==identity.organization.id,
        OrganizationMembership.user_id==learner_id, OrganizationMembership.role=="trainee", User.is_active.is_(True)))
    if member is None: raise HTTPException(404, "Участник не найден")

@router.put("/participants/{learner_id}")
def add_participant(learner_id: uuid.UUID, identity: Staff, db: Db):
    learner_in_org(db, learner_id, identity)
    exists = db.scalar(select(InstructorTrainee).where(InstructorTrainee.organization_id==identity.organization.id,
        InstructorTrainee.instructor_id==identity.user.id, InstructorTrainee.trainee_id==learner_id))
    if not exists:
        db.add(InstructorTrainee(organization_id=identity.organization.id, instructor_id=identity.user.id, trainee_id=learner_id))
        try: db.commit()
        except IntegrityError: db.rollback()
    return {"ok":True}

@router.delete("/participants/{learner_id}")
def remove_participant(learner_id: uuid.UUID, identity: Staff, db: Db):
    row = db.scalar(select(InstructorTrainee).where(InstructorTrainee.organization_id==identity.organization.id,
        InstructorTrainee.instructor_id==identity.user.id, InstructorTrainee.trainee_id==learner_id))
    if row: db.delete(row); db.commit()
    return {"ok":True}

class Assign(Strict):
    id: str = Field(min_length=36, max_length=36)
    learner_id: str = Field(min_length=36, max_length=36)
    scenario: Scenario
    due_at: AwareDatetime | None = Field(default=None, strict=False)

    @field_validator("due_at")
    @classmethod
    def utc_deadline(cls, value):
        return value.astimezone(timezone.utc) if value else None

def iso(value):
    if value is None:
        return None
    return value.replace(tzinfo=timezone.utc).isoformat() if value.tzinfo is None else value.astimezone(timezone.utc).isoformat()


def assignment_json(row):
    return dict(id=str(row.id), learner_id=str(row.learner_id), instructor_id=str(row.instructor_id),
        revision=row.revision, scenario=row.scenario, status=row.status, submission=row.submission,
        metrics=row.metrics, feedback=row.feedback, updated_at=iso(row.updated_at),
        created_at=iso(row.created_at), due_at=iso(row.due_at), submitted_at=iso(row.submitted_at),
        feedback_at=iso(row.feedback_at), history=row.history or [])

def assignment_visible(assignment_id, identity, db):
    row = db.get(StrategyAssignment, assignment_id)
    if row is None or row.organization_id != identity.organization.id or (
        identity.role != "admin" and identity.user.id not in (row.learner_id, row.instructor_id)):
        raise HTTPException(404, "Назначение не найдено")
    return row

@router.get("/assignments")
def assignments(identity: Current, db: Db):
    query = select(StrategyAssignment).where(StrategyAssignment.organization_id==identity.organization.id)
    if identity.role == "trainee": query = query.where(StrategyAssignment.learner_id==identity.user.id)
    elif identity.role != "admin": query = query.where(StrategyAssignment.instructor_id==identity.user.id)
    return {"items":[assignment_json(r) for r in db.scalars(query.order_by(StrategyAssignment.updated_at.desc()))]}

@router.post("/assignments")
def assign(request: Assign, identity: Staff, db: Db):
    try: aid, learner_id = uuid.UUID(request.id), uuid.UUID(request.learner_id)
    except ValueError: raise HTTPException(422, "Некорректный идентификатор")
    learner_in_org(db, learner_id, identity)
    pair = db.scalar(select(InstructorTrainee).where(InstructorTrainee.organization_id==identity.organization.id,
        InstructorTrainee.instructor_id==identity.user.id, InstructorTrainee.trainee_id==learner_id))
    if pair is None: raise HTTPException(403, "Сначала добавьте участника в свою группу")
    # Validate that the assigned scenario can actually run.
    from app.strategy_domain import Run
    try: replay(Run(version=1, scenario=request.scenario, commands=[]))
    except ValueError as error: raise HTTPException(422, str(error))
    row = db.get(StrategyAssignment, aid)
    if row:
        if row.organization_id==identity.organization.id and row.instructor_id==identity.user.id and row.learner_id==learner_id and row.scenario==request.scenario.model_dump() and iso(row.due_at)==iso(request.due_at):
            return assignment_json(row)
        raise HTTPException(409, "Идентификатор уже занят")
    row = StrategyAssignment(id=aid, organization_id=identity.organization.id, instructor_id=identity.user.id,
        learner_id=learner_id, scenario=request.scenario.model_dump(), revision=1, status="assigned", feedback="", due_at=request.due_at,
        history=[dict(kind="assigned", at=iso(datetime.now(timezone.utc)), actor=str(identity.user.id))])
    db.add(row)
    try: db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(409, "Назначение уже создано; обновите список")
    return assignment_json(row)

class Submission(Strict):
    base_revision: int = Field(ge=1)
    document: Document
class Feedback(Strict):
    base_revision: int = Field(ge=1)
    feedback: str = Field(max_length=4000)
    cancel: bool = False
    request_id: uuid.UUID | None = Field(default=None, strict=False)


class Deadline(Strict):
    base_revision: int = Field(ge=1)
    due_at: AwareDatetime | None = Field(strict=False)

    @field_validator("due_at")
    @classmethod
    def utc_deadline(cls, value):
        return value.astimezone(timezone.utc) if value else None
    request_id: uuid.UUID | None = Field(default=None, strict=False)


def mutation_retry(row, request, identity, kind, payload):
    if request.request_id is None:
        return False
    for event in row.history or []:
        if event.get("request_id") == str(request.request_id):
            if event.get("actor") == str(identity.user.id) and event["kind"] == kind and event.get("payload") == payload:
                return True
            raise HTTPException(409, "Идентификатор запроса уже использован")
    return False


def activity(row, identity, kind, payload=None, request_id=None):
    return [*(row.history or []), dict(kind=kind, at=iso(datetime.now(timezone.utc)),
        actor=str(identity.user.id), payload=payload,
        request_id=str(request_id) if request_id else None)]

def change_assignment(row, revision, values, db):
    result = db.execute(update(StrategyAssignment).where(StrategyAssignment.id==row.id,
        StrategyAssignment.revision==revision).values(**values, revision=revision+1, updated_at=datetime.now(timezone.utc)))
    if result.rowcount != 1:
        db.rollback(); raise HTTPException(409, "Назначение изменилось; обновите список")
    db.commit(); db.refresh(row)
    return assignment_json(row)

@router.post("/assignments/{assignment_id}/submit")
def submit(assignment_id: uuid.UUID, request: Submission, identity: Current, db: Db):
    row = assignment_visible(assignment_id, identity, db)
    if row.learner_id != identity.user.id or identity.role != "trainee": raise HTTPException(403, "Только назначенный обучаемый")
    if row.status == "cancelled": raise HTTPException(409, "Назначение отменено")
    document = request.document
    if document.assignmentId != str(row.id) or document.run is None:
        raise HTTPException(422, "Нужна запись назначенного занятия")
    if assignment_rules(document.scenario) != assignment_rules(Scenario.model_validate(row.scenario)):
        raise HTTPException(422, "Правила назначенного сценария изменены")
    metrics = replay(document.run)
    if row.submission == document.model_dump(): return assignment_json(row)
    if row.status == "submitted": raise HTTPException(409, "Результат уже сдан; новая попытка требует нового назначения")
    return change_assignment(row, request.base_revision, dict(submission=document.model_dump(), metrics=metrics,
        status="submitted" if metrics["completed"] else "in_progress",
        submitted_at=datetime.now(timezone.utc) if metrics["completed"] else None,
        history=activity(row, identity, "submitted" if metrics["completed"] else "progress")), db)

@router.patch("/assignments/{assignment_id}/feedback")
def feedback(assignment_id: uuid.UUID, request: Feedback, identity: Staff, db: Db):
    row = assignment_visible(assignment_id, identity, db)
    if row.instructor_id != identity.user.id and identity.role != "admin": raise HTTPException(403, "Нет прав на отзыв")
    payload = dict(feedback=request.feedback, cancel=request.cancel)
    if mutation_retry(row, request, identity, "feedback", payload):
        return assignment_json(row)
    values = dict(feedback=request.feedback, feedback_at=datetime.now(timezone.utc),
        history=activity(row, identity, "feedback", payload, request.request_id))
    if request.cancel: values["status"] = "cancelled"
    return change_assignment(row, request.base_revision, values, db)


@router.patch("/assignments/{assignment_id}/deadline")
def deadline(assignment_id: uuid.UUID, request: Deadline, identity: Staff, db: Db):
    row = assignment_visible(assignment_id, identity, db)
    if row.instructor_id != identity.user.id and identity.role != "admin": raise HTTPException(403, "Нет прав на срок")
    payload = dict(due_at=iso(request.due_at))
    if mutation_retry(row, request, identity, "deadline", payload):
        return assignment_json(row)
    return change_assignment(row, request.base_revision,
        dict(due_at=request.due_at, history=activity(row, identity, "deadline", payload, request.request_id)), db)
