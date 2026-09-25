import 'dart:convert';

import 'models.dart';

class DecisionEngine {
  final DecisionScenario scenario;
  const DecisionEngine(this.scenario);
  static const initialValues = {
    'time': 65,
    'supplies': 8,
    'safety': 45,
    'coordination': 45,
    'trust': 50,
    'evidence': 20,
    'fatigue': 20,
  };
  RunState start({required String runId, int seed = 17}) => RunState(
    runId: runId,
    sceneId: scenario.scenes.first.id,
    seed: seed,
    randomState: seed & 0x7fffffff,
    values: initialValues,
    knownDocuments: scenario.scenes.first.documents.toSet(),
  );

  bool available(RunState state, StoryAction action) =>
      !state.completed &&
      scenario.scene(state.sceneId).actions.any((a) => identical(a, action)) &&
      !state.usedActions.contains('${state.sceneId}/${action.id}') &&
      action.when.matches(state) &&
      state.values['supplies']! >= action.supplies &&
      (!action.inquiry || state.minutes > action.minutes);

  RunState apply(RunState before, String actionId, {String note = ''}) {
    if (before.completed) throw StateError('Эпизод уже завершён');
    final scene = scenario.scene(before.sceneId);
    final matches = scene.actions.where((a) => a.id == actionId);
    if (matches.isEmpty) throw ArgumentError('Неизвестное действие');
    final action = matches.single;
    if (!available(before, action)) throw StateError('Действие недоступно');
    if (note.length > 1200) {
      throw ArgumentError('Обоснование длиннее 1200 знаков');
    }
    final values = Map<String, int>.from(before.values);
    final flags = Set<String>.from(before.flags);
    final used = Set<String>.from(before.usedActions);
    final docs = Set<String>.from(before.knownDocuments);
    final pending = List<PendingConsequence>.from(before.pending);
    final events = List<RunEvent>.from(before.events);
    final step = before.step + (action.inquiry ? 0 : 1);
    var random = before.randomState;
    final cause = '${scene.id}/${action.id}';
    used.add(cause);
    void change(Effect effect, String kind, String text, String origin) {
      final delta = <String, int>{};
      for (final entry in effect.delta.entries) {
        final old = values[entry.key];
        if (old == null) {
          throw StateError('Неизвестная переменная ${entry.key}');
        }
        final cap = entry.key == 'time'
            ? 65
            : entry.key == 'supplies'
            ? 12
            : 100;
        values[entry.key] = (old + entry.value).clamp(0, cap);
        delta[entry.key] = values[entry.key]! - old;
      }
      flags
        ..removeAll(effect.removeFlags)
        ..addAll(effect.flags);
      events.add(
        RunEvent(
          sequence: events.length + 1,
          step: step,
          scene: scene.id,
          kind: kind,
          text: text,
          cause: origin,
          delta: delta,
        ),
      );
    }

    change(
      Effect(delta: {'time': -action.minutes, 'supplies': -action.supplies}),
      'cost',
      'Затрачено: ${action.minutes} мин., резерв: ${action.supplies}.',
      cause,
    );
    change(
      action.effect,
      action.inquiry ? 'inquiry' : 'decision',
      action.response,
      cause,
    );
    if (note.trim().isNotEmpty) {
      events.add(
        RunEvent(
          sequence: events.length + 1,
          step: step,
          scene: scene.id,
          kind: 'rationale',
          text: note.trim(),
          cause: cause,
        ),
      );
    }
    if (action.document != null) docs.add(action.document!);
    for (final delayed in action.delayed) {
      pending.add(
        PendingConsequence(
          id: '$cause/${delayed.id}',
          cause: cause,
          text: delayed.text,
          due: step + delayed.afterSteps,
          effect: delayed.effect,
          condition: delayed.condition,
        ),
      );
    }
    RunState snapshot({String? sceneId, String? ending}) => RunState(
      runId: before.runId,
      sceneId: sceneId ?? before.sceneId,
      seed: before.seed,
      randomState: random,
      step: step,
      revision: before.revision + 1,
      values: values,
      flags: flags,
      usedActions: used,
      knownDocuments: docs,
      pending: pending,
      events: events,
      commands: [
        ...before.commands,
        RunCommand(scene.id, action.id, note.trim()),
      ],
      ending: ending,
    );
    pending.sort((a, b) {
      final order = a.due.compareTo(b.due);
      return order != 0 ? order : a.id.compareTo(b.id);
    });
    for (final event in List<PendingConsequence>.from(pending)) {
      if (event.due > step) continue;
      if (event.condition.matches(snapshot())) {
        change(event.effect, 'consequence', event.text, event.cause);
      } else {
        change(
          const Effect(),
          'averted',
          'Событие не произошло: ${event.text}',
          event.cause,
        );
      }
      pending.remove(event);
    }
    // Authored probabilities; generator state and results survive save/resume.
    for (final event in scenario.chanceEvents) {
      final marker = 'chance:${event.id}';
      if (step < event.afterStep ||
          flags.contains(marker) ||
          !event.when.matches(snapshot())) {
        continue;
      }
      random = (1103515245 * random + 12345) & 0x7fffffff;
      final occurred = random % 100 < event.percent;
      flags.add(marker);
      change(
        occurred ? event.effect : const Effect(),
        'chance',
        occurred ? event.occurredText : event.absentText,
        event.id,
      );
    }
    String? ending;
    var target = scene.id;
    if (values['time']! <= 0) {
      ending = 'crisis';
    } else if (!action.inquiry) {
      final current = snapshot();
      final route = action.transitions.where((t) => t.when.matches(current));
      if (route.isEmpty) throw StateError('Нет доступного перехода: $cause');
      target = route.first.target;
      if (target == '@end') {
        ending = scenario.endings.firstWhere((e) => e.when.matches(current)).id;
        target = scene.id;
      } else {
        docs.addAll(scenario.scene(target).documents);
      }
    }
    if (ending != null) {
      change(
        const Effect(),
        'ending',
        scenario.endings.firstWhere((e) => e.id == ending).title,
        cause,
      );
    }
    return snapshot(sceneId: target, ending: ending);
  }

  RunState restore(Map<String, dynamic> envelope) {
    if (envelope['schema'] != 1 ||
        envelope['scenario'] != scenario.id ||
        envelope['version'] != scenario.version) {
      throw const FormatException('Несовместимая версия сохранения');
    }
    final saved = Map<String, dynamic>.from(envelope['state'] as Map);
    final commands = saved['commands'] as List;
    if (commands.length > 100) {
      throw const FormatException('Слишком длинная история');
    }
    var state = start(
      runId: saved['runId'] as String,
      seed: saved['seed'] as int,
    );
    for (final raw in commands) {
      final command = RunCommand.fromJson(
        Map<String, dynamic>.from(raw as Map),
      );
      if (command.scene != state.sceneId) {
        throw const FormatException('Нарушен порядок сцен');
      }
      state = apply(state, command.action, note: command.note);
    }
    if (jsonEncode(state.toJson()) != jsonEncode(saved)) {
      throw const FormatException('Состояние не соответствует журналу');
    }
    return state;
  }

  Map<String, Object?> export(RunState state) => {
    'schema': 1,
    'scenario': scenario.id,
    'version': scenario.version,
    'state': state.toJson(),
  };
}
