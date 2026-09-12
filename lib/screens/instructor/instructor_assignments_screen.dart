import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../app/user_session_scope.dart';
import '../../models/training_assignment.dart';
import '../../services/assignment_storage_service.dart';

class InstructorAssignmentsScreen
    extends StatefulWidget {
  const InstructorAssignmentsScreen({
    super.key,
  });

  @override
  State<InstructorAssignmentsScreen> createState() =>
      _InstructorAssignmentsScreenState();
}

class _InstructorAssignmentsScreenState
    extends State<InstructorAssignmentsScreen> {
  List<TrainingAssignment> _items = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user =
        UserSessionScope.read(context)
            .currentUser;

    if (user == null) {
      if (mounted) {
        setState(() {
          _items = const [];
          _loading = false;
        });
      }
      return;
    }

    final items =
        await AssignmentStorageService
            .loadAssignedBy(
      user.id,
    );

    items.sort(
      (a, b) => b.assignedAt
          .compareTo(a.assignedAt),
    );

    if (!mounted) return;

    setState(() {
      _items = items;
      _loading = false;
    });
  }

  int get _activeCount => _items
      .where(
        (item) =>
            item.effectiveStatus !=
            AssignmentStatus.completed,
      )
      .length;

  int get _completedCount => _items
      .where(
        (item) =>
            item.effectiveStatus ==
            AssignmentStatus.completed,
      )
      .length;

  int get _overdueCount => _items
      .where(
        (item) =>
            item.effectiveStatus ==
            AssignmentStatus.overdue,
      )
      .length;

  String _formatDate(
    DateTime? date,
  ) {
    if (date == null) {
      return 'Без срока';
    }

    final day =
        date.day.toString().padLeft(2, '0');
    final month =
        date.month.toString().padLeft(2, '0');

    return '$day.$month.${date.year}';
  }

  Color _statusColor(
    AssignmentStatus status,
  ) {
    switch (status) {
      case AssignmentStatus.completed:
        return const Color(0xFF4EE39A);
      case AssignmentStatus.overdue:
        return const Color(0xFFFF6B6B);
      case AssignmentStatus.inProgress:
        return const Color(0xFFFFC857);
      case AssignmentStatus.assigned:
        return TactixTheme.cyan;
    }
  }

  Future<void> _delete(
    TrainingAssignment item,
  ) async {
    final answer =
        await showDialog<bool>(
      context: context,
      builder: (dialogContext) =>
          AlertDialog(
        title: const Text(
          'Удалить назначение?',
        ),
        content: Text(
          'Удалить тренировку В«${item.scenarioTitle}В» для ${item.assigneeCallsign}?',
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(
              dialogContext,
              false,
            ),
            child:
                const Text('ОТМЕНА'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(
              dialogContext,
              true,
            ),
            child:
                const Text('УДАЛИТЬ'),
          ),
        ],
      ),
    );

    if (answer != true) return;

    await AssignmentStorageService.delete(
      item.id,
    );

    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TactixTheme.bg,
      appBar: AppBar(
        title: const Text(
          'КОНТРОЛЬ НАЗНАЧЕНИЙ',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Обновить',
            onPressed:
                _loading ? null : _load,
            icon: const Icon(
              Icons.sync_rounded,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        color: TactixTheme.gold,
        backgroundColor:
            TactixTheme.panel,
        child: ListView(
          padding:
              const EdgeInsets.fromLTRB(
            20,
            20,
            20,
            40,
          ),
          children: [
            _Summary(
              active: _activeCount,
              overdue: _overdueCount,
              completed:
                  _completedCount,
            ),
            const SizedBox(height: 20),
            if (_loading)
              const Padding(
                padding:
                    EdgeInsets.only(top: 60),
                child: Center(
                  child:
                      CircularProgressIndicator(),
                ),
              )
            else if (_items.isEmpty)
              const _EmptyState()
            else
              ..._items.map(
                (item) => Padding(
                  padding:
                      const EdgeInsets.only(
                    bottom: 10,
                  ),
                  child: _AssignmentCard(
                    item: item,
                    dueText:
                        _formatDate(
                      item.dueAt,
                    ),
                    statusColor:
                        _statusColor(
                      item.effectiveStatus,
                    ),
                    onDelete: () =>
                        _delete(item),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Summary
    extends StatelessWidget {
  final int active;
  final int overdue;
  final int completed;

  const _Summary({
    required this.active,
    required this.overdue,
    required this.completed,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _Metric(
          label: 'АКТИВНЫЕ',
          value: active,
          color: TactixTheme.cyan,
        ),
        _Metric(
          label: 'ПРОСРОЧЕНЫ',
          value: overdue,
          color:
              const Color(0xFFFF6B6B),
        ),
        _Metric(
          label: 'ЗАВЕРШЕНЫ',
          value: completed,
          color:
              const Color(0xFF4EE39A),
        ),
      ],
    );
  }
}

class _Metric
    extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _Metric({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 155,
      padding:
          const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TactixTheme.panel,
        borderRadius:
            BorderRadius.circular(14),
        border: Border.all(
          color: color.withValues(
            alpha: .25,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color:
                  TactixTheme.textMuted,
              fontSize: 9,
              fontWeight:
                  FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            '$value',
            style: TextStyle(
              color: color,
              fontSize: 28,
              fontWeight:
                  FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _AssignmentCard
    extends StatelessWidget {
  final TrainingAssignment item;
  final String dueText;
  final Color statusColor;
  final VoidCallback onDelete;

  const _AssignmentCard({
    required this.item,
    required this.dueText,
    required this.statusColor,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TactixTheme.panel,
        borderRadius:
            BorderRadius.circular(14),
        border: Border.all(
          color: TactixTheme.line,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: TactixTheme.gold
                      .withValues(
                    alpha: .08,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    11,
                  ),
                  border: Border.all(
                    color: TactixTheme.gold
                        .withValues(
                      alpha: .22,
                    ),
                  ),
                ),
                child: const Icon(
                  Icons.person_outline,
                  color: TactixTheme.gold,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Text(
                      item.assigneeCallsign,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight:
                            FontWeight.w900,
                      ),
                    ),
                    const SizedBox(
                      height: 3,
                    ),
                    Text(
                      item.scenarioTitle,
                      maxLines: 1,
                      overflow:
                          TextOverflow
                              .ellipsis,
                      style: const TextStyle(
                        color:
                            Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets
                        .symmetric(
                  horizontal: 9,
                  vertical: 6,
                ),
                decoration:
                    BoxDecoration(
                  color: statusColor
                      .withValues(
                    alpha: .09,
                  ),
                  borderRadius:
                      BorderRadius
                          .circular(8),
                  border: Border.all(
                    color: statusColor
                        .withValues(
                      alpha: .3,
                    ),
                  ),
                ),
                child: Text(
                  item.effectiveStatus
                      .label,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 9,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip:
                    'Удалить назначение',
                onPressed: onDelete,
                icon: const Icon(
                  Icons.delete_outline,
                  color: Colors.white38,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 18,
            runSpacing: 8,
            children: [
              _Info(
                icon:
                    Icons.event_outlined,
                text:
                    'Срок: $dueText',
              ),
              _Info(
                icon:
                    Icons.schedule_outlined,
                text:
                    'Назначено: ${_date(item.assignedAt)}',
              ),
              if (item.finalScore != null)
                _Info(
                  icon:
                      Icons.score_outlined,
                  text:
                      'TACTIX Score: ${item.finalScore}',
                ),
              if (item.completedAt != null)
                _Info(
                  icon:
                      Icons.check_circle_outline,
                  text:
                      'Завершено: ${_date(item.completedAt!)}',
                ),
            ],
          ),
          if (item.finalScore != null) ...[
            const SizedBox(height: 14),
            LinearProgressIndicator(
              value:
                  item.finalScore!.clamp(
                        0,
                        100,
                      ) /
                      100,
              minHeight: 7,
              borderRadius:
                  BorderRadius.circular(
                10,
              ),
              backgroundColor:
                  TactixTheme.line,
            ),
          ],
        ],
      ),
    );
  }

  static String _date(
    DateTime date,
  ) {
    final day =
        date.day.toString().padLeft(2, '0');
    final month =
        date.month.toString().padLeft(2, '0');

    return '$day.$month.${date.year}';
  }
}

class _Info
    extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Info({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize:
          MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 15,
          color:
              TactixTheme.textMuted,
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(
            color:
                TactixTheme.textMuted,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

class _EmptyState
    extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin:
          const EdgeInsets.only(top: 24),
      padding:
          const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: TactixTheme.panel,
        borderRadius:
            BorderRadius.circular(16),
        border: Border.all(
          color: TactixTheme.line,
        ),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.assignment_outlined,
            size: 48,
            color:
                TactixTheme.textMuted,
          ),
          SizedBox(height: 12),
          Text(
            'НАЗНАЧЕНИЙ ПОКА НЕТ',
            style: TextStyle(
              fontWeight:
                  FontWeight.w900,
              letterSpacing: .8,
            ),
          ),
          SizedBox(height: 7),
          Text(
            'Созданные инструктором задания и результаты обучаемых появятся здесь.',
            textAlign:
                TextAlign.center,
            style: TextStyle(
              color:
                  TactixTheme.textMuted,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

