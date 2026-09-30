// Fictional training scenario. No real geographic or weapons data.
enum ExerciseKind { attack, defense, escort, response }

enum ObjectKind {
  group,
  transport,
  armor,
  objective,
  facility,
  recon,
  aerial,
  emergency,
  reserve,
  logistics,
}

enum InjectKind { road, communications, weather }

const exerciseLabels = [
  'Атака · занятие зон',
  'Оборона · удержание зон',
  'Сопровождение',
  'Реагирование',
];
const objectLabels = [
  'Учебная группа',
  'Транспорт',
  'Бронетехника',
  'Цель занятия',
  'Пункт обеспечения',
  'Жетон наблюдения',
  'Воздушный жетон',
  'Экстренная поддержка',
  'Резерв',
  'Логистика',
];
const injectLabels = ['Перекрытие дороги', 'Потеря связи', 'Ухудшение погоды'];

class MapPoint {
  final double x, y;
  const MapPoint(this.x, this.y);
  List<double> toJson() => [x, y];
  factory MapPoint.read(dynamic data) {
    final p = MapPoint(
      (data[0] as num).toDouble(),
      (data[1] as num).toDouble(),
    );
    if (!p.x.isFinite ||
        !p.y.isFinite ||
        p.x < 0 ||
        p.x > 1 ||
        p.y < 0 ||
        p.y > 1) {
      throw const FormatException('Координаты вне учебной карты');
    }
    return p;
  }
}

class MapObject {
  final String id, name;
  final ObjectKind kind;
  final MapPoint position;
  final int readiness;
  final int rotation;
  final String group;
  bool get mobile =>
      kind != ObjectKind.objective && kind != ObjectKind.facility;
  const MapObject({
    required this.id,
    required this.name,
    required this.kind,
    required this.position,
    this.readiness = 100,
    this.rotation = 0,
    this.group = '',
  });
  MapObject copyWith({
    String? name,
    MapPoint? position,
    int? readiness,
    int? rotation,
    String? group,
  }) => MapObject(
    id: id,
    name: name ?? this.name,
    kind: kind,
    position: position ?? this.position,
    readiness: readiness ?? this.readiness,
    rotation: rotation ?? this.rotation,
    group: group ?? this.group,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'kind': kind.index,
    'position': position.toJson(),
    'readiness': readiness,
    'rotation': rotation,
    'group': group,
  };
  factory MapObject.read(Map<String, dynamic> j) => MapObject(
    id: j['id'] as String,
    name: j['name'] as String,
    kind: ObjectKind.values[j['kind'] as int],
    position: MapPoint.read(j['position']),
    readiness: j['readiness'] as int,
    rotation: j['rotation'] as int? ?? 0,
    group: j['group'] as String? ?? '',
  );
}

class ScenarioInject {
  final String id;
  final InjectKind kind;
  final int tick;
  const ScenarioInject(this.id, this.kind, this.tick);
  Map<String, dynamic> toJson() => {'id': id, 'kind': kind.index, 'tick': tick};
  factory ScenarioInject.read(Map<String, dynamic> j) => ScenarioInject(
    j['id'] as String,
    InjectKind.values[j['kind'] as int],
    j['tick'] as int,
  );
}

