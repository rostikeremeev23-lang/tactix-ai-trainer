import 'scenario.dart';

/// Authored fictional geometry. No geographic, weapon or infrastructure data.
class CityScenarios {
  static const titles = ['Янтарный берег', 'Город на паузе', 'Три горизонта'];
  static const subtitles = [
    'Сохранить устойчивость района',
    'Восстановить городские сервисы',
    'Согласовать действия трёх секторов',
  ];
  static const briefings = [
    'В вымышленном районе Янтарный берег возникли абстрактные игровые угрозы: '
        'сбои маршрутов, связи и видимости. Разместите жетоны у двух целей и '
        'сохраняйте присутствие, выбирая между резервом ресурсов и устойчивостью. '
        'Успех: обе цели заняты не менее половины тактов, итог не ниже 75.',
    'После вымышленного городского сбоя узлы «Люмен» и «Сад» ждут поддержки. '
        'Распределите мобильные команды между двумя целями; во время игры назначайте им прямые маршруты. '
        'Успех: посетить обе цели и набрать 75 баллов. Переназначение стоит одну единицу ресурса; готовность задаёт игровой темп.',
    'Секторы «Арка», «Сад» и «Маяк» одновременно запрашивают помощь. '
        'Разделите команды между тремя целями и отреагируйте на пять вводных. '
        'Успех: посетить все три цели и набрать 75 баллов. Сохранение ресурсов может снизить согласованность; решения имеют отложенные последствия.',
  ];

  static StudioScenario create(int index, {int difficulty = 1, int seed = 42}) {
    if (index < 0 ||
        index > 2 ||
        difficulty < 0 ||
        difficulty > 2 ||
        seed < 0 ||
        seed > 999999) {
      throw ArgumentError('Некорректные параметры городской игры');
    }
    // Stable integer arithmetic, independent of runtime Random implementation.
    var state = seed;
    int jitter() {
      state = (state * 1664525 + 1013904223) & 0xffffffff;
      return state % 5;
    }

    const starts = [MapPoint(.25, .69), MapPoint(.48, .72), MapPoint(.73, .65)];
    const goals = [MapPoint(.25, .37), MapPoint(.58, .42), MapPoint(.79, .29)];
    final count = index == 2 ? 3 : 2;
    return StudioScenario(
      name: titles[index],
      briefing: briefings[index],
      cityMap: true,
      seed: seed,
      kind: index == 0 ? ExerciseKind.defense : ExerciseKind.response,
      duration: [80, 60, 40][difficulty],
      resources: [100, 75, 45][difficulty],
      objects: [
        for (var i = 0; i < count; i++)
          MapObject(
            id: 'team-$i',
            name: ['Команда Арка', 'Команда Сад', 'Команда Маяк'][i],
            kind: [
              ObjectKind.group,
              ObjectKind.emergency,
              ObjectKind.logistics,
            ][i],
            position: starts[i],
          ),
        for (var i = 0; i < count; i++)
          MapObject(
            id: 'goal-$i',
            name: ['Узел Люмен', 'Сервис Сад', 'Центр Маяк'][i],
            kind: ObjectKind.objective,
            position: goals[i],
          ),
        const MapObject(
          id: 'reserve',
          name: 'Резерв Берег',
          kind: ObjectKind.reserve,
          position: MapPoint(.40, .82),
        ),
      ],
      injects: [
        ScenarioInject('city-1', InjectKind.road, 6 + jitter()),
        ScenarioInject('city-2', InjectKind.communications, 14 + jitter()),
        ScenarioInject('city-3', InjectKind.weather, 23 + jitter()),
        if (index == 2) ...[
          ScenarioInject('city-4', InjectKind.communications, 29 + jitter()),
          ScenarioInject('city-5', InjectKind.road, 34 + jitter() % 2),
        ],
      ],
    );
  }
}
