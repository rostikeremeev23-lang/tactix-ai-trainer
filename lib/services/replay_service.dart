import '../models/decision_record.dart';
import '../models/training_debrief_data.dart';
import 'simulation_engine.dart';

class ReplayFrame {
  final int index;
  final DecisionRecord record;
  final SimulationState before;
  final SimulationState after;
  final int runningScore;

  const ReplayFrame({
    required this.index,
    required this.record,
    required this.before,
    required this.after,
    required this.runningScore,
  });
}

class WhatIfResult {
  final int changedIndex;
  final String originalDecision;
  final String alternativeDecision;
  final int originalFinalScore;
  final int alternativeFinalScore;
  final List<ReplayFrame> frames;

  const WhatIfResult({
    required this.changedIndex,
    required this.originalDecision,
    required this.alternativeDecision,
    required this.originalFinalScore,
    required this.alternativeFinalScore,
    required this.frames,
  });

  int get delta => alternativeFinalScore - originalFinalScore;
}

class ReplayService {
  const ReplayService();

  List<ReplayFrame> buildFrames(TrainingDebriefData data) {
    if (data.history.isEmpty) return const [];

    final frames = <ReplayFrame>[];
    var current = data.initialState;
    var scoreSum = 0;

    for (var index = 0; index < data.history.length; index++) {
      final record = data.history[index];
      final after = _applyRecordedDelta(current, record.delta);
      scoreSum += record.score;

      frames.add(
        ReplayFrame(
          index: index,
          record: record,
          before: current,
          after: after,
          runningScore: (scoreSum / (index + 1)).round().clamp(0, 100),
        ),
      );

      current = after;
    }

    return frames;
  }

  List<int> scoreEvolution(TrainingDebriefData data) {
    return buildFrames(data).map((frame) => frame.runningScore).toList();
  }

  ReplayFrame? keyMoment(TrainingDebriefData data) {
    final frames = buildFrames(data);
    if (frames.isEmpty) return null;

    var selected = frames.first;
    var selectedDistance = (selected.record.score - data.score).abs();

    for (final frame in frames.skip(1)) {
      final distance = (frame.record.score - data.score).abs();
      if (distance > selectedDistance) {
        selected = frame;
        selectedDistance = distance;
      }
    }

    return selected;
  }

  WhatIfResult simulateAlternative({
    required TrainingDebriefData data,
    required int changedIndex,
    required String alternativeDecision,
  }) {
    final actualFrames = buildFrames(data);
    if (actualFrames.isEmpty) {
      throw StateError('Нет решений для альтернативной симуляции.');
    }
    if (changedIndex < 0 || changedIndex >= actualFrames.length) {
      throw RangeError.index(changedIndex, actualFrames, 'changedIndex');
    }

    final normalized = alternativeDecision.trim().toUpperCase();
    if (!const {'A', 'B', 'C'}.contains(normalized)) {
      throw ArgumentError.value(
        alternativeDecision,
        'alternativeDecision',
        'Допустимы только A, B или C.',
      );
    }

    const engine = SimulationEngine();
    final alternativeFrames = <ReplayFrame>[];
    var current = data.initialState;
    var scoreSum = 0;

    for (var index = 0; index < actualFrames.length; index++) {
      final actualFrame = actualFrames[index];
      final originalRecord = actualFrame.record;
      final chosenDecision = index == changedIndex
          ? normalized
          : originalRecord.decision;

      // Внешняя среда в ScenarioRunScreen добавляется после SimulationEngine.
      // Вычисляем фактический остаточный модификатор исходного хода и применяем
      // тот же модификатор к альтернативной ветке. Поэтому WHAT IF остаётся
      // детерминированным и не меняет исходный результат.
      final originalBase = engine
          .applyDecision(actualFrame.before, originalRecord.decision)
          .state;
      final residual = _stateDifference(actualFrame.after, originalBase);

      final alternativeBase = engine.applyDecision(current, chosenDecision).state;
      final alternativeAfter = _applyResidual(alternativeBase, residual);
      final score = engine.scoreDecision(
        before: current,
        after: alternativeAfter,
      );
      final delta = _stateDifference(alternativeAfter, current);

      final alternativeRecord = DecisionRecord(
        turn: originalRecord.turn,
        decision: chosenDecision,
        score: score.total,
        goalScore: score.goal,
        resourceScore: score.resources,
        stabilityScore: score.stability,
        uncertaintyScore: score.uncertainty,
        timeScore: score.time,
        level: score.level,
        delta: delta,
      );

      scoreSum += score.total;
      alternativeFrames.add(
        ReplayFrame(
          index: index,
          record: alternativeRecord,
          before: current,
          after: alternativeAfter,
          runningScore: (scoreSum / (index + 1)).round().clamp(0, 100),
        ),
      );

      current = alternativeAfter;
    }

    return WhatIfResult(
      changedIndex: changedIndex,
      originalDecision: actualFrames[changedIndex].record.decision,
      alternativeDecision: normalized,
      originalFinalScore: data.score,
      alternativeFinalScore: alternativeFrames.last.runningScore,
      frames: alternativeFrames,
    );
  }

  String decisionLabel(String decision) {
    switch (decision.toUpperCase()) {
      case 'A':
        return 'Интенсивный подход';
      case 'B':
        return 'Сбалансированный подход';
      case 'C':
        return 'Осторожный подход';
      default:
        return 'Решение';
    }
  }

  SimulationState _applyRecordedDelta(
    SimulationState before,
    Map<String, int> delta,
  ) {
    return SimulationState(
      time: _clamp(before.time + (delta['time'] ?? 0), 0, 120),
      resources: _clamp(
        before.resources + (delta['resources'] ?? 0),
        0,
        100,
      ),
      stability: _clamp(
        before.stability + (delta['stability'] ?? 0),
        0,
        100,
      ),
      progress: _clamp(
        before.progress + (delta['progress'] ?? 0),
        0,
        100,
      ),
      uncertainty: _clamp(
        before.uncertainty + (delta['uncertainty'] ?? 0),
        0,
        100,
      ),
      turn: before.turn + 1,
    );
  }

  Map<String, int> _stateDifference(
    SimulationState after,
    SimulationState before,
  ) {
    return <String, int>{
      'time': after.time - before.time,
      'resources': after.resources - before.resources,
      'stability': after.stability - before.stability,
      'progress': after.progress - before.progress,
      'uncertainty': after.uncertainty - before.uncertainty,
    };
  }

  SimulationState _applyResidual(
    SimulationState state,
    Map<String, int> residual,
  ) {
    return SimulationState(
      time: _clamp(state.time + (residual['time'] ?? 0), 0, 120),
      resources: _clamp(
        state.resources + (residual['resources'] ?? 0),
        0,
        100,
      ),
      stability: _clamp(
        state.stability + (residual['stability'] ?? 0),
        0,
        100,
      ),
      progress: _clamp(
        state.progress + (residual['progress'] ?? 0),
        0,
        100,
      ),
      uncertainty: _clamp(
        state.uncertainty + (residual['uncertainty'] ?? 0),
        0,
        100,
      ),
      turn: state.turn,
    );
  }

  int _clamp(int value, int min, int max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }
}
