import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/strategy_session.dart';

class StrategyRepository {
  final String userId;
  StrategyRepository(this.userId) {
    if (userId.isEmpty) throw ArgumentError('Требуется профиль');
  }
  String get key => 'tactix_strategy_v1_${Uri.encodeComponent(userId)}';
  String? recoveryMessage;

  Future<List<Map<String, dynamic>>> _read(SharedPreferences prefs) async {
    recoveryMessage = null;
    final entries = <Map<String, dynamic>>[];
    for (var slot = 0; slot < 2; slot++) {
      final raw = prefs.getString('$key.$slot');
      if (raw == null) continue;
      try {
        final data = Map<String, dynamic>.from(jsonDecode(raw) as Map);
        if (data['generation'] is! int || (data['generation'] as int) < 1) {
          throw const FormatException();
        }
        StrategySession.fromJson(
          Map<String, dynamic>.from(data['session'] as Map),
        );
        entries.add(data);
      } catch (_) {
        recoveryMessage = 'Повреждённая копия пропущена; загружена исправная.';
      }
    }
    entries.sort(
      (a, b) => (b['generation'] as int).compareTo(a['generation'] as int),
    );
    return entries;
  }

  Future<StrategySession?> load() async {
    final entries = await _read(await SharedPreferences.getInstance());
    if (entries.isEmpty) {
      if (recoveryMessage != null) {
        throw const FormatException('Нет исправной копии');
      }
      return null;
    }
    return StrategySession.fromJson(
      Map<String, dynamic>.from(entries.first['session'] as Map),
    );
  }

  Future<void> save(StrategySession session) async {
    final snapshot = session.toJson();
    StrategySession.fromJson(snapshot);
    final prefs = await SharedPreferences.getInstance();
    final entries = await _read(prefs);
    final generation = entries.isEmpty
        ? 1
        : (entries.first['generation'] as int) + 1;
    final target = '$key.${generation % 2}';
    final encoded = jsonEncode({'generation': generation, 'session': snapshot});
    if (!await prefs.setString(target, encoded) ||
        prefs.getString(target) != encoded) {
      throw StateError('Сохранение не подтверждено');
    }
  }
}
