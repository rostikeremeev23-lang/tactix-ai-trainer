import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/decision_engine.dart';
import '../domain/models.dart';

/// Two alternating snapshots. The previous successful generation remains usable.
class RunRepository {
  final String userId;
  final DecisionEngine engine;
  String? recoveryMessage;
  RunRepository(this.userId, this.engine) {
    if (userId.isEmpty) throw ArgumentError('Требуется профиль пользователя');
  }
  String get key =>
      'decision_simulation_v1_${Uri.encodeComponent(userId)}_${engine.scenario.id}';
  Future<List<Map<String, dynamic>>> _envelopes() async {
    final prefs = await SharedPreferences.getInstance();
    final found = <Map<String, dynamic>>[];
    recoveryMessage = null;
    for (var slot = 0; slot < 2; slot++) {
      final raw = prefs.getString('$key.$slot');
      if (raw == null) continue;
      try {
        final envelope = Map<String, dynamic>.from(jsonDecode(raw) as Map);
        if (envelope['generation'] is! int) throw const FormatException();
        engine.restore(envelope);
        found.add(envelope);
      } catch (_) {
        recoveryMessage =
            'Одна копия сохранения повреждена или несовместима. '
            'Использована последняя исправная копия, если она доступна.';
      }
    }
    found.sort(
      (a, b) => (b['generation'] as int).compareTo(a['generation'] as int),
    );
    return found;
  }

  Future<RunState?> load() async {
    final found = await _envelopes();
    if (found.isEmpty) {
      if (recoveryMessage != null) {
        throw const FormatException(
          'Исправное сохранение не найдено. Можно начать новое прохождение.',
        );
      }
      return null;
    }
    return engine.restore(found.first);
  }

  Future<void> save(RunState state) async {
    // Validate before committing, including every recorded consequence.
    final exported = engine.export(state);
    engine.restore(Map<String, dynamic>.from(exported));
    final found = await _envelopes();
    final generation = found.isEmpty
        ? 1
        : (found.first['generation'] as int) + 1;
    final envelope = {...exported, 'generation': generation};
    final prefs = await SharedPreferences.getInstance();
    final target = '$key.${generation % 2}';
    final encoded = jsonEncode(envelope);
    final success = await prefs.setString(target, encoded);
    if (!success || prefs.getString(target) != encoded) {
      throw StateError('Не удалось подтвердить сохранение');
    }
  }
}