class StudioScenario {
  final String name, briefing;
  final ExerciseKind kind;
  final int duration, resources;
  final bool cityMap;
  final int seed;
  final List<MapObject> objects;
  final List<ScenarioInject> injects;
  StudioScenario({
    required this.name,
    required this.briefing,
    required this.kind,
    this.duration = 60,
    this.resources = 100,
    this.cityMap = false,
    this.seed = 0,
    required List<MapObject> objects,
    required List<ScenarioInject> injects,
  }) : objects = List.unmodifiable(objects),
       injects = List.unmodifiable(injects);
  factory StudioScenario.demo() => StudioScenario(
    name: 'Долина Северная · учебный маршрут',
    kind: ExerciseKind.escort,
    briefing:
        'Доставьте учебный транспорт из складского квартала к пункту за рекой. '
        'При запуске транспорт движется к первой цели. Для изменения пути выберите транспорт, '
        'нажмите «Задать маршрут» и укажите точку на карте. '
        'Реагируйте на три вводные. Сохраните ресурсы и согласованность действий. '
        'Карта вымышлена; движение прямолинейное, дороги не рассчитываются.',
    objects: const [
      MapObject(
        id: 'obj-1',
        name: 'Группа Север',
        kind: ObjectKind.group,
        position: MapPoint(.40, .54),
      ),
      MapObject(
        id: 'obj-2',
        name: 'Транспорт 01',
        kind: ObjectKind.transport,
        position: MapPoint(.22, .72),
      ),
      MapObject(
        id: 'obj-3',
        name: 'Бронетехника 01',
        kind: ObjectKind.armor,
        position: MapPoint(.31, .63),
      ),
      MapObject(
        id: 'obj-4',
        name: 'Пункт прибытия',
        kind: ObjectKind.objective,
        position: MapPoint(.84, .43),
      ),
      MapObject(
        id: 'obj-5',
        name: 'Учебный склад',
        kind: ObjectKind.facility,
        position: MapPoint(.18, .80),
      ),
    ],
    injects: const [
      ScenarioInject('evt-1', InjectKind.road, 8),
      ScenarioInject('evt-2', InjectKind.communications, 18),
      ScenarioInject('evt-3', InjectKind.weather, 30),
    ],
  );
  factory StudioScenario.blank() => StudioScenario(
    name: 'Новое занятие',
    briefing: 'Опишите исходную обстановку и учебные цели.',
    kind: ExerciseKind.response,
    objects: const [],
    injects: StudioScenario.demo().injects,
  );
  StudioScenario copyWith({
    String? name,
    String? briefing,
    ExerciseKind? kind,
    int? duration,
    int? resources,
    bool? cityMap,
    int? seed,
    List<MapObject>? objects,
    List<ScenarioInject>? injects,
  }) => StudioScenario(
    name: name ?? this.name,
    briefing: briefing ?? this.briefing,
    kind: kind ?? this.kind,
    duration: duration ?? this.duration,
    resources: resources ?? this.resources,
    cityMap: cityMap ?? this.cityMap,
    seed: seed ?? this.seed,
    objects: objects ?? this.objects,
    injects: injects ?? this.injects,
  );
  String? get launchProblem {
    if (!objects.any((o) => o.mobile && o.readiness > 0)) {
      return 'Добавьте действующую учебную группу или технику.';
    }
    if (!objects.any((o) => o.kind == ObjectKind.objective)) {
      return 'Разместите хотя бы одну цель занятия.';
    }
    if (kind == ExerciseKind.escort &&
        !objects.any(
          (o) => o.kind == ObjectKind.transport && o.readiness > 0,
        )) {
      return 'Для сопровождения нужен транспорт с готовностью выше нуля.';
    }
    return null;
  }

  void validate() {
    if (name.trim().isEmpty ||
        name.length > 100 ||
        briefing.length > 2000 ||
        seed < 0 ||
        seed > 999999 ||
        duration < 40 ||
        duration > 120 ||
        resources < 10 ||
        resources > 100 ||
        objects.length > 30 ||
        injects.length > 8 ||
        objects.map((o) => o.id).toSet().length != objects.length ||
        injects.map((e) => e.id).toSet().length != injects.length) {
      throw const FormatException('Некорректные настройки сценария');
    }
    for (final o in objects) {
      MapPoint.read(o.position.toJson());
      if (o.id.isEmpty ||
          o.name.trim().isEmpty ||
          o.name.length > 60 ||
          o.rotation < 0 ||
          o.rotation >= 360 ||
          o.group.length > 30 ||
          o.readiness < 0 ||
          o.readiness > 100) {
        throw const FormatException('Некорректный объект');
      }
    }
    for (final e in injects) {
      if (e.id.isEmpty || e.tick < 1 || e.tick >= duration - 3) {
        throw const FormatException('Вводная должна предшествовать завершению');
      }
    }
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'briefing': briefing,
    'kind': kind.index,
    'duration': duration,
    'resources': resources,
    'cityMap': cityMap,
    'seed': seed,
    'objects': objects.map((o) => o.toJson()).toList(),
    'injects': injects.map((e) => e.toJson()).toList(),
  };
  factory StudioScenario.read(Map<String, dynamic> j) {
    final s = StudioScenario(
      name: j['name'] as String,
      briefing: j['briefing'] as String,
      kind: ExerciseKind.values[j['kind'] as int],
      duration: j['duration'] as int,
      resources: j['resources'] as int,
      cityMap: j['cityMap'] as bool? ?? false,
      seed: j['seed'] as int? ?? 0,
      objects: (j['objects'] as List)
          .map((o) => MapObject.read(Map<String, dynamic>.from(o)))
          .toList(),
      injects: (j['injects'] as List)
          .map((e) => ScenarioInject.read(Map<String, dynamic>.from(e)))
          .toList(),
    );
    s.validate();
    return s;
  }
}
