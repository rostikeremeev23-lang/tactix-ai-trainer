import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ai_trainer_mobile/features/strategy/studio/domain/city_scenarios.dart';
import 'package:ai_trainer_mobile/features/strategy/studio/domain/scenario.dart';
import 'package:ai_trainer_mobile/features/strategy/studio/domain/engine.dart';
import 'package:ai_trainer_mobile/features/strategy/studio/data/studio_archive.dart';
import 'package:ai_trainer_mobile/features/strategy/studio/data/studio_store.dart';
import 'package:ai_trainer_mobile/features/strategy/studio/presentation/studio_controller.dart';

ExerciseEngine finish(StudioScenario scenario, {bool careful = true}) {
  final e = ExerciseEngine(scenario);
  while (!e.completed) {
    if (e.current.pending != null) {
      if (!e.decide(careful ? 0 : 1)) expect(e.decide(careful ? 1 : 0), isTrue);
    } else {
      expect(e.advance(), isTrue);
    }
  }
  return e;
}

StudioScenario placed(StudioScenario s) => s.copyWith(
  objects: s.objects
      .map(
        (o) => o.id.startsWith('team-')
            ? o.copyWith(
                position: s.objects
                    .firstWhere(
                      (g) => g.id == o.id.replaceFirst('team-', 'goal-'),
                    )
                    .position,
              )
            : o,
      )
      .toList(),
);
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('all city scenarios/difficulties finish, have reachable success, and replay exactly', () {
    for (var index = 0; index < 3; index++) {
      for (var difficulty = 0; difficulty < 3; difficulty++) {
        final s = CityScenarios.create(index, difficulty: difficulty);
        expect(s.launchProblem, isNull);
        expect(s.cityMap, isTrue);
        final good = finish(placed(s));
        final idle = finish(s, careful: false);
        expect(
          good.succeeded,
          isTrue,
          reason: 'scenario $index difficulty $difficulty',
        );
        expect(good.score, greaterThan(idle.score));
        final replay = ExerciseEngine.read(
          jsonDecode(jsonEncode(good.toJson())),
        );
        expect(replay.report, good.report);
        expect(
          replay.frames
              .map((f) => f.objects.map((o) => o.toJson()).toList())
              .toList(),
          good.frames
              .map((f) => f.objects.map((o) => o.toJson()).toList())
              .toList(),
        );
      }
    }
  });
  test('seed controls event timing and survives serialization', () {
    final a = CityScenarios.create(2, seed: 73);
    expect(a.toJson(), CityScenarios.create(2, seed: 73).toJson());
    expect(
      a.injects.map((e) => e.tick).toList(),
      isNot(
        CityScenarios.create(2, seed: 74).injects.map((e) => e.tick).toList(),
      ),
    );
    expect(StudioScenario.read(a.toJson()).seed, 73);
    expect(() => CityScenarios.create(0, seed: -1), throwsArgumentError);
  });
  test('legacy saves without new fields remain readable', () {
    final j = StudioScenario.demo().toJson()
      ..remove('cityMap')
      ..remove('seed');
    for (final o in j['objects'] as List) {
      o.remove('rotation');
      o.remove('group');
    }
    final s = StudioScenario.read(j);
    expect(s.cityMap, isFalse);
    expect(s.objects.first.rotation, 0);
    expect(s.objects.first.group, isEmpty);
  });
  test('archive snapshots, de-duplicates, serializes competing writes and isolates profiles', () async {
    final archive = StudioArchive('alice');
    final e = finish(placed(CityScenarios.create(0)));
    final doc = StudioDocument(e.scenario, e);
    await Future.wait([
      archive.add(doc),
      StudioArchive('alice').add(doc),
      archive.add(StudioDocument(CityScenarios.create(1))),
    ]);
    final loaded = await archive.load();
    expect(loaded.length, 2);
    expect(loaded.last.document.engine!.report, e.report);
    expect(await StudioArchive('bob').load(), isEmpty);
    final prefs = await SharedPreferences.getInstance();
    // Three writes: latest generation is .1; older generation must survive.
    await prefs.setString('${archive.key}.1', 'broken');
    expect((await archive.load()).length, 1);
    expect(archive.recoveryMessage, isNotNull);
    await prefs.setString('${archive.key}.0', 'also broken');
    await expectLater(archive.load(), throwsFormatException);
    await expectLater(archive.add(doc), throwsFormatException);
  });
  test(
    'undo/redo, group and rotation survive save; replay cannot edit',
    () async {
      final c = StudioController('undo');
      await c.restore();
      c.openDocument(StudioDocument(CityScenarios.create(1)));
      final original = c.scenario.toJson();
      c.armAdd(ObjectKind.recon);
      c.tapMap(const MapPoint(.8, .8));
      c.updateObject(c.selected!.copyWith(group: 'Сектор Сад', rotation: 90));
      c.undo();
      expect(c.selected!.rotation, 0);
      c.undo();
      expect(c.scenario.toJson(), original);
      c.redo();
      c.redo();
      await c.save();
      expect((await c.store.load())!.scenario.objects.last.group, 'Сектор Сад');
      c.undo();
      c.configure(c.scenario.copyWith(name: 'Новая ветка'));
      expect(c.canRedo, isFalse);
      c.play();
      c.pause();
      expect(c.canUndo, isFalse);
      c.dispose();
    },
  );
}
