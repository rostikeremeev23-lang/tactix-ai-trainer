import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ai_trainer_mobile/app/theme.dart';
import 'package:ai_trainer_mobile/features/strategy/studio/data/platform_sync.dart';
import 'package:ai_trainer_mobile/features/strategy/studio/data/studio_archive.dart';
import 'package:ai_trainer_mobile/features/strategy/studio/data/studio_store.dart';
import 'package:ai_trainer_mobile/features/strategy/studio/domain/city_scenarios.dart';
import 'package:ai_trainer_mobile/features/strategy/studio/presentation/studio_screen.dart';

import 'city_test.dart' as game;

Map<String, dynamic> clone(Map<String, dynamic> value) =>
    Map<String, dynamic>.from(jsonDecode(jsonEncode(value)));

class Server implements PlatformTransport {
  final Map<String, Map<String, dynamic>> records = {};
  bool offline = false, loseAcknowledgement = false;
  int? rejectRecord, rejectAction;
  int actionCalls = 0;
  Completer<void>? gate;
  @override
  Future<Map<String, dynamic>> request(
    String method,
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    if (offline) throw const PlatformFailure(503, 'Offline');
    if (method == 'PUT' && path.startsWith('/records/')) {
      if (rejectRecord != null) {
        throw PlatformFailure(rejectRecord!, 'Rejected');
      }
      final id = path.split('/').last;
      final old = records[id];
      if (old != null &&
          jsonEncode(old['document']) == jsonEncode(body!['document']) &&
          old['deleted'] == body['deleted']) {
        return clone(old);
      }
      if ((old?['revision'] ?? 0) != body!['base_revision']) {
        throw const PlatformFailure(409, 'Conflict');
      }
      final result = records[id] = {
        'id': id,
        'revision': (old?['revision'] ?? 0) + 1,
        'document': body['document'],
        'deleted': body['deleted'],
      };
      if (gate != null) await gate!.future;
      if (loseAcknowledgement) {
        loseAcknowledgement = false;
        throw const PlatformFailure(503, 'Lost response');
      }
      return clone(result);
    }
    if (method == 'GET' && path.startsWith('/records')) {
      return {'items': records.values.map(clone).toList(), 'next': null};
    }
    if (method == 'GET') return {'items': <Map<String, dynamic>>[]};
    actionCalls++;
    if (rejectAction != null) throw PlatformFailure(rejectAction!, 'Rejected');
    return {'ok': true};
  }
}

