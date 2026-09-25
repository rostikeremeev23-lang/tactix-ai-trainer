import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ai_trainer_mobile/features/strategy/studio/domain/scenario.dart';
import 'package:ai_trainer_mobile/features/strategy/studio/presentation/studio_controller.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'create, place, edit, move, delete and restore an authored scenario',
    () async {
      final c = StudioController('editor');
      await c.restore();
      c.newScenario();
      c.configure(c.scenario.copyWith(name: 'Проверка редактора'));
      c.armAdd(ObjectKind.group);
      c.tapMap(const MapPoint(.2, .3));
      final group = c.selected!;
      c.updateObject(group.copyWith(name: 'Учебная группа A', readiness: 80));
      c.armMove();
      c.tapMap(const MapPoint(.4, .5));
      expect(c.selected!.position.x, .4);
      c.armAdd(ObjectKind.facility);
      c.tapMap(const MapPoint(.8, .3));
      c.deleteSelected();
      c.armAdd(ObjectKind.objective);
      c.tapMap(const MapPoint(.6, .5));
      await c.save();
      final next = StudioController('editor');
      await next.restore();
      expect(next.scenario.objects.length, 2);
      expect(next.scenario.objects.first.name, 'Учебная группа A');
      expect(next.scenario.name, 'Проверка редактора');
      expect(next.running, isFalse);
      c.dispose();
      next.dispose();
    },
  );
  testWidgets(
    'pause, speeds, pending decision, replay and seek cannot mutate live history',
    (tester) async {
      final c = StudioController('clock');
      await c.restore();
      c.play();
      await tester.pump(const Duration(seconds: 2));
      expect(c.frame!.tick, 2);
      c.pause();
      await tester.pump(const Duration(seconds: 3));
      expect(c.frame!.tick, 2);
      c.setSpeed(4);
      c.play();
      await tester.pump(const Duration(milliseconds: 1500));
      expect(c.frame!.tick, 8);
      expect(c.running, isFalse);
      c.decide(0);
      final live = c.engine!.toJson();
      c.toggleReplay();
      c.seek(2);
      c.select('obj-2');
      c.armMove();
      c.tapMap(const MapPoint(.9, .9));
      c.decide(1);
      expect(c.engine!.toJson(), live);
      c.play();
      await tester.pump(const Duration(milliseconds: 250));
      expect(c.replayIndex, 3);
      c.pause();
      c.toggleReplay();
      expect(c.frame!.tick, 8);
      c.reset();
      expect(c.editing, isTrue);
      c.dispose();
      await tester.pump(const Duration(seconds: 1));
    },
  );
}
