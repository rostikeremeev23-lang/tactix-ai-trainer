import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/ai_chat_message.dart';

enum AIMode { auto, cloud, local, offline }

enum AIBackendKind { none, cloud, local }

class AIService {
  AIService._();

  // ============================================================
  // AI MODE / BACKEND ROUTING
  // ============================================================

  static const String _baseUrlKey = 'ai_backend_url';
  static const String _modeKey = 'ai_mode';

  static const String _buildTimeBaseUrl =
      String.fromEnvironment('AI_BACKEND_URL');

  static const String _defaultCloudBaseUrl =
      'https://tactix-api.onrender.com';

  static String? _configuredBaseUrl;
  static AIMode _mode = AIMode.auto;
  static AIBackendKind _activeBackend = AIBackendKind.none;
  static String? _activeBaseUrl;
  static bool _configLoaded = false;

  static AIMode get mode => _mode;
  static AIBackendKind get activeBackend => _activeBackend;
  static String? get activeBaseUrl => _activeBaseUrl;

  static String get cloudBaseUrl {
    final buildUrl = _buildTimeBaseUrl.trim();
    if (buildUrl.startsWith('https://')) {
      return _normalizeBaseUrl(buildUrl);
    }
    return _defaultCloudBaseUrl;
  }

  static String get localBaseUrl {
    final configured = _configuredBaseUrl?.trim();
    if (configured != null && configured.isNotEmpty) {
      return _normalizeBaseUrl(configured);
    }

    if (kIsWeb) {
      return 'http://127.0.0.1:8000';
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000';
    }

    return 'http://127.0.0.1:8000';
  }

  /// Совместимость со старым кодом. Для AUTO возвращает
  /// активный backend, а если он ещё не определён — cloud URL.
  static String get baseUrl {
    if (_activeBaseUrl != null && _activeBaseUrl!.isNotEmpty) {
      return _activeBaseUrl!;
    }

    switch (_mode) {
      case AIMode.cloud:
        return cloudBaseUrl;
      case AIMode.local:
        return localBaseUrl;
      case AIMode.offline:
        return '';
      case AIMode.auto:
        return cloudBaseUrl;
    }
  }

  static String get modeLabel {
    switch (_mode) {
      case AIMode.auto:
        return 'AUTO';
      case AIMode.cloud:
        return 'CLOUD';
      case AIMode.local:
        return 'LOCAL';
      case AIMode.offline:
        return 'OFFLINE';
    }
  }

  static String get statusLabel {
    if (_mode == AIMode.offline || _activeBackend == AIBackendKind.none) {
      return 'AI OFFLINE';
    }
    if (_activeBackend == AIBackendKind.cloud) {
      return 'AI CLOUD';
    }
    return 'AI LOCAL';
  }

  static String get providerLabel {
    if (_activeBackend == AIBackendKind.cloud) {
      return 'Gemini';
    }
    if (_activeBackend == AIBackendKind.local) {
      return 'Ollama';
    }
    return 'Offline Engine';
  }

  static Future<void> loadConfig() async {
    final prefs = await SharedPreferences.getInstance();

    _configuredBaseUrl = prefs.getString(_baseUrlKey);

    final savedMode = prefs.getString(_modeKey);
    _mode = AIMode.values.firstWhere(
      (item) => item.name == savedMode,
      orElse: () => AIMode.auto,
    );

    _configLoaded = true;
  }

  static Future<void> _ensureConfigLoaded() async {
    if (_configLoaded) return;
    await loadConfig();
  }

  static Future<void> setMode(AIMode mode) async {
    await _ensureConfigLoaded();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_modeKey, mode.name);

