import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AIService {
  AIService._();

  // ============================================================
  // BACKEND URL
  // ============================================================

  /// Backend можно переопределить при сборке через --dart-define:
  ///
  /// Chrome / Windows:
  /// flutter run --dart-define=AI_BACKEND_URL=http://127.0.0.1:8000
  ///
  /// Android Emulator:
  /// flutter run --dart-define=AI_BACKEND_URL=http://10.0.2.2:8000
  ///
  /// Планшет / телефон в одной Wi-Fi сети:
  /// flutter run -d web-server
  ///   --web-hostname 0.0.0.0
  ///   --web-port 8080
  ///   --dart-define=AI_BACKEND_URL=http://10.167.14.90:8000
  ///
  /// Release APK:
  /// flutter build apk --release
  ///   --dart-define=AI_BACKEND_URL=https://YOUR-BACKEND.example.com
  ///
  /// Если адрес не задан, используются локальные адреса
  /// для текущей платформы.

  static const String _baseUrlKey = 'ai_backend_url';

  static const String _buildTimeBaseUrl =
      String.fromEnvironment('AI_BACKEND_URL');

  static String? _configuredBaseUrl;

  static String get baseUrl {
    if (_buildTimeBaseUrl.trim().isNotEmpty) {
      return _normalizeBaseUrl(
        _buildTimeBaseUrl,
      );
    }

    final configured =
        _configuredBaseUrl?.trim();

    if (configured != null &&
        configured.isNotEmpty) {
      return _normalizeBaseUrl(
        configured,
      );
    }

    // Flutter Web (Chrome):
    // backend на этой же машине.
    if (kIsWeb) {
      return 'http://127.0.0.1:8000';
    }

    // Android Emulator:
    // 10.0.2.2 указывает на Windows-хост.
    if (defaultTargetPlatform ==
        TargetPlatform.android) {
      return 'http://10.0.2.2:8000';
    }

    // Windows / macOS / Linux.
    return 'http://127.0.0.1:8000';
  }

  static Future<void> loadConfig() async {
    final prefs =
        await SharedPreferences.getInstance();

    _configuredBaseUrl =
        prefs.getString(
      _baseUrlKey,
    );
  }

  static Future<void> setBaseUrl(
    String url,
  ) async {
    final normalized =
        _normalizeBaseUrl(url);

    final parsed =
        Uri.tryParse(normalized);

    if (parsed == null ||
        !parsed.hasScheme ||
        parsed.host.isEmpty) {
      throw const FormatException(
        'Некорректный адрес backend.',
      );
    }

    final prefs =
        await SharedPreferences.getInstance();

    await prefs.setString(
      _baseUrlKey,
      normalized,
    );

    _configuredBaseUrl =
        normalized;
  }

  static Future<void> clearBaseUrl() async {
    final prefs =
        await SharedPreferences.getInstance();

    await prefs.remove(
      _baseUrlKey,
    );

    _configuredBaseUrl = null;
  }

  static String _normalizeBaseUrl(
    String url,
  ) {
    var value = url.trim();

    while (value.endsWith('/')) {
      value = value.substring(
        0,
        value.length - 1,
      );
    }

    return value;
  }

  static const Duration requestTimeout =
      Duration(seconds: 15);

  static const Duration scenarioTimeout =
      Duration(seconds: 30);

  // ============================================================
  // HEADERS
  // ============================================================

  static Map<String, String> get _headers {
    return {
      'Content-Type':
          'application/json; charset=utf-8',
      'Accept':
          'application/json',
    };
  }

  // ============================================================
  // ANALYZE DECISION
  // ============================================================

  static Future<String> analyze({
    required String situation,
    required String decision,
    String goal = '',
    List<String> criteria = const [],
    required SimulationData simulation,
    required List<dynamic> history,
  }) async {
    final body =
        <String, dynamic>{
      'situation': situation,
      'decision': decision,
      'goal': goal,
      'criteria': criteria,

      // Сохраняем старый формат API:
      'time': simulation.time,
      'resources':
          simulation.resources,
      'stability':
          simulation.stability,
      'progress':
          simulation.progress,
      'uncertainty':
          simulation.uncertainty,

      'history':
          _serializeHistory(history),
    };

    final response =
        await http
            .post(
              Uri.parse(
                '$baseUrl/analyze',
              ),
              headers: _headers,
              body: jsonEncode(body),
            )
            .timeout(
              requestTimeout,
            );

    final data =
        _decodeResponse(response);

    final text =
        _extractText(
      data,
      const [
        'analysis',
        'result',
        'text',
        'response',
        'message',
        'content',
      ],
    );

    if (text.isEmpty) {
      throw Exception(
        'AI не вернул анализ.',
      );
    }

    return text;
  }

  // ============================================================
  // LOCAL ANALYSIS
  // ============================================================

  static String localAnalysis({
    required String decision,
    String goal = '',
    List<String> criteria = const [],
    required SimulationData simulation,
    required List<dynamic> history,
  }) {
    final score =
        _calculateLocalScore(
      simulation,
    );

    final strengths =
        <String>[];

    final weaknesses =
        <String>[];

    if (simulation.progress >=
        60) {
      strengths.add(
        'Прогресс учебной задачи высокий.',
      );
    }

    if (simulation.resources >=
        50) {
      strengths.add(
        'Сохраняется достаточный запас ресурсов.',
      );
    }

    if (simulation.stability >=
        70) {
      strengths.add(
        'Устойчивость системы остаётся высокой.',
      );
    }

    if (simulation.uncertainty <=
        35) {
      strengths.add(
        'Неопределённость находится под контролем.',
      );
    }

    if (simulation.progress <
        40) {
      weaknesses.add(
        'Прогресс пока недостаточный.',
      );
    }

    if (simulation.resources <
        30) {
      weaknesses.add(
        'Ресурс приближается к критическому уровню.',
      );
    }

    if (simulation.stability <
        40) {
      weaknesses.add(
        'Устойчивость заметно снизилась.',
      );
    }

    if (simulation.uncertainty >
        70) {
      weaknesses.add(
        'Высокая неопределённость затрудняет последовательное управление сценарием.',
      );
    }

    if (strengths.isEmpty) {
      strengths.add(
        'Выраженных положительных признаков пока недостаточно.',
      );
    }

    if (weaknesses.isEmpty) {
      weaknesses.add(
        'Критических слабых сторон не обнаружено.',
      );
    }

    return '''
ОЦЕНКА: $score/100

РЕШЕНИЕ:
$decision

ЦЕЛЬ СЦЕНАРИЯ:
${goal.isEmpty ? 'Учебная задача не задана.' : goal}

КРИТЕРИИ ОЦЕНКИ:
${criteria.isEmpty ? '- не заданы' : criteria.map((item) => '- $item').join('\n')}

СИЛЬНЫЕ СТОРОНЫ:
${strengths.map((item) => '- $item').join('\n')}

СЛАБЫЕ СТОРОНЫ:
${weaknesses.map((item) => '- $item').join('\n')}

ТЕКУЩЕЕ СОСТОЯНИЕ:
Время: ${simulation.time}
Ресурсы: ${simulation.resources}%
Устойчивость: ${simulation.stability}%
Прогресс: ${simulation.progress}%
Неопределённость: ${simulation.uncertainty}%

Предыдущих решений: ${history.length}

Использован локальный учебный анализ.
''';
  }


  // ============================================================
  // EXPLAIN OBJECTIVE TACTIX SCORE
  // ============================================================

  /// Competition Build:
  /// AI объясняет уже рассчитанный локальным движком TACTIX Score.
  /// Сам итоговый балл формируется SimulationEngine, а не LLM.
  static Future<String> explainObjectiveScore({
    required String situation,
    required String decision,
    String goal = '',
    List<String> criteria = const [],
    required int objectiveScore,
    required String level,
    required Map<String, int> scoreBreakdown,
    required Map<String, int> stateDelta,
    required SimulationData simulation,
    required List<dynamic> history,
  }) async {
    final body = <String, dynamic>{
      'situation': situation,
      'decision': decision,
      'goal': goal,
      'criteria': criteria,
      'objective_score': objectiveScore,
      'level': level,
      'score_breakdown': scoreBreakdown,
      'state_delta': stateDelta,
      'time': simulation.time,
      'resources': simulation.resources,
      'stability': simulation.stability,
      'progress': simulation.progress,
      'uncertainty': simulation.uncertainty,
      'history': _serializeHistory(history),
    };

    final response = await http
        .post(
          Uri.parse('$baseUrl/explain-score'),
          headers: _headers,
          body: jsonEncode(body),
        )
        .timeout(requestTimeout);

    final data = _decodeResponse(response);

    final text = _extractText(
      data,
      const [
        'explanation',
        'analysis',
        'result',
        'text',
        'response',
        'message',
        'content',
      ],
    );

    if (text.isEmpty) {
      throw Exception(
        'AI не вернул объяснение TACTIX Score.',
      );
    }

    return text;
  }

  /// Полностью локальное объяснение вЂ” используется как fallback,
  /// если backend/Ollama недоступны.
  static String localObjectiveScoreExplanation({
    required String decision,
    required int objectiveScore,
    required String level,
    required Map<String, int> scoreBreakdown,
    required Map<String, int> stateDelta,
  }) {
    String deltaText(String key, String label) {
      final value = stateDelta[key] ?? 0;
      final sign = value > 0 ? '+' : '';
      return '$label: $sign$value';
    }

    final lines = <String>[
      'TACTIX SCORE: $objectiveScore/100',
      'УРОВЕНЬ: $level',
      '',
      'РЕШЕНИЕ:',
      decision,
      '',
      'КОМПОНЕНТЫ ОЦЕНКИ:',
      'Цель: ${scoreBreakdown['goal'] ?? 0}',
      'Ресурсы: ${scoreBreakdown['resources'] ?? 0}',
      'Устойчивость: ${scoreBreakdown['stability'] ?? 0}',
      'Неопределённость: ${scoreBreakdown['uncertainty'] ?? 0}',
      'Время: ${scoreBreakdown['time'] ?? 0}',
      '',
      'ИЗМЕНЕНИЕ СОСТОЯНИЯ:',
      deltaText('time', 'Время'),
      deltaText('resources', 'Ресурсы'),
      deltaText('stability', 'Устойчивость'),
      deltaText('progress', 'Прогресс'),
      deltaText('uncertainty', 'Неопределённость'),
      '',
      'Итоговая цифра рассчитана локальным TACTIX Score Engine.',
      'AI используется только для пояснения результата.',
    ];

    return lines.join('\n');
  }

  // ============================================================
  // SUMMARY
  // ============================================================

  static Future<String>
      generateSituationSummary({
    required String situation,
    String goal = '',
    List<String> criteria = const [],
    required SimulationData simulation,
    required List<String> events,
    required List<dynamic> history,
  }) async {
    final body =
        <String, dynamic>{
      'situation': situation,
      'goal': goal,
      'criteria': criteria,

      // Старый формат backend API:
      'decision':
          'Сделай сводку текущего учебного состояния.',

      'time': simulation.time,
      'resources':
          simulation.resources,
      'stability':
          simulation.stability,
      'progress':
          simulation.progress,
      'uncertainty':
          simulation.uncertainty,

      'events': events,
      'history':
          _serializeHistory(history),
    };

    final response =
        await http
            .post(
              Uri.parse(
                '$baseUrl/summary',
              ),
              headers: _headers,
              body: jsonEncode(body),
            )
            .timeout(
              requestTimeout,
            );

    final data =
        _decodeResponse(response);

    final text =
        _extractText(
      data,
      const [
        'summary',
        'result',
        'text',
        'response',
        'message',
        'content',
      ],
    );

    if (text.isEmpty) {
      throw Exception(
        'AI не вернул сводку.',
      );
    }

    return text;
  }

  // ============================================================
  // LOCAL SUMMARY
  // ============================================================

  static String localSummary({
    required SimulationData simulation,
    required List<String> events,
  }) {
    final parts =
        <String>[];

    if (simulation.resources <
        30) {
      parts.add(
        'Ресурс находится на низком уровне.',
      );
    } else if (simulation.resources <
        60) {
      parts.add(
        'Ресурс находится на среднем уровне.',
      );
    } else {
      parts.add(
        'Ресурс остаётся высоким.',
      );
    }

    if (simulation.stability <
        40) {
      parts.add(
        'Устойчивость заметно снизилась.',
      );
    } else if (simulation.stability >=
        70) {
      parts.add(
        'Устойчивость сохраняется.',
      );
    }

    if (simulation.progress >=
        80) {
      parts.add(
        'Прогресс высокий.',
      );
    } else if (simulation.progress >=
        50) {
      parts.add(
        'Прогресс находится на среднем уровне.',
      );
    } else {
      parts.add(
        'Прогресс пока ограничен.',
      );
    }

    if (simulation.uncertainty >
        70) {
      parts.add(
        'Неопределённость высокая.',
      );
    } else if (simulation.uncertainty <=
        30) {
      parts.add(
        'Неопределённость находится под контролем.',
      );
    }

    if (events.isNotEmpty) {
      parts.add(
        'Последнее событие: ${events.last}',
      );
    }

    return parts.join(' ');
  }

  // ============================================================
  // GENERATE SCENARIO
  // ============================================================

  static Future<GeneratedScenario>
      generateScenario({
    required String userDescription,
  }) async {
    final description =
        userDescription.trim();

    if (description.isEmpty) {
      throw Exception(
        'Описание сценария пустое.',
      );
    }

    try {
      final response =
          await http
              .post(
                Uri.parse(
                  '$baseUrl/generate-scenario',
                ),
                headers: _headers,
                body: jsonEncode({
                  'description':
                      description,
                }),
              )
              .timeout(
                scenarioTimeout,
              );

      final data =
          _decodeResponse(response);

      return GeneratedScenario.fromJson(
        data,
      );
    } on TimeoutException catch (e) {
      throw Exception(
        'AI-сервер слишком долго отвечает.\n'
        'Адрес: $baseUrl\n\n'
        'Ошибка: $e',
      );
    } on FormatException catch (e) {
      throw Exception(
        'AI-сервер вернул некорректный JSON.\n\n'
        '$e',
      );
    } on http.ClientException catch (e) {
      throw Exception(
        'Не удалось подключиться к AI-серверу.\n'
        'Адрес: $baseUrl\n\n'
        'Проверьте, что backend запущен.\n\n'
        'Ошибка: $e',
      );
    } on Exception catch (e) {
      throw Exception(
        'Не удалось подключиться к AI-серверу.\n'
        'Адрес: $baseUrl\n\n'
        'Проверьте, что backend запущен.\n\n'
        'Ошибка: $e',
      );
    } catch (e) {
      throw Exception(
        'Не удалось создать сценарий.\n\n'
        '$e',
      );
    }
  }

  // ============================================================
  // NEXT SITUATION
  // ============================================================

  static Future<NextSituation>
      generateNextSituation({
    required String scenario,
    required List<String> history,
    required List<String> events,
    required SimulationData simulation,
    required int turn,
  }) async {
    final body =
        <String, dynamic>{
      'scenario': scenario,
      'history': history,
      'events': events,

      // Старый формат backend API:
      'time': simulation.time,
      'resources':
          simulation.resources,
      'stability':
          simulation.stability,
      'progress':
          simulation.progress,
      'uncertainty':
          simulation.uncertainty,

      'turn': turn,
    };

    try {
      final response =
          await http
              .post(
                Uri.parse(
                  '$baseUrl/next-situation',
                ),
                headers: _headers,
                body: jsonEncode(body),
              )
              .timeout(
                requestTimeout,
              );

      final data =
          _decodeResponse(response);

      return NextSituation.fromJson(
        data,
      );
    } on TimeoutException catch (e) {
      throw Exception(
        'AI-сервер слишком долго отвечает.\n'
        'Адрес: $baseUrl\n'
        '$e',
      );
    } on FormatException catch (e) {
      throw Exception(
        'AI-сервер вернул некорректный ответ.\n'
        '$e',
      );
    } on http.ClientException catch (e) {
      throw Exception(
        'Не удалось подключиться к AI-серверу.\n'
        'Адрес: $baseUrl\n'
        '$e',
      );
    } on Exception catch (e) {
      throw Exception(
        'Не удалось получить следующую ситуацию.\n'
        '$e',
      );
    } catch (e) {
      throw Exception(
        'Не удалось получить следующую ситуацию.\n'
        '$e',
      );
    }
  }

  // ============================================================
  // SERVER CHECK
  // ============================================================

  static Future<bool>
      isServerAvailable() async {
    try {
      final response =
          await http
              .get(
                Uri.parse(
                  '$baseUrl/health',
                ),
              )
              .timeout(
                const Duration(
                  seconds: 5,
                ),
              );

      if (response.statusCode < 200 ||
          response.statusCode >= 300) {
        return false;
      }

      final data = jsonDecode(response.body);
      return data is Map<String, dynamic> &&
          data['ai_ready'] == true;
    } catch (_) {
      return false;
    }
  }

  // ============================================================
  // HTTP RESPONSE
  // ============================================================

  static dynamic _decodeResponse(
    http.Response response,
  ) {
    if (response.statusCode < 200 ||
        response.statusCode >= 300) {
      String message =
          'AI-сервер вернул HTTP ${response.statusCode}.';

      try {
        final decoded =
            jsonDecode(
          response.body,
        );

        if (decoded is Map) {
          if (decoded['detail'] != null) {
            message =
                decoded['detail']
                    .toString();
          } else if (decoded['error'] !=
              null) {
            message =
                decoded['error']
                    .toString();
          } else if (decoded['message'] !=
              null) {
            message =
                decoded['message']
                    .toString();
          }
        }
      } catch (_) {
        if (response.body
            .trim()
            .isNotEmpty) {
          message =
              response.body;
        }
      }

      throw Exception(
        message,
      );
    }

    if (response.body
        .trim()
        .isEmpty) {
      throw const FormatException(
        'AI-сервер вернул пустой ответ.',
      );
    }

    try {
      return jsonDecode(
        response.body,
      );
    } catch (e) {
      throw FormatException(
        'Не удалось прочитать JSON ответа: $e',
      );
    }
  }

  // ============================================================
  // TEXT EXTRACTION
  // ============================================================

  static String _extractText(
    dynamic data,
    List<String> keys,
  ) {
    if (data is String) {
      return data.trim();
    }

    if (data is Map) {
      for (final key in keys) {
        final value = data[key];

        if (value == null) {
          continue;
        }

        if (value is String &&
            value.trim().isNotEmpty) {
          return value.trim();
        }

        if (value is List) {
          return value
              .map(
                (item) =>
                    item.toString(),
              )
              .join('\n')
              .trim();
        }

        if (value is Map) {
          return jsonEncode(
            value,
          );
        }

        final text =
            value.toString().trim();

        if (text.isNotEmpty) {
          return text;
        }
      }

      // Иногда backend возвращает:
      // {"data": {"analysis": "..."}}
      final nested =
          data['data'];

      if (nested != null) {
        return _extractText(
          nested,
          keys,
        );
      }
    }

    return '';
  }

  // ============================================================
  // HISTORY SERIALIZATION
  // ============================================================

  static List<Map<String, dynamic>>
      _serializeHistory(
    List<dynamic> history,
  ) {
    return history
        .map(
          _serializeHistoryItem,
        )
        .toList();
  }

  static Map<String, dynamic>
      _serializeHistoryItem(
    dynamic item,
  ) {
    try {
      return {
        'turn': item.turn,
        'decision': item.decision,
        'score': item.score,
      };
    } catch (_) {
      if (item is Map) {
        return {
          'turn': item['turn'],
          'decision': item['decision'],
          'score': item['score'],
        };
      }

      return {
        'value':
            item.toString(),
      };
    }
  }

  // ============================================================
  // LOCAL SCORE
  // ============================================================

  static int _calculateLocalScore(
    SimulationData simulation,
  ) {
    final raw =
        simulation.resources * 0.25 +
            simulation.stability *
                0.25 +
            simulation.progress *
                0.35 +
            (100 -
                    simulation
                        .uncertainty) *
                0.15;

    return raw
        .round()
        .clamp(
          0,
          100,
        );
  }
}

