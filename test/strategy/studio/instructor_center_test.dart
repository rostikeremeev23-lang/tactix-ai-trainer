import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ai_trainer_mobile/app/theme.dart';
import 'package:ai_trainer_mobile/features/strategy/studio/data/platform_sync.dart';
import 'package:ai_trainer_mobile/features/strategy/studio/data/studio_store.dart';
import 'package:ai_trainer_mobile/features/strategy/studio/domain/city_scenarios.dart';
import 'package:ai_trainer_mobile/features/strategy/studio/domain/training_summary.dart';
import 'package:ai_trainer_mobile/features/strategy/studio/presentation/platform_screen.dart';

import 'city_test.dart' as game;

class Classroom {
  final Map<String, Map<String, dynamic>> assignments = {};
  bool offline = false;
}

class ClassroomApi implements PlatformTransport {
  final Classroom room;
  final bool staff;
  ClassroomApi(this.room, this.staff);
  Map<String, dynamic> copy(Map<String, dynamic> value) =>
      jsonDecode(jsonEncode(value));
  @override
  Future<Map<String, dynamic>> request(
    String method,
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    if (room.offline) throw const PlatformFailure(503, 'Нет связи');
    if (path.startsWith('/records')) return {'items': [], 'next': null};
    if (path == '/participants') {
      return {
        'items': [
          {
            'id': 'learner',
            'name': 'Учебный участник',
            'callsign': 'АЛЬФА',
            'managed': true,
          },
        ],
      };
    }
    if (method == 'GET') {
      return {'items': room.assignments.values.map(copy).toList()};
    }
    if (path == '/assignments') {
      if (!staff) throw const PlatformFailure(403, 'Нет прав');
      final a = <String, dynamic>{
        ...body!,
        'revision': 1,
        'instructor_id': 'teacher',
        'status': 'assigned',
        'feedback': '',
        'submission': null,
        'metrics': null,
        'history': [],
        'created_at': '2026-09-01T12:00:00Z',
        'updated_at': '2026-09-01T12:00:00Z',
      };
      room.assignments[a['id']] = a;
      return copy(a);
    }
    final a = room.assignments[path.split('/')[2]]!;
    if (a['revision'] != body!['base_revision']) {
      throw const PlatformFailure(409, 'Конфликт версий');
    }
    if (path.endsWith('/submit')) {
      if (staff) throw const PlatformFailure(403, 'Нет прав');
      final doc = StudioDocument.read(
        Map<String, dynamic>.from(body['document']),
      );
      a.addAll({
        'submission': body['document'],
        'status': doc.engine!.completed ? 'submitted' : 'in_progress',
        'submitted_at': '2026-09-02T12:00:00Z',
        'metrics': {
          'tick': doc.engine!.current.tick,
          'score': doc.engine!.score,
          'completed': doc.engine!.completed,
        },
      });
    } else if (path.endsWith('/feedback')) {
      if (!staff) throw const PlatformFailure(403, 'Нет прав');
      a.addAll({
        'feedback': body['feedback'],
        'feedback_at': '2026-09-03T12:00:00Z',
      });
    }
    a['revision']++;
    return copy(a);
  }
}

Future<PlatformSync> open(Classroom room, bool staff) async {
  final sync = PlatformSync(
    staff ? 'teacher' : 'learner',
    ClassroomApi(room, staff),
    staff: staff,
  );
  await sync.restore(autoSync: false);
  await sync.sync();
  return sync;
}

Widget app(PlatformSync sync, StudioDocument document) => MaterialApp(
  theme: TactixTheme.dark,
  home: RepaintBoundary(
    key: const Key('instructor-capture'),
    child: StrategyPlatformScreen(sync: sync, current: document),
  ),
);

