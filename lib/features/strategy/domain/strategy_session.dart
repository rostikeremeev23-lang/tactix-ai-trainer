import 'strategy_state.dart';

/// Immutable snapshots keep replay independent of the live exercise.
class StrategySession {
  final List<StrategyState> _history;
  bool _started;
  StrategySession() : _history = [StrategyState.initial()], _started = false;
  StrategySession._(this._history, this._started);
  List<StrategyState> get history => List.unmodifiable(_history);
  StrategyState get current => _history.last;
  bool get started => _started;

  void configure({String? unitId, int? sector, int? strength, int? resources}) {
    if (started) throw StateError('Учения уже начаты');
    final next = current.copyWith(
      resources: resources,
      units: current.units
          .map(
            (u) => u.id == unitId
                ? u.copyWith(sector: sector, strength: strength)
                : u,
          )
          .toList(),
    );
    StrategyState.fromJson(next.toJson());
    _history[0] = next;
  }

  void start() => _started = true;

  bool move(String id, int sector) {
    if (!started || current.completed || sector < 0 || sector >= 6) {
      return false;
    }
    final index = current.units.indexWhere((u) => u.id == id);
    if (index < 0) return false;
    final unit = current.units[index];
    final cost = unit.type == 'Техника' ? 4 : 2;
    if (unit.sector == sector || current.resources < cost) return false;
    _history.add(
      current.copyWith(
        resources: current.resources - cost,
        units: current.units
            .map((u) => u.id == id ? u.copyWith(sector: sector) : u)
            .toList(),
        log: [
          ...current.log,
          'Ход ${current.turn} • ${unit.name} → ${strategySectorNames[sector]} (−$cost).',
        ],
      ),
    );
    return true;
  }

  void nextTurn() {
    if (!started || current.completed) return;
    final s = current;
    final done = s.turn == 8;
    final held = {
      3,
      4,
      5,
    }.where((sector) => s.units.any((u) => u.sector == sector)).length;
    _history.add(
      s.copyWith(
        turn: done ? 8 : s.turn + 1,
        completed: done,
        time: (s.time - 12).clamp(0, 100),
        control: (s.control - 3 + held).clamp(0, 100),
        stability: (s.stability - (3 - held)).clamp(0, 100),
        intel:
            (s.intel +
                    (s.units.any((u) => u.id == 'recon' && u.sector >= 3)
                        ? 5
                        : 1))
                .clamp(0, 100),
        log: [
          ...s.log,
          'Ход ${s.turn} завершён • занято точек: $held / 3.',
          if (done) 'Учения завершены. Итог рассчитан по учебным правилам.',
        ],
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'version': 1,
    'started': started,
    'history': _history.map((s) => s.toJson()).toList(),
  };

  factory StrategySession.fromJson(Map<String, dynamic> json) {
    if (json['version'] != 1 || json['started'] is! bool) {
      throw const FormatException('Несовместимое сохранение Strategy');
    }
    final history = (json['history'] as List)
        .map((s) => StrategyState.fromJson(Map<String, dynamic>.from(s as Map)))
        .toList();
    if (history.isEmpty ||
        history.length > 500 ||
        history.first.turn != 1 ||
        history.first.completed ||
        (!(json['started'] as bool) && history.length != 1)) {
      throw const FormatException('Некорректная история Strategy');
    }
    for (var i = 1; i < history.length; i++) {
      final before = history[i - 1];
      final after = history[i];
      if (before.completed ||
          after.turn < before.turn ||
          after.turn > before.turn + 1 ||
          after.log.length <= before.log.length ||
          after.resources > before.resources ||
          after.time > before.time) {
        throw const FormatException('Нарушен порядок истории Strategy');
      }
    }
    return StrategySession._(history, json['started'] as bool);
  }
}