    _mode = mode;
    _activeBackend = AIBackendKind.none;
    _activeBaseUrl = null;
  }

  /// Пользовательский адрес LOCAL backend.
  /// Для Windows обычно http://127.0.0.1:8000.
  /// Для физического Android можно указать IP компьютера в Wi-Fi сети.
  static Future<void> setBaseUrl(String url) async {
    final normalized = _normalizeBaseUrl(url);
    final parsed = Uri.tryParse(normalized);

    if (parsed == null || !parsed.hasScheme || parsed.host.isEmpty) {
      throw const FormatException('Некорректный адрес backend.');
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_baseUrlKey, normalized);

    _configuredBaseUrl = normalized;
    _activeBackend = AIBackendKind.none;
    _activeBaseUrl = null;
  }

  static Future<void> clearBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_baseUrlKey);

    _configuredBaseUrl = null;
    _activeBackend = AIBackendKind.none;
    _activeBaseUrl = null;
  }

  static String _normalizeBaseUrl(String url) {
    var value = url.trim();
    while (value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }
    return value;
  }

  static List<String> _candidateBaseUrls() {
    switch (_mode) {
      case AIMode.cloud:
        return [cloudBaseUrl];
      case AIMode.local:
        return [localBaseUrl];
      case AIMode.offline:
        return const [];
      case AIMode.auto:
        final values = <String>[cloudBaseUrl, localBaseUrl];
        return values.toSet().toList();
    }
  }

  static AIBackendKind _kindForUrl(String url) {
    if (_normalizeBaseUrl(url) == _normalizeBaseUrl(cloudBaseUrl)) {
      return AIBackendKind.cloud;
    }
    return AIBackendKind.local;
  }

  static Future<bool> _healthAt(String url) async {
    try {
      final response = await http
          .get(Uri.parse('${_normalizeBaseUrl(url)}/health'))
          .timeout(const Duration(seconds: 12));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return false;
      }

      final data = jsonDecode(response.body);
      return data is Map<String, dynamic> && data['ai_ready'] == true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> refreshStatus() async {
    await _ensureConfigLoaded();

    _activeBackend = AIBackendKind.none;
    _activeBaseUrl = null;

    if (_mode == AIMode.offline) {
      return false;
    }

    for (final url in _candidateBaseUrls()) {
      if (await _healthAt(url)) {
        _activeBaseUrl = _normalizeBaseUrl(url);
        _activeBackend = _kindForUrl(url);
        return true;
      }
    }

    return false;
  }

  static Future<http.Response> _postJson(
    String path,
    Map<String, dynamic> body, {
    required Duration timeout,
  }) async {
    await _ensureConfigLoaded();

    if (_mode == AIMode.offline) {
      throw Exception('AI OFFLINE: выбран автономный режим.');
    }

    final candidates = _candidateBaseUrls();
    final ordered = <String>[];

    if (_activeBaseUrl != null && candidates.contains(_activeBaseUrl)) {
      ordered.add(_activeBaseUrl!);
    }
    for (final url in candidates) {
      if (!ordered.contains(url)) ordered.add(url);
    }

    Object? lastError;

    for (final url in ordered) {
      try {
        final response = await http
            .post(
              Uri.parse('${_normalizeBaseUrl(url)}$path'),
              headers: _headers,
              body: jsonEncode(body),
            )
            .timeout(timeout);

        final ok = response.statusCode >= 200 && response.statusCode < 300;
        if (ok) {
          _activeBaseUrl = _normalizeBaseUrl(url);
          _activeBackend = _kindForUrl(url);
          return response;
        }

        // В AUTO при лимите/ошибке cloud пробуем LOCAL Ollama.
        final retryable = response.statusCode == 429 || response.statusCode >= 500;
        if (_mode == AIMode.auto && retryable) {
          lastError = Exception(
            'AI backend ${response.statusCode}: ${response.body}',
          );
          continue;
        }

        return response;
      } on TimeoutException catch (error) {
        lastError = error;
        if (_mode != AIMode.auto) rethrow;
      } on http.ClientException catch (error) {
        lastError = error;
        if (_mode != AIMode.auto) rethrow;
      } catch (error) {
        lastError = error;
        if (_mode != AIMode.auto) rethrow;
      }
    }

    _activeBackend = AIBackendKind.none;
    _activeBaseUrl = null;

    throw Exception(
      'AI backend недоступен. ${lastError ?? ''}'.trim(),
    );
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

    final response = await _postJson(
      '/analyze',
      body,
      timeout: requestTimeout,
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

    final response = await _postJson(
      '/explain-score',
      body,
      timeout: requestTimeout,
    );

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

  /// Полностью локальное объяснение — используется как fallback,
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

    final response = await _postJson(
      '/summary',
      body,
      timeout: requestTimeout,
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
  // TACTIX AI CHAT
  // ============================================================

  /// Унифицированный чат поверх существующей AI routing-системы.
  /// AUTO: Cloud -> Local -> offline fallback.
  /// CLOUD/LOCAL: ошибка выбранного backend показывается пользователю.
  /// OFFLINE: используется локальный детерминированный помощник.
  static Future<String> chat({
    required String message,
    required AIChatContextType contextType,
    List<AIChatMessage> history = const [],
    Map<String, dynamic> context = const {},
  }) async {
    final cleanMessage = message.trim();
    if (cleanMessage.isEmpty) {
      throw const FormatException('Сообщение пустое.');
    }

    await _ensureConfigLoaded();

    if (_mode == AIMode.offline) {
      return localChat(
        message: cleanMessage,
        contextType: contextType,
        context: context,
      );
    }

    final body = <String, dynamic>{
      'message': cleanMessage,
      'context_type': contextType.name,
      'history': history
          .where((item) => item.text.trim().isNotEmpty)
          .toList()
          .reversed
          .take(12)
          .toList()
          .reversed
          .map(
            (item) => <String, dynamic>{
              'role': item.role.name,
              'text': item.text,
            },
          )
          .toList(),
      'context': context,
    };

    try {
      final response = await _postJson(
        '/chat',
        body,
        timeout: scenarioTimeout,
      );

      final data = _decodeResponse(response);
      final text = _extractText(
        data,
        const [
          'response',
          'answer',
          'text',
          'result',
          'message',
          'content',
        ],
      );

      if (text.isEmpty) {
        throw Exception('TACTIX AI не вернул ответ.');
      }

      return text;
    } catch (_) {
      // В AUTO приложение не должно превращаться в пустой экран,
      // даже если Cloud и Local AI временно недоступны.
      if (_mode == AIMode.auto) {
        return localChat(
          message: cleanMessage,
          contextType: contextType,
          context: context,
        );
      }
      rethrow;
    }
  }

  /// Ограниченный автономный помощник.
  /// Это НЕ LLM: он честно работает только с локальными данными TACTIX.
  static String localChat({
    required String message,
    required AIChatContextType contextType,
    Map<String, dynamic> context = const {},
  }) {
    final q = message.trim().toLowerCase();

    int intValue(String key) {
      final value = context[key];
      if (value is int) return value;
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    final scenarioTitle =
        (context['scenario_title'] ?? context['scenarioTitle'] ?? '')
            .toString()
            .trim();
    final score = intValue('score');
    final level = (context['level'] ?? '').toString().trim();
    final outcome = (context['outcome'] ?? '').toString().trim();

    final rawMetrics = context['metrics'];
    final metrics = rawMetrics is Map
        ? Map<String, dynamic>.from(rawMetrics)
        : <String, dynamic>{};

    final rawDecisions = context['decisions'];
    final decisions = rawDecisions is List
        ? rawDecisions.map((item) => item.toString()).toList()
        : <String>[];

    String metric(String key, String label) {
      final value = metrics[key];
      if (value == null) return '';
      return '$label: $value';
    }

    String scoreSummary() {
      if (score <= 0) {
        return 'Для точного разбора сначала завершите учебный сценарий. '
            'TACTIX Score рассчитывается локальным детерминированным движком, '
            'а AI только объясняет уже полученный результат.';
      }

      final parts = <String>[
        'TACTIX Score: $score/100${level.isEmpty ? '' : ' • $level'}.',
      ];

      if (scenarioTitle.isNotEmpty) {
        parts.add('Сценарий: $scenarioTitle.');
      }
      if (outcome.isNotEmpty) {
        parts.add('Итог симуляции: $outcome.');
      }

      final metricLines = <String>[
        metric('goal', 'Цель'),
        metric('resources', 'Ресурсы'),
        metric('stability', 'Устойчивость'),
        metric('uncertainty', 'Контроль неопределённости'),
        metric('time', 'Время'),
      ].where((item) => item.isNotEmpty).toList();

      if (metricLines.isNotEmpty) {
        parts.add('Компоненты: ${metricLines.join(' • ')}.');
      }

      return parts.join('\n');
    }

    if (contextType == AIChatContextType.debrief || context.isNotEmpty) {
      if (q.contains('почему') ||
          q.contains('score') ||
          q.contains('балл') ||
          q.contains('результ')) {
        return '${scoreSummary()}\n\n'
            'Числовая оценка не генерируется AI. Она уже была рассчитана '
            'SimulationEngine по изменениям цели, ресурсов, устойчивости, '
            'неопределённости и времени. В автономном режиме я могу объяснить '
            'эти данные, но не меняю итоговый балл.';
      }

      if (q.contains('решен') ||
          q.contains('ход') ||
          q.contains('ошиб') ||
          q.contains('улучш')) {
        final decisionText = decisions.isEmpty
            ? 'История решений в сохранённом результате отсутствует.'
            : 'Последние решения:\n${decisions.take(5).map((e) => '• $e').join('\n')}';
        return '$decisionText\n\n'
            'Для следующего учебного прохождения сравнивайте не только '
            'краткосрочный прогресс, но и расход ресурса, устойчивость и '
            'изменение неопределённости. В TACTIX эти показатели оцениваются '
            'локально и одинаково для одинаковых входных данных.';
      }

      return '${scoreSummary()}\n\n'
          'Спросите, например: «Почему такой Score?», '
          '«Что улучшить?» или «Разбери мои решения». '
          'Сейчас используется автономный помощник TACTIX.';
    }

    if (contextType == AIChatContextType.coach) {
      return 'Режим ТРЕНЕР работает как учебный помощник. '
          'Я могу помочь разобрать результат, сформулировать цель следующей '
          'тренировки и предложить безопасное упражнение на принятие решений. '
          'Например: завершите сценарий, затем сравните самый сильный и самый '
          'слабый ход по TACTIX Score и объясните, какой компромисс вы сделали.';
    }

    if (q.contains('режим') || q.contains('cloud') || q.contains('offline')) {
      return 'TACTIX AI поддерживает AUTO, CLOUD, LOCAL и OFFLINE. '
          'AUTO сначала использует Cloud, затем Local, а при недоступности '
          'обоих сохраняет базовые локальные функции. OFFLINE не требует сети.';
    }

    if (q.contains('score') || q.contains('оцен')) {
      return 'TACTIX Score рассчитывается локальным SimulationEngine. '
          'AI не придумывает числовую оценку: он только объясняет уже '
          'рассчитанный результат и помогает провести учебный разбор.';
    }

    return 'Я TACTIX AI. В автономном режиме могу объяснить TACTIX Score, '
        'помочь с интерфейсом и разобрать сохранённый учебный результат. '
        'Для свободного диалога переключитесь на AUTO, CLOUD или LOCAL, '
        'когда соответствующий AI backend доступен.';
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
      final response = await _postJson(
        '/generate-scenario',
        <String, dynamic>{
          'description': description,
        },
        timeout: scenarioTimeout,
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
      final response = await _postJson(
        '/next-situation',
        body,
        timeout: requestTimeout,
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
    return refreshStatus();
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
