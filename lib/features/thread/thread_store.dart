import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../strategy/studio/data/platform_sync.dart';

/// Uses the existing authenticated PlatformTransport and two-generation local
/// persistence pattern. Case commands never overwrite simulator snapshots.
class ThreadStore extends ChangeNotifier {
  ThreadStore(this.userId, {this.api, this.staff = false});
  final String userId;
  final PlatformTransport? api;
  final bool staff;
  Map<String, dynamic> _state = {
    'cases': <String, dynamic>{},
    'events': <String, dynamic>{},
    'queue': <dynamic>[],
    'relations': <dynamic>[],
  };
  int _generation = 0;
  bool ready = false, syncing = false, _disposed = false;
  String? error;
  Timer? _timer;
  Future<void>? _syncRequest;
  String? get recoveryWarning => _state['recovery_warning'] as String?;
  Future<void> _writes = Future.value();
  String get key => 'tactix.thread.v1.$userId';
  List<Map<String, dynamic>> get pending => (_state['queue'] as List)
      .map((e) => Map<String, dynamic>.from(e))
      .toList();
  Map<String, dynamic> _copy(Map<String, dynamic> value) =>
      Map<String, dynamic>.from(jsonDecode(jsonEncode(value)));
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> restore({bool autoSync = true}) async {
    final prefs = await SharedPreferences.getInstance();
    final candidates = <Map<String, dynamic>>[];
    var found = false;
    final rawCopies = <String, String>{};
    for (final slot in [0, 1]) {
      final raw = prefs.getString('$key.$slot');
      if (raw == null) continue;
      found = true;
      rawCopies['$key.$slot'] = raw;
      try {
        final data = Map<String, dynamic>.from(jsonDecode(raw));
        if (data['version'] != 1 ||
            data['generation'] is! int ||
            data['state'] is! Map) {
          continue;
        }
        final state = data['state'] as Map;
        if (state['cases'] is! Map ||
            state['events'] is! Map ||
            state['queue'] is! List) {
          continue;
        }
        if ((state['cases'] as Map).values.any(
          (v) => v is! Map || v['id'] is! String || v['revision'] is! int,
        )) {
          continue;
        }
        if ((state['queue'] as List).any(
          (v) =>
              v is! Map ||
              v['body'] is! Map ||
              v['case_id'] is! String ||
              v['path'] is! String ||
              v['method'] is! String,
        )) {
          continue;
        }
        if (state['relations'] != null &&
            (state['relations'] is! List ||
                (state['relations'] as List).any(
                  (v) =>
                      v is! Map ||
                      v['id'] is! String ||
                      v['from_type'] is! String ||
                      v['from_id'] is! String ||
                      v['to_type'] is! String ||
                      v['to_id'] is! String ||
                      v['relationship_type'] is! String,
                ))) {
          continue;
        }
        candidates.add(data);
      } catch (_) {
        /* Preserve unreadable generations for recovery. */
      }
    }
    if (found && candidates.isEmpty) {
      error =
          'Local Thread data could not be read. Original copies are preserved.';
      _notify();
      return;
    }
    candidates.sort(
      (a, b) => (b['generation'] as int).compareTo(a['generation'] as int),
    );
    if (candidates.isNotEmpty) {
      _generation = candidates.first['generation'];
      _state = Map<String, dynamic>.from(candidates.first['state']);
    }
    _state['relations'] ??= <dynamic>[];
    if (candidates.length < rawCopies.length) {
      final recoveryId = platformId();
      for (final entry in rawCopies.entries) {
        if (!await prefs.setString(
          '${entry.key}.recovery.$recoveryId',
          entry.value,
        )) {
          error = 'Recovery backup failed. Original data is preserved; writes are blocked.';
          _notify();
          return;
        }
      }
      _state['recovery_warning'] = 'Recovered an older valid local copy. Unreadable copies were backed up; the newest actions may need recovery.';
    }
    ready = true;
    _notify();
    if (autoSync && api != null && !_disposed) {
      _timer = Timer.periodic(
        const Duration(seconds: 30),
        (_) => unawaited(sync()),
      );
      unawaited(sync());
    }
  }

