/// Transparent summaries of server-confirmed educational assignments.
class TrainingSummary {
  final List<Map<String, dynamic>> assignments;
  TrainingSummary(this.assignments);
  List<Map<String, dynamic>> get completed =>
      assignments.where((a) => a['status'] == 'submitted').toList();
  int get active => assignments
      .where((a) => a['status'] == 'assigned' || a['status'] == 'in_progress')
      .length;
  int get eligible =>
      assignments.where((a) => a['status'] != 'cancelled').length;
  double get completion => eligible == 0 ? 0 : completed.length / eligible;
  int get awaitingFeedback => completed.where(needsFeedback).length;
  static bool needsFeedback(Map<String, dynamic> a) {
    if (a['status'] != 'submitted') return false;
    if ((a['feedback'] as String? ?? '').trim().isEmpty) return true;
    final submitted = DateTime.tryParse(a['submitted_at'] ?? '');
    final reviewed = DateTime.tryParse(a['feedback_at'] ?? '');
    return submitted != null &&
        reviewed != null &&
        reviewed.isBefore(submitted);
  }

  static double progress(Map<String, dynamic> a) {
    if (a['status'] == 'submitted') return 1;
    final duration = (a['scenario']['duration'] as num).toDouble();
    return duration <= 0
        ? 0
        : ((a['metrics']?['tick'] as num? ?? 0) / duration).clamp(0.0, 1.0);
  }

  static DateTime time(Map<String, dynamic> a) =>
      DateTime.tryParse(a['submitted_at'] ?? a['updated_at'] ?? '') ??
      DateTime.fromMillisecondsSinceEpoch(0);
}
