import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ai_trainer_mobile/features/decision_simulation/data/storm_scenario.dart';
import 'package:ai_trainer_mobile/features/decision_simulation/data/run_repository.dart';
import 'package:ai_trainer_mobile/features/decision_simulation/domain/decision_engine.dart';
import 'package:ai_trainer_mobile/features/decision_simulation/domain/models.dart';
import 'package:ai_trainer_mobile/features/decision_simulation/application/simulation_controller.dart';

class ControlledRepository extends RunRepository {
  final gate = Completer<void>();
  ControlledRepository(super.userId, super.engine);
  @override
  Future<void> save(RunState state) => gate.future;
}

void main() {
  test(
    'duplicate clicks cannot commit twice while persistence is in flight',
    () async {
      final engine = DecisionEngine(stormScenario());
      final repository = ControlledRepository('test', engine);
      final controller = SimulationController(
        engine,
        repository,
        engine.start(runId: 'once'),
      );
      final first = controller.act('audit');
      expect(controller.busy, isTrue);
      expect(await controller.act('dispatch'), isFalse);
      expect(controller.state.revision, 0);
      repository.gate.complete();
      expect(await first, isTrue);
      expect(controller.state.revision, 1);
      expect(controller.state.commands, hasLength(1));
      controller.dispose();
    },
  );

  test(
    'failed persistence leaves old state visible and reports failure',
    () async {
      final engine = DecisionEngine(stormScenario());
      final repository = ControlledRepository('test', engine);
      final initial = engine.start(runId: 'failure');
      final controller = SimulationController(engine, repository, initial);
      final command = controller.act('audit');
      repository.gate.completeError(StateError('disk unavailable'));
      expect(await command, isFalse);
      expect(identical(controller.state, initial), isTrue);
      expect(controller.error, contains('Решение не сохранено'));
      expect(controller.busy, isFalse);
      controller.dispose();
    },
  );

  test('conditional graph edges use post-action state with fallback', () {
    final source = stormScenario();
    final scenario = DecisionScenario(
      id: 'routing',
      version: '1',
      title: '',
      intro: '',
      documents: [],
      characters: [],
      endings: source.endings,
      scenes: [
        const StoryScene(
          id: 'start',
          title: '',
          location: '',
          speaker: '',
          text: '',
          actions: [
            StoryAction(
              id: 'route',
              title: '',
              tradeoff: '',
              response: '',
              effect: Effect(delta: {'safety': 30}),
              transitions: [
                Transition(
                  'high',
                  when: Condition(variable: 'safety', minimum: 70),
                ),
                Transition('low'),
              ],
            ),
          ],
        ),
        const StoryScene(
          id: 'high',
          title: '',
          location: '',
          speaker: '',
          text: '',
          actions: [],
        ),
        const StoryScene(
          id: 'low',
          title: '',
          location: '',
          speaker: '',
          text: '',
          actions: [],
        ),
      ],
    );
    final engine = DecisionEngine(scenario);
    final result = engine.apply(engine.start(runId: 'branch'), 'route');
    expect(result.sceneId, 'high');
    expect(result.values['safety'], 75);
  });

  test('conditional delayed consequence can be prevented by prior facts', () {
    final engine = DecisionEngine(stormScenario());
    var state = engine.start(runId: 'conditions');
    for (final action in [
      'audit',
      'precaution',
      'inspect',
      'radio',
      'listen',
      'transparent',
      'stay',
      'reconcile',
    ]) {
      state = engine.apply(state, action);
    }
    expect(
      state.events.where((e) => e.kind == 'averted' && e.cause == 's7/stay'),
      hasLength(1),
    );
    expect(
      state.events.where(
        (e) => e.kind == 'consequence' && e.cause == 's7/stay',
      ),
      hasLength(1),
    );
  });
}
