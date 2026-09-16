import 'package:ai_trainer_mobile/services/simulation_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('TACTIX score is deterministic for identical local input', () {
    const engine = SimulationEngine();
    const state = SimulationState(
      time: 45,
      resources: 80,
      stability: 75,
      progress: 20,
      uncertainty: 25,
      turn: 1,
    );

    final first = engine.applyDecision(state, 'B');
    final second = engine.applyDecision(state, 'B');

    expect(second.state.time, first.state.time);
    expect(second.state.resources, first.state.resources);
    expect(second.state.stability, first.state.stability);
    expect(second.state.progress, first.state.progress);
    expect(second.state.uncertainty, first.state.uncertainty);
    expect(second.decisionScore.toJson(), first.decisionScore.toJson());
  });

  test('different local decisions produce bounded score components', () {
    const engine = SimulationEngine();
    const state = SimulationState(
      time: 45,
      resources: 80,
      stability: 75,
      progress: 20,
      uncertainty: 25,
      turn: 1,
    );

    for (final decision in const ['A', 'B', 'C']) {
      final score = engine.applyDecision(state, decision).decisionScore;
      expect(score.total, inInclusiveRange(0, 100));
      expect(score.goal, inInclusiveRange(0, 100));
      expect(score.resources, inInclusiveRange(0, 100));
      expect(score.stability, inInclusiveRange(0, 100));
      expect(score.uncertainty, inInclusiveRange(0, 100));
      expect(score.time, inInclusiveRange(0, 100));
    }
  });
}
