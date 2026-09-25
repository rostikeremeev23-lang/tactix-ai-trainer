import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ai_trainer_mobile/features/strategy/studio/domain/scenario.dart';
import 'package:ai_trainer_mobile/features/strategy/studio/domain/engine.dart';
import 'package:ai_trainer_mobile/features/strategy/studio/data/studio_store.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'draft and paused run survive restart and remain profile isolated',
    () async {
      final store = StudioStore('commander');
      final s = StudioScenario.demo().copyWith(name: 'Авторский сценарий');
      await store.save(StudioDocument(s));
      final draft = await StudioStore('commander').load();
      expect(draft!.scenario.name, s.name);
      expect(draft.engine, isNull);
      final e = ExerciseEngine(s)..move('obj-2', const MapPoint(.84, .43));
      for (var i = 0; i < 8; i++) {
        e.advance();
      }
      await store.save(StudioDocument(s, e));
      final restored = await StudioStore('commander').load();
      expect(restored!.engine!.current.pending!.kind, InjectKind.road);
      expect(restored.engine!.toJson(), e.toJson());
      expect(await StudioStore('another').load(), isNull);
    },
  );
  test(
    'serialized writes capture snapshots; corrupt latest recovers previous',
    () async {
      final store = StudioStore('recovery');
      final s = StudioScenario.demo();
      final e = ExerciseEngine(s);
      final first = store.save(StudioDocument(s, e));
      e.advance();
      final second = store.save(StudioDocument(s, e));
      await Future.wait([first, second]);
      expect((await store.load())!.engine!.current.tick, 1);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('${store.key}.0', '{truncated');
      expect((await store.load())!.engine!.current.tick, 0);
      expect(store.recoveryMessage, isNotNull);
      await store.save(StudioDocument(s, e));
      expect((await store.load())!.engine!.current.tick, 1);
      await prefs.setString('${store.key}.0', '{}');
      await prefs.setString('${store.key}.1', '{}');
      await expectLater(store.load(), throwsFormatException);
    },
  );
}