  Future<void> _change(void Function() mutate) {
    final operation = _writes.then((_) async {
      final before = _copy(_state);
      try {
        mutate();
        final generation = _generation + 1;
        final raw = jsonEncode({
          'version': 1,
          'generation': generation,
          'state': _state,
        });
        final prefs = await SharedPreferences.getInstance();
        if (!await prefs.setString('$key.${generation % 2}', raw)) {
          throw StateError('Local save failed. Action was not recorded.');
        }
        _generation = generation;
      } catch (_) {
        _state = before;
        rethrow;
      }
      _notify();
    });
    _writes = operation.catchError((Object _) {});
    return operation;
  }

  List<Map<String, dynamic>> get cases {
    final result = (_state['cases'] as Map).keys
        .map((id) => caseById(id as String)!)
        .toList();
    result.sort(
      (a, b) =>
          (b['updated_at'] as String).compareTo(a['updated_at'] as String),
    );
    return result;
  }

  Map<String, dynamic>? confirmedCase(String id) {
    final row = _state['cases'][id];
    return row == null ? null : _copy(Map<String, dynamic>.from(row));
  }

  Map<String, dynamic>? caseById(String id) {
    final raw = _state['cases'][id];
    if (raw == null) return null;
    final result = _copy(Map<String, dynamic>.from(raw));
    for (final op in pending.where((e) => e['case_id'] == id)) {
      final body = op['body'] as Map;
      if (op['entity'] != 'relation' &&
          op['method'] == 'PATCH' &&
          body.containsKey('status') &&
          body['status'] != 'CLOSED') {
        result['status'] = body['status'];
      }
      if (op['entity'] != 'relation' &&
          (op['path'] as String).endsWith('/evidence')) {
        (result['evidence'] as List).add({
          ...body,
          'verification_state': 'UNVERIFIED',
          'pending': true,
        });
      }
    }
    final evidence = result['evidence'] as List;
    result['verification_state'] =
        evidence.isNotEmpty &&
            evidence.every((e) => e['verification_state'] == 'VERIFIED')
        ? 'VERIFIED'
        : 'UNVERIFIED';
    return result;
  }

  List<Map<String, dynamic>> events(String id) =>
      ((_state['events'][id] ?? []) as List)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

  List<Map<String, dynamic>> get relations =>
      ((_state['relations'] ?? <dynamic>[]) as List)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

  List<Map<String, dynamic>> relationsForCase(String id) => relations
      .where((r) =>
          (r['from_type'] == 'CASE' && r['from_id'] == id) ||
          (r['to_type'] == 'CASE' && r['to_id'] == id) ||
          ((caseById(id)?['evidence'] as List?) ?? const <dynamic>[])
              .any((e) =>
                  (r['from_type'] == 'EVIDENCE' && r['from_id'] == e['id']) ||
                  (r['to_type'] == 'EVIDENCE' && r['to_id'] == e['id'])))
      .toList();

  Future<String> create(
    String title,
    String description, {
    String priority = 'NORMAL',
    DateTime? due,
  }) async {
    if (!ready) throw StateError('Thread is not ready');
    final id = platformId();
    final body = <String, dynamic>{
      'id': id,
      'request_id': platformId(),
      'title': title.trim(),
      'description': description.trim(),
      'priority': priority,
      if (due != null) 'due_date': due.toUtc().toIso8601String(),
    };
    if (title.trim().isEmpty ||
        title.trim().length > 200 ||
        description.trim().length > 8000) {
      throw ArgumentError('Check title and description');
    }
    final date = DateTime.now().toUtc().toIso8601String();
    await _change(() {
      _state['cases'][id] = {
        ...body,
        'revision': 0,
        'status': 'OPEN',
        'type': 'ISSUE',
        'owner_id': userId,
        'created_by': userId,
        'created_at': date,
        'updated_at': date,
        'evidence': <dynamic>[],
      };
      (_state['queue'] as List).add({
        'case_id': id,
        'method': 'POST',
        'path': '/cases',
        'body': body,
      });
    });
    unawaited(sync());
    return id;
  }

