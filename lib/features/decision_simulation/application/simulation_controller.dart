import 'package:flutter/foundation.dart';

import '../data/run_repository.dart';
import '../domain/decision_engine.dart';
import '../domain/models.dart';

class SimulationController extends ChangeNotifier {
  final DecisionEngine engine;
  final RunRepository repository;
  RunState state;
  bool busy = false;
  String? error;
  SimulationController(this.engine, this.repository, this.state);
  Future<bool> act(String action, {String note = ''}) async {
    if (busy || state.completed) return false;
    busy = true;
    error = null;
    notifyListeners();
    try {
      final next = engine.apply(state, action, note: note);
      // Keep the old visible state if durable storage failed.
      await repository.save(next);
      state = next;
      return true;
    } catch (e) {
      error = 'Решение не сохранено: $e';
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }
}
