import 'decision_record.dart';
import 'scenario.dart';
import '../services/simulation_engine.dart';

class TrainingDebriefData {
  final TrainingScenario scenario;
  final SimulationState initialState;
  final SimulationState finalState;
  final List<DecisionRecord> history;
  final int score;
  final String aar;
  const TrainingDebriefData({required this.scenario, required this.initialState, required this.finalState, required this.history, required this.score, required this.aar});
  Map<String, dynamic> toSafeContext() => {
    'scenario_title': scenario.title, 'goal': scenario.goal,
    'score': score,
    'decisions': history.map((d) => {'turn': d.turn, 'decision': d.decision, 'score': d.score, 'delta': d.delta}).toList(),
    'metrics': {'resources': finalState.resources, 'stability': finalState.stability, 'progress': finalState.progress, 'uncertainty': finalState.uncertainty, 'time': finalState.time},
    'aar': aar.length > 2400 ? aar.substring(0, 2400) : aar,
  };
}