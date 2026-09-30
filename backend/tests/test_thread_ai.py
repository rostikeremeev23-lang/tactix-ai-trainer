import json
import re
import uuid

import pytest

from test_auth import system, _auth_headers
from app import thread_ai
from app.models import (
    Base,
    ThreadCase,
    CaseEvent,
    ThreadEvidence,
    ThreadRelation,
    ThreadRelationEvent,
    StrategyAssignment,
)


@pytest.fixture
def ai_thread(system):
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


def uid():
    return str(uuid.uuid4())


def create_case(client, headers, title="Evidence Case"):
    response = client.post(
        "/v1/thread/cases",
        headers=headers,
        json={"id": uid(), "request_id": uid(), "title": title, "description": "Training administration review"},
    )
    assert response.status_code == 200, response.text
    return response.json()


def test_ask_thread_two_passes_and_filters_fabricated_sources(ai_thread, monkeypatch):
    client, _, _ = ai_thread
    staff = _auth_headers(client, "admin@example.test")
    case = create_case(client, staff)
    evidence_id = uid()
    added = client.post(
        f"/v1/thread/cases/{case['id']}/evidence",
        headers=staff,
        json={
            "id": evidence_id,
            "request_id": uid(),
            "base_revision": 1,
            "title": "Completion report",
            "description": "The assigned training review was completed and documented.",
            "source": "internal-report:demo-001",
        },
    )
    assert added.status_code == 200, added.text
    verified = client.post(
        f"/v1/thread/cases/{case['id']}/evidence/{evidence_id}/verify",
        headers=staff,
        json={
            "request_id": uid(),
            "base_revision": 2,
            "state": "VERIFIED",
            "note": "Checked against the exercise record",
        },
    )
    assert verified.status_code == 200, verified.text

    calls = []

    def fake_ai(prompt, **_):
        calls.append(prompt)
        refs = re.findall(r'EVIDENCE-[A-F0-9]{8}', prompt)
        evidence_ref = refs[0]
        if len(calls) == 1:
            return json.dumps({
                "answer": "Черновик: завершение подтверждено.",
                "confidence": "HIGH",
                "source_refs": [evidence_ref, "FABRICATED-REF"],
                "claims": [{"text": "Завершение подтверждено", "source_refs": [evidence_ref]}],
                "open_questions": [],
            }, ensure_ascii=False)
        return json.dumps({
            "corrected_answer": "В THREAD есть проверенное свидетельство завершения учебного обзора.",
            "confidence": "HIGH",
            "approved_source_refs": [evidence_ref, "FABRICATED-REF"],
            "unsupported_claims": ["Удалено неподтвержденное утверждение"],
            "open_questions": ["Нужна ли дополнительная проверка результата?"],
        }, ensure_ascii=False)

    monkeypatch.setattr(thread_ai, "_ai_provider", fake_ai)
    response = client.post(
        f"/v1/thread/cases/{case['id']}/ask",
        headers=staff,
        json={"question": "Что подтверждено по этому Case?"},
    )
    assert response.status_code == 200, response.text
    body = response.json()
    assert len(calls) == 2
    assert body["passes"] == 2
    assert body["confidence"] == "HIGH"
    assert body["case_revision"] == 3
    assert body["sources"] and body["sources"][0]["kind"] == "EVIDENCE"
    assert body["sources"][0]["verification_state"] == "VERIFIED"
    assert all(source["ref"] != "FABRICATED-REF" for source in body["sources"])
    assert "VERIFIED" in calls[0]
    assert "internal-report:demo-001" in calls[0]


def test_ask_thread_uses_case_authorization_before_ai(ai_thread, monkeypatch):
    client, _, _ = ai_thread
    staff = _auth_headers(client, "instructor@example.test")
    trainee = _auth_headers(client, "trainee@example.test")
    case = create_case(client, staff, "Staff-only case")
    called = False

    def fake_ai(prompt, **_):
        nonlocal called
        called = True
        return '{}'

    monkeypatch.setattr(thread_ai, "_ai_provider", fake_ai)
    response = client.post(
        f"/v1/thread/cases/{case['id']}/ask",
        headers=trainee,
        json={"question": "Summarize this case"},
    )
    assert response.status_code == 404
    assert called is False


def test_ask_thread_reports_provider_unavailable(ai_thread, monkeypatch):
    client, _, _ = ai_thread
    staff = _auth_headers(client, "admin@example.test")
    case = create_case(client, staff)
    monkeypatch.setattr(thread_ai, "_ai_provider", None)
    response = client.post(
        f"/v1/thread/cases/{case['id']}/ask",
        headers=staff,
        json={"question": "What is known?"},
    )
    assert response.status_code == 503
    assert "not configured" in response.json()["detail"]