StudioDocument doc(int index) => StudioDocument(CityScenarios.create(index));
Future<PlatformSync> client(Server server, [String owner = 'alice']) async {
  final sync = PlatformSync(owner, server, staff: false);
  await sync.restore(autoSync: false);
  return sync;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'offline outbox survives restart and lost acknowledgement is idempotent',
    () async {
      final server = Server()..offline = true;
      final first = await client(server);
      final engine = game.finish(doc(0).scenario);
      final saved = StudioDocument(engine.scenario, engine);
      await first.stage('run', saved);
      await first.sync();
      expect(first.pending, 1);
      final deviceId = first.deviceId;
      first.dispose();
      final restored = await client(server);
      expect(restored.deviceId, deviceId);
      expect(
        StudioDocument.read(restored.records['run']!['document'])
            .engine!
            .report,
        engine.report,
      );
      server
        ..offline = false
        ..loseAcknowledgement = true;
      await restored.sync();
      expect(restored.pending, 1);
      await restored.sync();
      expect(restored.pending, 0);
      expect(server.records['run']!['revision'], 1);
      restored.dispose();
    },
  );

  for (final keepLocal in [true, false]) {
    test(
      'conflict resolution preserves both documents: keepLocal=$keepLocal',
      () async {
        final server = Server();
        final sync = await client(server);
        await sync.stage('shared', doc(0));
        await sync.sync();
        server.records['shared'] = {
          'id': 'shared',
          'revision': 2,
          'deleted': false,
          'document': doc(1).toJson(),
        };
        await sync.stage('shared', doc(2));
        await sync.sync();
        expect(sync.conflicts, 1);
        await sync.resolve('shared', keepLocal: keepLocal);
        expect(sync.conflicts, 0);
        expect(sync.pending, 0);
        expect(
          server.records.values.map((r) => r['document']['scenario']['name']),
          unorderedEquals([doc(1).scenario.name, doc(2).scenario.name]),
        );
        sync.dispose();
      },
    );
  }

  test('archive capture cannot overwrite accepted remote version or resurrect deletion', () async {
    final server = Server();
    final sync = await client(server);
    final item = ArchivedExercise('one', DateTime.utc(2026), doc(0));
    await sync.captureArchive([item]);
    await sync.sync();
    server.records['a_one'] = {
      'id': 'a_one',
      'revision': 2,
      'deleted': true,
      'document': null,
    };
    await sync.sync();
    await sync.captureArchive([item]);
    await sync.sync();
    expect(server.records['a_one']!['deleted'], isTrue);
    expect(sync.pending, 0);
    sync.dispose();
  });

  test(
    'edit during upload retains new payload and advances base revision',
    () async {
      final server = Server()..gate = Completer<void>();
      final sync = await client(server);
      await sync.stage('current', doc(0));
      final uploading = sync.sync();
      while (server.records.isEmpty) {
        await Future<void>.delayed(Duration.zero);
      }
      await sync.stage('current', doc(1));
      server.gate!.complete();
      await uploading;
      expect(sync.records['current']!['dirty'], isTrue);
      expect(sync.records['current']!['revision'], 1);
      await sync.sync();
      expect(
        server.records['current']!['document']['scenario']['name'],
        doc(1).scenario.name,
      );
      expect(sync.pending, 0);
      sync.dispose();
    },
  );

  test('cross-device mirror restores completed simulation without replacing local save', () async {
    final server = Server();
    final a = await client(server);
    final engine = game.finish(doc(0).scenario);
    await a.stage('run', StudioDocument(engine.scenario, engine));
    await a.sync();
    SharedPreferences.setMockInitialValues({});
    final b = await client(server);
    expect(b.deviceId, isNot(a.deviceId));
    await b.sync();
    final restored = StudioDocument.read(b.records['run']!['document']);
    expect(restored.engine!.report, engine.report);
    expect(await StudioStore('alice').load(), isNull);
    a.dispose();
    b.dispose();
  });

  test(
    'corrupt latest generation recovers; two corrupt generations block writes',
    () async {
      final sync = await client(Server());
      await sync.stage('one', doc(0));
      await sync.stage('two', doc(1));
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('${sync.key}.0', 'broken');
      final recovered = await client(Server());
      expect(recovered.ready, isTrue);
      expect(recovered.records.keys, ['one']);
      await prefs.setString('${sync.key}.1', 'broken');
      final blocked = await client(Server());
      expect(blocked.ready, isFalse);
      await expectLater(blocked.stage('x', doc(0)), throwsStateError);
      sync.dispose();
      recovered.dispose();
      blocked.dispose();
    },
  );

  test('profile queues are isolated', () async {
    final a = await client(Server());
    await a.stage('private', doc(0));
    final b = await client(Server(), 'bob');
    expect(b.records, isEmpty);
    a.dispose();
    b.dispose();
  });

  test(
    'invalid record stays visible without blocking downloads and can retry',
    () async {
      final server = Server()..rejectRecord = 422;
      server.records['remote'] = {
        'id': 'remote',
        'revision': 1,
        'document': doc(1).toJson(),
        'deleted': false,
      };
      final sync = await client(server);
      await sync.stage('local', doc(0));
      await sync.sync();
      expect(sync.records['local']!['error'], isNotNull);
      expect(sync.records.containsKey('remote'), isTrue);
      server.rejectRecord = null;
      await sync.retryRecord('local');
      expect(sync.pending, 0);
      sync.dispose();
    },
  );

  test(
    'throttled assignment retries after restart without losing queued request',
    () async {
      final server = Server()..offline = true;
      final sync = await client(server);
      await sync.enqueue('POST', '/assignments', {'id': 'stable-request-id'});
      while (sync.busy) {
        await Future<void>.delayed(Duration.zero);
      }
      sync.dispose();
      final restored = await client(server);
      server
        ..offline = false
        ..rejectAction = 429;
      await restored.sync();
      expect(restored.actions.single['error'], isNull);
      server.rejectAction = null;
      await restored.sync();
      expect(restored.actions, isEmpty);
      expect(server.actionCalls, 2);
      restored.dispose();
    },
  );

  testWidgets(
    'mobile Strategy opens connected platform and imports a remote plan',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final server = Server();
      server.records['remote'] = {
        'id': 'remote',
        'revision': 1,
        'document': doc(1).toJson(),
        'deleted': false,
      };
      final sync = PlatformSync('ui', server, staff: false);
      await tester.pumpWidget(
        MaterialApp(
          theme: TactixTheme.dark,
          home: StrategyStudioScreen(
            userId: 'ui',
            startInLibrary: true,
            platform: sync,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Учебная платформа'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Облако'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Открыть запись'), 250);
      await tester.tap(find.text('Открыть запись'));
      await tester.pumpAndSettle();
      expect(find.text(doc(1).scenario.name), findsWidgets);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      expect((await StudioArchive('ui').load()).isNotEmpty, isTrue);
      sync.dispose();
    },
  );
}
