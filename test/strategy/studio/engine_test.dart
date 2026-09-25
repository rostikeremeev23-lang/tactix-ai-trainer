import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ai_trainer_mobile/services/ai_service.dart';
import 'package:ai_trainer_mobile/features/strategy/studio/domain/scenario.dart';
import 'package:ai_trainer_mobile/features/strategy/studio/domain/engine.dart';
import 'package:ai_trainer_mobile/features/strategy/studio/data/ai_review_adapter.dart';

ExerciseEngine complete({bool careful = true}) {
  final engine = ExerciseEngine(StudioScenario.demo());
  engine.move('obj-2', const MapPoint(.84, .43));
  while (!engine.completed) {
    if (engine.current.pending != null) {
      engine.decide(careful ? 0 : 1);
    } else {
      engine.advance();
    }
  }
  return engine;
}

void main() {
  test(
    'demonstration starts moving without extra setup and works without AI',
    () async {
      SharedPreferences.setMockInitialValues({});
      final engine = ExerciseEngine(StudioScenario.demo());
      final start = engine.current.objects
          .firstWhere((o) => o.id == 'obj-2')
          .position;
      engine.advance();
      expect(
        engine.current.objects.firstWhere((o) => o.id == 'obj-2').position.x,
        greaterThan(start.x),
      );
      while (!engine.completed) {
        if (engine.current.pending != null) {
          engine.decide(0);
        } else {
          engine.advance();
        }
      }
      expect(engine.current.reached, contains('obj-4'));
      await AIService.setMode(AIMode.offline);
      expect(
        await StrategyAIReviewAdapter().review(engine),
        contains(engine.report),
      );
      expect(engine.score, 98);
    },
  );
  test(
    'full demo reaches goal, freezes for injects, reproduces every frame',
    () {
      final engine = complete();
      expect(engine.current.tick, 60);
      expect(engine.current.reached, contains('obj-4'));
      expect(engine.current.resources, 77);
      expect(engine.current.safety, 100);
      expect(engine.current.cohesion, 100);
      expect(engine.score, 98);
      final restored = ExerciseEngine.read(
        jsonDecode(jsonEncode(engine.toJson())),
      );
      expect(restored.report, engine.report);
      expect(restored.frames.length, engine.frames.length);
      for (var i = 0; i < engine.frames.length; i++) {
        expect(
          restored.frames[i].objects.map((o) => o.toJson()).toList(),
          engine.frames[i].objects.map((o) => o.toJson()).toList(),
        );
        expect(restored.frames[i].log, engine.frames[i].log);
        expect(restored.frames[i].resources, engine.frames[i].resources);
      }
      expect(engine.advance(), isFalse);
      expect(engine.move('obj-2', const MapPoint(.1, .2)), isFalse);
      expect(engine.decide(0), isFalse);
      expect(() => engine.frames.clear(), throwsUnsupportedError);
      expect(() => engine.current.objects.clear(), throwsUnsupportedError);
    },
  );
  test('decisions produce immediate and delayed observable consequences', () {
    final e = ExerciseEngine(StudioScenario.demo());
    for (var i = 0; i < 8; i++) {
      e.advance();
    }
    expect(e.current.pending!.kind, InjectKind.road);
    expect(e.advance(), isFalse);
    expect(e.move('obj-2', const MapPoint(.8, .4)), isFalse);
    final before = e.current;
    expect(e.decide(1), isTrue);
    expect(e.decide(1), isFalse);
    expect(e.current.safety, 100);
    for (var i = 0; i < 3; i++) {
      e.advance();
    }
    expect(e.current.safety, 80);
    expect(before.safety, 100);
    expect(e.current.log.last, contains('Отложенное последствие'));
    final risky = complete(careful: false);
    expect(risky.current.safety, 65);
    expect(risky.current.cohesion, 80);
    expect(risky.score, lessThan(complete().score));
  });
  test('empty scenarios cannot launch; duplicate ids and corrupt commands rejected', () {
    expect(() => ExerciseEngine(StudioScenario.blank()), throwsStateError);
    final s = StudioScenario.demo();
    expect(
      () => s.copyWith(objects: [...s.objects, s.objects.first]).validate(),
      throwsFormatException,
    );
    final e = ExerciseEngine(s).toJson();
    (e['commands'] as List).add({'action': 'decide', 'choice': 0});
    expect(() => ExerciseEngine.read(e), throwsFormatException);
    expect(() => MapPoint.read([double.nan, .5]), throwsFormatException);
  });
  test(
    'insufficient resources and immobile objects cannot execute actions',
    () {
      final e = ExerciseEngine(StudioScenario.demo().copyWith(resources: 10));
      expect(e.move('obj-4', const MapPoint(.5, .5)), isFalse);
      expect(e.move('missing', const MapPoint(.5, .5)), isFalse);
      for (var i = 0; i < 8; i++) {
        e.advance();
      }
      expect(e.decide(0), isFalse);
      expect(e.decide(1), isTrue);
    },
  );
  test('all four exercise types have reachable objectives and explicit score rules', () {
    for (final kind in ExerciseKind.values) {
      final s = StudioScenario.demo().copyWith(
        kind: kind,
        injects: [],
        objects: [
          const MapObject(
            id: 'mobile',
            name: 'Участник',
            kind: ObjectKind.transport,
            position: MapPoint(.5, .5),
          ),
          const MapObject(
            id: 'goal',
            name: 'Цель',
            kind: ObjectKind.objective,
            position: MapPoint(.5, .5),
          ),
        ],
      );
      final e = ExerciseEngine(s);
      while (!e.completed) {
        e.advance();
      }
      expect(e.score, 100);
      expect(e.current.holdTicks, 60);
    }
  });
  test(
    'same-time injects remain sequential, never overwrite a pending decision',
    () {
      final s = StudioScenario.demo().copyWith(
        injects: [
          const ScenarioInject('a', InjectKind.road, 1),
          const ScenarioInject('b', InjectKind.weather, 1),
        ],
      );
      final e = ExerciseEngine(s)..advance();
      expect(e.current.pending!.id, 'a');
      e.decide(0);
      expect(e.current.pending!.id, 'b');
      e.decide(0);
      expect(e.current.pending, isNull);
      expect(e.current.tick, 1);
    },
  );
  test('AI adapter exposes verified facts without mutating engine', () {
    final e = complete();
    final before = jsonEncode(e.toJson());
    final payload = StrategyAIReviewAdapter().payload(e);
    expect(payload['score'], e.score);
    expect(payload['confirmed_events'], e.current.log);
    expect(jsonEncode(e.toJson()), before);
  });
}
