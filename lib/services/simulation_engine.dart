class SimulationState {
  final int time;
  final int resources;
  final int stability;
  final int progress;
  final int uncertainty;
  final int turn;

  const SimulationState({
    required this.time,
    required this.resources,
    required this.stability,
    required this.progress,
    required this.uncertainty,
    required this.turn,
  });
}

class DecisionEffect {
  final String letter;
  final int timeDelta;
  final int resourcesDelta;
  final int stabilityDelta;
  final int progressDelta;
  final int uncertaintyDelta;

  const DecisionEffect({
    required this.letter,
    required this.timeDelta,
    required this.resourcesDelta,
    required this.stabilityDelta,
    required this.progressDelta,
    required this.uncertaintyDelta,
  });
}

class DecisionScore {
  final int total;
  final int goal;
  final int resources;
  final int stability;
  final int uncertainty;
  final int time;
  final int scoreDelta;
  final Map<String, double> weights;

  const DecisionScore({
    required this.total,
    required this.goal,
    required this.resources,
    required this.stability,
    required this.uncertainty,
    required this.time,
    required this.scoreDelta,
    required this.weights,
  });

  String get level {
    if (total >= 85) return 'Отлично';
    if (total >= 70) return 'Хорошо';
    if (total >= 55) return 'Удовлетворительно';
    return 'Требует развития';
  }

  Map<String, dynamic> toJson() {
    return {
      'total': total,
      'level': level,
      'goal': goal,
      'resources': resources,
      'stability': stability,
      'uncertainty': uncertainty,
      'time': time,
      'scoreDelta': scoreDelta,
      'weights': weights,
    };
  }
}

class StateDelta {
  final int time;
  final int resources;
  final int stability;
  final int progress;
  final int uncertainty;

  const StateDelta({
    required this.time,
    required this.resources,
    required this.stability,
    required this.progress,
    required this.uncertainty,
  });

  Map<String, int> toJson() {
    return {
      'time': time,
      'resources': resources,
      'stability': stability,
      'progress': progress,
      'uncertainty': uncertainty,
    };
  }
}

class SimulationResult {
  final SimulationState state;
  final List<String> events;
  final String summary;
  final bool completed;
  final String outcome;
  final DecisionScore decisionScore;
  final StateDelta delta;

  const SimulationResult({
    required this.state,
    required this.events,
    required this.summary,
    required this.completed,
    required this.outcome,
    required this.decisionScore,
    required this.delta,
  });
}

class SimulationEngine {
  const SimulationEngine();

  SimulationResult applyDecision(
    SimulationState current,
    String decision,
  ) {
    final effect = _effectForDecision(decision);

    var time = current.time + effect.timeDelta;
    var resources = current.resources + effect.resourcesDelta;
    var stability = current.stability + effect.stabilityDelta;
    var progress = current.progress + effect.progressDelta;
    var uncertainty =
        current.uncertainty + effect.uncertaintyDelta;

    final events = <String>[
      _decisionEvent(decision),
    ];

    if (current.uncertainty >= 70) {
      stability -= 4;
      events.add(
        'Высокая неопределённость дополнительно снизила устойчивость.',
      );
    }

    if (current.resources <= 30) {
      progress -= 3;
      events.add(
        'Ограниченный ресурс замедлил продвижение к учебной цели.',
      );
    }

    if (current.stability >= 80) {
      progress += 2;
      events.add(
        'Высокая устойчивость помогла сохранить темп.',
      );
    }

    _applyTurnPressure(
      current.turn,
      onEvent: events.add,
      onTime: (delta) => time += delta,
      onResources: (delta) => resources += delta,
      onStability: (delta) => stability += delta,
      onProgress: (delta) => progress += delta,
      onUncertainty: (delta) => uncertainty += delta,
    );

    time = time.clamp(0, 120);
    resources = resources.clamp(0, 100);
    stability = stability.clamp(0, 100);
    progress = progress.clamp(0, 100);
    uncertainty = uncertainty.clamp(0, 100);

    final nextTurn = current.turn + 1;

    final newState = SimulationState(
      time: time,
      resources: resources,
      stability: stability,
      progress: progress,
      uncertainty: uncertainty,
      turn: nextTurn,
    );

    final delta = StateDelta(
      time: newState.time - current.time,
      resources: newState.resources - current.resources,
      stability: newState.stability - current.stability,
      progress: newState.progress - current.progress,
      uncertainty: newState.uncertainty - current.uncertainty,
    );

    final decisionScore = scoreDecision(
      before: current,
      after: newState,
    );

    // КЛЮЧЕВАЯ ПРАВКА: ровно 3 решения.
    final completed =
        current.turn >= 3 ||
        time <= 0 ||
        resources <= 0 ||
        progress >= 100;

    return SimulationResult(
      state: newState,
      events: events,
      summary: _buildSummary(newState),
      completed: completed,
      outcome: _calculateOutcome(newState),
      decisionScore: decisionScore,
      delta: delta,
    );
  }

