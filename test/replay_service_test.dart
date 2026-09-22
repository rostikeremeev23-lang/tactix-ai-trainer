import 'package:ai_trainer_mobile/models/decision_record.dart';
import 'package:ai_trainer_mobile/models/scenario.dart';
import 'package:ai_trainer_mobile/models/training_debrief_data.dart';
import 'package:ai_trainer_mobile/services/replay_service.dart';
import 'package:ai_trainer_mobile/services/simulation_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const engine = SimulationEngine();
  const service = ReplayService();
  const scenario = TrainingScenario(
    title: 'Учебный сценарий',
    description: 'Тест',
    time: '45',
    resources: '80',
    conditions: 'Учебные',
    optionA: 'A',
    optionB: 'B',
    optionC: 'C',
  );

  TrainingDebriefData buildData() {
    const initial = SimulationState(
      time: 45,
      resources: 80,
      stability: 75,
      progress: 20,
      uncertainty: 25,
      turn: 1,
    );

    var state = initial;
    final history = <DecisionRecord>[];
    for (final decision in const ['B', 'A', 'C']) {
      final result = engine.applyDecision(state, decision);
      final score = engine.scoreDecision(before: state, after: result.state);
      history.add(
        DecisionRecord(
          turn: state.turn,
          decision: decision,
          score: score.total,
          goalScore: score.goal,
          resourceScore: score.resources,
          stabilityScore: score.stability,
          uncertaintyScore: score.uncertainty,
          timeScore: score.time,
          level: score.level,
          delta: result.delta.toJson(),
        ),
      );
      state = result.state;
    }

    final finalScore =
        (history.fold<int>(0, (sum, item) => sum + item.score) / history.length)
            .round();

    return TrainingDebriefData(
      scenario: scenario,
      initialState: initial,
      finalState: state,
      history: history,
      score: finalScore,
      aar: 'AAR',
    );
  }

  test('replay reconstructs decision order and final state', () {
    final data = buildData();
    final frames = service.buildFrames(data);

    expect(frames.length, 3);
    expect(frames.map((item) => item.record.decision), ['B', 'A', 'C']);
    expect(frames.last.after.time, data.finalState.time);
    expect(frames.last.after.resources, data.finalState.resources);
    expect(frames.last.after.stability, data.finalState.stability);
    expect(frames.last.after.progress, data.finalState.progress);
    expect(frames.last.after.uncertainty, data.finalState.uncertainty);
    expect(frames.last.runningScore, data.score);
  });

  test('what if with the same decision reproduces original score', () {
    final data = buildData();
    final result = service.simulateAlternative(
      data: data,
      changedIndex: 1,
      alternativeDecision: data.history[1].decision,
    );

    expect(result.alternativeFinalScore, data.score);
    expect(result.frames.length, data.history.length);
  });

  test('what if never mutates original debrief data', () {
    final data = buildData();
    final original = List<String>.from(
      data.history.map((item) => item.decision),
    );

    service.simulateAlternative(
      data: data,
      changedIndex: 0,
      alternativeDecision: 'C',
    );

    expect(data.history.map((item) => item.decision), original);
  });
}