  Future<void> _enqueue(
    String id,
    String method,
    String path,
    Map<String, dynamic> body,
  ) async {
    if (!ready) throw StateError('Thread is not ready');
    await _change(() {
      final row = _state['cases'][id] as Map;
      final revision =
          (row['revision'] as int) +
          pending
              .where((e) => e['case_id'] == id && e['entity'] != 'relation')
              .length;
      (_state['queue'] as List).add({
        'case_id': id,
        'method': method,
        'path': path,
        'body': {
          ...body,
          'request_id': platformId(),
          'base_revision': revision,
        },
      });
    });
    unawaited(sync());
  }

  Future<void> changeStatus(String id, String status, String note) =>
      _enqueue(id, 'PATCH', '/cases/$id', {'status': status, 'note': note});
  Future<void> addEvidence(
    String id,
    String title,
    String description,
    String source,
  ) => _enqueue(id, 'POST', '/cases/$id/evidence', {
    'id': platformId(),
    'title': title,
    'description': description,
    'source': source,
    'type': 'NOTE',
  });
  Future<void> verify(String id, String evidenceId, String state, String note) {
    if (!staff || api == null) {
      throw StateError('Server instructor access required');
    }
    return _enqueue(id, 'POST', '/cases/$id/evidence/$evidenceId/verify', {
      'state': state,
      'note': note,
    });
  }

  Future<String> createRelation(
    String rootCaseId, {
    required String fromType,
    required String fromId,
    required String toType,
    required String toId,
    required String relationshipType,
  }) async {
    if (!ready) throw StateError('Thread is not ready');
    if (fromType == toType && fromId == toId) {
      throw ArgumentError('A relation cannot point to itself');
    }
    if (caseById(rootCaseId) == null) {
      throw ArgumentError('Root Case is not available');
    }
    final id = platformId();
    final body = <String, dynamic>{
      'id': id,
      'request_id': platformId(),
      'from_type': fromType,
      'from_id': fromId,
      'to_type': toType,
      'to_id': toId,
      'relationship_type': relationshipType,
    };
    await _change(() {
      (_state['relations'] as List).add({
        ...body,
        'created_by': userId,
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'pending': true,
      });
      (_state['queue'] as List).add({
        'case_id': rootCaseId,
        'entity': 'relation',
        'method': 'POST',
        'path': '/relations',
        'body': body,
      });
    });
    unawaited(sync());
    return id;
  }

