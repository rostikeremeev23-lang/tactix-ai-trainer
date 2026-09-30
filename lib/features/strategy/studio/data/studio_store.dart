import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/engine.dart';
import '../domain/scenario.dart';

class StudioDocument {
  final StudioScenario scenario;
  final ExerciseEngine? engine;
  final String? assignmentId;
  StudioDocument(this.scenario, [this.engine, this.assignmentId]);
  Map<String, dynamic> toJson() => {
    'version': 1,
    if (assignmentId != null) 'assignmentId': assignmentId,
    'scenario': scenario.toJson(),
    'run': engine?.toJson(),
  };
  factory StudioDocument.read(Map<String, dynamic> json) {
    if (json['version'] != 1) {
      throw const FormatException('Неизвестная версия Strategy Studio');
    }
    final scenario = StudioScenario.read(
      Map<String, dynamic>.from(json['scenario']),
    );
    final run = json['run'] == null
        ? null
        : ExerciseEngine.read(Map<String, dynamic>.from(json['run']));
    if (run != null &&
        jsonEncode(run.scenario.toJson()) != jsonEncode(scenario.toJson())) {
      throw const FormatException('Запись не соответствует сценарию');
    }
    return StudioDocument(scenario, run, json['assignmentId'] as String?);
  }
}

/// Separate namespace preserves all previous Strategy and Decision saves.
class StudioStore {
  final String userId;
  StudioStore(this.userId) {
    if (userId.isEmpty) throw ArgumentError('Нужен профиль');
  }
  String get key => 'tactix_studio_v1_${Uri.encodeComponent(userId)}';
  String? recoveryMessage;
  Future<void> _queue = Future.value();
  List<Map<String, dynamic>> _read(SharedPreferences prefs) {
    recoveryMessage = null;
    final good = <Map<String, dynamic>>[];
    for (var slot = 0; slot < 2; slot++) {
      try {
        final raw = prefs.getString('$key.$slot');
        if (raw == null) continue;
        final entry = Map<String, dynamic>.from(jsonDecode(raw));
        if (entry['revision'] is! int || entry['revision'] < 1) {
          throw const FormatException();
        }
        StudioDocument.read(Map<String, dynamic>.from(entry['document']));
        good.add(entry);
      } catch (_) {
        recoveryMessage =
            'Повреждённая копия пропущена. Использована резервная.';
      }
    }
    good.sort((a, b) => (b['revision'] as int).compareTo(a['revision'] as int));
    return good;
  }

  Future<StudioDocument?> load() async {
    await _queue;
    final entries = _read(await SharedPreferences.getInstance());
    if (entries.isEmpty) {
      if (recoveryMessage != null) {
        throw const FormatException('Обе копии недоступны');
      }
      return null;
    }
    return StudioDocument.read(
      Map<String, dynamic>.from(entries.first['document']),
    );
  }

  Future<void> save(StudioDocument document) {
    // Capture before awaiting: subsequent UI edits cannot alter this write.
    final snapshot =
        jsonDecode(jsonEncode(document.toJson())) as Map<String, dynamic>;
    StudioDocument.read(snapshot);
    final operation = _queue.then((_) async {
      final prefs = await SharedPreferences.getInstance();
      final entries = _read(prefs);
      if (entries.isEmpty && recoveryMessage != null) {
        throw const FormatException('Обе копии повреждены; запись заблокирована');
      }
      final revision = entries.isEmpty
          ? 1
          : (entries.first['revision'] as int) + 1;
      final encoded = jsonEncode({'revision': revision, 'document': snapshot});
      final target = '$key.${revision % 2}';
      if (!await prefs.setString(target, encoded) ||
          prefs.getString(target) != encoded) {
        throw StateError('Запись не подтверждена');
      }
    });
    _queue = operation.then<void>((_) {}, onError: (Object _) {});
    return operation;
  }
}
