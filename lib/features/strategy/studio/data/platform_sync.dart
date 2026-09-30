import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../services/auth_service.dart';
import '../../../../services/user_session_controller.dart';
import 'studio_store.dart';
import 'studio_archive.dart';

String platformId() {
  final r = Random.secure();
  final b = List<int>.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 15) | 64;
  b[8] = (b[8] & 63) | 128;
  final h = b.map((v) => v.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
}

class PlatformFailure implements Exception {
  final int status;
  final String message;
  const PlatformFailure(this.status, this.message);
  @override
  String toString() => message;
}

abstract interface class PlatformTransport {
  Future<Map<String, dynamic>> request(
    String method,
    String path, [
    Map<String, dynamic>? body,
  ]);
}

class PlatformApi implements PlatformTransport {
  final UserSessionController session;
  final String owner;
  final http.Client client;
  final String apiPrefix;
  PlatformApi(this.session, this.owner, {http.Client? client, this.apiPrefix = '/v1/strategy'})
    : client = client ?? http.Client();
  @override
  Future<Map<String, dynamic>> request(
    String method,
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      if (session.currentUser?.id != owner) {
        throw const PlatformFailure(401, 'Профиль изменился');
      }
      final token = await session.tokenForRequest(refresh: attempt == 1);
      if (token == null || session.currentUser?.id != owner) {
        throw const PlatformFailure(401, 'Требуется серверный вход');
      }
      final url = AuthApiConfig.baseUrl;
      if (url.isEmpty) {
        throw const PlatformFailure(503, 'Адрес сервера не настроен');
      }
      final req = http.Request(method, Uri.parse('$url$apiPrefix$path'))
        ..headers.addAll({
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json; charset=utf-8',
        });
      if (body != null) req.body = jsonEncode(body);
      final response = await http.Response.fromStream(
        await client.send(req).timeout(const Duration(seconds: 15)),
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode == 401 && attempt == 0) continue;
      if (response.statusCode >= 400) {
        String message = response.statusCode == 409
            ? 'Конфликт версий: обновите данные'
            : 'Сервер отклонил запрос (${response.statusCode})';
        try {
          final detail = jsonDecode(utf8.decode(response.bodyBytes))['detail'];
          if (detail is String) message = detail;
        } catch (_) {}
        throw PlatformFailure(response.statusCode, message);
      }
      return Map<String, dynamic>.from(
        jsonDecode(utf8.decode(response.bodyBytes)),
      );
    }
    throw const PlatformFailure(401, 'Повторите вход');
  }

  void dispose() => client.close();
}

/// Durable profile-specific mirror and outbox. Transport never changes an open game.
class PlatformSync extends ChangeNotifier {
  final String userId;
  final PlatformTransport api;
  final bool staff;
  PlatformSync(this.userId, this.api, {required this.staff});
  final Map<String, Map<String, dynamic>> records = {};
  final Set<String> localArchiveIds = {};
  List<Map<String, dynamic>> assignments = [], participants = [], actions = [];
  String status = 'Загрузка синхронизации…';
  bool ready = false, busy = false, _disposed = false;
  int _revision = 0;
  String deviceId = platformId();
  Future<void> _writes = Future.value();
  Timer? _timer;
  String get key => 'tactix_platform_v1_${Uri.encodeComponent(userId)}';
  int get pending =>
      records.values.where((r) => r['dirty'] == true).length + actions.length;
  int get conflicts =>
      records.values.where((r) => r['conflict'] != null).length;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _validateRecord(dynamic value, {required bool local}) {
    final record = Map<String, dynamic>.from(value as Map);
    if (record['id'] is! String ||
        !RegExp(r'^[a-zA-Z0-9_-]{1,80}$').hasMatch(record['id']) ||
        record['revision'] is! int ||
        record['revision'] < 0 ||
        record['deleted'] is! bool ||
        (local && record['dirty'] is! bool) ||
        (record['deleted'] == true) != (record['document'] == null)) {
      throw const FormatException('Invalid sync record');
    }
    if (record['document'] != null) {
      StudioDocument.read(Map<String, dynamic>.from(record['document']));
    }
    if (record['conflict'] != null) {
      _validateRecord(record['conflict'], local: false);
    }
  }

