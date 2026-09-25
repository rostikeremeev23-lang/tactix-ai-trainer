import 'dart:math' as math;

import 'scenario.dart';
import 'decisions.dart';

class ExerciseFrame {
  final int tick, resources, safety, cohesion, holdTicks;
  final List<MapObject> objects;
  final Map<String, MapPoint> destinations;
  final List<String> log;
  final Set<String> reached;
  final ScenarioInject? pending;
  final String condition;
  ExerciseFrame({
    required this.tick,
    required this.resources,
    required this.safety,
    required this.cohesion,
    required this.holdTicks,
    required List<MapObject> objects,
    required Map<String, MapPoint> destinations,
    required List<String> log,
    required Set<String> reached,
    required this.pending,
    required this.condition,
  }) : objects = List.unmodifiable(objects),
       destinations = Map.unmodifiable(destinations),
       log = List.unmodifiable(log),
       reached = Set.unmodifiable(reached);
}

class ExerciseEngine {
  final StudioScenario scenario;
  final List<ExerciseFrame> _frames = [];
  final List<Map<String, dynamic>> _commands = [];
  final Set<String> _resolved = {};
  final List<({int due, int safety, int cohesion, String reason})> _delayed =
      [];
  late List<MapObject> _objects;
  final Map<String, MapPoint> _destinations = {};
  final List<String> _log = [];
  final Set<String> _reached = {};
  int _tick = 0,
      _resources = 100,
      _safety = 100,
      _cohesion = 100,
      _holdTicks = 0;
  int _slowUntil = 0;
  ScenarioInject? _pending;
  String _condition = 'Условия штатные';
  ExerciseEngine(this.scenario) {
    scenario.validate();
    if (scenario.launchProblem != null) {
      throw StateError(scenario.launchProblem!);
    }
    _objects = [...scenario.objects];
    _resources = scenario.resources;
    _record('Занятие начато. Все величины — условные игровые единицы.');
    if (scenario.kind == ExerciseKind.escort) {
      final target = _objects.firstWhere((o) => o.kind == ObjectKind.objective);
      for (final object in _objects.where(
        (o) => o.kind == ObjectKind.transport && o.readiness > 0,
      )) {
        _destinations[object.id] = target.position;
        _record(
          '${object.name}: начальный маршрут сопровождения к цели «${target.name}».',
        );
      }
    }
    _snapshot();
  }
  ExerciseFrame get current => _frames.last;
  List<ExerciseFrame> get frames => List.unmodifiable(_frames);
  bool get completed => _tick >= scenario.duration;
  int get score {
    final goals = scenario.objects
        .where((o) => o.kind == ObjectKind.objective)
        .length;
    final objective = scenario.kind == ExerciseKind.defense
        ? 50 * _holdTicks / scenario.duration
        : 50 * _reached.length / goals;
    return (objective + _safety * .2 + _cohesion * .2 + _resources * .1)
        .round()
        .clamp(0, 100);
  }

  String get objectiveRule => switch (scenario.kind) {
    ExerciseKind.defense => '50 баллов × доля времени, когда заняты все цели.',
    ExerciseKind.escort => '50 баллов × доля целей, достигнутых транспортом.',
    _ =>
      '50 баллов × доля целей, достигнутых действующей группой или техникой.',
  };
  static double distance(MapPoint a, MapPoint b) =>
      math.sqrt(math.pow(a.x - b.x, 2) + math.pow(a.y - b.y, 2));
  void _record(String text) =>
      _log.add('T+${_tick.toString().padLeft(3, '0')}  $text');
  void _snapshot() => _frames.add(
    ExerciseFrame(
      tick: _tick,
      resources: _resources,
      safety: _safety,
      cohesion: _cohesion,
      holdTicks: _holdTicks,
      objects: _objects,
      destinations: _destinations,
      log: _log,
      reached: _reached,
      pending: _pending,
      condition: _condition,
    ),
  );
  void _command(Map<String, dynamic> command) {
    if (_commands.length >= 1000) {
      throw StateError('Лимит записи: 1000 действий');
    }
    _commands.add(Map.unmodifiable(command));
  }

  bool move(String id, MapPoint target) {
    if (completed || _pending != null || _resources < 1) return false;
    final found = _objects.where(
      (o) => o.id == id && o.mobile && o.readiness > 0,
    );
    if (found.isEmpty) return false;
    MapPoint.read(target.toJson());
    _command({'action': 'move', 'id': id, 'target': target.toJson()});
    _destinations[id] = target;
    _resources--;
    _record('${found.first.name}: новый прямой маршрут. Ресурсы −1.');
    _snapshot();
    return true;
  }

