import 'models.dart';
import 'decision_engine.dart';

List<String> validateScenario(DecisionScenario scenario) {
  final errors = <String>[];
  final ids = scenario.scenes.map((s) => s.id).toSet();
  final docs = scenario.documents.map((d) => d.id).toSet();
  if (ids.length != scenario.scenes.length || ids.isEmpty) {
    errors.add('Пустой граф или повторяющиеся сцены');
  }
  if (docs.length != scenario.documents.length) errors.add('Повтор документов');
  final endings = scenario.endings.map((e) => e.id).toSet();
  if (endings.length != scenario.endings.length ||
      !endings.contains('crisis')) {
    errors.add('Некорректные финалы');
  }
  void condition(Condition c) {
    if (c.variable != null &&
        !DecisionEngine.initialValues.containsKey(c.variable)) {
      errors.add('Неизвестная переменная условия: ${c.variable}');
    }
    for (final child in [...c.all, ...c.any]) {
      condition(child);
    }
  }

  void effect(Effect e) {
    for (final key in e.delta.keys) {
      if (!DecisionEngine.initialValues.containsKey(key)) {
        errors.add('Переменная: $key');
      }
    }
  }

  if (scenario.chanceEvents.map((e) => e.id).toSet().length !=
      scenario.chanceEvents.length) {
    errors.add('Повтор случайного события');
  }
  for (final event in scenario.chanceEvents) {
    condition(event.when);
    effect(event.effect);
    if (event.percent < 0 || event.percent > 100 || event.afterStep < 1) {
      errors.add('???Повтор случайного события: ${event.id}');
    }
  }
  if (!scenario.endings.any(
    (e) =>
        e.when.variable == null &&
        e.when.flag == null &&
        e.when.all.isEmpty &&
        e.when.any.isEmpty,
  )) {
    errors.add('Нет резервного финала');
  }
  for (final ending in scenario.endings) {
    condition(ending.when);
  }
  for (final scene in scenario.scenes) {
    if (scene.actions.map((a) => a.id).toSet().length != scene.actions.length) {
      errors.add('Повтор действия: ${scene.id}');
    }
    if (!scene.actions.any(
      (a) =>
          !a.inquiry &&
          a.supplies == 0 &&
          a.when.variable == null &&
          a.when.flag == null &&
          a.when.all.isEmpty &&
          a.when.any.isEmpty,
    )) {
      errors.add('Нет гарантированного выхода: ${scene.id}');
    }
    for (final variant in scene.variants) {
      condition(variant.when);
    }
    for (final doc in scene.documents) {
      if (!docs.contains(doc)) errors.add('Документ: $doc');
    }
    for (final action in scene.actions) {
      condition(action.when);
      effect(action.effect);
      if (action.minutes <= 0 || action.supplies < 0) {
        errors.add('Время должно быть положительным, резерв — неотрицательным');
      }
      if (action.document != null && !docs.contains(action.document)) {
        errors.add('Документ: ${action.document}');
      }
      if (!action.inquiry &&
          (action.transitions.isEmpty ||
              !action.transitions.any(
                (t) =>
                    t.when.variable == null &&
                    t.when.flag == null &&
                    t.when.all.isEmpty &&
                    t.when.any.isEmpty,
              ))) {
        errors.add('Нет резервного перехода: ${scene.id}/${action.id}');
      }
      for (final t in action.transitions) {
        condition(t.when);
        if (t.target != '@end' && !ids.contains(t.target)) {
          errors.add('Переход: ${t.target}');
        }
      }
      for (final d in action.delayed) {
        if (d.afterSteps < 1) errors.add('Задержка: ${d.id}');
        effect(d.effect);
        condition(d.condition);
      }
    }
  }
  final reachable = <String>{};
  void visit(String id) {
    if (!ids.contains(id) || !reachable.add(id)) return;
    for (final action in scenario.scene(id).actions) {
      for (final t in action.transitions) {
        visit(t.target);
      }
    }
  }

  if (scenario.scenes.isNotEmpty) visit(scenario.scenes.first.id);
  for (final id in ids.difference(reachable)) {
    errors.add('Недостижимая сцена: $id');
  }
  return errors;
}