  Future<void> restore({bool autoSync = true}) async {
    final prefs = await SharedPreferences.getInstance();
    final generations = <Map<String, dynamic>>[];
    var bad = false;
    for (var slot = 0; slot < 2; slot++) {
      final raw = prefs.getString('$key.$slot');
      if (raw == null) continue;
      try {
        final j = Map<String, dynamic>.from(jsonDecode(raw));
        if (j['version'] != 1 || j['revision'] is! int) {
          throw const FormatException();
        }
        for (final entry in (j['records'] as Map).entries) {
          _validateRecord(entry.value, local: true);
          if (entry.key != entry.value['id']) throw const FormatException();
        }
        if (j['revision'] < 1) throw const FormatException();
        if (j['deviceId'] != null && j['deviceId'] is! String) {
          throw const FormatException();
        }
        List<String>.from(j['localArchiveIds'] ?? []);
        for (final field in ['actions', 'assignments', 'participants']) {
          for (final value in j[field] as List) {
            Map<String, dynamic>.from(value as Map);
          }
        }
        if (j['actions'] is! List ||
            j['assignments'] is! List ||
            j['participants'] is! List) {
          throw const FormatException();
        }
        generations.add(j);
      } catch (_) {
        bad = true;
      }
    }
    if (generations.isEmpty && bad) {
      status = 'Очередь повреждена; синхронизация заблокирована';
      _notify();
      return;
    }
    generations.sort(
      (a, b) => (b['revision'] as int).compareTo(a['revision'] as int),
    );
    if (generations.isNotEmpty) {
      final j = generations.first;
      _revision = j['revision'];
      deviceId = j['deviceId'] as String? ?? deviceId;
      localArchiveIds.addAll(List<String>.from(j['localArchiveIds'] ?? []));
      (j['records'] as Map).forEach(
        (id, r) => records[id as String] = Map<String, dynamic>.from(r),
      );
      assignments = (j['assignments'] as List)
          .map((v) => Map<String, dynamic>.from(v))
          .toList();
      participants = (j['participants'] as List)
          .map((v) => Map<String, dynamic>.from(v))
          .toList();
      actions = (j['actions'] as List)
          .map((v) => Map<String, dynamic>.from(v))
          .toList();
    }
    ready = true;
    status = bad
        ? 'Очередь восстановлена из копии'
        : 'Локальная очередь готова';
    _notify();
    if (autoSync) start();
  }

  void start() {
    if (!ready || _disposed) return;
    _timer ??= Timer.periodic(
      const Duration(seconds: 30),
      (_) => unawaited(sync()),
    );
    unawaited(sync());
  }

  Future<void> retryRecord(String id) async {
    records[id]?.remove('error');
    await _persist();
    _notify();
    await sync();
  }

