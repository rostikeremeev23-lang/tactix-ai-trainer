import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ai_trainer_mobile/app/theme.dart';
import 'package:ai_trainer_mobile/screens/strategy/strategy_screen.dart';
import 'package:ai_trainer_mobile/features/strategy/studio/domain/scenario.dart';
import 'package:ai_trainer_mobile/features/strategy/studio/presentation/terrain_view.dart';
import 'package:ai_trainer_mobile/features/strategy/studio/data/studio_store.dart';

Widget app({double scale = 1}) => MaterialApp(
  theme: TactixTheme.dark,
  builder: (context, child) => RepaintBoundary(
    key: const Key('studio-capture'),
    child: MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
  ),
  home: const TactixStrategyScreen(
    userId: 'studio-test',
    startInLibrary: false,
  ),
);

Future<void> capture(WidgetTester tester, String name) async {
  if (!const bool.fromEnvironment('CAPTURE_STRATEGY')) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('studio-capture')),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final directory = Directory('artifacts/strategy');
    await directory.create(recursive: true);
    await File('${directory.path}/$name.png')
        .writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

Future<void> closePanel(WidgetTester tester) async {
  final state = tester.state<ScaffoldState>(find.byType(Scaffold).first);
  state.closeDrawer();
  state.closeEndDrawer();
  await tester.pumpAndSettle();
}

void main() {
  WidgetController.hitTestWarningShouldBeFatal = true;
  setUpAll(() async {
    if (!const bool.fromEnvironment('CAPTURE_STRATEGY')) return;
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    final file = File('C:/Windows/Fonts/arial.ttf');
    if (await file.exists()) {
      final font = FontLoader('Arial')
        ..addFont(Future.value(ByteData.sublistView(await file.readAsBytes())));
      await font.load();
    }
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets(
    'create named scenario and place through a zoomed and panned map',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Создать'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Продолжить'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Занятие Янтарь');
      await tester.tap(find.text('Применить'));
      await tester.pumpAndSettle();
      await closePanel(tester);
      final viewer = tester.widget<InteractiveViewer>(
        find.byType(InteractiveViewer),
      );
      final initialScale = viewer.transformationController!.value
          .getMaxScaleOnAxis();
      await tester.tap(find.byTooltip('Приблизить'));
      await tester.pumpAndSettle();
      expect(
        viewer.transformationController!.value.getMaxScaleOnAxis(),
        greaterThan(initialScale),
      );
      await tester.drag(find.byType(InteractiveViewer), const Offset(80, 40));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Конструктор сценария'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Учебная группа'));
      await tester.pumpAndSettle();
      final center = tester.getCenter(find.byType(InteractiveViewer));
      final local = center - tester.getTopLeft(find.byType(InteractiveViewer));
      final expected = viewer.transformationController!.toScene(local);
      await tester.tapAt(center);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Сохранить Strategy'));
      await tester.pumpAndSettle();
      final restored = (await StudioStore('studio-test').load())!.scenario;
      expect(restored.name, 'Занятие Янтарь');
      expect(
        restored.objects.single.position.x,
        closeTo(expected.dx / 1000, .001),
      );
      expect(
        restored.objects.single.position.y,
        closeTo(expected.dy / 1000, .001),
      );
      await tester.tap(find.byTooltip('Слои карты'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(CheckedPopupMenuItem<String>).first);
      await tester.pumpAndSettle();
      expect(
        tester.widget<TerrainView>(find.byType(TerrainView)).labels,
        isFalse,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
  for (final size in [
    const Size(1440, 900),
    const Size(1024, 768),
    const Size(800, 1280),
    const Size(600, 800),
  ]) {
    testWidgets('map/editor/decision/report/replay/restore at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(app(scale: size.width < 1100 ? 1.2 : 1));
      await tester.pumpAndSettle();
      // Asset decode is asynchronous; explicitly wait for the actual raster.
      await tester.runAsync(
        () => precacheImage(
          const AssetImage('assets/strategy/valley.png'),
          tester.element(find.byType(TerrainView)),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await capture(tester, 'map_${size.width.toInt()}');
      await tester.tap(find.byTooltip('Конструктор сценария'));
      await tester.pumpAndSettle();
      expect(find.text('БИБЛИОТЕКА ОБЪЕКТОВ'), findsOneWidget);
      await capture(tester, 'editor_${size.width.toInt()}');
      await closePanel(tester);
      await tester.tap(find.byKey(const ValueKey('play-exercise')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('play-exercise')));
      await tester.pumpAndSettle();
      // Pick transport on the map, then give a route to the objective.
      await tester.tap(find.byKey(const ValueKey('map-obj-2')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('move-object')));
      await tester.tap(find.byKey(const ValueKey('move-object')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('map-obj-4')));
      await tester.pumpAndSettle();
      var decisions = 0;
      for (var tick = 1; tick <= 60; tick++) {
        await tester.tap(find.byKey(const ValueKey('step-exercise')));
        await tester.pumpAndSettle();
        if ([8, 18, 30].contains(tick)) {
          await tester.ensureVisible(find.byKey(const ValueKey('decision-0')));
          if (tick == 8) {
            await capture(tester, 'decision_${size.width.toInt()}');
          }
          await tester.tap(find.byKey(const ValueKey('decision-0')));
          await tester.pumpAndSettle();
          await closePanel(tester);
          decisions++;
        }
        expect(tester.takeException(), isNull);
      }
      expect(decisions, 3);
      await tester.tap(find.text('Отчёт'));
      await tester.pumpAndSettle();
      expect(find.text('98 / 100'), findsOneWidget);
      await capture(tester, 'report_${size.width.toInt()}');
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Запись'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('replay-slider')), findsOneWidget);
      final slider = tester.widget<Slider>(
        find.byKey(const ValueKey('replay-slider')),
      );
      slider.onChanged!(slider.max / 2);
      await tester.pumpAndSettle();
      await capture(tester, 'replay_${size.width.toInt()}');
      await tester.tap(find.text('К текущему состоянию'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Сохранить Strategy'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(find.text('Отчёт'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
  }
  testWidgets('library places and edits objects in an empty custom scenario', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await StudioStore('studio-test')
        .save(StudioDocument(StudioScenario.blank()));
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Конструктор сценария'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Учебная группа'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('terrain-canvas')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('map-obj-1')), findsOneWidget);
    await tester.tap(find.text('Свойства объекта'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Группа Янтарь');
    await tester.tap(find.text('Применить'));
    await tester.pumpAndSettle();
    expect(find.text('Группа Янтарь'), findsWidgets);
    await tester.tap(find.text('Удалить объект'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('map-obj-1')), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
