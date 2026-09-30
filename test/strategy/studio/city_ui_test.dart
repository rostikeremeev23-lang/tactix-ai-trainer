import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ai_trainer_mobile/app/theme.dart';
import 'package:ai_trainer_mobile/screens/strategy/strategy_screen.dart';
import 'package:ai_trainer_mobile/features/strategy/studio/presentation/studio_controller.dart';
import 'package:ai_trainer_mobile/features/strategy/studio/presentation/terrain_view.dart';
import 'package:ai_trainer_mobile/features/strategy/studio/presentation/city_library.dart';
import 'package:ai_trainer_mobile/features/strategy/studio/presentation/archive_screen.dart';
import 'package:ai_trainer_mobile/features/strategy/studio/data/studio_store.dart';
import 'package:ai_trainer_mobile/features/strategy/studio/data/studio_archive.dart';
import 'package:ai_trainer_mobile/features/strategy/studio/domain/city_scenarios.dart';

import 'city_test.dart' as game;

Widget app() => MaterialApp(
  theme: TactixTheme.dark,
  home: const RepaintBoundary(
    key: Key('capture'),
    child: TactixStrategyScreen(userId: 'city-ui'),
  ),
);
Future<void> capture(WidgetTester tester, String name) async {
  if (!const bool.fromEnvironment('CAPTURE_CITY')) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('capture')),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory('artifacts/strategy').create(recursive: true);
    await File('artifacts/strategy/city_$name.png')
        .writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  WidgetController.hitTestWarningShouldBeFatal = true;
  setUp(() => SharedPreferences.setMockInitialValues({}));
  setUpAll(() async {
    if (!const bool.fromEnvironment('CAPTURE_CITY')) return;
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    final file = File('C:/Windows/Fonts/arial.ttf');
    if (await file.exists()) {
      await (FontLoader('Arial')..addFont(
            Future.value(ByteData.sublistView(await file.readAsBytes())),
          ))
          .load();
    }
  });
  for (final size in [
    const Size(390, 844),
    const Size(1024, 768),
    const Size(1440, 900),
  ]) {
    testWidgets('library briefing plan map save and archive at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(find.byType(CityLibrary), findsOneWidget);
      await capture(tester, 'landing_${size.width.toInt()}');
      await tester.scrollUntilVisible(
        find.byKey(const Key('city-scenario-0')),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('city-scenario-0')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('prepare-city')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TerrainView>(find.byType(TerrainView)).cityMap,
        isTrue,
      );
      await tester.tap(find.byTooltip('Вся территория'));
      await tester.pumpAndSettle();
      await capture(tester, 'map_${size.width.toInt()}');
      final before = tester
          .widget<TerrainView>(find.byType(TerrainView))
          .objects
          .first
          .position;
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('map-team-0'))),
      );
      await tester.pump(const Duration(milliseconds: 600));
      await gesture.moveBy(const Offset(25, -25));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
      final after = tester
          .widget<TerrainView>(find.byType(TerrainView))
          .objects
          .first
          .position;
      expect(after.x, greaterThan(before.x));
      expect(after.y, lessThan(before.y));
      await tester.tap(find.byTooltip('Отменить изменение'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TerrainView>(find.byType(TerrainView))
            .objects
            .first
            .position
            .x,
        before.x,
      );
      await tester.tap(find.byTooltip('Повторить изменение'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Сохранить Strategy'));
      await tester.pumpAndSettle();
      expect(
        (await StudioStore('city-ui').load())!.scenario.name,
        CityScenarios.titles[0],
      );
      await tester.tap(find.byTooltip('Сценарии'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Сохранить план / запись в архив'));
      await tester.pumpAndSettle();
      expect((await StudioArchive('city-ui').load()).length, 2);
      await tester.tap(find.byTooltip('Библиотека сценариев'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Мои планы и результаты'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Мои планы и результаты'));
      await tester.pumpAndSettle();
      expect(find.byType(StudioArchiveScreen), findsOneWidget);
      await tester.tap(find.text('Открыть').first);
      await tester.pumpAndSettle();
      expect(find.byType(TerrainView), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
  }
  testWidgets(
    'city finish, auto archive, retry alternative, compare and restore on phone',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final c = StudioController('city-ui');
      await c.restore();
      c.openDocument(StudioDocument(game.placed(CityScenarios.create(1))));
      c.play();
      c.pause();
      while (!c.engine!.completed) {
        if (c.frame!.pending != null) {
          c.decide(0);
        } else {
          c.step();
        }
      }
      await c.archiveCurrent();
      await c.save();
      final goodScore = c.engine!.score;
      c.reset();
      c.play();
      c.pause();
      while (!c.engine!.completed) {
        if (c.frame!.pending != null) {
          c.decide(1);
        } else {
          c.step();
        }
      }
      await c.archiveCurrent();
      await c.save();
      expect(c.engine!.score, lessThan(goodScore));
      c.dispose();
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Мои планы и результаты'));
      await tester.pumpAndSettle();
      expect(find.byType(Checkbox), findsNWidgets(2));
      await tester.tap(find.byType(Checkbox).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Checkbox).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Сравнить (2/2)'));
      await tester.pumpAndSettle();
      expect(find.text('Сравнение попыток'), findsOneWidget);
      await tester.tap(find.text('Закрыть'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Открыть').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Открыть').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Отчёт'));
      await tester.pumpAndSettle();
      expect(find.text('$goodScore / 100'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Запись'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('replay-slider')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
}