  Future<void> _persist() {
    final snapshot = jsonEncode({
      'version': 1,
      'revision': ++_revision,
      'deviceId': deviceId,
      'records': records,
      'assignments': assignments,
      'participants': participants,
      'actions': actions,
      'localArchiveIds': localArchiveIds.toList(),
    });
    final revision = _revision;
    final operation = _writes.then((_) async {
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.setString('$key.${revision % 2}', snapshot)) {
        throw StateError('Не удалось записать очередь');
      }
    });
    _writes = operation.then<void>(
      (_) {},
      onError: (Object _) {
        ready = false;
        status = 'Ошибка сохранения очереди · синхронизация остановлена';
        _notify();
      },
    );
    return operation;
  }

  Future<void> captureArchive(List<ArchivedExercise> items) async {
    final ids = items.map((e) => 'a_${e.id}').toSet();
    for (final old in localArchiveIds.difference(ids)) {
      await stage(old, null);
    }
    for (final item in items) {
      final id = 'a_${item.id}';
      // Archive entries are immutable. Do not resurrect a remotely deleted entry
      // or overwrite a conflict resolution with its old local archive snapshot.
      if (!localArchiveIds.contains(id)) await stage(id, item.document);
    }
    localArchiveIds
      ..clear()
      ..addAll(ids);
    await _persist();
  }

  Future<void> stage(String id, StudioDocument? document) async {
    if (!ready) throw StateError('Очередь недоступна');
    final snapshot = document == null
        ? null
        : jsonDecode(jsonEncode(document.toJson()));
    final old = records[id];
    if (old != null &&
        jsonEncode(old['document']) == jsonEncode(snapshot) &&
        old['deleted'] == (document == null)) {
      return;
    }
    records[id] = {
      ...?old,
      'id': id,
      'revision': old?['revision'] ?? 0,
      'document': snapshot,
      'deleted': document == null,
      'dirty': true,
    }..remove('error');
    await _persist();
    status = 'В очереди: $pending';
    _notify();
  }

  Future<void> enqueue(
    String method,
    String path,
    Map<String, dynamic> body,
  ) async {
    if (!ready) throw StateError('Очередь недоступна');
    final requestBody = Map<String, dynamic>.from(body);
    if (path.endsWith('/feedback') || path.endsWith('/deadline')) {
      requestBody.putIfAbsent('request_id', platformId);
    }
    actions.add({
      'id': platformId(),
      'method': method,
      'path': path,
      'body': jsonDecode(jsonEncode(requestBody)),
    });
    await _persist();
    _notify();
    unawaited(sync());
  }

  bool assignmentPending(String id) =>
      actions.any((a) => (a['path'] as String).startsWith('/assignments/$id/'));

  Future<void> retryAction(String id, {bool useLatestRevision = false}) async {
    final action = actions.firstWhere((a) => a['id'] == id);
    if (useLatestRevision) {
      final parts = (action['path'] as String).split('/');
      final assignment = assignments.firstWhere((a) => a['id'] == parts[2]);
      action['body']['base_revision'] = assignment['revision'];
      if (action['body']['request_id'] != null) {
        action['body']['request_id'] = platformId();
      }
    }
    action.remove('error');
    action.remove('errorStatus');
    await _persist();
    _notify();
    await sync();
  }

  Future<void> dismissAction(String id) async {
    actions.removeWhere((a) => a['id'] == id);
    await _persist();
    _notify();
  }

  Future<void> resolve(String id, {required bool keepLocal}) async {
    final local = records[id]!;
    final remote = Map<String, dynamic>.from(local['conflict']);
    final preserve = keepLocal ? remote : local;
    if (preserve['document'] != null) {
      final copyId = 'copy_${platformId()}';
      records[copyId] = {
        'id': copyId,
        'revision': 0,
        'document': preserve['document'],
        'deleted': false,
        'dirty': true,
      };
    }
    records[id] = keepLocal
        ? {...local, 'revision': remote['revision'], 'dirty': true}
        : {...remote, 'dirty': false};
    records[id]!.remove('conflict');
    await _persist();
    _notify();
    await sync();
  }

  Future<void> sync() async {
    if (!ready || busy || _disposed) return;
    busy = true;
    status = 'Синхронизация…';
    _notify();
    try {
      await _writes;
      if (!ready || _disposed) return;
      for (final id in records.keys.toList()) {
        final local = records[id]!;
        if (local['dirty'] != true ||
            local['conflict'] != null ||
            local['error'] != null) {
          continue;
        }
        final captured = jsonEncode(local);
        try {
          final remote = await api.request('PUT', '/records/$id', {
            'base_revision': local['revision'],
            'deleted': local['deleted'],
            if (local['document'] != null) 'document': local['document'],
          });
          if (_disposed) return;
          if (jsonEncode(records[id]) == captured) {
            records[id] = {...remote, 'dirty': false};
          } else {
            records[id]!['revision'] = remote['revision'];
          }
        } on PlatformFailure catch (e) {
          if (e.status == 409) {
            // Fetch the authoritative revision below, preserving any newer edit.
          } else if (e.status == 400 || e.status == 413 || e.status == 422) {
            if (jsonEncode(records[id]) == captured) {
              records[id]!['error'] = e.message;
            }
          } else {
            rethrow;
          }
        }
        await _persist();
      }
      String? after = '';
      do {
        final response = await api.request(
          'GET',
          '/records?after=${Uri.encodeComponent(after!)}',
        );
        if (_disposed) return;
        for (final raw in response['items'] as List) {
          final remote = Map<String, dynamic>.from(raw);
          final id = remote['id'] as String;
          _validateRecord(remote, local: false);
          final local = records[id];
          if (local == null || local['dirty'] != true) {
            records[id] = {...remote, 'dirty': false};
          } else if (remote['revision'] != local['revision']) {
            local['conflict'] = remote;
          }
          local?.remove('awaitingConflict');
        }
        after = response['next'] as String?;
        // Downloaded progress must survive later assignment endpoint failures.
        await _persist();
      } while (after != null);
      for (final action in [...actions]) {
        if (action['error'] != null) continue;
        try {
          final result = await api.request(
            action['method'],
            action['path'],
            Map<String, dynamic>.from(action['body']),
          );
          if (result['id'] != null &&
              result['revision'] is int &&
              result['scenario'] != null) {
            final index = assignments.indexWhere(
              (a) => a['id'] == result['id'],
            );
            if (index < 0) {
              assignments.add(result);
            } else {
              assignments[index] = result;
            }
            // Only chain changes authored against the same known revision.
            for (final next in actions) {
              if (action['body']['base_revision'] is int &&
                  result['revision'] == action['body']['base_revision'] + 1 &&
                  next['id'] != action['id'] &&
                  (next['path'] as String).startsWith(
                    '/assignments/${result['id']}/',
                  ) &&
                  next['body']['base_revision'] ==
                      action['body']['base_revision']) {
                next['body']['base_revision'] = result['revision'];
              }
            }
          }
          actions.removeWhere((a) => a['id'] == action['id']);
        } on PlatformFailure catch (e) {
          if (e.status >= 500 ||
              e.status == 401 ||
              e.status == 408 ||
              e.status == 429) {
            rethrow;
          }
          action['error'] = e.message;
          action['errorStatus'] = e.status;
        }
        if (_disposed) return;
        await _persist();
      }
      assignments =
          ((await api.request('GET', '/assignments'))['items'] as List)
              .map((v) => Map<String, dynamic>.from(v))
              .toList();
      if (staff) {
        participants =
            ((await api.request('GET', '/participants'))['items'] as List)
                .map((v) => Map<String, dynamic>.from(v))
                .toList();
      }
      if (_disposed) return;
      await _persist();
      status = conflicts > 0
          ? 'Конфликты: $conflicts · обе версии сохранены'
          : pending > 0
          ? 'Требуют внимания: $pending'
          : 'Синхронизировано';
    } catch (error) {
      if (!ready) return;
      status = error is PlatformFailure
          ? error.message
          : 'Нет связи · изменения сохранены на устройстве';
    } finally {
      busy = false;
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
