import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/training_result.dart';
import 'user_storage_service.dart';

class ResultStorageService {
  static const String _legacyKey =
      'training_results';

  static Future<String> _currentKey() async {
    final user =
        await UserStorageService.loadCurrentUser();

    if (user == null) {
      return _legacyKey;
    }

    return 'training_results_${user.id}';
  }

  static Future<List<TrainingResult>> load() async {
    final prefs =
        await SharedPreferences.getInstance();

    final key =
        await _currentKey();

    final raw =
        prefs.getStringList(key) ?? [];

    final results = <TrainingResult>[];

    for (final item in raw) {
      try {
        final decoded =
            jsonDecode(item);

        if (decoded is Map<String, dynamic>) {
          results.add(
            TrainingResult.fromJson(
              decoded,
            ),
          );
        }
      } catch (_) {
        // Повреждённую запись просто пропускаем.
      }
    }

    results.sort(
      (a, b) => b.date.compareTo(a.date),
    );

    return results;
  }

  static Future<void> save(
    TrainingResult result,
  ) async {
    final prefs =
        await SharedPreferences.getInstance();

    final key =
        await _currentKey();

    final raw =
        prefs.getStringList(key) ?? [];

    raw.add(
      jsonEncode(result.toJson()),
    );

    await prefs.setStringList(
      key,
      raw,
    );
  }

  static Future<void> clear() async {
    final prefs =
        await SharedPreferences.getInstance();

    final key =
        await _currentKey();

    await prefs.remove(key);
  }
}