Future<void> capture(WidgetTester tester, String name) async {
  if (!const bool.fromEnvironment('CAPTURE_INSTRUCTOR')) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('instructor-capture')),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory('artifacts/instructor').create(recursive: true);
    await File('artifacts/instructor/$name.png')
        .writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  setUpAll(() async {
    if (!const bool.fromEnvironment('CAPTURE_INSTRUCTOR')) return;
    await (FontLoader('Arial')..addFont(
          File('C:/Windows/Fonts/arial.ttf')
              .readAsBytes()
              .then((v) => ByteData.sublistView(v)),
        ))
        .load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'transparent completion and pending review exclude cancelled assignments',
    () {
      final scenario = CityScenarios.create(0).toJson();
      final summary = TrainingSummary([
        {'status': 'assigned', 'scenario': scenario},
        {'status': 'submitted', 'scenario': scenario, 'feedback': ''},
        {'status': 'cancelled', 'scenario': scenario},
      ]);
      expect(summary.eligible, 2);
      expect(summary.completion, .5);
      expect(summary.awaitingFeedback, 1);
      expect(summary.active, 1);
      expect(TrainingSummary([]).completion, 0);
      expect(
        TrainingSummary.progress({
          'status': 'in_progress',
          'scenario': {'duration': 40},
          'metrics': {'tick': 20},
        }),
        .5,
      );
      expect(
        TrainingSummary.needsFeedback({
          'status': 'submitted',
          'feedback': 'Old review',
          'submitted_at': '2026-09-03T00:00:00Z',
          'feedback_at': '2026-09-01T00:00:00Z',
        }),
        isTrue,
      );
    },
  );

  testWidgets(
    'instructor creates, learner submits offline, restart restores, instructor reviews, learner receives feedback',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final room = Classroom();
      final teacher = await open(room, true);
      await tester.pumpWidget(
        app(teacher, StudioDocument(CityScenarios.create(0))),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Новое назначение'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Назначить'));
      await tester.pumpAndSettle();
      expect(room.assignments.length, 1);
      final a = room.assignments.values.single;
      await tester.pumpWidget(const SizedBox());
      teacher.dispose();
      final learner = await open(room, false);
      final engine = game.finish(CityScenarios.create(0));
      final doc = StudioDocument(engine.scenario, engine, a['id']);
      room.offline = true;
      await tester.pumpWidget(app(learner, doc));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Задания'));
      await tester.pumpAndSettle();
      expect(find.text('Новое назначение'), findsNothing);
      await tester.ensureVisible(find.text('Сдать результат'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Сдать результат'));
      await tester.pumpAndSettle();
      expect(learner.actions.length, 1);
      expect(a['status'], 'assigned');
      await tester.pumpWidget(const SizedBox());
      learner.dispose();
      room.offline = false;
      final restored = await open(room, false);
      expect(restored.actions, isEmpty);
      expect(restored.assignments.single['status'], 'submitted');
      restored.dispose();
      final reviewer = await open(room, true);
      await tester.pumpWidget(app(reviewer, doc));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Написать отзыв'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Написать отзыв'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField),
        'Объясните распределение ресурсов.',
      );
      await tester.tap(find.text('Сохранить отзыв'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(
        room.assignments.values.single['feedback'],
        'Объясните распределение ресурсов.',
      );
      await tester.pumpWidget(const SizedBox());
      reviewer.dispose();
      final finalLearner = await open(room, false);
      expect(
        finalLearner.assignments.single['feedback'],
        'Объясните распределение ресурсов.',
      );
      await tester.pumpWidget(app(finalLearner, doc));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.text('Объясните распределение ресурсов.'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Объясните распределение ресурсов.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      finalLearner.dispose();
    },
  );

  for (final size in [
    const Size(390, 844),
    const Size(1024, 768),
    const Size(1440, 900),
  ]) {
    testWidgets(
      'dashboard, roster, analytics and comparison responsive at $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final room = Classroom();
        final engine = game.finish(CityScenarios.create(0));
        for (var i = 0; i < 2; i++) {
          room.assignments['a$i'] = {
            'id': 'a$i',
            'learner_id': 'learner',
            'revision': 2,
            'scenario': engine.scenario.toJson(),
            'status': 'submitted',
            'feedback': '',
            'metrics': {'score': engine.score, 'tick': engine.current.tick},
            'submission': StudioDocument(
              engine.scenario,
              engine,
              'a$i',
            ).toJson(),
            'submitted_at': '2026-09-0${i + 1}T12:00:00Z',
            'history': [],
          };
        }
        final sync = await open(room, true);
        await tester.pumpWidget(app(sync, StudioDocument(engine.scenario)));
        await tester.pumpAndSettle();
        expect(find.text('Пространство развития'), findsOneWidget);
        await capture(tester, 'overview_${size.width.toInt()}');
        await tester.tap(find.text('Участники'));
        await tester.pumpAndSettle();
        expect(find.text('АЛЬФА · Учебный участник'), findsOneWidget);
        await tester.tap(find.text('Результаты'));
        await tester.pumpAndSettle();
        await capture(tester, 'analytics_${size.width.toInt()}');
        await tester.ensureVisible(find.byType(CheckboxListTile).first);
        await tester.pumpAndSettle();
        await tester.tap(find.byType(CheckboxListTile).first);
        await tester.ensureVisible(find.byType(CheckboxListTile).last);
        await tester.pumpAndSettle();
        await tester.tap(find.byType(CheckboxListTile).last);
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Сравнить (2/2)'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Сравнить (2/2)'));
        await tester.pumpAndSettle();
        expect(find.text('Сравнение занятий'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        sync.dispose();
      },
    );
  }

  test(
    'stale feedback remains durable and explicit retry uses refreshed revision',
    () async {
      final room = Classroom();
      final sync = await open(room, true);
      await sync.enqueue('POST', '/assignments', {
        'id': 'one',
        'learner_id': 'learner',
        'scenario': CityScenarios.create(0).toJson(),
      });
      while (sync.busy) {
        await Future<void>.delayed(Duration.zero);
      }
      room.assignments['one']!['revision'] = 2;
      await sync.enqueue('PATCH', '/assignments/one/feedback', {
        'base_revision': 1,
        'feedback': 'Preserve my draft',
      });
      while (sync.busy) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(sync.actions.single['errorStatus'], 409);
      final request = sync.actions.single['body']['request_id'];
      sync.dispose();
      final restored = await open(room, true);
      expect(restored.actions.single['body']['feedback'], 'Preserve my draft');
      await restored.retryAction(
        restored.actions.single['id'],
        useLatestRevision: true,
      );
      expect(restored.actions, isEmpty);
      expect(room.assignments['one']!['feedback'], 'Preserve my draft');
      expect(request, isNotNull);
      restored.dispose();
    },
  );
}