// ============================================================
// SIMULATION DATA
// ============================================================

class SimulationData {
  final int time;
  final int resources;
  final int stability;
  final int progress;
  final int uncertainty;

  const SimulationData({
    required this.time,
    required this.resources,
    required this.stability,
    required this.progress,
    required this.uncertainty,
  });

  Map<String, dynamic> toJson() {
    return {
      'time': time,
      'resources': resources,
      'stability': stability,
      'progress': progress,
      'uncertainty': uncertainty,
    };
  }

  factory SimulationData.fromJson(
    Map<String, dynamic> json,
  ) {
    return SimulationData(
      time: _toInt(
        json['time'],
      ),
      resources: _toInt(
        json['resources'],
      ),
      stability: _toInt(
        json['stability'],
      ),
      progress: _toInt(
        json['progress'],
      ),
      uncertainty: _toInt(
        json['uncertainty'],
      ),
    );
  }

  static int _toInt(
    dynamic value,
  ) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.round();
    }

    return int.tryParse(
          value?.toString() ?? '',
        ) ??
        0;
  }
}

// ============================================================
// GENERATED SCENARIO
// ============================================================

class GeneratedScenario {
  final String title;
  final String description;

  final int time;
  final int resources;

  final String conditions;

  final String optionA;
  final String optionB;
  final String optionC;

