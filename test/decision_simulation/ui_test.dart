import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ai_trainer_mobile/features/decision_simulation/data/storm_scenario.dart';
import 'package:ai_trainer_mobile/features/decision_simulation/data/run_repository.dart';
import 'package:ai_trainer_mobile/features/decision_simulation/domain/decision_engine.dart';
import 'package:ai_trainer_mobile/features/decision_simulation/presentation/episode_library_screen.dart';
import 'package:ai_trainer_mobile/features/decision_simulation/presentation/episode_screen.dart';
import 'package:ai_trainer_mobile/features/decision_simulation/presentation/decision_tree_screen.dart';
import 'package:ai_trainer_mobile/features/decision_simulation/presentation/cinematic_widgets.dart';
import 'package:ai_trainer_mobile/features/decision_simulation/presentation/cinematic_art.dart';

Widget app(Widget home, {double scale = 1, bool reducedMotion = false}) =>
    MaterialApp(
      theme: ThemeData.dark(useMaterial3: true),
      builder: (context, child) => RepaintBoundary(
        key: const Key('capture'),
        child: MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            disableAnimations: reducedMotion,
          ),
          child: child!,
        ),
      ),
      home: home,
    );

Future<void> capture(WidgetTester tester, String name) async {
  if (!const bool.fromEnvironment('CAPTURE_STORY')) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('capture')),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final dir = Directory('artifacts/decision_simulation');
    await dir.create(recursive: true);
    await File('${dir.path}/$name.png')
        .writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  WidgetController.hitTestWarningShouldBeFatal = true;
  setUpAll(() async {
    if (const bool.fromEnvironment('CAPTURE_STORY')) {
      final icons = FontLoader('MaterialIcons');
      icons.addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await icons.load();
      final font = File('C:/Windows/Fonts/arial.ttf');
      if (await font.exists()) {
        final loader = FontLoader('Roboto');
        loader.addFont(
          Future.value(ByteData.sublistView(await font.readAsBytes())),
        );
        await loader.load();
      }
    }
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final size in [
    const Size(1280, 900),
    const Size(1024, 768),
    const Size(800, 1280),
    const Size(600, 800),
  ]) {
    testWidgets('cinematic first three scenes restore and commit at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final engine = DecisionEngine(stormScenario());
      final repository = RunRepository('cinematic', engine);
      var expected = engine.start(runId: 'cinematic');
      await repository.save(expected);
      const actions = ['audit', 'precaution', 'inspect'];
      for (var i = 0; i < actions.length; i++) {
        // A fresh screen/controller must render the saved scene, not start over.
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpWidget(
          app(
            const EpisodeLibraryScreen(userId: 'cinematic'),
            scale: size.width < 1100 ? 1.3 : 1,
          ),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byKey(const Key('resume-episode')));
        await tester.tap(find.byKey(const Key('resume-episode')));
        await tester.pumpAndSettle();
        expect(find.text(engine.scenario.scenes[i].title), findsOneWidget);
        expect(find.byType(CinematicStage), findsOneWidget);
        expect(find.byType(CharacterPortrait), findsOneWidget);
        expect(
          tester
              .widget<SceneIllustration>(find.byType(SceneIllustration))
              .direction
              .set,
          SceneSet.values[i],
        );
        expect(tester.takeException(), isNull);
        await capture(tester, 'cinematic_s${i + 1}_${size.width.toInt()}');
        await tester.ensureVisible(find.byKey(Key('action-${actions[i]}')));
        if (i == 0) {
          await tester.pumpAndSettle();
          await capture(tester, 'cinematic_choices_${size.width.toInt()}');
        }
        await tester.tap(find.byKey(Key('action-${actions[i]}')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('confirm-decision')));
        await tester.pumpAndSettle();
        expected = engine.apply(expected, actions[i]);
        expect((await repository.load())!.toJson(), expected.toJson());
        expect(find.byKey(const Key('consequence-feed')), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    });
  }

  testWidgets(
    'dialogue skip, reduced motion and cancelled choice preserve state',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final engine = DecisionEngine(stormScenario());
      final state = engine.start(runId: 'presentation-only');
      final repository = RunRepository('presentation-only', engine);
      await repository.save(state);
      Widget screen() => EpisodeScreen(
        engine: engine,
        repository: repository,
        initialState: state,
      );
      await tester.pumpWidget(app(screen()));
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.byKey(const Key('finish-dialogue')), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('finish-dialogue')));
      await tester.tap(find.byKey(const Key('finish-dialogue')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.byKey(const Key('narration-visible'))).data,
        engine.scenario.scenes.first.text,
      );
      expect((await repository.load())!.toJson(), state.toJson());
      await tester.ensureVisible(find.byKey(const Key('action-audit')));
      await tester.tap(find.byKey(const Key('action-audit')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Вернуться'));
      await tester.pumpAndSettle();
      expect((await repository.load())!.toJson(), state.toJson());
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(app(screen(), reducedMotion: true, scale: 1.5));
      await tester.pump();
      expect(find.byKey(const Key('finish-dialogue')), findsNothing);
      expect(
        tester.widget<Text>(find.byKey(const Key('narration-visible'))).data,
        engine.scenario.scenes.first.text,
      );
      expect((await repository.load())!.toJson(), state.toJson());
      expect(tester.takeException(), isNull);
      // Disposing during an active reveal must not leave a ticker or callback.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(app(screen()));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'library -> all 12 scenes -> report -> interactive tree -> replay',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(app(const EpisodeLibraryScreen(userId: 'ui')));
      await tester.pumpAndSettle();
      await capture(tester, 'library_windows');
      await tester.ensureVisible(find.byKey(const Key('new-episode')));
      await tester.tap(find.byKey(const Key('new-episode')));
      await tester.pumpAndSettle();
      expect(find.byType(EpisodeScreen), findsOneWidget);
      await capture(tester, 'episode_windows');

      // Authored dialogue is an offline engine command with a real time cost.
      await tester.ensureVisible(find.byKey(const Key('action-ask')));
      await tester.tap(find.byKey(const Key('action-ask')));
      await tester.pumpAndSettle();
      expect(find.text('Запрос выполнен'), findsOneWidget);
      final engine = DecisionEngine(stormScenario());
      final repository = RunRepository('ui', engine);
      var expected = (await repository.load())!;
      expect(expected.commands.single.action, 'ask');
      await tester.tap(find.byTooltip('Журнал событий'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Изменения: Время: -2, Резерв: 0'),
        findsOneWidget,
      );
      expect(find.textContaining('Работа со сведениями: +7'), findsOneWidget);
      expect(find.textContaining('s1/ask'), findsNothing);
      expect(find.textContaining('evidence:'), findsNothing);
      await tester.tap(find.text('Закрыть'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Документы'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Задача смены • 18:40'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Подтверждённый документ'), findsOneWidget);
      await tester.tap(find.text('Закрыть'));
      await tester.pumpAndSettle();
      // Close document index.
      Navigator.of(tester.element(find.text('Документы смены'))).pop();
      await tester.pumpAndSettle();

      const path = [
        'audit',
        'precaution',
        'inspect',
        'shelter_power',
        'listen',
        'transparent',
        'stay',
        'reconcile',
        'include',
        'delegate',
        'reinforce',
        'full',
      ];
      for (final action in path) {
        expect(
          find.text(engine.scenario.scene(expected.sceneId).title),
          findsOneWidget,
        );
        if (action == 'reinforce') {
          await tester.ensureVisible(find.byType(TextField));
          await tester.enterText(
            find.byType(TextField),
            'Усилить помощь, сохранив понятного ответственного.',
          );
        }
        await tester.ensureVisible(find.byKey(Key('action-$action')));
        await tester.tap(find.byKey(Key('action-$action')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('confirm-decision')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expected = engine.apply(
          expected,
          action,
          note: action == 'reinforce'
              ? 'Усилить помощь, сохранив понятного ответственного.'
              : '',
        );
        expect((await repository.load())!.toJson(), expected.toJson());
      }
      expect(find.text('Помощь на месте'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('ЭПИЗОД ЗАВЕРШЁН')).dy,
        greaterThanOrEqualTo(tester.getBottomLeft(find.byType(AppBar)).dy),
      );
      await capture(tester, 'report_windows');
      final saved = await RunRepository(
        'ui',
        DecisionEngine(stormScenario()),
      ).load();
      expect(saved!.completed, isTrue);
      expect(saved.step, 12);
      expect(saved.commands, hasLength(13));
      expect(saved.commands.where((c) => c.note.isNotEmpty), hasLength(1));
      // Recreate the UI and restore the completed report from storage.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(app(const EpisodeLibraryScreen(userId: 'ui')));
      await tester.pumpAndSettle();
      expect(find.text('Открыть итог и дерево'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('resume-episode')));
      await tester.tap(find.byKey(const Key('resume-episode')));
      await tester.pumpAndSettle();
      expect(find.text('Помощь на месте'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('ЭПИЗОД ЗАВЕРШЁН')).dy,
        greaterThanOrEqualTo(tester.getBottomLeft(find.byType(AppBar)).dy),
      );
      await tester.ensureVisible(find.byKey(const Key('decision-tree')));
      await tester.tap(find.byKey(const Key('decision-tree')));
      await tester.pumpAndSettle();
      expect(find.byType(DecisionTreeScreen), findsOneWidget);
      await capture(tester, 'tree_windows');
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Сразу распределить задачи'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Непосредственный результат из вашего состояния'),
        findsOneWidget,
      );
      await tester.tap(find.text('Закрыть'));
      await tester.pumpAndSettle();
      expect((await repository.load())!.toJson(), saved.toJson());
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('replay-episode')));
      await tester.tap(find.byKey(const Key('replay-episode')));
      await tester.pumpAndSettle();
      expect(find.text('01 / Приём смены'), findsOneWidget);
      final replay = (await repository.load())!;
      expect(replay.runId, isNot(saved.runId));
      expect(replay.completed, isFalse);
      expect(replay.revision, 0);
      expect(replay.commands, isEmpty);
      expect(replay.events, isEmpty);
      expect(replay.values, DecisionEngine.initialValues);
      expect(tester.takeException(), isNull);
    },
  );

  for (final size in [
    const Size(1024, 768),
    const Size(800, 1280),
    const Size(600, 800),
  ]) {
    testWidgets(
      'episode adapts to $size and larger text; reload continues saved state',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final engine = DecisionEngine(stormScenario());
        final repository = RunRepository('tablet', engine);
        final state = engine.apply(engine.start(runId: 'tablet'), 'audit');
        await repository.save(state);
        await tester.pumpWidget(
          app(const EpisodeLibraryScreen(userId: 'tablet'), scale: 1.3),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byKey(const Key('resume-episode')));
        await tester.tap(find.byKey(const Key('resume-episode')));
        await tester.pumpAndSettle();
        expect(find.text('02 / Два донесения'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await capture(tester, 'tablet_${size.width.toInt()}');
        await tester.ensureVisible(find.byKey(const Key('action-observe')));
        await tester.tap(find.byKey(const Key('action-observe')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('confirm-decision')));
        await tester.pumpAndSettle();
        expect(find.text('03 / Цена проверки'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
