"""Evidence-constrained ASK THREAD endpoint.

Phase E deliberately keeps AI read-only. It builds a bounded source pack from the
current authorized Case, asks the configured TACTIX AI for a draft, then asks for
a second verification pass. Returned source references are intersected with the
server-generated allow-list, so the client never receives fabricated citations.
"""
from __future__ import annotations

import json
import uuid
from datetime import datetime, timezone
from typing import Any, Callable, Literal

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, ConfigDict, Field
from sqlalchemy import select

from app.auth import Current, Db
from app.models import CaseEvent, StrategyAssignment, ThreadEvidence
from app.thread import case_for, _case_training_relations, _training_visible, timestamp

router = APIRouter(prefix="/v1/thread", tags=["thread-ai"])

AskProvider = Callable[..., str]
_ai_provider: AskProvider | None = None


def configure_ai_provider(provider: AskProvider | None) -> None:
    global _ai_provider
    _ai_provider = provider


class Strict(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)


class AskThreadRequest(Strict):
    question: str = Field(min_length=2, max_length=1600)
    max_sources: int = Field(default=24, ge=6, le=40)


def _clip(value: Any, limit: int = 1400) -> str:
    if value is None:
        return ""
    if isinstance(value, (dict, list)):
        text = json.dumps(value, ensure_ascii=False, sort_keys=True, default=str)
    else:
        text = str(value)
    text = " ".join(text.split())
    return text[:limit]


def _ref(prefix: str, value: uuid.UUID) -> str:
    return f"{prefix}-{str(value).replace('-', '')[:8].upper()}"


def _source(ref: str, kind: str, label: str, excerpt: str, **extra: Any) -> dict[str, Any]:
    return {
        "ref": ref,
        "kind": kind,
        "label": label,
        "excerpt": _clip(excerpt, 900),
        **extra,
    }


def _build_source_pack(db, identity, row, max_sources: int) -> list[dict[str, Any]]:
    sources: list[dict[str, Any]] = [
        _source(
            "CASE",
            "CASE",
            row.title,
            f"Type: {row.type}. Priority: {row.priority}. Status: {row.status}. "
            f"Description: {row.description or 'No description.'}",
            verification_state="AUTHORITATIVE_CASE_STATE",
            source="thread_case",
        )
    ]

    evidence = db.scalars(
        select(ThreadEvidence)
        .where(ThreadEvidence.case_id == row.id)
        .order_by(ThreadEvidence.created_at, ThreadEvidence.id)
    ).all()
    for item in evidence:
        sources.append(
            _source(
                _ref("EVIDENCE", item.id),
                "EVIDENCE",
                item.title,
                item.description,
                verification_state=item.verification_state,
                source=item.source,
                created_at=timestamp(item.created_at),
                verified_at=timestamp(item.verified_at),
                verification_note=_clip(item.verification_note, 500),
            )
        )

    events = db.scalars(
        select(CaseEvent)
        .where(CaseEvent.case_id == row.id)
        .order_by(CaseEvent.revision.desc())
        .limit(16)
    ).all()
    for item in reversed(events):
        sources.append(
            _source(
                f"EVENT-R{item.revision}",
                "EVENT",
                item.type,
                item.details,
                verification_state="CONFIRMED_EVENT",
                source="thread_timeline",
                created_at=timestamp(item.created_at),
            )
        )

    for relation in _case_training_relations(db, identity, row.id):
        assignment_id = relation.to_id if relation.to_type == "TRAINING" else relation.from_id
        try:
            assignment: StrategyAssignment = _training_visible(db, identity, assignment_id)
        except HTTPException:
            continue
        scenario = assignment.scenario or {}
        training_excerpt = {
            "title": scenario.get("title") or "Simulation Lab training",
            "status": assignment.status,
            "metrics": assignment.metrics or {},
            "feedback": assignment.feedback or "",
            "submitted_at": timestamp(assignment.submitted_at),
        }
        sources.append(
            _source(
                _ref("TRAINING", assignment.id),
                "TRAINING",
                str(training_excerpt["title"]),
                training_excerpt,
                verification_state=(
                    "SUBMITTED_RESULT" if assignment.status == "submitted" and assignment.submission is not None
                    else "TRAINING_RECORD"
                ),
                source=f"strategy_assignment:{assignment.id}",
            )
        )

    # Preserve the Case itself, then prioritize verified evidence and recent
    # confirmed records before cutting the source pack to a bounded size.
    if len(sources) <= max_sources:
        return sources
    case = sources[0]
    rest = sources[1:]
    rest.sort(
        key=lambda item: (
            0 if item.get("verification_state") == "VERIFIED" else 1,
            0 if item["kind"] == "EVIDENCE" else 1,
            item["ref"],
        )
    )
    return [case, *rest[: max_sources - 1]]


