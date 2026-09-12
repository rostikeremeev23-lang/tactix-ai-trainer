class DecisionRecord {
  final int turn;
  final String decision;
  final int score;

  final int goalScore;
  final int resourceScore;
  final int stabilityScore;
  final int uncertaintyScore;
  final int timeScore;

  final String level;
  final Map<String, int> delta;

  const DecisionRecord({
    required this.turn,
    required this.decision,
    required this.score,
    this.goalScore = 0,
    this.resourceScore = 0,
    this.stabilityScore = 0,
    this.uncertaintyScore = 0,
    this.timeScore = 0,
    this.level = '',
    this.delta = const {},
  });
}

