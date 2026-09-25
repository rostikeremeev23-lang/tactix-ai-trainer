import 'strategy_state.dart';

class StrategyReport {
  final StrategyState state;
  StrategyReport(this.state);
  int get held =>
      {3, 4, 5}.where((s) => state.units.any((u) => u.sector == s)).length;
  int get objective => held * 10;
  int get civil => (state.stability / 4).round().clamp(0, 25);
  int get force =>
      (state.units.fold<int>(0, (sum, u) => sum + u.strength) /
              state.units.length *
              .15)
          .round()
          .clamp(0, 15);
  int get coordination => (state.control * .15).round().clamp(0, 15);
  int get resource => (state.resources * .15).round().clamp(0, 15);
  int get total => objective + civil + force + coordination + resource;
  String get text => [
    'TACTIX Strategy — учебный отчёт',
    state.completed ? 'Учения завершены' : 'Промежуточный результат',
    'Ход: ${state.turn} / 8. Оценка: $total / 100.',
    'Выполнение задач: $objective / 30; точки: $held / 3.',
    'Безопасность гражданских (условный показатель): $civil / 25.',
    'Сохранение подразделений: $force / 15.',
    'Координация: $coordination / 15. Ресурсы: $resource / 15.',
    'Остаток ресурсов: ${state.resources}%.',
    'Оценка рассчитана по правилам учебной модели, без AI-анализа.',
    'Подложка стилизованная; объекты и маршруты вымышлены.',
    '',
    'Журнал:',
    ...state.log,
  ].join('\n');
}