  /// Прозрачная локальная оценка качества решения.
  ///
  /// Важно: итоговая цифра НЕ генерируется AI. Она считается
  /// детерминированно из состояния до/после решения. AI может
  /// только объяснять уже рассчитанный результат.
  DecisionScore scoreDecision({
    required SimulationState before,
    required SimulationState after,
  }) {
    final deltaProgress = after.progress - before.progress;
    final deltaResources = after.resources - before.resources;
    final deltaStability = after.stability - before.stability;
    final deltaUncertainty = after.uncertainty - before.uncertainty;

    final goalScore = _clampScore(
      50 + deltaProgress * 2.5,
    );

    final resourceEfficiency = _clampScore(
      100 + deltaResources * 3.0,
    );
    final resourceScore = _clampScore(
      after.resources * 0.5 + resourceEfficiency * 0.5,
    );

    final stabilityResponse = _clampScore(
      50 + deltaStability * 5.0,
    );
    final stabilityScore = _clampScore(
      after.stability * 0.5 + stabilityResponse * 0.5,
    );

    final uncertaintyResponse = _clampScore(
      50 - deltaUncertainty * 3.0,
    );
    final uncertaintyControl = 100 - after.uncertainty;
    final uncertaintyScore = _clampScore(
      uncertaintyControl * 0.5 + uncertaintyResponse * 0.5,
    );

    final timeScore = before.time <= 0
        ? 0
        : _clampScore(
            after.time / before.time * 100,
          );

    final weights = _adaptiveWeights(before);

    final total = _clampScore(
      goalScore * weights['goal']! +
          resourceScore * weights['resources']! +
          stabilityScore * weights['stability']! +
          uncertaintyScore * weights['uncertainty']! +
          timeScore * weights['time']!,
    );

    final beforeBaseline = _baselineStateScore(before);
    final afterBaseline = _baselineStateScore(after);

    return DecisionScore(
      total: total,
      goal: goalScore,
      resources: resourceScore,
      stability: stabilityScore,
      uncertainty: uncertaintyScore,
      time: timeScore,
      scoreDelta: afterBaseline - beforeBaseline,
      weights: weights,
    );
  }

  Map<String, double> _adaptiveWeights(
    SimulationState state,
  ) {
    final weights = <String, double>{
      'goal': 0.35,
      'resources': 0.20,
      'stability': 0.20,
      'uncertainty': 0.15,
      'time': 0.10,
    };

    // Контекстная адаптация критериев без участия AI.
    if (state.resources <= 35) {
      weights['resources'] = weights['resources']! + 0.10;
    }
    if (state.stability <= 40) {
      weights['stability'] = weights['stability']! + 0.10;
    }
    if (state.uncertainty >= 65) {
      weights['uncertainty'] = weights['uncertainty']! + 0.10;
    }
    if (state.time <= 20) {
      weights['time'] = weights['time']! + 0.10;
    }
    if (state.turn >= 3 && state.progress < 70) {
      weights['goal'] = weights['goal']! + 0.10;
    }

    final sum = weights.values.fold<double>(
      0,
      (value, item) => value + item,
    );

    return weights.map(
      (key, value) => MapEntry(key, value / sum),
    );
  }

