/// Pure Dart authoring model. No network or UI dependencies.
class Condition {
  final String? variable;
  final int minimum;
  final String? flag;
  final bool expected;
  final List<Condition> all;
  final List<Condition> any;
  const Condition({
    this.variable,
    this.minimum = 0,
    this.flag,
    this.expected = true,
    this.all = const [],
    this.any = const [],
  });
  bool matches(RunState state) =>
      (variable == null || (state.values[variable] ?? 0) >= minimum) &&
      (flag == null || state.flags.contains(flag) == expected) &&
      all.every((c) => c.matches(state)) &&
      (any.isEmpty || any.any((c) => c.matches(state)));
}

class Effect {
  final Map<String, int> delta;
  final Set<String> flags;
  final Set<String> removeFlags;
  const Effect({
    this.delta = const {},
    this.flags = const {},
    this.removeFlags = const {},
  });
}

class Consequence {
  final String id;
  final int afterSteps;
  final String text;
  final Effect effect;
  final Condition condition;
  const Consequence(
    this.id,
    this.afterSteps,
    this.text,
    this.effect, {
    this.condition = const Condition(),
  });
}

class Transition {
  final String target;
  final Condition when;
  const Transition(this.target, {this.when = const Condition()});
}

class StoryAction {
  final String id, title, tradeoff, response;
  final int minutes, supplies;
  final bool inquiry;
  final String? document;
  final Condition when;
  final Effect effect;
  final List<Consequence> delayed;
  final List<Transition> transitions;
  const StoryAction({
    required this.id,
    required this.title,
    required this.tradeoff,
    required this.response,
    this.minutes = 2,
    this.supplies = 0,
    this.inquiry = false,
    this.document,
    this.when = const Condition(),
    this.effect = const Effect(),
    this.delayed = const [],
    this.transitions = const [],
  });
}

class SceneVariant {
  final Condition when;
  final String text;
  const SceneVariant(this.when, this.text);
}

class StoryScene {
  final String id, title, location, speaker, text;
  final List<String> documents;
  final List<SceneVariant> variants;
  final List<StoryAction> actions;
  const StoryScene({
    required this.id,
    required this.title,
    required this.location,
    required this.speaker,
    required this.text,
    required this.actions,
    this.documents = const [],
    this.variants = const [],
  });
}

class StoryDocument {
  final String id, title, source, reliability, text;
  const StoryDocument(
    this.id,
    this.title,
    this.source,
    this.reliability,
    this.text,
  );
}

class StoryCharacter {
  final String id, name, role, position;
  const StoryCharacter(this.id, this.name, this.role, this.position);
}

class StoryEnding {
  final String id, title, text;
  final Condition when;
  const StoryEnding(this.id, this.title, this.text, this.when);
}

class ChanceEvent {
  final String id, occurredText, absentText;
  final int afterStep, percent;
  final Condition when;
  final Effect effect;
  const ChanceEvent({
    required this.id,
    required this.afterStep,
    required this.percent,
    required this.occurredText,
    required this.absentText,
    required this.effect,
    this.when = const Condition(),
  });
}

class DecisionScenario {
  final String id, version, title, intro;
  final List<StoryScene> scenes;
  final List<StoryDocument> documents;
  final List<StoryCharacter> characters;
  final List<StoryEnding> endings;
  final List<ChanceEvent> chanceEvents;
  const DecisionScenario({
    required this.id,
    required this.version,
    required this.title,
    required this.intro,
    required this.scenes,
    required this.documents,
    required this.characters,
    required this.endings,
    this.chanceEvents = const [],
  });
  StoryScene scene(String id) => scenes.firstWhere((s) => s.id == id);
  StoryDocument document(String id) => documents.firstWhere((d) => d.id == id);
}

class PendingConsequence {
  final String id, cause, text;
  final int due;
  final Effect effect;
  final Condition condition;
  const PendingConsequence({
    required this.id,
    required this.cause,
    required this.text,
    required this.due,
    required this.effect,
    required this.condition,
  });
  Map<String, Object?> toJson() => {'id': id, 'cause': cause, 'due': due};
}

class RunEvent {
  final int sequence, step;
  final String scene, kind, text, cause;
  final Map<String, int> delta;
  RunEvent({
    required this.sequence,
    required this.step,
    required this.scene,
    required this.kind,
    required this.text,
    required this.cause,
    Map<String, int> delta = const {},
  }) : delta = Map.unmodifiable(delta);
  Map<String, Object?> toJson() => {
    'sequence': sequence,
    'step': step,
    'scene': scene,
    'kind': kind,
    'text': text,
    'cause': cause,
    'delta': delta,
  };
}

class RunCommand {
  final String scene, action, note;
  const RunCommand(this.scene, this.action, [this.note = '']);
  Map<String, Object?> toJson() => {
    'scene': scene,
    'action': action,
    'note': note,
  };
  factory RunCommand.fromJson(Map<String, dynamic> json) => RunCommand(
    json['scene'] as String,
    json['action'] as String,
    json['note'] as String? ?? '',
  );
}

class RunState {
  final String runId, sceneId;
  final int seed, randomState, step, revision;
  final Map<String, int> values;
  final Set<String> flags, usedActions, knownDocuments;
  final List<PendingConsequence> pending;
  final List<RunEvent> events;
  final List<RunCommand> commands;
  final String? ending;
  RunState({
    required this.runId,
    required this.sceneId,
    required this.seed,
    required this.randomState,
    this.step = 0,
    this.revision = 0,
    required Map<String, int> values,
    Set<String> flags = const {},
    Set<String> usedActions = const {},
    Set<String> knownDocuments = const {},
    List<PendingConsequence> pending = const [],
    List<RunEvent> events = const [],
    List<RunCommand> commands = const [],
    this.ending,
  }) : values = Map.unmodifiable(values),
       flags = Set.unmodifiable(flags),
       usedActions = Set.unmodifiable(usedActions),
       knownDocuments = Set.unmodifiable(knownDocuments),
       pending = List.unmodifiable(pending),
       events = List.unmodifiable(events),
       commands = List.unmodifiable(commands);
  bool get completed => ending != null;
  int get minutes => values['time']!;
  Map<String, Object?> toJson() => {
    'runId': runId,
    'scene': sceneId,
    'seed': seed,
    'random': randomState,
    'step': step,
    'revision': revision,
    'values': values,
    'flags': flags.toList()..sort(),
    'used': usedActions.toList()..sort(),
    'documents': knownDocuments.toList()..sort(),
    'pending': pending.map((p) => p.toJson()).toList(),
    'events': events.map((e) => e.toJson()).toList(),
    'commands': commands.map((c) => c.toJson()).toList(),
    'ending': ending,
  };
}