  Future<void> loadRelations(String caseId) async {
    if (api == null || !ready) return;
    final response = await api!.request('GET', '/cases/$caseId/relations');
    final remote = (response['items'] as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    await _change(() {
      final pendingIds = pending
          .where((e) => e['entity'] == 'relation')
          .map((e) => e['body']['id'])
          .toSet();
      final list = (_state['relations'] as List);
      list.removeWhere((e) {
        final relation = e as Map;
        final touches =
            (relation['from_type'] == 'CASE' && relation['from_id'] == caseId) ||
            (relation['to_type'] == 'CASE' && relation['to_id'] == caseId);
        return touches && !pendingIds.contains(relation['id']);
      });
      final ids = list.map((e) => (e as Map)['id']).toSet();
      for (final relation in remote) {
        if (ids.add(relation['id'])) list.add(relation);
      }
    });
  }

  Future<void> loadEvents(String id) async {
    if (api == null || !ready) return;
    final current = events(id);
    final after = current.isEmpty ? 0 : current.last['revision'];
    final response = await api!.request(
      'GET',
      '/cases/$id/events?after=$after',
    );
    await _change(() {
      final list = (_state['events'][id] ??= <dynamic>[]) as List;
      final ids = list.map((e) => e['id']).toSet();
      list.addAll(
        (response['items'] as List).where((e) => !ids.contains(e['id'])),
      );
    });
  }

  /// Explicit user review is required before this method is called. Both the
  /// failed draft and its prior revision remain in the operation's review log.
  Future<void> retryAfterReview(
    String id, {
    required int reviewedRevision,
  }) async {
    if (api == null) return;
    final remote = await api!.request('GET', '/cases/$id');
    if (remote['revision'] != reviewedRevision) {
      throw StateError('Case changed since review. Refresh and review again.');
    }
    await _change(() {
      _state['cases'][id] = remote;
      var revision = remote['revision'] as int;
      for (final op in _state['queue'] as List) {
        if (op['case_id'] != id || op['entity'] == 'relation') continue;
        if (op['path'] == '/cases') {
          throw StateError('Creation conflict needs administrator review');
        }
        (_state['conflict_history'] ??= <dynamic>[]).add({
          'case_id': id,
          'body': _copy(Map<String, dynamic>.from(op['body'])),
          'remote_revision': revision,
          'at': DateTime.now().toUtc().toIso8601String(),
        });
        op['body']['base_revision'] = revision++;
        op['body']['request_id'] = platformId();
        op.remove('error');
      }
    });
    await sync();
  }

  Future<void> sync() {
    if (_syncRequest != null) return _syncRequest!;
    final request = _syncOnce();
    _syncRequest = request.whenComplete(() => _syncRequest = null);
    return _syncRequest!;
  }

  Future<void> _syncOnce() async {
    if (!ready || api == null || syncing || _disposed) return;
    syncing = true;
    error = null;
    _notify();
    try {
      final blocked = <String>{};
      for (final op in pending) {
        if (_disposed) return;
        final id = op['case_id'] as String;
        if (op['error'] != null || blocked.contains(id)) {
          blocked.add(id);
          continue;
        }
        try {
          final response = await api!.request(
            op['method'],
            op['path'],
            Map<String, dynamic>.from(op['body']),
          );
          await _change(() {
            if (op['entity'] == 'relation') {
              final list = (_state['relations'] as List);
              list.removeWhere((e) => (e as Map)['id'] == response['id']);
              list.add(response);
            } else {
              _state['cases'][id] = response;
            }
            (_state['queue'] as List).removeWhere(
              (e) => e['body']['request_id'] == op['body']['request_id'],
            );
          });
        } on PlatformFailure catch (failure) {
          if (![403, 404, 409, 422].contains(failure.status)) rethrow;
          blocked.add(id);
          await _change(() {
            final live = (_state['queue'] as List).firstWhere(
              (e) => e['body']['request_id'] == op['body']['request_id'],
            );
            live['error'] = '${failure.status}: ${failure.message}';
          });
        }
      }
      // Paged transport; refresh never replaces pending drafts.
      String? after;
      final downloaded = <String, dynamic>{};
      do {
        final page = await api!.request(
          'GET',
          '/cases${after == null ? '' : '?after=$after'}',
        );
        for (final row in page['items'] as List) {
          downloaded[row['id']] = row;
        }
        after = page['next'] as String?;
      } while (after != null && !_disposed);
      if (!_disposed) {
        await _change(() {
          final queuedIds = pending.map((e) => e['case_id']).toSet();
          (_state['cases'] as Map).removeWhere(
            (id, row) => !queuedIds.contains(id) && !downloaded.containsKey(id),
          );
          (_state['events'] as Map).removeWhere(
            (id, _) =>
                !(_state['cases'] as Map).containsKey(id) &&
                !downloaded.containsKey(id),
          );
          for (final entry in downloaded.entries) {
            _state['cases'][entry.key] = entry.value;
          }
        });
      }
    } catch (failure) {
      error = 'Sync unavailable. Local work retained. $failure';
    } finally {
      syncing = false;
      _notify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}
