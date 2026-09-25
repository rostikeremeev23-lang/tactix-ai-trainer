import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ai_trainer_mobile/screens/strategy/strategy_screen.dart';

void main() {
  WidgetController.hitTestWarningShouldBeFatal = true;
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final size in [const Size(1280, 900), const Size(390, 844)]) {
    testWidgets(
      'Strategy editor, full run, replay and fresh restart at $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: const TactixStrategyScreen(userId: 'test'),
          ),
        );
        await tester.tap(find.text('АСТАНА'));
        await tester.pumpAndSettle();
        expect(find.text('РЕДАКТОР УЧЕБНОЙ ОБСТАНОВКИ'), findsOneWidget);
        final dropdown = find.byKey(const ValueKey('sector-alpha'));
        await tester.ensureVisible(dropdown);
        await tester.tap(dropdown);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Точка A').last);
        await tester.pumpAndSettle();
        final start = find.text('НАЧАТЬ МИССИЮ');
        await tester.ensureVisible(start);
        await tester.tap(start);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        for (var turn = 1; turn <= 8; turn++) {
          final next = find.text(
            turn == 8 ? 'ЗАВЕРШИТЬ МИССИЮ' : 'ЗАВЕРШИТЬ ХОД',
          );
          await tester.scrollUntilVisible(
            next,
            200,
            scrollable: find.descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            ),
          );
          await tester.pumpAndSettle();
          await Scrollable.ensureVisible(tester.element(next), alignment: .5);
          await tester.pumpAndSettle();
          await tester.tap(next);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
        expect(find.text('After Action Review'), findsOneWidget);
        expect(find.text('Контрольных точек удержано: 3 / 3'), findsOneWidget);
        await tester.tap(find.byTooltip('Сохранить Strategy'));
        await tester.pumpAndSettle();
        final replay = find.text('Воспроизвести историю');
        await tester.ensureVisible(replay);
        await tester.tap(replay);
        await tester.pumpAndSettle();
        expect(find.text('История 1 / 9'), findsOneWidget);
        await tester.tap(find.byTooltip('Воспроизвести'));
        await tester.pump(const Duration(milliseconds: 1100));
        expect(find.text('История 2 / 9'), findsOneWidget);
        await tester.tap(find.byTooltip('Пауза'));
        await tester.pump(const Duration(seconds: 2));
        expect(find.text('История 2 / 9'), findsOneWidget);
        await tester.tap(find.text('К текущему состоянию'));
        await tester.pumpAndSettle();
        final reset = find.text('ВЕРНУТЬСЯ НА КАРТУ КАЗАХСТАНА');
        await tester.ensureVisible(reset);
        await tester.tap(reset);
        await tester.pumpAndSettle();
        await tester.tap(find.text('АСТАНА'));
        await tester.pumpAndSettle();
        final restoredDropdown = tester.widget<DropdownButton<int>>(
          find.byKey(const ValueKey('sector-alpha')),
        );
        expect(restoredDropdown.value, 0);
        await tester.tap(find.byTooltip('Загрузить Strategy'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Загрузить'));
        await tester.pumpAndSettle();
        expect(find.text('After Action Review'), findsOneWidget);
        expect(find.text('Контрольных точек удержано: 3 / 3'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
