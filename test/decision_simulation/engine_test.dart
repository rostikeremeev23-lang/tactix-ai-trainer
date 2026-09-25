import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ai_trainer_mobile/features/decision_simulation/data/storm_scenario.dart';
import 'package:ai_trainer_mobile/features/decision_simulation/data/run_repository.dart';
import 'package:ai_trainer_mobile/features/decision_simulation/domain/models.dart';
import 'package:ai_trainer_mobile/features/decision_simulation/domain/decision_engine.dart';
import 'package:ai_trainer_mobile/features/decision_simulation/domain/scenario_validator.dart';
import 'package:ai_trainer_mobile/features/decision_simulation/application/simulation_ai_adapter.dart';

void main() {
  final scenario = stormScenario();
  final engine = DecisionEngine(scenario);
  RunState start() => engine.start(runId: 'test');
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('authored graph and document references are valid', () {
    expect(validateScenario(scenario), isEmpty);
    expect(scenario.scenes, hasLength(12));
    expect(scenario.endings, hasLength(4));
  });

  test(
    'every reachable main decision path terminates; all four endings reachable',
    () {
      final witnesses = <String, List<String>>{};
      final visitedScenes = <String>{};
      var leaves = 0;
      void walk(RunState state) {
        expect(state.commands.length, lessThanOrEqualTo(12));
        if (state.completed) {
          leaves++;
          witnesses.putIfAbsent(
            state.ending!,
            () => state.commands.map((c) => c.action).toList(),
          );
          expect(state.pending, isEmpty);
          return;
        }
        visitedScenes.add(state.sceneId);
        final actions = scenario
            .scene(state.sceneId)
            .actions
            .where((a) => !a.inquiry && engine.available(state, a))
            .toList();
        expect(actions, isNotEmpty, reason: state.sceneId);
        for (final action in actions) {
          final next = engine.apply(state, action.id);
          expect(next.revision, state.revision + 1);
          expect(next.values.values.every((v) => v >= 0), isTrue);
          walk(next);
        }
        // Every available inquiry preserves a route out and cannot repeat.
        for (final ask
            in scenario.scene(state.sceneId).actions.where((a) => a.inquiry)) {
          if (!engine.available(state, ask)) continue;
          final next = engine.apply(state, ask.id);
          expect(engine.available(next, ask), isFalse);
          expect(
            scenario
                .scene(next.sceneId)
                .actions
                .any((a) => !a.inquiry && engine.available(next, a)),
            isTrue,
          );
        }
      }

      walk(start());
      expect(visitedScenes, hasLength(12));
      expect(witnesses.keys.toSet(), {
        'shelter',
        'relocation',
        'fragile',
        'crisis',
      });
      expect(leaves, greaterThan(1000));
      // Useful executable witnesses, not an assumed outcome list.
      // ignore: avoid_print
      print('Verified $leaves complete paths. Ending witnesses: $witnesses');
    },
  );

  test(
    'all main paths with both weather outcomes and inquiry policies terminate',
    () {
      final weatherOutcomes = <String>{};
      for (final seed in [1, 42]) {
        for (final askAll in [false, true]) {
          var leaves = 0;
          var coveredPolicies = 0;
          var earlyEndings = 0;
          final endings = <String>{};
          void walk(RunState state) {
            expect(state.commands.length, lessThanOrEqualTo(24));
            if (state.completed) {
              leaves++;
              // A timeout ends every remaining continuation of this prefix.
              coveredPolicies += 1 << (12 - state.step);
              if (state.step < 12) {
                earlyEndings++;
                expect(state.ending, 'crisis');
                expect(state.minutes, 0);
              }
              endings.add(state.ending!);
              expect(state.pending, isEmpty);
              final weather = state.events.where(
                (event) => event.kind == 'chance',
              );
              expect(weather, hasLength(1));
              weatherOutcomes.add(weather.single.text);
              return;
            }
            final scene = scenario.scene(state.sceneId);
            if (askAll) {
              for (final inquiry in scene.actions.where(
                (action) => action.inquiry,
              )) {
                if (!engine.available(state, inquiry)) continue;
                state = engine.apply(state, inquiry.id);
                expect(engine.available(state, inquiry), isFalse);
              }
            }
            if (state.completed) {
              walk(state);
              return;
            }
            final choices = scene.actions
                .where(
                  (action) =>
                      !action.inquiry && engine.available(state, action),
                )
                .toList();
            expect(
              choices,
              isNotEmpty,
              reason: 'seed=$seed, scene=${scene.id}',
            );
            for (final action in choices) {
              final next = engine.apply(state, action.id);
              expect(next.step, state.step + 1);
              expect(next.values.values.every((value) => value >= 0), isTrue);
              walk(next);
            }
          }

          walk(engine.start(runId: 'weather-$seed-$askAll', seed: seed));
          expect(coveredPolicies, 4096);
          expect(leaves, greaterThan(1000));
          expect(endings, {'shelter', 'relocation', 'fragile', 'crisis'});
          // ignore: avoid_print
          print(
            'Verified $leaves paths ($earlyEndings early endings), '
            'covering $coveredPolicies policies: seed=$seed, inquiries=$askAll',
          );
        }
      }
      expect(weatherOutcomes, {
        scenario.chanceEvents.single.occurredText,
        scenario.chanceEvents.single.absentText,
      });
    },
  );

  test('all inquiries with each main policy finish without deadlock', () {
    for (final preferLast in [false, true]) {
      for (final seed in [1, 17, 42, 1234]) {
        var state = engine.start(runId: 'inquiries', seed: seed);
        while (!state.completed) {
          final scene = scenario.scene(state.sceneId);
          for (final action in scene.actions.where((a) => a.inquiry)) {
            if (engine.available(state, action)) {
              state = engine.apply(state, action.id);
            }
          }
          if (state.completed) break;
          final choices = scene.actions
              .where((a) => !a.inquiry && engine.available(state, a))
              .toList();
          expect(choices, isNotEmpty);
          state = engine.apply(
            state,
            (preferLast ? choices.last : choices.first).id,
          );
          expect(state.commands.length, lessThanOrEqualTo(24));
        }
      }
    }
  });

  test('invalid and repeated commands cannot mutate input state', () {
    final before = start();
    final original = jsonEncode(before.toJson());
    expect(() => engine.apply(before, 'invented'), throwsArgumentError);
    final after = engine.apply(before, 'ask');
    expect(() => engine.apply(after, 'ask'), throwsStateError);
    expect(jsonEncode(before.toJson()), original);
    expect(() => before.values['safety'] = 0, throwsUnsupportedError);
  });

  test('delayed effects fire once and retain causal source', () {
    var state = engine.apply(start(), 'dispatch');
    expect(state.pending, hasLength(1));
    state = engine.apply(state, 'precaution');
    state = engine.apply(state, 'inspect');
    expect(state.events.where((e) => e.kind == 'consequence'), isEmpty);
    state = engine.apply(state, 'radio');
    final fired = state.events.where((e) => e.kind == 'consequence').toList();
    expect(fired, hasLength(1));
    expect(fired.single.cause, 's1/dispatch');
    expect(state.pending, isEmpty);
    final original = jsonEncode(state.toJson());
    final restored = engine.restore(
      Map<String, dynamic>.from(engine.export(state)),
    );
    expect(jsonEncode(restored.toJson()), original);
    state = engine.apply(restored, 'listen');
    expect(
      state.events.where(
        (e) => e.cause == 's1/dispatch' && e.kind == 'consequence',
      ),
      hasLength(1),
    );
  });

  test(
    'save and resume after every command preserves random event and journal',
    () async {
      final repository = RunRepository('alice', engine);
      var state = start();
      while (!state.completed) {
        final scene = scenario.scene(state.sceneId);
        final choices = scene.actions
            .where((a) => !a.inquiry && engine.available(state, a))
            .toList();
        state = engine.apply(state, choices.first.id, note: 'Моё обоснование');
        await repository.save(state);
        final restored = await RunRepository('alice', engine).load();
        expect(jsonEncode(restored!.toJson()), jsonEncode(state.toJson()));
      }
      expect(state.events.where((e) => e.kind == 'chance'), hasLength(1));
      expect(
        state.events.map((e) => e.sequence).toList(),
        List.generate(state.events.length, (i) => i + 1),
      );
      expect(() => engine.apply(state, 'ask'), throwsStateError);
      expect(await RunRepository('bob', engine).load(), isNull);
    },
  );

  test(
    'corrupt latest snapshot recovers previous committed generation',
    () async {
      final repository = RunRepository('alice', engine);
      final before = engine.apply(start(), 'audit');
      await repository.save(before); // slot 1
      await repository.save(engine.apply(before, 'precaution')); // slot 0
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('${repository.key}.0', '{bad json');
      final recovered = await repository.load();
      expect(recovered!.sceneId, before.sceneId);
      expect(repository.recoveryMessage, isNotNull);
    },
  );

  test('rejects tampered state and incompatible version', () {
    final envelope =
        jsonDecode(jsonEncode(engine.export(start()))) as Map<String, dynamic>;
    (envelope['state']['values'] as Map)['safety'] = 100;
    expect(() => engine.restore(envelope), throwsFormatException);
    envelope['version'] = 'future';
    expect(() => engine.restore(envelope), throwsFormatException);
  });

  test('AI proposals are limited to allowed IDs and never execute', () {
    final state = start();
    expect(
      SimulationAiAdapter.validateProposal('{"actionId":"audit"}', {'audit'}),
      'audit',
    );
    expect(
      SimulationAiAdapter.validateProposal('{"actionId":"cheat","score":100}', {
        'audit',
      }),
      isNull,
    );
    expect(SimulationAiAdapter.validateProposal('not json', {'audit'}), isNull);
    expect(state.revision, 0);
  });

  test('validator detects missing target and unknown effect variable', () {
    final broken = DecisionScenario(
      id: 'bad',
      version: '1',
      title: '',
      intro: '',
      documents: [],
      characters: [],
      endings: scenario.endings,
      scenes: [
        StoryScene(
          id: 'x',
          title: '',
          location: '',
          speaker: '',
          text: '',
          actions: [
            StoryAction(
              id: 'a',
              title: '',
              tradeoff: '',
              response: '',
              effect: Effect(delta: {'magic': 1}),
              transitions: [Transition('missing')],
            ),
          ],
        ),
      ],
    );
    expect(validateScenario(broken), contains('Переход: missing'));
    expect(validateScenario(broken), contains('Переменная: magic'));
  });
}
