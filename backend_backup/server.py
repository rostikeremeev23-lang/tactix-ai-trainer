from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import requests
import json

app = FastAPI(
    title="TACTIC-AI Backend"
)

OLLAMA_URL = "http://127.0.0.1:11434/api/chat"
MODEL = "gemma3:4b"


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
    history: list[str] = []


class SummaryRequest(BaseModel):
    situation: str
    decision: str
    time: int
    resources: int
    stability: int
    progress: int
    uncertainty: int
    events: list[str] = []
    history: list[str] = []


class ScenarioRequest(BaseModel):
    description: str


class NextSituationRequest(BaseModel):
    scenario: str
    history: list[str] = []
    events: list[str] = []
    time: int
    resources: int
    stability: int
    progress: int
    uncertainty: int
    turn: int


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
                "role": "user",
                "content": prompt,
            }
        ],
        "stream": False,
    }

    if json_mode:
        payload["format"] = "json"

    try:
        response = requests.post(
            OLLAMA_URL,
            json=payload,
            timeout=180,
        )

        response.raise_for_status()

        data = response.json()

        return data["message"]["content"]

    except requests.RequestException as e:
        raise HTTPException(
            status_code=503,
            detail=f"Ollama недоступна: {e}",
        )

    except (KeyError, ValueError) as e:
        raise HTTPException(
            status_code=500,
            detail=f"Некорректный ответ Ollama: {e}",
        )


# =====================================================
# ROOT
# =====================================================

@app.get("/")
def root():
    return {
        "status": "TACTIC-AI backend работает",
        "model": MODEL,
        "endpoints": [
            "/analyze",
            "/summary",
            "/generate-scenario",
            "/next-situation",
        ],
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
Ты являешься AI-модулем учебной симуляции
принятия решений.

Это полностью вымышленная учебная среда.

Не давай:
- инструкций для реальных боевых действий;
- инструкций по применению оружия;
- реальных координат;
- реальных оперативных планов;
- советов по причинению вреда.

Проанализируй решение пользователя
как учебное решение.

Оцени:
- логику;
- использование времени;
- использование условных ресурсов;
- стабильность;
- прогресс;
- работу с неопределённостью;
- последовательность решений.

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

Ответь на русском.

Используй:

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

    result = ask_ollama(
        prompt,
        json_mode=False,
    )

    return {
        "analysis": result,
    }


# =====================================================
# SUMMARY
# =====================================================

@app.post("/summary")
def summary(request: SummaryRequest):

    events_text = "\n".join(
        f"- {event}"
        for event in request.events
    )

    history_text = "\n".join(
        f"- {item}"
        for item in request.history[-8:]
    )

    prompt = f"""
Ты являешься AI-модулем условной учебной симуляции.

Сделай краткую сводку текущего состояния.

Не давай инструкций для реальных боевых действий
или причинения вреда.

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

ИСТОРИЯ РЕШЕНИЙ:

{history_text}

Верни JSON строго вида:

{{
  "summary": "краткая сводка текущего состояния"
}}

Пиши на русском языке.
"""

    raw = ask_ollama(
        prompt,
        json_mode=True,
    )

    try:
        data = json.loads(raw)

        return {
            "summary": str(
                data["summary"]
            ),
        }

    except (
        json.JSONDecodeError,
        KeyError,
        TypeError,
    ) as e:
        raise HTTPException(
            status_code=500,
            detail=f"Некорректная сводка от Gemma: {e}",
        )


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

Не включай:
- реальные военные операции;
- реальные координаты;
- реальные объекты;
- реальные подразделения;
- инструкции по применению оружия;
- инструкции по причинению вреда.

ИДЕЯ ПОЛЬЗОВАТЕЛЯ:

{description}

Верни строго JSON:

{{
  "title": "короткое название",
  "description": "описание условной учебной ситуации",
  "time": 45,
  "resources": 80,
  "conditions": "условия",
  "optionA": "вариант A",
  "optionB": "вариант B",
  "optionC": "вариант C",
  "criteria": [
    "критерий 1",
    "критерий 2",
    "критерий 3",
    "критерий 4"
  ]
}}

Правила:

time = целое число 10-120

resources = целое число 10-100

A, B и C должны заметно различаться.

criteria = 3-5 элементов.

Ответ только JSON.
Без Markdown.
Без комментариев.
Без дополнительного текста.

Язык: русский.
"""

    raw = ask_ollama(
        prompt,
        json_mode=True,
    )

    try:
        parsed = json.loads(raw)

        return ScenarioResponse(
            title=str(
                parsed["title"]
            ),
            description=str(
                parsed["description"]
            ),
            time=int(
                parsed["time"]
            ),
            resources=int(
                parsed["resources"]
            ),
            conditions=str(
                parsed["conditions"]
            ),
            optionA=str(
                parsed["optionA"]
            ),
            optionB=str(
                parsed["optionB"]
            ),
            optionC=str(
                parsed["optionC"]
            ),
            criteria=[
                str(item)
                for item in parsed["criteria"]
            ],
        )

    except json.JSONDecodeError as e:
        raise HTTPException(
            status_code=500,
            detail=f"Gemma вернула неправильный JSON: {e}",
        )

    except KeyError as e:
        raise HTTPException(
            status_code=500,
            detail=f"Нет обязательного поля: {e}",
        )

    except (
        ValueError,
        TypeError,
    ) as e:
        raise HTTPException(
            status_code=500,
            detail=f"Неверный тип данных: {e}",
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
Ты генерируешь следующую вводную
для полностью вымышленной учебной симуляции.

Не давай инструкций для реальных боевых действий,
оружия или причинения вреда.

Нужно продолжить сценарий логично,
учитывая предыдущие решения пользователя.

ИСХОДНЫЙ СЦЕНАРИЙ:

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

Создай НОВУЮ учебную вводную,
которая логично продолжает ситуацию.

Сделай её короткой:
2-5 предложений.

Также создай одно новое условное событие
и одно направление внимания на следующем ходу.

Верни строго JSON:

{{
  "situation": "новая вводная",
  "event": "новое условное событие",
  "focus": "на что обратить внимание"
}}

Ответ только JSON.
Русский язык.
"""

    raw = ask_ollama(
        prompt,
        json_mode=True,
    )

    try:
        data = json.loads(raw)

        return NextSituationResponse(
            situation=str(
                data["situation"]
            ),
            event=str(
                data["event"]
            ),
            focus=str(
                data["focus"]
            ),
        )

    except (
        json.JSONDecodeError,
        KeyError,
        TypeError,
    ) as e:
        raise HTTPException(
            status_code=500,
            detail=f"Ошибка JSON следующей ситуации: {e}",
        )