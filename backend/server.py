
import json

import requests
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field


# =====================================================
# APP
# =====================================================

app = FastAPI(
    title="TACTIX Backend",
    version="1.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)


# =====================================================
# OLLAMA CONFIG
# =====================================================

OLLAMA_URL = "http://127.0.0.1:11434/api/chat"
MODEL = "gemma3:1b"

REQUEST_TIMEOUT = 180


# =====================================================
# REQUEST MODELS
# =====================================================

class AnalysisRequest(BaseModel):
    situation: str
    decision: str
    time: int
    resources: int
    stability: int
    progress: int
    uncertainty: int
    history: list[str] = Field(default_factory=list)


class SummaryRequest(BaseModel):
    situation: str
    decision: str
    time: int
    resources: int
    stability: int
    progress: int
    uncertainty: int
    events: list[str] = Field(default_factory=list)
    history: list[str] = Field(default_factory=list)


class ScenarioRequest(BaseModel):
    description: str


class NextSituationRequest(BaseModel):
    scenario: str
    history: list[str] = Field(default_factory=list)
    events: list[str] = Field(default_factory=list)
    time: int
    resources: int
    stability: int
    progress: int
    uncertainty: int
    turn: int


class ExplainScoreRequest(BaseModel):
    situation: str
    decision: str
    goal: str = ""
    criteria: list[str] = Field(default_factory=list)
    objective_score: int
    level: str
    score_breakdown: dict[str, int] = Field(default_factory=dict)
    state_delta: dict[str, int] = Field(default_factory=dict)
    time: int
    resources: int
    stability: int
    progress: int
    uncertainty: int
    history: list[str] = Field(default_factory=list)


class ScenarioResponse(BaseModel):
    title: str
    description: str
    time: int
    resources: int
    conditions: str
    optionA: str
    optionB: str
    optionC: str
    criteria: list[str]
    goal: str = ""


class NextSituationResponse(BaseModel):
    situation: str
    event: str
    focus: str


# =====================================================
# OLLAMA
# =====================================================

def ask_ollama(
    prompt: str,
    json_mode: bool = False,
) -> str:
    payload = {
        "model": MODEL,
        "messages": [
            {
                "role": "system",
                "content": (
                    "Ты AI-модуль учебного симулятора "
                    "TACTIX. Все сценарии полностью "
                    "вымышленные и предназначены только "
                    "для обучения принятию решений. "
                    "Не давай инструкции для реального "
                    "насилия, применения оружия, боевых "
                    "операций или причинения вреда. "
                    "Отвечай на русском языке."
                ),
            },
            {
                "role": "user",
                "content": prompt,
            },
        ],
        "stream": False,
    }

    if json_mode:
        payload["format"] = "json"

    try:
        response = requests.post(
            OLLAMA_URL,
            json=payload,
            timeout=REQUEST_TIMEOUT,
        )

        response.raise_for_status()

        data = response.json()

        message = data.get("message")

        if not isinstance(message, dict):
            raise HTTPException(
                status_code=500,
                detail="Ollama вернула некорректный ответ.",
            )

        content = message.get("content")

        if not content:
            raise HTTPException(
                status_code=500,
                detail="Ollama вернула пустой ответ.",
            )

        return str(content)

    except requests.Timeout:
        raise HTTPException(
            status_code=504,
            detail="Ollama слишком долго отвечает.",
        )

    except requests.ConnectionError:
        raise HTTPException(
            status_code=503,
            detail=(
                "Ollama недоступна. "
                "Убедитесь, что Ollama запущена."
            ),
        )

    except requests.RequestException as exc:
        raise HTTPException(
            status_code=503,
            detail=f"Ошибка подключения к Ollama: {exc}",
        )

    except (ValueError, KeyError) as exc:
        raise HTTPException(
            status_code=500,
            detail=f"Ollama вернула некорректный JSON: {exc}",
        )


def parse_json_object(raw: str) -> dict:
    try:
        data = json.loads(raw)
    except json.JSONDecodeError as exc:
        raise HTTPException(
            status_code=500,
            detail=f"Ollama вернула некорректный JSON: {exc}",
        )

    if not isinstance(data, dict):
        raise HTTPException(
            status_code=500,
            detail="Ожидался JSON-объект.",
        )

    return data


# =====================================================
# ROOT
# =====================================================

@app.get("/")
def root():
    return {
        "status": "TACTIX backend работает",
        "model": MODEL,
        "ollama_url": OLLAMA_URL,
        "endpoints": [
            "/",
            "/health",
            "/analyze",
            "/summary",
            "/generate-scenario",
            "/next-situation",
            "/explain-score",
        ],
    }


# =====================================================
# HEALTH
# =====================================================

@app.get("/health")
def health():
    ollama_available = False

    try:
        response = requests.get(
            "http://127.0.0.1:11434/api/tags",
            timeout=5,
        )

        ollama_available = (
            response.status_code >= 200
            and response.status_code < 300
        )
    except requests.RequestException:
        ollama_available = False

    return {
        "status": "ok",
        "model": MODEL,
        "ollama_available": ollama_available,
    }


# =====================================================
# ANALYZE
# =====================================================

@app.post("/analyze")
def analyze(request: AnalysisRequest):
    history_text = "\n".join(
        f"- {item}"
        for item in request.history[-8:]
    )

    prompt = f"""
Ты анализируешь решение пользователя в полностью
вымышленной учебной симуляции принятия решений.

Оцени:
- логику;
- использование времени;
- использование условных ресурсов;
- стабильность;
- прогресс;
- работу с неопределённостью;
- последовательность решений.

Не давай инструкции для реального насилия,
оружия, боевых действий или причинения вреда.

ТЕКУЩЕЕ СОСТОЯНИЕ:

Время: {request.time}
Ресурсы: {request.resources}
Стабильность: {request.stability}
Прогресс: {request.progress}
Неопределённость: {request.uncertainty}

СЦЕНАРИЙ:

{request.situation}

ТЕКУЩЕЕ РЕШЕНИЕ:

{request.decision}

ПРЕДЫДУЩИЕ РЕШЕНИЯ:

{history_text}

Ответь на русском языке.

Используй формат:

ОЦЕНКА: 0-100

УРОВЕНЬ:
низкий / средний / высокий

СИЛЬНЫЕ СТОРОНЫ:
- ...
- ...

СЛАБЫЕ СТОРОНЫ:
- ...
- ...

АНАЛИЗ:
...

ВОПРОС ДЛЯ УТОЧНЕНИЯ:
...
"""

    result = ask_ollama(prompt)

    return {
        "analysis": result,
    }


# =====================================================
# EXPLAIN OBJECTIVE TACTIX SCORE
# =====================================================

@app.post("/explain-score")
def explain_score(request: ExplainScoreRequest):
    criteria_text = "\n".join(
        f"- {item}"
        for item in request.criteria[:8]
        if str(item).strip()
    )

    history_text = "\n".join(
        f"- {item}"
        for item in request.history[-8:]
        if str(item).strip()
    )

    breakdown = request.score_breakdown or {}
    delta = request.state_delta or {}

    prompt = f"""
Ты объясняешь уже рассчитанный объективный TACTIX Score
в полностью вымышленной учебной симуляции принятия решений.

ВАЖНО:
- итоговый балл уже рассчитан локальным движком;
- не пересчитывай и не изменяй итоговый балл;
- не давай инструкции для реального насилия, оружия,
  боевых действий или причинения вреда;
- объясни только учебную логику результата.

СИТУАЦИЯ:
{request.situation}

РЕШЕНИЕ:
{request.decision}

ЦЕЛЬ СЦЕНАРИЯ:
{request.goal}

КРИТЕРИИ УСПЕХА:
{criteria_text}

TACTIX SCORE: {request.objective_score}/100
УРОВЕНЬ: {request.level}

КОМПОНЕНТЫ ОЦЕНКИ:
- Цель: {breakdown.get('goal', 0)}
- Ресурсы: {breakdown.get('resources', 0)}
- Устойчивость: {breakdown.get('stability', 0)}
- Неопределённость: {breakdown.get('uncertainty', 0)}
- Время: {breakdown.get('time', 0)}

ИЗМЕНЕНИЕ СОСТОЯНИЯ:
- Время: {delta.get('time', 0)}
- Ресурсы: {delta.get('resources', 0)}
- Устойчивость: {delta.get('stability', 0)}
- Прогресс: {delta.get('progress', 0)}
- Неопределённость: {delta.get('uncertainty', 0)}

ТЕКУЩЕЕ СОСТОЯНИЕ:
- Время: {request.time}
- Ресурсы: {request.resources}
- Стабильность: {request.stability}
- Прогресс: {request.progress}
- Неопределённость: {request.uncertainty}

ПРЕДЫДУЩИЕ РЕШЕНИЯ:
{history_text}

Ответь на русском языке в формате:

КРАТКАЯ ОЦЕНКА:
1-2 предложения.

ПОЧЕМУ ТАКОЙ БАЛЛ:
- ...
- ...
- ...

СИЛЬНЫЕ СТОРОНЫ:
- ...
- ...

ЧТО УХУДШИЛО РЕЗУЛЬТАТ:
- ...
- ...

РЕКОМЕНДАЦИЯ НА СЛЕДУЮЩИЙ ХОД:
Одна короткая учебная рекомендация без реальных боевых инструкций.
"""

    result = ask_ollama(prompt)

    return {
        "explanation": result,
    }


# =====================================================
# SUMMARY
# =====================================================

@app.post("/summary")
def summary(request: SummaryRequest):
    events_text = "\n".join(
        f"- {event}"
        for event in request.events[-8:]
    )

    history_text = "\n".join(
        f"- {item}"
        for item in request.history[-8:]
    )

    prompt = f"""
Сделай краткую сводку текущего состояния полностью
вымышленной учебной симуляции.

Не давай инструкции для реальных боевых действий,
насилия, оружия или причинения вреда.

СЦЕНАРИЙ:

{request.situation}

ПАРАМЕТРЫ:

Время: {request.time}
Ресурсы: {request.resources}
Стабильность: {request.stability}
Прогресс: {request.progress}
Неопределённость: {request.uncertainty}

ПОСЛЕДНИЕ СОБЫТИЯ:

{events_text}

ПРЕДЫДУЩИЕ РЕШЕНИЯ:

{history_text}

Верни JSON строго такого вида:

{{
  "summary": "краткая сводка текущего состояния"
}}

Только JSON.
Язык: русский.
"""

    raw = ask_ollama(
        prompt,
        json_mode=True,
    )

    data = parse_json_object(raw)

    summary_text = data.get("summary")

    if summary_text is None:
        raise HTTPException(
            status_code=500,
            detail="В ответе Ollama отсутствует поле summary.",
        )

    return {
        "summary": str(summary_text),
    }


# =====================================================
# GENERATE SCENARIO
# =====================================================

@app.post(
    "/generate-scenario",
    response_model=ScenarioResponse,
)
def generate_scenario(
    request: ScenarioRequest,
):
    description = request.description.strip()

    if not description:
        raise HTTPException(
            status_code=400,
            detail="Описание сценария пустое.",
        )

    prompt = f"""
Создай полностью вымышленный учебный сценарий
для симулятора принятия решений.

Сценарий предназначен только для обучения.

Не используй:
- реальные военные операции;
- реальные координаты;
- реальные подразделения;
- инструкции по применению оружия;
- инструкции по причинению вреда.

ОПИСАНИЕ ПОЛЬЗОВАТЕЛЯ:

{description}

Верни строго JSON:

{{
  "title": "короткое название",
  "description": "описание учебной ситуации",
  "time": 45,
  "resources": 80,
  "conditions": "условия",
  "optionA": "вариант A",
  "optionB": "вариант B",
  "optionC": "вариант C",
  "criteria": [
    "критерий 1",
    "критерий 2",
    "критерий 3"
  ],
  "goal": "цель сценария"
}}

Правила:

time = целое число от 10 до 120.

resources = целое число от 10 до 100.

A, B и C должны заметно различаться.

criteria = 3-5 элементов.

Только JSON.
Без Markdown.
Без комментариев.
Без дополнительного текста.

Язык: русский.
"""

    raw = ask_ollama(
        prompt,
        json_mode=True,
    )

    parsed = parse_json_object(raw)

    try:
        criteria_raw = parsed.get(
            "criteria",
            [],
        )

        if not isinstance(
            criteria_raw,
            list,
        ):
            criteria_raw = []

        criteria = [
            str(item)
            for item in criteria_raw
            if str(item).strip()
        ]

        return ScenarioResponse(
            title=str(
                parsed["title"],
            ),
            description=str(
                parsed["description"],
            ),
            time=int(
                parsed["time"],
            ),
            resources=int(
                parsed["resources"],
            ),
            conditions=str(
                parsed.get(
                    "conditions",
                    "",
                ),
            ),
            optionA=str(
                parsed["optionA"],
            ),
            optionB=str(
                parsed["optionB"],
            ),
            optionC=str(
                parsed["optionC"],
            ),
            criteria=criteria,
            goal=str(
                parsed.get(
                    "goal",
                    "",
                ),
            ),
        )

    except (
        KeyError,
        ValueError,
        TypeError,
    ) as exc:
        raise HTTPException(
            status_code=500,
            detail=(
                f"Некорректная структура сценария "
                f"от Ollama: {exc}"
            ),
        )


# =====================================================
# NEXT SITUATION
# =====================================================

@app.post(
    "/next-situation",
    response_model=NextSituationResponse,
)
def next_situation(
    request: NextSituationRequest,
):
    history_text = "\n".join(
        f"- {item}"
        for item in request.history[-8:]
    )

    events_text = "\n".join(
        f"- {event}"
        for event in request.events[-5:]
    )

    prompt = f"""
Сгенерируй следующую вводную для полностью
вымышленной учебной симуляции принятия решений.

Сценарий должен логично продолжать предыдущий ход.

Не используй инструкции для реальных боевых действий,
оружия, причинения вреда или реальные оперативные данные.

СЦЕНАРИЙ:

{request.scenario}

ТЕКУЩИЙ ХОД:

{request.turn}

ТЕКУЩИЕ ПАРАМЕТРЫ:

Время: {request.time}
Ресурсы: {request.resources}
Стабильность: {request.stability}
Прогресс: {request.progress}
Неопределённость: {request.uncertainty}

ПРЕДЫДУЩИЕ РЕШЕНИЯ:

{history_text}

ПОСЛЕДНИЕ СОБЫТИЯ:

{events_text}

Создай:

1. новую учебную вводную;
2. одно новое условное событие;
3. один фокус внимания на следующий ход.

Верни строго JSON:

{{
  "situation": "новая вводная",
  "event": "новое условное событие",
  "focus": "на что обратить внимание"
}}

Язык: русский.
Только JSON.
"""

    raw = ask_ollama(
        prompt,
        json_mode=True,
    )

    data = parse_json_object(raw)

    try:
        return NextSituationResponse(
            situation=str(
                data["situation"],
            ),
            event=str(
                data["event"],
            ),
            focus=str(
                data["focus"],
            ),
        )
    except (
        KeyError,
        TypeError,
    ) as exc:
        raise HTTPException(
            status_code=500,
            detail=(
                f"Некорректный ответ следующей "
                f"ситуации от Ollama: {exc}"
            ),
        )
