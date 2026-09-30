import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ai_trainer_mobile/features/thread/thread_store.dart';
import 'package:ai_trainer_mobile/features/strategy/studio/data/platform_sync.dart';

class ThreadTransport implements PlatformTransport {
  bool online = false;
  bool loseResponse = false;
  final rows = <String, Map<String, dynamic>>{};
  final requests = <String, Map<String, dynamic>>{};
  final relations = <String, Map<String, dynamic>>{};
  int accepted = 0;
  Map<String, dynamic> copy(Map<String, dynamic> v) =>
      Map<String, dynamic>.from(jsonDecode(jsonEncode(v)));
  @override
  Future<Map<String, dynamic>> request(
    String method,
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    if (!online) throw const PlatformFailure(503, 'Offline');
    if (method == 'GET') {
      if (path.contains('/events')) return {'items': <dynamic>[], 'next': null};
      if (path.endsWith('/relations') && path.startsWith('/cases/')) {
        final caseId = path.split('/')[2];
        return {
          'items': relations.values
              .where((r) =>
                  (r['from_type'] == 'CASE' && r['from_id'] == caseId) ||
                  (r['to_type'] == 'CASE' && r['to_id'] == caseId))
              .map(copy)
              .toList(),
        };
      }
      if (path.startsWith('/cases/')) return copy(rows[path.split('/')[2]]!);
      return {'items': rows.values.map(copy).toList(), 'next': null};
    }
    final requestId = body!['request_id'] as String;
    if (requests.containsKey(requestId)) return copy(requests[requestId]!);
    if (path == '/relations') {
      final relation = {
        ...body,
        'created_by': 'owner',
        'created_at': '2026-09-30T10:00:00Z',
      };
      relations[body['id'] as String] = relation;
      accepted++;
      requests[requestId] = copy(relation);
      if (loseResponse) {
        loseResponse = false;
        throw const PlatformFailure(503, 'Acknowledgement lost');
      }
      return copy(relation);
    }
    final id = path == '/cases' ? body['id'] as String : path.split('/')[2];
    Map<String, dynamic> row;
    if (path == '/cases') {
      row = {
        ...body,
        'revision': 1,
        'status': 'OPEN',
        'type': 'ISSUE',
        'priority': 'NORMAL',
        'created_at': '2026-09-30T10:00:00Z',
        'updated_at': '2026-09-30T10:00:00Z',
        'owner_id': 'owner',
        'evidence': <dynamic>[],
      };
    } else {
      row = rows[id]!;
      if (row['revision'] != body['base_revision']) {
        throw const PlatformFailure(409, 'Concurrent edit');
      }
      if (method == 'PATCH') row['status'] = body['status'];
      if (path.endsWith('/evidence')) {
        (row['evidence'] as List).add({
          ...body,
          'verification_state': 'UNVERIFIED',
        });
      }
      if (path.endsWith('/verify')) {
        final evidence = (row['evidence'] as List).firstWhere(
          (e) => e['id'] == path.split('/')[4],
        );
        evidence['verification_state'] = body['state'];
      }
      row['revision'] = (row['revision'] as int) + 1;
    }
    rows[id] = row;
    accepted++;
    requests[requestId] = copy(row);
    if (loseResponse) {
      loseResponse = false;
      throw const PlatformFailure(503, 'Acknowledgement lost');
    }
    return copy(row);
  }
}

