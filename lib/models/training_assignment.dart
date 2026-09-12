import 'app_user.dart';
import 'scenario.dart';

enum AssignmentStatus {
  assigned,
  inProgress,
  completed,
  overdue;

  String get label {
    switch (this) {
      case AssignmentStatus.assigned:
        return 'НАЗНАЧЕНО';
      case AssignmentStatus.inProgress:
        return 'В ПРОЦЕССЕ';
      case AssignmentStatus.completed:
        return 'ЗАВЕРШЕНО';
      case AssignmentStatus.overdue:
        return 'ПРОСРОЧЕНО';
    }
  }

  static AssignmentStatus fromName(
    String? value,
  ) {
    return AssignmentStatus.values.firstWhere(
      (item) => item.name == value,
      orElse: () =>
          AssignmentStatus.assigned,
    );
  }
}

class TrainingAssignment {
  final String id;

  final String scenarioTitle;
  final String scenarioId;

  final String assigneeUserId;
  final String assigneeCallsign;

  final String assignedByUserId;
  final String assignedByCallsign;

  final DateTime assignedAt;
  final DateTime? dueAt;

  final AssignmentStatus status;

  final int? finalScore;
  final DateTime? completedAt;

  // Снимок сценария.
  // Нужен, чтобы назначенная тренировка
  // не зависела от дальнейшего удаления
  // или изменения исходного сценария.
  final String scenarioDescription;
  final String scenarioTime;
  final String scenarioResources;
  final String scenarioConditions;
  final String scenarioOptionA;
  final String scenarioOptionB;
  final String scenarioOptionC;
  final String scenarioGoal;
  final List<String> scenarioCriteria;

  const TrainingAssignment({
    required this.id,
    required this.scenarioTitle,
    required this.scenarioId,
    required this.assigneeUserId,
    required this.assigneeCallsign,
    required this.assignedByUserId,
    required this.assignedByCallsign,
    required this.assignedAt,
    this.dueAt,
    this.status =
        AssignmentStatus.assigned,
    this.finalScore,
    this.completedAt,
    this.scenarioDescription = '',
    this.scenarioTime = '',
    this.scenarioResources = '',
    this.scenarioConditions = '',
    this.scenarioOptionA = '',
    this.scenarioOptionB = '',
    this.scenarioOptionC = '',
    this.scenarioGoal = '',
    this.scenarioCriteria = const [],
  });

  bool get isCompleted =>
      status ==
      AssignmentStatus.completed;

  bool get isOverdue {
    if (isCompleted || dueAt == null) {
      return false;
    }

    return DateTime.now().isAfter(
      dueAt!,
    );
  }

  AssignmentStatus get effectiveStatus {
    if (isCompleted) {
      return AssignmentStatus.completed;
    }

    if (isOverdue) {
      return AssignmentStatus.overdue;
    }

    return status;
  }

  bool get hasScenarioSnapshot {
    return scenarioDescription
            .trim()
            .isNotEmpty &&
        scenarioOptionA.trim().isNotEmpty &&
        scenarioOptionB.trim().isNotEmpty &&
        scenarioOptionC.trim().isNotEmpty;
  }

  TrainingScenario toScenario() {
    return TrainingScenario(
      title: scenarioTitle,
      description: scenarioDescription,
      time: scenarioTime,
      resources: scenarioResources,
      conditions: scenarioConditions,
      optionA: scenarioOptionA,
      optionB: scenarioOptionB,
      optionC: scenarioOptionC,
      goal: scenarioGoal,
      criteria: scenarioCriteria,
    );
  }

  factory TrainingAssignment.fromScenario({
    required TrainingScenario scenario,
    required AppUser assignee,
    required AppUser assignedBy,
    DateTime? dueAt,
  }) {
    final now = DateTime.now();

    final assignmentId =
        now.microsecondsSinceEpoch
            .toString();

    return TrainingAssignment(
      id: assignmentId,
      scenarioId:
          'snapshot_$assignmentId',
      scenarioTitle:
          scenario.title,
      assigneeUserId:
          assignee.id,
      assigneeCallsign:
          assignee.callsign,
      assignedByUserId:
          assignedBy.id,
      assignedByCallsign:
          assignedBy.callsign,
      assignedAt: now,
      dueAt: dueAt,
      scenarioDescription:
          scenario.description,
      scenarioTime:
          scenario.time,
      scenarioResources:
          scenario.resources,
      scenarioConditions:
          scenario.conditions,
      scenarioOptionA:
          scenario.optionA,
      scenarioOptionB:
          scenario.optionB,
      scenarioOptionC:
          scenario.optionC,
      scenarioGoal:
          scenario.goal,
      scenarioCriteria:
          List<String>.from(
        scenario.criteria,
      ),
    );
  }