  int _baselineStateScore(SimulationState state) {
    final raw =
        state.resources * 0.20 +
        state.stability * 0.20 +
        state.progress * 0.35 +
        (100 - state.uncertainty) * 0.15 +
        (state.time.clamp(0, 120) / 120 * 100) * 0.10;

    return _clampScore(raw);
  }

  int _clampScore(num value) {
    return value.round().clamp(0, 100);
  }

  DecisionEffect _effectForDecision(String decision) {
    switch (decision) {
      case 'A':
        return const DecisionEffect(
          letter: 'A',
          timeDelta: -7,
          resourcesDelta: -15,
          stabilityDelta: -6,
          progressDelta: 18,
          uncertaintyDelta: 8,
        );

      case 'B':
        return const DecisionEffect(
          letter: 'B',
          timeDelta: -6,
          resourcesDelta: -9,
          stabilityDelta: 4,
          progressDelta: 12,
          uncertaintyDelta: -3,
        );

      case 'C':
        return const DecisionEffect(
          letter: 'C',
          timeDelta: -9,
          resourcesDelta: -5,
          stabilityDelta: 3,
          progressDelta: 6,
          uncertaintyDelta: -14,
        );

      default:
        return const DecisionEffect(
          letter: 'X',
          timeDelta: -5,
          resourcesDelta: -8,
          stabilityDelta: 0,
          progressDelta: 4,
          uncertaintyDelta: 3,
        );
    }
  }

  String _decisionEvent(String decision) {
    switch (decision) {
      case 'A':
        return 'Интенсивный подход ускорил прогресс, но повысил нагрузку на систему.';
      case 'B':
        return 'Сбалансированный подход обеспечил умеренный прогресс при контролируемом риске.';
      case 'C':
        return 'Осторожный подход уменьшил неопределённость, но потребовал больше времени.';
      default:
        return 'Применено нейтральное решение.';
    }
  }

  void _applyTurnPressure(
    int turn, {
    required void Function(String) onEvent,
    required void Function(int) onTime,
    required void Function(int) onResources,
    required void Function(int) onStability,
    required void Function(int) onProgress,
    required void Function(int) onUncertainty,
  }) {
    switch (turn) {
      case 1:
        onEvent('Исходные условия ещё относительно стабильны.');
        break;

      case 2:
        onTime(-2);
        onUncertainty(3);
        onEvent('Появилось дополнительное ограничение.');
        break;

      case 3:
        onResources(-3);
        onStability(-2);
        onEvent('Финальный этап требует завершить учебную задачу.');
        break;
    }
  }

  String _calculateOutcome(SimulationState state) {
    if (state.progress >= 100 && state.stability >= 50) {
      return 'success';
    }

    if (state.resources <= 0 || state.time <= 0) {
      return 'resource_failure';
    }

    if (state.stability < 25) {
      return 'stability_failure';
    }

    if (state.progress >= 70) {
      return 'partial_success';
    }

    return 'incomplete';
  }

  String _buildSummary(SimulationState state) {
    if (state.progress >= 100) {
      return 'Учебная цель достигнута.';
    }

    if (state.time <= 0) {
      return 'Временной ресурс исчерпан.';
    }

    if (state.resources <= 0) {
      return 'Запас ресурса исчерпан.';
    }

    if (state.stability < 25) {
      return 'Система находится в критически нестабильном состоянии.';
    }

    if (state.uncertainty >= 75) {
      return 'Неопределённость стала высокой и требует особого внимания.';
    }

    if (state.progress >= 70) {
      return 'Прогресс высокий, но учебная цель ещё не полностью закрыта.';
    }

    return 'Ситуация остаётся управляемой.';
  }
}