  final List<String> criteria;

  final String goal;

  const GeneratedScenario({
    required this.title,
    required this.description,
    required this.time,
    required this.resources,
    required this.conditions,
    required this.optionA,
    required this.optionB,
    required this.optionC,
    required this.criteria,
    required this.goal,
  });

  factory GeneratedScenario.fromJson(
    dynamic json,
  ) {
    if (json is! Map) {
      throw const FormatException(
        'Ответ генератора сценария имеет неверный формат.',
      );
    }

    final map =
        Map<String, dynamic>.from(
      json,
    );

    final criteria =
        _parseCriteria(
      map['criteria'],
    );

    return GeneratedScenario(
      title: _string(
        map,
        const [
          'title',
          'name',
        ],
        fallback:
            'Тренировочный сценарий',
      ),
      description: _string(
        map,
        const [
          'description',
          'scenario',
        ],
        fallback: '',
      ),
      time: _int(
        map,
        const [
          'time',
          'duration',
          'timeLimit',
          'time_limit',
        ],
        fallback: 45,
      ),
      resources: _int(
        map,
        const [
          'resources',
          'resource',
          'initialResources',
          'initial_resources',
        ],
        fallback: 80,
      ),
      conditions: _string(
        map,
        const [
          'conditions',
          'condition',
          'environment',
        ],
        fallback: '',
      ),
      optionA: _option(
        map,
        const [
          'optionA',
          'option_a',
          'a',
        ],
        fallback:
            'Выбрать активный вариант действий.',
      ),
      optionB: _option(
        map,
        const [
          'optionB',
          'option_b',
          'b',
        ],
        fallback:
            'Выбрать сбалансированный вариант действий.',
      ),
      optionC: _option(
        map,
        const [
          'optionC',
          'option_c',
          'c',
        ],
        fallback:
            'Выбрать осторожный вариант действий.',
      ),
      criteria: criteria,
      goal: _string(
        map,
        const [
          'goal',
          'objective',
          'mission',
        ],
        fallback:
            'Выполнить учебную задачу.',
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'time': time,
      'resources': resources,
      'conditions': conditions,
      'optionA': optionA,
      'optionB': optionB,
      'optionC': optionC,
      'criteria': criteria,
      'goal': goal,
    };
  }

  static String _string(
    Map<String, dynamic> map,
    List<String> keys, {
    required String fallback,
  }) {
    for (final key in keys) {
      final value = map[key];

      if (value == null) {
        continue;
      }

      final text =
          value.toString().trim();

      if (text.isNotEmpty) {
        return text;
      }
    }

    return fallback;
  }

  static int _int(
    Map<String, dynamic> map,
    List<String> keys, {
    required int fallback,
  }) {
    for (final key in keys) {
      final value = map[key];

      if (value is int) {
        return value;
      }

      if (value is num) {
        return value.round();
      }

      final parsed =
          int.tryParse(
        value?.toString() ?? '',
      );

      if (parsed != null) {
        return parsed;
      }
    }

    return fallback;
  }

  static String _option(
    Map<String, dynamic> map,
    List<String> keys, {
    required String fallback,
  }) {
    for (final key in keys) {
      final value = map[key];

      if (value == null) {
        continue;
      }

      if (value is String &&
          value.trim().isNotEmpty) {
        return value.trim();
      }

      if (value is Map) {
        final text =
            value['text'] ??
            value['description'] ??
            value['title'] ??
            value['label'];

        if (text != null &&
            text
                .toString()
                .trim()
                .isNotEmpty) {
          return text
              .toString()
              .trim();
        }
      }

      final text =
          value.toString().trim();

      if (text.isNotEmpty) {
        return text;
      }
    }

    return fallback;
  }

  static List<String> _parseCriteria(
    dynamic raw,
  ) {
    if (raw is List) {
      return raw
          .map(
            (item) =>
                item.toString(),
          )
          .where(
            (item) =>
                item.trim().isNotEmpty,
          )
          .toList();
    }

    if (raw is String &&
        raw.trim().isNotEmpty) {
      return raw
          .split(
            RegExp(r'[\n;,]+'),
          )
          .map(
            (item) => item.trim(),
          )
          .where(
            (item) =>
                item.isNotEmpty,
          )
          .toList();
    }

    return <String>[];
  }
}

// ============================================================
// NEXT SITUATION
// ============================================================

class NextSituation {
  final String situation;
  final String event;
  final String focus;
  final int turn;

