class TrainingScenario {
  final String title;
  final String description;
  final String time;
  final String resources;
  final String conditions;

  final String optionA;
  final String optionB;
  final String optionC;

  final String goal;
  final List<String> criteria;

  const TrainingScenario({
    required this.title,
    required this.description,
    required this.time,
    required this.resources,
    required this.conditions,
    required this.optionA,
    required this.optionB,
    required this.optionC,
    this.goal = '',
    this.criteria = const [],
  });

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
      'goal': goal,
      'criteria': criteria,
    };
  }

  factory TrainingScenario.fromJson(
    Map<String, dynamic> json,
  ) {
    final rawCriteria = json['criteria'];

    final criteria = rawCriteria is List
        ? rawCriteria
            .map((item) => item.toString())
            .toList()
        : <String>[];

    return TrainingScenario(
      title: (json['title'] ?? '').toString(),
      description:
          (json['description'] ?? '').toString(),
      time: (json['time'] ?? '').toString(),
      resources:
          (json['resources'] ?? '').toString(),
      conditions:
          (json['conditions'] ?? '').toString(),
      optionA:
          (json['optionA'] ?? '').toString(),
      optionB:
          (json['optionB'] ?? '').toString(),
      optionC:
          (json['optionC'] ?? '').toString(),
      goal: (json['goal'] ?? '').toString(),
      criteria: criteria,
    );
  }
}
