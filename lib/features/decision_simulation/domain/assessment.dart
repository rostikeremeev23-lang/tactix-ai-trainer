import 'models.dart';

class Assessment {
  final Map<String, int> components;
  final int total;
  final List<String> findings;
  Assessment(this.components, this.total, this.findings);
  factory Assessment.fromRun(RunState run) {
    final components = <String, int>{
      'Безопасность': run.values['safety']!,
      'Координация': run.values['coordination']!,
      'Доверие': run.values['trust']!,
      'Работа со сведениями': run.values['evidence']!,
      'Устойчивость команды': 100 - run.values['fatigue']!,
    };
    final total =
        (components['Безопасность']! * .35 +
                components['Координация']! * .25 +
                components['Доверие']! * .15 +
                components['Работа со сведениями']! * .15 +
                components['Устойчивость команды']! * .10)
            .round();
    final findings = <String>[
      'Рубрика DS-1: безопасность 35%, координация 25%, доверие 15%, '
          'работа со сведениями 15%, устойчивость команды 10%. Это отдельная '
          'оценка эпизода; она не заменяет баллы старых тренировок.',
      if (run.flags.contains('verified'))
        'Вы проверили противоречивое донесение. Основание: решение в сцене 3.'
      else
        'Независимая проверка донесения не проводилась. Доступные сведения '
            'оставались неполными; это не означает, что выбранный путь был невозможен.',
      if (run.flags.contains('delegated')) 'Делегирование позволило сохранить резерв внимания. См. журнал сцены 10.',
      if (run.values['fatigue']! > 55)
        'Команда передана следующей смене с высокой нагрузкой.',
      if (run.pending.isNotEmpty)
        'Осталось обязательств за горизонтом эпизода: ${run.pending.length}.',
      'Погодное событие оценено отдельно в журнале. Итоговые показатели '
          'отражают состояние мира, а не моральную оценку командира.',
    ];
    return Assessment(
      Map.unmodifiable(components),
      total,
      List.unmodifiable(findings),
    );
  }
}
