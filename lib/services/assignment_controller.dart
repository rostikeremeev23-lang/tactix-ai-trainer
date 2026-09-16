import 'package:flutter/foundation.dart';

import '../models/training_assignment.dart';
import 'assignment_storage_service.dart';

class AssignmentController
    extends ChangeNotifier {
  List<TrainingAssignment> _items = const [];
  bool _loading = false;
  int _loadGeneration = 0;

  List<TrainingAssignment> get items =>
      List.unmodifiable(_items);

  bool get loading => _loading;

  int get activeCount => _items
      .where(
        (item) =>
            item.effectiveStatus !=
                AssignmentStatus.completed,
      )
      .length;

  int get completedCount => _items
      .where(
        (item) =>
            item.effectiveStatus ==
                AssignmentStatus.completed,
      )
      .length;

  int get overdueCount => _items
      .where(
        (item) =>
            item.effectiveStatus ==
                AssignmentStatus.overdue,
      )
      .length;

  Future<void> loadForAssignee(
    String userId,
  ) async {
    final generation =
        ++_loadGeneration;
    _items = const [];
    _loading = true;
    notifyListeners();

    try {
      final items =
          await AssignmentStorageService
              .loadForAssignee(userId);
      if (generation !=
          _loadGeneration) {
        return;
      }
      _items = items;
    } finally {
      if (generation ==
          _loadGeneration) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadAssignedBy(
    String userId,
  ) async {
    final generation =
        ++_loadGeneration;
    _items = const [];
    _loading = true;
    notifyListeners();

    try {
      final items =
          await AssignmentStorageService
              .loadAssignedBy(userId);
      if (generation !=
          _loadGeneration) {
        return;
      }
      _items = items;
    } finally {
      if (generation ==
          _loadGeneration) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  void resetLoaded() {
    _loadGeneration++;
    _items = const [];
    _loading = false;
    notifyListeners();
  }

  Future<void> create(
    TrainingAssignment assignment,
  ) async {
    await AssignmentStorageService.upsert(
      assignment,
    );

    _items = [
      assignment,
      ..._items.where(
        (item) =>
            item.id != assignment.id,
      ),
    ];

    notifyListeners();
  }

  Future<void> markInProgress(
    String assignmentId,
  ) async {
    await AssignmentStorageService
        .markInProgress(
      assignmentId,
    );

    _items = _items
        .map(
          (item) => item.id == assignmentId
              ? item.copyWith(
                  status:
                      AssignmentStatus.inProgress,
                )
              : item,
        )
        .toList();

    notifyListeners();
  }

  Future<void> markCompleted(
    String assignmentId, {
    required int finalScore,
  }) async {
    await AssignmentStorageService
        .markCompleted(
      assignmentId,
      finalScore: finalScore,
    );

    _items = _items
        .map(
          (item) => item.id == assignmentId
              ? item.copyWith(
                  status:
                      AssignmentStatus.completed,
                  finalScore: finalScore,
                  completedAt: DateTime.now(),
                )
              : item,
        )
        .toList();

    notifyListeners();
  }

  Future<void> delete(
    String assignmentId,
  ) async {
    await AssignmentStorageService.delete(
      assignmentId,
    );

    _items = _items
        .where(
          (item) =>
              item.id != assignmentId,
        )
        .toList();

    notifyListeners();
  }

  Future<void> clear() async {
    await AssignmentStorageService
        .clearAll();

    _items = const [];
    notifyListeners();
  }
}

