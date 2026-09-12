class TrainingResult {
  final String scenarioTitle;
  final DateTime date;
  final int score;
  final int decisions;
  final int durationSeconds;

  // Старые показатели — оставлены для полной совместимости
  // с уже существующим интерфейсом и сохранёнными результатами.
  final int resourceScore;
  final int stabilityScore;
  final int progressScore;
  final int adaptationScore;

  // Competition Build: прозрачные компоненты TACTIX Score.
  final int goalScore;
  final int uncertaintyScore;
  final int timeScore;

  // Краткий итог и история решений для будущего AAR.
  final String level;
  final String outcome;
  final List<String> decisionHistory;

  const TrainingResult({
    required this.scenarioTitle,
    required this.date,
    required this.score,
    required this.decisions,
    required this.durationSeconds,
    required this.resourceScore,
    required this.stabilityScore,
    required this.progressScore,
    required this.adaptationScore,
    this.goalScore = 0,
    this.uncertaintyScore = 0,
    this.timeScore = 0,
    this.level = '',
    this.outcome = '',
    this.decisionHistory = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'scenarioTitle': scenarioTitle,
      'date': date.toIso8601String(),
      'score': score,
      'decisions': decisions,
      'durationSeconds': durationSeconds,
      'resourceScore': resourceScore,
      'stabilityScore': stabilityScore,
      'progressScore': progressScore,
      'adaptationScore': adaptationScore,
      'goalScore': goalScore,
      'uncertaintyScore': uncertaintyScore,
      'timeScore': timeScore,
      'level': level,
      'outcome': outcome,
      'decisionHistory': decisionHistory,
    };
  }

  factory TrainingResult.fromJson(
    Map<String, dynamic> json,
  ) {
    final rawHistory = json['decisionHistory'];

    return TrainingResult(
      scenarioTitle:
          (json['scenarioTitle'] ?? '').toString(),
      date: DateTime.tryParse(
            (json['date'] ?? '').toString(),
          ) ??
          DateTime.now(),
      score: _toInt(json['score']),
      decisions: _toInt(json['decisions']),
      durationSeconds:
          _toInt(json['durationSeconds']),
      resourceScore:
          _toInt(json['resourceScore']),
      stabilityScore:
          _toInt(json['stabilityScore']),
      progressScore:
          _toInt(json['progressScore']),
      adaptationScore:
          _toInt(json['adaptationScore']),
      goalScore:
          _toInt(json['goalScore']),
      uncertaintyScore:
          _toInt(json['uncertaintyScore']),
      timeScore:
          _toInt(json['timeScore']),
      level:
          (json['level'] ?? '').toString(),
      outcome:
          (json['outcome'] ?? '').toString(),
      decisionHistory: rawHistory is List
          ? rawHistory
              .map((item) => item.toString())
              .toList()
          : const [],
    );
  }

  static int _toInt(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is double) {
      return value.round();
    }

    return int.tryParse(
          value?.toString() ?? '',
        ) ??
        0;
  }
}