def _parse_ai_json(raw: str, stage: str) -> dict[str, Any]:
    text = raw.strip()
    if text.startswith("```json"):
        text = text[7:]
    elif text.startswith("```"):
        text = text[3:]
    if text.endswith("```"):
        text = text[:-3]
    try:
        value = json.loads(text.strip())
    except (json.JSONDecodeError, TypeError) as exc:
        raise HTTPException(502, f"ASK THREAD {stage} returned invalid JSON: {exc}")
    if not isinstance(value, dict):
        raise HTTPException(502, f"ASK THREAD {stage} must return a JSON object")
    return value


def _refs(value: Any, allowed: set[str]) -> list[str]:
    if not isinstance(value, list):
        return []
    result: list[str] = []
    for item in value:
        ref = str(item).strip().upper()
        if ref in allowed and ref not in result:
            result.append(ref)
    return result


def _call_ai(prompt: str) -> dict[str, Any]:
    if _ai_provider is None:
        raise HTTPException(503, "ASK THREAD AI provider is not configured")
    try:
        raw = _ai_provider(prompt, json_mode=True, timeout=45)
    except TypeError:
        # Keeps the module easy to unit-test with a minimal callable.
        raw = _ai_provider(prompt)
    return _parse_ai_json(raw, "pipeline")


@router.post("/cases/{case_id}/ask")
def ask_thread(case_id: uuid.UUID, request: AskThreadRequest, identity: Current, db: Db):
    row = case_for(db, identity, case_id)
    sources = _build_source_pack(db, identity, row, request.max_sources)
    allowed = {item["ref"] for item in sources}
    source_json = json.dumps(sources, ensure_ascii=False, separators=(",", ":"), default=str)

    draft_prompt = f"""
You are ASK THREAD inside TACTIX. This is a READ-ONLY evidence analysis tool.
Answer the user's question using ONLY the supplied Case source pack.

SAFETY AND EVIDENCE RULES:
- This product is for training/administrative review. Do not provide real-world
  combat, weapons, targeting, attack planning, or harmful operational instructions.
- Never invent a fact, source, status, metric, person, date, or causal claim.
- VERIFIED evidence may support a factual conclusion. UNVERIFIED/REJECTED evidence
  must be explicitly described as unverified/rejected and cannot be treated as fact.
- If the sources do not support an answer, say that the Thread contains insufficient evidence.
- Cite only source refs exactly as they appear in SOURCE_PACK.
- Return JSON only. No markdown fences.

Return this shape:
{{
  "answer": "concise answer in Russian",
  "confidence": "HIGH|MEDIUM|LOW",
  "source_refs": ["CASE"],
  "claims": [{{"text":"claim in Russian","source_refs":["CASE"]}}],
  "open_questions": ["what is still unknown"]
}}

CASE_REVISION: {row.revision}
QUESTION: {request.question}
SOURCE_PACK: {source_json}
""".strip()
    draft = _call_ai(draft_prompt)

    verifier_prompt = f"""
You are the verification pass for ASK THREAD. Audit the candidate answer against
SOURCE_PACK. Remove or rewrite every unsupported statement. Do not add new facts.
Treat UNVERIFIED/REJECTED evidence as non-authoritative and label it accordingly.
Do not provide real-world combat or harmful operational instructions.
Return JSON only, no markdown fences.

Return this shape:
{{
  "corrected_answer": "final concise answer in Russian",
  "confidence": "HIGH|MEDIUM|LOW",
  "approved_source_refs": ["CASE"],
  "unsupported_claims": ["claim removed or not supported"],
  "open_questions": ["remaining information gap"]
}}

QUESTION: {request.question}
SOURCE_PACK: {source_json}
CANDIDATE: {json.dumps(draft, ensure_ascii=False, separators=(",", ":"), default=str)}
""".strip()
    verified = _call_ai(verifier_prompt)

    refs = _refs(verified.get("approved_source_refs"), allowed)
    # If the verifier omitted refs, accept only draft refs that are in the server
    # allow-list. Fabricated refs are always discarded.
    if not refs:
        refs = _refs(draft.get("source_refs"), allowed)

    answer = str(verified.get("corrected_answer") or "").strip()
    if not answer:
        answer = str(draft.get("answer") or "").strip()
    if not answer:
        answer = "В Digital Thread недостаточно подтвержденных данных для ответа."

    confidence = str(verified.get("confidence") or draft.get("confidence") or "LOW").upper()
    if confidence not in {"HIGH", "MEDIUM", "LOW"}:
        confidence = "LOW"
    if not refs:
        confidence = "LOW"

    source_index = {item["ref"]: item for item in sources}
    unsupported = verified.get("unsupported_claims")
    open_questions = verified.get("open_questions", draft.get("open_questions"))

    return {
        "answer": answer[:6000],
        "confidence": confidence,
        "sources": [source_index[ref] for ref in refs],
        "unsupported_claims": [str(v)[:500] for v in unsupported[:8]] if isinstance(unsupported, list) else [],
        "open_questions": [str(v)[:500] for v in open_questions[:8]] if isinstance(open_questions, list) else [],
        "case_revision": row.revision,
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "passes": 2,
        "evidence_policy": "verified-first",
    }