Future<void> idle(ThreadStore store) async {
  while (store.syncing) {
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'offline Case/status/evidence survive restart and sync in order',
    () async {
      final api = ThreadTransport();
      var store = ThreadStore('owner', api: api);
      await store.restore(autoSync: false);
      final id = await store.create('Training gap', 'Observed during review');
      await store.changeStatus(id, 'WAITING_FOR_EVIDENCE', 'Task completed');
      await store.addEvidence(id, 'Report', 'Observed result', 'Local record');
      await idle(store);
      expect(store.pending.length, 3);
      store.dispose();
      store = ThreadStore('owner', api: api);
      await store.restore(autoSync: false);
      expect(store.caseById(id)!['status'], 'WAITING_FOR_EVIDENCE');
      expect(store.caseById(id)!['evidence'], hasLength(1));
      expect(store.caseById(id)!['verification_state'], 'UNVERIFIED');
      api.online = true;
      await store.sync();
      expect(store.pending, isEmpty);
      expect(api.rows[id]!['revision'], 3);
      expect(api.accepted, 3);
      store.dispose();
    },
  );

  test(
    'lost acknowledgement reuses request ID without duplicate mutation',
    () async {
      final api = ThreadTransport()
        ..online = true
        ..loseResponse = true;
      final store = ThreadStore('owner', api: api);
      await store.restore(autoSync: false);
      await store.create('Test', 'Context');
      await idle(store);
      expect(store.pending, hasLength(1));
      await store.sync();
      expect(store.pending, isEmpty);
      expect(api.accepted, 1);
      store.dispose();
    },
  );

  test(
    'conflict preserves draft and requires review of exact current revision',
    () async {
      final api = ThreadTransport()..online = true;
      var store = ThreadStore('owner', api: api);
      await store.restore(autoSync: false);
      final id = await store.create('Test', 'Context');
      await idle(store);
      api.online = false;
      await store.changeStatus(id, 'IN_PROGRESS', 'My draft');
      await idle(store);
      api.rows[id]!['revision'] = 2;
      api.rows[id]!['status'] = 'IN_REVIEW';
      api.online = true;
      await store.sync();
      expect(store.pending.single['error'], contains('409'));
      expect(store.caseById(id)!['status'], 'IN_PROGRESS');
      expect(store.confirmedCase(id)!['status'], 'IN_REVIEW');
      store.dispose();
      store = ThreadStore('owner', api: api);
      await store.restore(autoSync: false);
      expect(store.pending.single['body']['note'], 'My draft');
      await expectLater(
        store.retryAfterReview(id, reviewedRevision: 1),
        throwsStateError,
      );
      await store.retryAfterReview(id, reviewedRevision: 2);
      expect(store.pending, isEmpty);
      expect(api.rows[id]!['status'], 'IN_PROGRESS');
      expect(api.rows[id]!['revision'], 3);
      store.dispose();
    },
  );

  test(
    'verification and closure never appear confirmed while offline',
    () async {
      final api = ThreadTransport()..online = true;
      final store = ThreadStore('owner', api: api, staff: true);
      await store.restore(autoSync: false);
      final id = await store.create('Test', 'Context');
      await idle(store);
      await store.addEvidence(id, 'Note', 'Observation', '');
      await idle(store);
      final eid = store.caseById(id)!['evidence'][0]['id'];
      api.online = false;
      await store.verify(id, eid, 'VERIFIED', 'Checked');
      await store.changeStatus(id, 'CLOSED', 'Done');
      await idle(store);
      expect(store.caseById(id)!['verification_state'], 'UNVERIFIED');
      expect(store.caseById(id)!['status'], 'OPEN');
      api.online = true;
      await store.sync();
      expect(store.pending, isEmpty);
      expect(store.caseById(id)!['verification_state'], 'VERIFIED');
      expect(store.caseById(id)!['status'], 'CLOSED');
      store.dispose();
    },
  );

  test('offline relation survives restart and synchronizes without changing Case revision', () async {
    final api = ThreadTransport();
    var store = ThreadStore('owner', api: api);
    await store.restore(autoSync: false);
    final a = await store.create('A', 'First Case');
    final b = await store.create('B', 'Second Case');
    await idle(store);
    await store.createRelation(
      a,
      fromType: 'CASE',
      fromId: a,
      toType: 'CASE',
      toId: b,
      relationshipType: 'RELATED_TO',
    );
    await idle(store);
    expect(store.relations, hasLength(1));
    expect(store.relations.single['pending'], isTrue);
    store.dispose();

    store = ThreadStore('owner', api: api);
    await store.restore(autoSync: false);
    expect(store.relations, hasLength(1));
    api.online = true;
    await store.sync();
    expect(store.pending, isEmpty);
    expect(store.relations.single['pending'], isNull);
    expect(api.relations, hasLength(1));
    expect(api.rows[a]!['revision'], 1);
    expect(api.rows[b]!['revision'], 1);
    store.dispose();
  });


  test('training link is durable offline and marks Case as training required', () async {
    final api = ThreadTransport();
    var store = ThreadStore('owner', api: api, staff: true);
    await store.restore(autoSync: false);
    final id = await store.create('Training gap', 'Needs Simulation Lab practice');
    await idle(store);
    final assignmentId = '11111111-1111-4111-8111-111111111111';
    await store.linkTraining(id, assignmentId);
    await idle(store);
    expect(store.relations.single['to_type'], 'TRAINING');
    expect(store.relations.single['to_id'], assignmentId);
    expect(store.caseById(id)!['status'], 'TRAINING_REQUIRED');
    store.dispose();

    store = ThreadStore('owner', api: api, staff: true);
    await store.restore(autoSync: false);
    expect(store.relations.single['to_type'], 'TRAINING');
    expect(store.caseById(id)!['status'], 'TRAINING_REQUIRED');
    api.online = true;
    await store.sync();
    expect(store.pending, isEmpty);
    expect(api.rows[id]!['status'], 'TRAINING_REQUIRED');
    store.dispose();
  });

  test('different profiles cannot load each others local cases', () async {
    final a = ThreadStore('a');
    await a.restore(autoSync: false);
    await a.create('Private', 'Context');
    final b = ThreadStore('b');
    await b.restore(autoSync: false);
    expect(b.cases, isEmpty);
    expect(
      () => b.verify('missing', 'missing', 'VERIFIED', 'review'),
      throwsStateError,
    );
    a.dispose();
    b.dispose();
  });

  test('unreadable storage is retained and new writes are blocked', () async {
    SharedPreferences.setMockInitialValues({
      'tactix.thread.v1.a.0': 'not json',
    });
    final store = ThreadStore('a');
    await store.restore(autoSync: false);
    expect(store.ready, isFalse);
    expect(store.error, contains('preserved'));
    await expectLater(store.create('Test', 'Context'), throwsStateError);
    expect(
      (await SharedPreferences.getInstance()).getString('tactix.thread.v1.a.0'),
      'not json',
    );
    store.dispose();
  });
}
