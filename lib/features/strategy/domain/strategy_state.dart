const strategySectorNames = [
  'Северный сектор',
  'Центральный сектор',
  'Восточный сектор',
  'Точка A',
  'Точка B',
  'Точка C',
];

class StrategyUnit {
  final String id, name, type;
  final int sector, strength;
  const StrategyUnit({
    required this.id,
    required this.name,
    required this.type,
    required this.sector,
    required this.strength,
  });

  StrategyUnit copyWith({int? sector, int? strength}) => StrategyUnit(
    id: id,
    name: name,
    type: type,
    sector: sector ?? this.sector,
    strength: strength ?? this.strength,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type,
    'sector': sector,
    'strength': strength,
  };

  factory StrategyUnit.fromJson(Map<String, dynamic> json) {
    final unit = StrategyUnit(
      id: json['id'] as String,
      name: json['name'] as String,
      type: json['type'] as String,
      sector: json['sector'] as int,
      strength: json['strength'] as int,
    );
    if (unit.id.isEmpty ||
        unit.name.isEmpty ||
        unit.sector < 0 ||
        unit.sector >= strategySectorNames.length ||
        unit.strength < 0 ||
        unit.strength > 100) {
      throw const FormatException('Некорректное подразделение');
    }
    return unit;
  }
}

class StrategyState {
  final int turn, control, resources, stability, intel, time;
  final bool completed;
  final List<StrategyUnit> units;
  final List<String> log;
  StrategyState({
    this.turn = 1,
    this.control = 100,
    this.resources = 100,
    this.stability = 100,
    this.intel = 65,
    this.time = 100,
    this.completed = false,
    required List<StrategyUnit> units,
    List<String> log = const ['Учебная обстановка готова.'],
  }) : units = List.unmodifiable(units),
       log = List.unmodifiable(log);

  factory StrategyState.initial() => StrategyState(
    units: const [
      StrategyUnit(
        id: 'alpha',
        name: 'Группа Альфа',
        type: 'Пехота',
        sector: 0,
        strength: 88,
      ),
      StrategyUnit(
        id: 'bravo',
        name: 'Группа Браво',
        type: 'Пехота',
        sector: 1,
        strength: 91,
      ),
      StrategyUnit(
        id: 'recon',
        name: 'Разведка',
        type: 'Разведка',
        sector: 2,
        strength: 84,
      ),
      StrategyUnit(
        id: 'engineer',
        name: 'Инженеры',
        type: 'Инженерная',
        sector: 4,
        strength: 95,
      ),
      StrategyUnit(
        id: 'reserve',
        name: 'Резерв',
        type: 'Резерв',
        sector: 5,
        strength: 100,
      ),
      StrategyUnit(
        id: 'armor',
        name: 'Бронемашина',
        type: 'Техника',
        sector: 5,
        strength: 100,
      ),
      StrategyUnit(
        id: 'transport',
        name: 'Транспорт',
        type: 'Техника',
        sector: 4,
        strength: 100,
      ),
    ],
  );

  StrategyState copyWith({
    int? turn,
    int? control,
    int? resources,
    int? stability,
    int? intel,
    int? time,
    bool? completed,
    List<StrategyUnit>? units,
    List<String>? log,
  }) => StrategyState(
    turn: turn ?? this.turn,
    control: control ?? this.control,
    resources: resources ?? this.resources,
    stability: stability ?? this.stability,
    intel: intel ?? this.intel,
    time: time ?? this.time,
    completed: completed ?? this.completed,
    units: units ?? this.units,
    log: log ?? this.log,
  );

  Map<String, dynamic> toJson() => {
    'turn': turn,
    'control': control,
    'resources': resources,
    'stability': stability,
    'intel': intel,
    'time': time,
    'completed': completed,
    'units': units.map((u) => u.toJson()).toList(),
    'log': log,
  };

  factory StrategyState.fromJson(Map<String, dynamic> json) {
    final state = StrategyState(
      turn: json['turn'] as int,
      control: json['control'] as int,
      resources: json['resources'] as int,
      stability: json['stability'] as int,
      intel: json['intel'] as int,
      time: json['time'] as int,
      completed: json['completed'] as bool,
      units: (json['units'] as List)
          .map(
            (u) => StrategyUnit.fromJson(Map<String, dynamic>.from(u as Map)),
          )
          .toList(),
      log: List<String>.from(json['log'] as List),
    );
    final expectedIds = StrategyState.initial().units.map((u) => u.id).toSet();
    if (state.turn < 1 ||
        state.turn > 8 ||
        (state.completed && state.turn != 8) ||
        [
          state.control,
          state.resources,
          state.stability,
          state.intel,
          state.time,
        ].any((v) => v < 0 || v > 100) ||
        state.units.length != expectedIds.length ||
        !state.units.map((u) => u.id).toSet().containsAll(expectedIds) ||
        state.log.isEmpty) {
      throw const FormatException('Некорректное состояние Strategy');
    }
    return state;
  }
}
