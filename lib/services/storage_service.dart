import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/scenario.dart';

class ScenarioStorage {
  static const String _key = 'my_scenarios';

  static Future<List<TrainingScenario>> load() async {
    final prefs = await SharedPreferences.getInstance();

    final data = prefs.getStringList(_key) ?? [];

    return data
        .map(
          (item) => TrainingScenario.fromJson(
            jsonDecode(item) as Map<String, dynamic>,
          ),
        )
        .toList();
  }

  static Future<void> save(TrainingScenario scenario) async {
    final prefs = await SharedPreferences.getInstance();

    final data = prefs.getStringList(_key) ?? [];

    data.add(
      jsonEncode(scenario.toJson()),
    );

    await prefs.setStringList(_key, data);
  }

  static Future<void> delete(int index) async {
    final prefs = await SharedPreferences.getInstance();

    final data = prefs.getStringList(_key) ?? [];

    if (index >= 0 && index < data.length) {
      data.removeAt(index);
      await prefs.setStringList(_key, data);
    }
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
