import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/training_assignment.dart';

class AssignmentStorageService {
  AssignmentStorageService._();

  static const String _assignmentsKey =
      'tactix_training_assignments';

  static Future<List<TrainingAssignment>>
      loadAll() async {
    final prefs =
        await SharedPreferences.getInstance();

    final raw =
        prefs.getString(_assignmentsKey);

    if (raw == null || raw.isEmpty) {
      return const [];
    }

    try {
      final decoded = jsonDecode(raw);

      if (decoded is! List) {
        return const [];
      }

      return decoded
          .whereType<Map>()
          .map(
            (item) =>
                TrainingAssignment.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<void> saveAll(
    List<TrainingAssignment> assignments,
  ) async {
    final prefs =
        await SharedPreferences.getInstance();

    await prefs.setString(
      _assignmentsKey,
      jsonEncode(
        assignments
            .map(
              (assignment) =>
                  assignment.toJson(),
            )
            .toList(),
      ),
    );
  }

  static Future<void> upsert(
    TrainingAssignment assignment,
  ) async {
    final assignments =
        (await loadAll()).toList();

    final index = assignments.indexWhere(
      (item) => item.id == assignment.id,
    );

    if (index == -1) {
      assignments.add(assignment);
    } else {
      assignments[index] = assignment;
    }

    await saveAll(assignments);
  }

  static Future<List<TrainingAssignment>>
      loadForAssignee(
    String userId,
  ) async {
    final assignments =
        await loadAll();

    final filtered = assignments
        .where(
          (item) =>
              item.assigneeUserId == userId,
        )
        .toList();

    filtered.sort(
      (a, b) =>
          b.assignedAt.compareTo(a.assignedAt),
    );

    return filtered;
  }

  static Future<List<TrainingAssignment>>
      loadAssignedBy(
    String userId,
  ) async {
    final assignments =
        await loadAll();

    final filtered = assignments
        .where(
          (item) =>
              item.assignedByUserId == userId,
        )
        .toList();

    filtered.sort(
      (a, b) =>
          b.assignedAt.compareTo(a.assignedAt),
    );

    return filtered;
  }

  static Future<void> markInProgress(
    String assignmentId,
  ) async {
    final assignments =
        (await loadAll()).toList();

    final index = assignments.indexWhere(
      (item) => item.id == assignmentId,
    );

    if (index == -1) {
      return;
    }

    assignments[index] =
        assignments[index].copyWith(
      status: AssignmentStatus.inProgress,
    );

    await saveAll(assignments);
  }

  static Future<void> markCompleted(
    String assignmentId, {
    required int finalScore,
  }) async {
    final assignments =
        (await loadAll()).toList();

    final index = assignments.indexWhere(
      (item) => item.id == assignmentId,
    );

    if (index == -1) {
      return;
    }

    assignments[index] =
        assignments[index].copyWith(
      status: AssignmentStatus.completed,
      finalScore: finalScore,
      completedAt: DateTime.now(),
    );

    await saveAll(assignments);
  }

  static Future<void> delete(
    String assignmentId,
  ) async {
    final assignments =
        (await loadAll()).toList();

    assignments.removeWhere(
      (item) => item.id == assignmentId,
    );

    await saveAll(assignments);
  }

  static Future<void> clearAll() async {
    final prefs =
        await SharedPreferences.getInstance();

    await prefs.remove(_assignmentsKey);
  }
}

