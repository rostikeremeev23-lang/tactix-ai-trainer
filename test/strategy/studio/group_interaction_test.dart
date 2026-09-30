import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ai_trainer_mobile/features/strategy/studio/domain/scenario.dart';
import 'package:ai_trainer_mobile/features/strategy/studio/presentation/studio_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('group selection, naming, movement, undo and restore persist', () async {
    SharedPreferences.setMockInitialValues({});
    final controller = StudioController('group-test');
    await controller.restore();
    final firstStart = controller.objects.firstWhere((o) => o.id == 'obj-1').position;
    final secondStart = controller.objects.firstWhere((o) => o.id == 'obj-3').position;

    controller.toggleMultiSelect();
    controller.select('obj-1');
    controller.select('obj-3');
    controller.groupSelected('Север');
    controller.dragObject('obj-1', const MapPoint(.5, .64));

    final firstMoved = controller.objects.firstWhere((o) => o.id == 'obj-1').position;
    final secondMoved = controller.objects.firstWhere((o) => o.id == 'obj-3').position;
    expect(firstMoved.x - firstStart.x, closeTo(secondMoved.x - secondStart.x, 0.0001));
    expect(firstMoved.y - firstStart.y, closeTo(secondMoved.y - secondStart.y, 0.0001));
    expect(controller.canUndo, isTrue);
    controller.undo();
    expect(controller.objects.firstWhere((o) => o.id == 'obj-1').position, firstStart);

    controller.selectGroup('Север');
    expect(controller.selectedIds, {'obj-1', 'obj-3'});
    await controller.save();
    final restored = StudioController('group-test');
    await restored.restore();
    expect(restored.objects.where((o) => o.group == 'Север').length, 2);
    controller.dispose();
    restored.dispose();
  });
}
