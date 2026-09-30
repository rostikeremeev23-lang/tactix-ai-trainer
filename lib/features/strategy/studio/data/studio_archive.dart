import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'studio_store.dart';

class ArchivedExercise {
  final String id;
  final DateTime savedAt;
  final StudioDocument document;
  ArchivedExercise(this.id, this.savedAt, this.document);
  Map<String, dynamic> toJson() => {
    'id': id,
    'savedAt': savedAt.toUtc().toIso8601String(),
    'document': document.toJson(),
  };
  factory ArchivedExercise.read(Map<String, dynamic> j) => ArchivedExercise(
    j['id'] as String,
    DateTime.parse(j['savedAt'] as String),
    StudioDocument.read(Map<String, dynamic>.from(j['document'])),
  );
}

/// Local, profile-isolated archive. Two validated generations; no silent eviction.
class StudioArchive {
  final String userId;
  StudioArchive(this.userId);
  String get key => 'tactix_city_archive_v1_${Uri.encodeComponent(userId)}';
  static final Map<String, Future<void>> _queues = {};
  String? recoveryMessage;

  List<Map<String, dynamic>> _generations(SharedPreferences prefs) {
    recoveryMessage = null;
    final good = <Map<String, dynamic>>[];
    for (var slot = 0; slot < 2; slot++) {
      final raw = prefs.getString('$key.$slot');
      if (raw == null) continue;
      try {
        final j = Map<String, dynamic>.from(jsonDecode(raw));
        if (j['version'] != 1 ||
            j['revision'] is! int ||
            j['revision'] < 1 ||
            (j['items'] as List).length > 40) {
          throw const FormatException();
        }
        for (final item in j['items'] as List) {
          ArchivedExercise.read(Map<String, dynamic>.from(item));
        }
        good.add(j);
      } catch (_) {
        recoveryMessage = 'Архив восстановлен из резервной копии.';
      }
    }
    if (good.isEmpty && recoveryMessage != null) {
      throw const FormatException('Архив повреждён; данные не перезаписаны');
    }
    good.sort((a, b) => (b['revision'] as int).compareTo(a['revision'] as int));
    return good;
  }

  Future<List<ArchivedExercise>> load() async {
    await (_queues[key] ?? Future<void>.value());
    final generations = _generations(await SharedPreferences.getInstance());
    if (generations.isEmpty) return [];
    return (generations.first['items'] as List)
        .map((j) => ArchivedExercise.read(Map<String, dynamic>.from(j)))
        .toList();
  }

  Future<void> add(StudioDocument document) {
    final snapshot =
        jsonDecode(jsonEncode(document.toJson())) as Map<String, dynamic>;
    StudioDocument.read(snapshot);
    return _mutate((items) {
      if (items.any((i) => jsonEncode(i['document']) == jsonEncode(snapshot))) {
        return;
      }
      if (items.length >= 40) {
        throw StateError(
          'Архив заполнен (40 записей). Удалите ненужную запись.',
        );
      }
      final now = DateTime.now().toUtc();
      items.insert(0, {
        'id': now.microsecondsSinceEpoch.toString(),
        'savedAt': now.toIso8601String(),
        'document': snapshot,
      });
    });
  }

  Future<void> remove(String id) =>
      _mutate((items) => items.removeWhere((i) => i['id'] == id));

  Future<void> _mutate(void Function(List<Map<String, dynamic>>) change) {
    final operation = (_queues[key] ?? Future<void>.value()).then((_) async {
      final prefs = await SharedPreferences.getInstance();
      final generations = _generations(prefs);
      final items = generations.isEmpty
          ? <Map<String, dynamic>>[]
          : (generations.first['items'] as List)
                .map((j) => Map<String, dynamic>.from(j))
                .toList();
      change(items);
      final revision = generations.isEmpty
          ? 1
          : (generations.first['revision'] as int) + 1;
      final encoded = jsonEncode({
        'version': 1,
        'revision': revision,
        'items': items,
      });
      final target = '$key.${revision % 2}';
      if (!await prefs.setString(target, encoded) ||
          prefs.getString(target) != encoded) {
        throw StateError('Запись архива не подтверждена');
      }
    });
    final barrier = operation.then<void>((_) {}, onError: (Object _) {});
    _queues[key] = barrier;
    barrier.then((_) {
      if (identical(_queues[key], barrier)) _queues.remove(key);
    });
    return operation;
  }
}