  const NextSituation({
    required this.situation,
    required this.event,
    required this.focus,
    this.turn = 0,
  });

  factory NextSituation.fromJson(
    dynamic json,
  ) {
    if (json is! Map) {
      throw const FormatException(
        'Ответ следующей ситуации имеет неверный формат.',
      );
    }

    final map =
        Map<String, dynamic>.from(
      json,
    );

    return NextSituation(
      situation: _string(
        map,
        const [
          'situation',
          'description',
          'text',
          'summary',
        ],
        fallback:
            'Обстановка продолжает развиваться. Необходимо принять следующее решение.',
      ),
      event: _string(
        map,
        const [
          'event',
          'nextEvent',
          'next_event',
        ],
        fallback:
            'Появилось новое изменение обстановки.',
      ),
      focus: _string(
        map,
        const [
          'focus',
          'nextFocus',
          'next_focus',
          'recommendation',
        ],
        fallback:
            'Оцените изменения состояния симуляции.',
      ),
      turn: _int(
        map,
        const [
          'turn',
        ],
        fallback: 0,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'situation': situation,
      'event': event,
      'focus': focus,
      'turn': turn,
    };
  }

  static String _string(
    Map<String, dynamic> map,
    List<String> keys, {
    required String fallback,
  }) {
    for (final key in keys) {
      final value = map[key];

      if (value == null) {
        continue;
      }

      final text =
          value.toString().trim();

      if (text.isNotEmpty) {
        return text;
      }
    }

    return fallback;
  }

  static int _int(
    Map<String, dynamic> map,
    List<String> keys, {
    required int fallback,
  }) {
    for (final key in keys) {
      final value = map[key];

      if (value is int) {
        return value;
      }

      if (value is num) {
        return value.round();
      }

      final parsed =
          int.tryParse(
        value?.toString() ?? '',
      );

      if (parsed != null) {
        return parsed;
      }
    }

    return fallback;
  }
}