  bool advance() {
    if (completed || _pending != null) return false;
    _command({'action': 'tick'});
    _tick++;
    if (_tick > _slowUntil && _condition.startsWith('Сниженный темп')) {
      _condition = 'Темп восстановлен';
      _record('Ограничение темпа снято.');
    }
    for (final effect in _delayed.where((e) => e.due <= _tick).toList()) {
      _safety = (_safety + effect.safety).clamp(0, 100);
      _cohesion = (_cohesion + effect.cohesion).clamp(0, 100);
      _record('Отложенное последствие: ${effect.reason}');
      _delayed.remove(effect);
    }
    _objects = _objects.map((o) {
      final target = _destinations[o.id];
      if (target == null) return o;
      final d = distance(o.position, target);
      final speed =
          (o.kind == ObjectKind.transport
              ? .024
              : o.kind == ObjectKind.armor
              ? .014
              : .018) *
          o.readiness /
          100 *
          (_tick <= _slowUntil ? .45 : 1);
      if (d <= speed) {
        _destinations.remove(o.id);
        _record('${o.name}: маршрут завершён.');
        return o.copyWith(position: target);
      }
      return o.copyWith(
        position: MapPoint(
          o.position.x + (target.x - o.position.x) / d * speed,
          o.position.y + (target.y - o.position.y) / d * speed,
        ),
      );
    }).toList();
    final goals = _objects
        .where((o) => o.kind == ObjectKind.objective)
        .toList();
    var held = 0;
    for (final goal in goals) {
      final occupied = _objects.any(
        (o) =>
            o.mobile &&
            o.readiness > 0 &&
            (scenario.kind != ExerciseKind.escort ||
                o.kind == ObjectKind.transport) &&
            distance(o.position, goal.position) <= .055,
      );
      if (occupied) {
        held++;
        if (_reached.add(goal.id)) _record('Цель достигнута: ${goal.name}.');
      }
    }
    if (held == goals.length) _holdTicks++;
    _selectInject();
    if (completed) _record('Занятие завершено. Оценка: $score / 100.');
    _snapshot();
    return true;
  }

  void _selectInject() {
    final due =
        scenario.injects
            .where((e) => e.tick <= _tick && !_resolved.contains(e.id))
            .toList()
          ..sort(
            (a, b) => a.tick != b.tick
                ? a.tick.compareTo(b.tick)
                : a.id.compareTo(b.id),
          );
    _pending = due.isEmpty ? null : due.first;
    if (_pending != null) {
      _condition = injectLabels[_pending!.kind.index];
      _record('Вводная: $_condition. Время остановлено до решения.');
    }
  }

  bool decide(int index) {
    if (_pending == null || completed || index < 0 || index > 1) return false;
    final event = _pending!;
    final choice = choicesFor(event.kind)[index];
    if (_resources < choice.cost) return false;
    _command({'action': 'decide', 'choice': index});
    _resources -= choice.cost;
    _safety = (_safety + choice.safety).clamp(0, 100);
    _cohesion = (_cohesion + choice.cohesion).clamp(0, 100);
    _slowUntil = math.max(_slowUntil, _tick + choice.delay);
    _record('Решение: ${choice.title}. ${choice.consequence}');
    if (choice.laterSafety != 0 || choice.laterCohesion != 0) {
      _delayed.add((
        due: _tick + 3,
        safety: choice.laterSafety,
        cohesion: choice.laterCohesion,
        reason:
            '${choice.title}: безопасность ${choice.laterSafety}, согласованность ${choice.laterCohesion}.',
      ));
    }
    _resolved.add(event.id);
    _condition = choice.delay > 0
        ? 'Сниженный темп до T+$_slowUntil'
        : 'Решение принято';
    _pending = null;
    _selectInject();
    _snapshot();
    return true;
  }

  Map<String, dynamic> toJson() => {
    'version': 1,
    'scenario': scenario.toJson(),
    'commands': _commands
        .map(
          (c) => <String, dynamic>{
            ...c,
            if (c['target'] != null)
              'target': List<num>.from(c['target'] as List),
          },
        )
        .toList(),
  };
  factory ExerciseEngine.read(Map<String, dynamic> json) {
    if (json['version'] != 1 ||
        json['commands'] is! List ||
        (json['commands'] as List).length > 1000) {
      throw const FormatException('Несовместимая запись прохождения');
    }
    final engine = ExerciseEngine(
      StudioScenario.read(Map<String, dynamic>.from(json['scenario'])),
    );
    for (final raw in json['commands'] as List) {
      final c = Map<String, dynamic>.from(raw);
      final accepted = switch (c['action']) {
        'tick' => engine.advance(),
        'move' => engine.move(c['id'] as String, MapPoint.read(c['target'])),
        'decide' => engine.decide(c['choice'] as int),
        _ => false,
      };
      if (!accepted) {
        throw const FormatException('Недопустимая команда в записи');
      }
    }
    return engine;
  }
  String get report => [
    'TACTIX / ${scenario.name}',
    completed
        ? 'Итог занятия: $score / 100'
        : 'Промежуточная оценка: $score / 100',
    'Время: $_tick / ${scenario.duration}. Цели: ${_reached.length}.',
    objectiveRule,
    'Остальные 50 баллов: безопасность ×0,2 + согласованность ×0,2 + ресурсы ×0,1.',
    'Безопасность: $_safety; согласованность: $_cohesion; ресурсы: $_resources.',
    'Вымышленная местность. Условные игровые правила. AI не определяет исход.',
    '',
    ..._log,
  ].join('\n');
}