  TrainingAssignment copyWith({
    String? id,
    String? scenarioTitle,
    String? scenarioId,
    String? assigneeUserId,
    String? assigneeCallsign,
    String? assignedByUserId,
    String? assignedByCallsign,
    DateTime? assignedAt,
    DateTime? dueAt,
    bool clearDueAt = false,
    AssignmentStatus? status,
    int? finalScore,
    bool clearFinalScore = false,
    DateTime? completedAt,
    bool clearCompletedAt = false,
    String? scenarioDescription,
    String? scenarioTime,
    String? scenarioResources,
    String? scenarioConditions,
    String? scenarioOptionA,
    String? scenarioOptionB,
    String? scenarioOptionC,
    String? scenarioGoal,
    List<String>? scenarioCriteria,
  }) {
    return TrainingAssignment(
      id: id ?? this.id,
      scenarioTitle:
          scenarioTitle ??
              this.scenarioTitle,
      scenarioId:
          scenarioId ??
              this.scenarioId,
      assigneeUserId:
          assigneeUserId ??
              this.assigneeUserId,
      assigneeCallsign:
          assigneeCallsign ??
              this.assigneeCallsign,
      assignedByUserId:
          assignedByUserId ??
              this.assignedByUserId,
      assignedByCallsign:
          assignedByCallsign ??
              this.assignedByCallsign,
      assignedAt:
          assignedAt ??
              this.assignedAt,
      dueAt: clearDueAt
          ? null
          : dueAt ?? this.dueAt,
      status:
          status ?? this.status,
      finalScore: clearFinalScore
          ? null
          : finalScore ??
              this.finalScore,
      completedAt:
          clearCompletedAt
              ? null
              : completedAt ??
                  this.completedAt,
      scenarioDescription:
          scenarioDescription ??
              this.scenarioDescription,
      scenarioTime:
          scenarioTime ??
              this.scenarioTime,
      scenarioResources:
          scenarioResources ??
              this.scenarioResources,
      scenarioConditions:
          scenarioConditions ??
              this.scenarioConditions,
      scenarioOptionA:
          scenarioOptionA ??
              this.scenarioOptionA,
      scenarioOptionB:
          scenarioOptionB ??
              this.scenarioOptionB,
      scenarioOptionC:
          scenarioOptionC ??
              this.scenarioOptionC,
      scenarioGoal:
          scenarioGoal ??
              this.scenarioGoal,
      scenarioCriteria:
          scenarioCriteria ??
              this.scenarioCriteria,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'scenarioTitle':
          scenarioTitle,
      'scenarioId':
          scenarioId,
      'assigneeUserId':
          assigneeUserId,
      'assigneeCallsign':
          assigneeCallsign,
      'assignedByUserId':
          assignedByUserId,
      'assignedByCallsign':
          assignedByCallsign,
      'assignedAt':
          assignedAt
              .toIso8601String(),
      'dueAt':
          dueAt?.toIso8601String(),
      'status': status.name,
      'finalScore':
          finalScore,
      'completedAt':
          completedAt
              ?.toIso8601String(),
      'scenarioDescription':
          scenarioDescription,
      'scenarioTime':
          scenarioTime,
      'scenarioResources':
          scenarioResources,
      'scenarioConditions':
          scenarioConditions,
      'scenarioOptionA':
          scenarioOptionA,
      'scenarioOptionB':
          scenarioOptionB,
      'scenarioOptionC':
          scenarioOptionC,
      'scenarioGoal':
          scenarioGoal,
      'scenarioCriteria':
          scenarioCriteria,
    };
  }

  factory TrainingAssignment.fromJson(
    Map<String, dynamic> json,
  ) {
    final rawCriteria =
        json['scenarioCriteria'];

    return TrainingAssignment(
      id: json['id']?.toString() ??
          '',
      scenarioTitle:
          json['scenarioTitle']
                  ?.toString() ??
              '',
      scenarioId:
          json['scenarioId']
                  ?.toString() ??
              '',
      assigneeUserId:
          json['assigneeUserId']
                  ?.toString() ??
              '',
      assigneeCallsign:
          json['assigneeCallsign']
                  ?.toString() ??
              '',
      assignedByUserId:
          json['assignedByUserId']
                  ?.toString() ??
              '',
      assignedByCallsign:
          json['assignedByCallsign']
                  ?.toString() ??
              '',
      assignedAt:
          DateTime.tryParse(
                json['assignedAt']
                        ?.toString() ??
                    '',
              ) ??
              DateTime.now(),
      dueAt: DateTime.tryParse(
        json['dueAt']?.toString() ??
            '',
      ),
      status:
          AssignmentStatus.fromName(
        json['status']?.toString(),
      ),
      finalScore:
          json['finalScore'] is num
              ? (json['finalScore']
                      as num)
                  .toInt()
              : int.tryParse(
                  json['finalScore']
                          ?.toString() ??
                      '',
                ),
      completedAt:
          DateTime.tryParse(
        json['completedAt']
                ?.toString() ??
            '',
      ),
      scenarioDescription:
          json['scenarioDescription']
                  ?.toString() ??
              '',
      scenarioTime:
          json['scenarioTime']
                  ?.toString() ??
              '',
      scenarioResources:
          json['scenarioResources']
                  ?.toString() ??
              '',
      scenarioConditions:
          json['scenarioConditions']
                  ?.toString() ??
              '',
      scenarioOptionA:
          json['scenarioOptionA']
                  ?.toString() ??
              '',
      scenarioOptionB:
          json['scenarioOptionB']
                  ?.toString() ??
              '',
      scenarioOptionC:
          json['scenarioOptionC']
                  ?.toString() ??
              '',
      scenarioGoal:
          json['scenarioGoal']
                  ?.toString() ??
              '',
      scenarioCriteria:
          rawCriteria is List
              ? rawCriteria
                  .map(
                    (item) =>
                        item.toString(),
                  )
                  .toList()
              : const [],
    );
  }
}

