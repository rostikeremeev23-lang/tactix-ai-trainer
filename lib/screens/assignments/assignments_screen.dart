import 'package:flutter/material.dart';

import '../../app/assignment_scope.dart';
import '../../app/theme.dart';
import '../../app/user_session_scope.dart';
import '../../models/training_assignment.dart';
import '../training/scenario_run_screen.dart';

class AssignmentsScreen extends StatelessWidget {
  const AssignmentsScreen({
    super.key,
  });

  Future<void> _refresh(
    BuildContext context,
  ) async {
    final user =
        UserSessionScope.read(context)
            .currentUser;

    if (user == null) {
      return;
    }

    await AssignmentScope.read(context)
        .loadForAssignee(user.id);
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

  @override
  Widget build(BuildContext context) {
    final controller =
        AssignmentScope.of(context);

    final items =
        controller.items.toList();

    final active = items
        .where(
          (item) =>
              item.effectiveStatus !=
                  AssignmentStatus.completed,
        )
        .toList();

    final completed = items
        .where(
          (item) =>
              item.effectiveStatus ==
                  AssignmentStatus.completed,
        )
        .toList();

    return Scaffold(
      backgroundColor: TactixTheme.bg,
      appBar: AppBar(
        title: const Text(
          'НАЗНАЧЕННЫЕ ТРЕНИРОВКИ',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Обновить',
            onPressed: controller.loading
                ? null
                : () => _refresh(context),
            icon: const Icon(
              Icons.sync_rounded,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _refresh(context),
        color: TactixTheme.gold,
        backgroundColor:
            TactixTheme.panel,
        child: ListView(
          padding:
              const EdgeInsets.all(20),
          children: [
            _SummaryRow(
              active:
                  controller.activeCount,
              overdue:
                  controller.overdueCount,
              completed:
                  controller.completedCount,
            ),
            const SizedBox(height: 22),
            if (controller.loading)
              const Padding(
                padding:
                    EdgeInsets.only(top: 60),
                child: Center(
                  child:
                      CircularProgressIndicator(),
                ),
              )
            else if (items.isEmpty)
              const _EmptyAssignments()
            else ...[
              const _SectionHeader(
                title: 'АКТИВНЫЕ',
              ),
              const SizedBox(height: 10),
              if (active.isEmpty)
                const _EmptySection(
                  text:
                      'Активных назначений нет',
                )
              else
                ...active.map(
                  (item) => Padding(
                    padding:
                        const EdgeInsets.only(
                      bottom: 10,
                    ),
                    child: _AssignmentCard(
                      assignment: item,
                      statusColor:
                          _statusColor(
                        item.effectiveStatus,
                      ),
                      dueText:
                          _formatDate(
                        item.dueAt,
                      ),
                      onStart:
                          item.hasScenarioSnapshot
                              ? () async {
                                  await controller
                                      .markInProgress(
                                    item.id,
                                  );

                                  if (!context.mounted) {
                                    return;
                                  }

                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          ScenarioRunScreen(
                                        scenario:
                                            item.toScenario(),
                                        onCompleted:
                                            (score) async {
                                          await controller
                                              .markCompleted(
                                            item.id,
                                            finalScore:
                                                score,
                                          );
                                        },
                                      ),
                                    ),
                                  );

                                  if (!context.mounted) {
                                    return;
                                  }

                                  await _refresh(
                                    context,
                                  );
                                }
                              : null,
                    ),
                  ),
                ),
              const SizedBox(height: 18),
              const _SectionHeader(
                title: 'ЗАВЕРШЁННЫЕ',
              ),
              const SizedBox(height: 10),
              if (completed.isEmpty)
                const _EmptySection(
                  text:
                      'Завершённых назначений пока нет',
                )
              else
                ...completed.map(
                  (item) => Padding(
                    padding:
                        const EdgeInsets.only(
                      bottom: 10,
                    ),
                    child: _AssignmentCard(
                      assignment: item,
                      statusColor:
                          _statusColor(
                        item.effectiveStatus,
                      ),
                      dueText:
                          _formatDate(
                        item.dueAt,
                      ),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SummaryRow
    extends StatelessWidget {
  final int active;
  final int overdue;
  final int completed;

  const _SummaryRow({
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
        _SummaryCard(
          label: 'АКТИВНЫЕ',
          value: active,
          color: TactixTheme.cyan,
        ),
        _SummaryCard(
          label: 'ПРОСРОЧЕНЫ',
          value: overdue,
          color:
              const Color(0xFFFF6B6B),
        ),
        _SummaryCard(
          label: 'ЗАВЕРШЕНЫ',
          value: completed,
          color:
              const Color(0xFF4EE39A),
        ),
      ],
    );
  }
}

class _SummaryCard
    extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _SummaryCard({
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
  final TrainingAssignment assignment;
  final Color statusColor;
  final String dueText;
  final VoidCallback? onStart;

  const _AssignmentCard({
    required this.assignment,
    required this.statusColor,
    required this.dueText,
    this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    final status =
        assignment.effectiveStatus;

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
              Expanded(
                child: Text(
                  assignment
                      .scenarioTitle,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 12),
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
                  status.label,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 9,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _Meta(
                icon:
                    Icons.person_outline,
                text:
                    'Назначил: ${assignment.assignedByCallsign}',
              ),
              _Meta(
                icon:
                    Icons.event_outlined,
                text:
                    'Срок: $dueText',
              ),
              if (assignment.finalScore !=
                  null)
                _Meta(
                  icon:
                      Icons.score_outlined,
                  text:
                      'TACTIX Score: ${assignment.finalScore}',
                ),
            ],
          ),
          if (onStart != null) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onStart,
                icon: const Icon(
                  Icons.play_arrow_rounded,
                ),
                label: Text(
                  assignment.status ==
                          AssignmentStatus.inProgress
                      ? 'ПРОДОЛЖИТЬ ТРЕНИРОВКУ'
                      : 'НАЧАТЬ ТРЕНИРОВКУ',
                  style: const TextStyle(
                    fontWeight:
                        FontWeight.w900,
                    letterSpacing: .6,
                  ),
                ),
              ),
            ),
          ] else if (!assignment.isCompleted &&
              !assignment.hasScenarioSnapshot) ...[
            const SizedBox(height: 12),
            const Text(
              'Сценарий недоступен: назначение создано до обновления системы.',
              style: TextStyle(
                color: TactixTheme.textMuted,
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Meta({
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

class _SectionHeader
    extends StatelessWidget {
  final String title;

  const _SectionHeader({
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: TactixTheme.textMuted,
        fontSize: 10,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.4,
      ),
    );
  }
}

class _EmptyAssignments
    extends StatelessWidget {
  const _EmptyAssignments();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin:
          const EdgeInsets.only(top: 26),
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
            size: 42,
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
            'Новые учебные задания от инструктора появятся здесь.',
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

class _EmptySection
    extends StatelessWidget {
  final String text;

  const _EmptySection({
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TactixTheme.panel,
        borderRadius:
            BorderRadius.circular(12),
        border: Border.all(
          color: TactixTheme.line,
        ),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color:
              TactixTheme.textMuted,
        ),
      ),
    );
  }
}

