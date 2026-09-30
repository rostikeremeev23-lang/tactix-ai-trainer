"""Version-one educational game contract and authoritative deterministic replay.
Only synthetic normalized coordinates and abstract game quantities are accepted.
"""
from __future__ import annotations
import math
from copy import deepcopy
from typing import Annotated, Literal, Union
from pydantic import BaseModel, ConfigDict, Field, model_validator

class Strict(BaseModel):
    model_config = ConfigDict(extra="forbid", strict=True, allow_inf_nan=False)

Coordinate = Annotated[float, Field(ge=0, le=1)]
class GameObject(Strict):
    id: str = Field(min_length=1, max_length=100)
    name: str = Field(min_length=1, max_length=60)
    kind: int = Field(ge=0, le=9)
    position: list[Coordinate] = Field(min_length=2, max_length=2)
    readiness: int = Field(ge=0, le=100)
    rotation: int = Field(default=0, ge=0, le=359)
    group: str = Field(default="", max_length=30)

class Inject(Strict):
    id: str = Field(min_length=1, max_length=100)
    kind: int = Field(ge=0, le=2)
    tick: int = Field(ge=1)

class Scenario(Strict):
    name: str = Field(min_length=1, max_length=100)
    briefing: str = Field(max_length=2000)
    kind: int = Field(ge=0, le=3)
    duration: int = Field(ge=40, le=120)
    resources: int = Field(ge=10, le=100)
    cityMap: bool = False
    seed: int = Field(default=0, ge=0, le=999999)
    objects: list[GameObject] = Field(max_length=30)
    injects: list[Inject] = Field(max_length=8)

    @model_validator(mode="after")
    def valid(self):
        if not self.name.strip() or any(not o.name.strip() for o in self.objects):
            raise ValueError("Пустое название")
        if len({o.id for o in self.objects}) != len(self.objects) or len({i.id for i in self.injects}) != len(self.injects):
            raise ValueError("Повтор идентификатора")
        if any(i.tick >= self.duration - 3 for i in self.injects):
            raise ValueError("Вводная за пределами времени")
        return self

class Tick(Strict):
    action: Literal["tick"]
class Move(Strict):
    action: Literal["move"]
    id: str = Field(min_length=1, max_length=100)
    target: list[Coordinate] = Field(min_length=2, max_length=2)
class Decide(Strict):
    action: Literal["decide"]
    choice: int = Field(ge=0, le=1)
Command = Annotated[Union[Tick, Move, Decide], Field(discriminator="action")]
class Run(Strict):
    version: Literal[1]
    scenario: Scenario
    commands: list[Command] = Field(max_length=1000)
class Document(Strict):
    version: Literal[1]
    scenario: Scenario
    run: Run | None = None
    assignmentId: str | None = Field(default=None, max_length=36)
    @model_validator(mode="after")
    def matching(self):
        if self.run and self.run.scenario != self.scenario:
            raise ValueError("Сценарий записи не совпадает")
        if self.run:
            replay(self.run)
        return self

# cost, immediate safety/cohesion, delay, delayed safety/cohesion.
CHOICES = (((12,0,0,6,0,5),(0,0,0,0,-20,0)),
           ((10,0,5,0,0,0),(0,0,-10,0,0,-10)),
           ((0,5,0,8,0,0),(5,0,0,0,-15,0)))
def replay(run: Run) -> dict:
    s = run.scenario
    objects = [o.model_dump() for o in s.objects]
    mobile = lambda o: o["kind"] not in (3,4) and o["readiness"] > 0
    goals = [o for o in objects if o["kind"] == 3]
    if not goals or not any(mobile(o) for o in objects) or (s.kind == 2 and not any(o["kind"] == 1 and mobile(o) for o in objects)):
        raise ValueError("Невозможно запустить сценарий")
    targets = {}
    if s.kind == 2:
        targets = {o["id"]: goals[0]["position"] for o in objects if o["kind"] == 1 and mobile(o)}
    tick = hold = slow = 0
    resources = s.resources
    safety = cohesion = 100
    reached, resolved = set(), set()
    delayed = []
    pending = None
    def event():
        due = sorted((i for i in s.injects if i.tick <= tick and i.id not in resolved), key=lambda i: (i.tick, i.id))
        return due[0] if due else None
    clamp = lambda v: max(0, min(100, v))
    for cmd in run.commands:
        if tick >= s.duration:
            raise ValueError("Команда после завершения")
        if isinstance(cmd, Move):
            obj = next((o for o in objects if o["id"] == cmd.id and mobile(o)), None)
            if pending or resources < 1 or obj is None:
                raise ValueError("Недопустимое перемещение")
            targets[cmd.id] = cmd.target
            resources -= 1
        elif isinstance(cmd, Decide):
            if pending is None:
                raise ValueError("Решение без вводной")
            cost, ds, dc, delay, ls, lc = CHOICES[pending.kind][cmd.choice]
            if cost > resources:
                raise ValueError("Недостаточно ресурсов")
            resources -= cost
            safety, cohesion = clamp(safety + ds), clamp(cohesion + dc)
            slow = max(slow, tick + delay)
            if ls or lc: delayed.append((tick+3, ls, lc))
            resolved.add(pending.id)
            pending = event()
        else:
            if pending: raise ValueError("Такт до решения вводной")
            tick += 1
            for due, ds, dc in delayed[:]:
                if due <= tick:
                    safety, cohesion = clamp(safety + ds), clamp(cohesion + dc)
                    delayed.remove((due, ds, dc))
            for o in objects:
                target = targets.get(o["id"])
                if target is None: continue
                x, y = o["position"]
                distance = math.hypot(target[0]-x, target[1]-y)
                speed = (.024 if o["kind"] == 1 else .014 if o["kind"] == 2 else .018) * o["readiness"] / 100 * (.45 if tick <= slow else 1)
                if distance <= speed:
                    o["position"] = target[:]
                    del targets[o["id"]]
                else:
                    o["position"] = [x + (target[0]-x)/distance*speed, y + (target[1]-y)/distance*speed]
            occupied = 0
            for goal in goals:
                if any(mobile(o) and (s.kind != 2 or o["kind"] == 1) and math.dist(o["position"], goal["position"]) <= .055 for o in objects):
                    occupied += 1
                    reached.add(goal["id"])
            if occupied == len(goals): hold += 1
            pending = event()
    objective = 50 * hold / s.duration if s.kind == 1 else 50 * len(reached) / len(goals)
    score = clamp(math.floor(objective + safety*.2 + cohesion*.2 + resources*.1 + .5))
    completed = tick == s.duration
    achieved = hold * 2 >= s.duration if s.kind == 1 else len(reached) == len(goals)
    return dict(tick=tick, score=score, resources=resources, safety=safety, cohesion=cohesion,
                reached=sorted(reached), holdTicks=hold, completed=completed, succeeded=completed and achieved and score>=75)

def assignment_rules(scenario: Scenario) -> dict:
    """Only mobile-token placement, visual rotation and labels may differ in a submission."""
    data = deepcopy(scenario.model_dump())
    for obj in data["objects"]:
        if obj["kind"] not in (3,4):
            for field in ("position", "rotation", "group", "name"): obj.pop(field)
    data["objects"].sort(key=lambda o: o["id"])
    return data
