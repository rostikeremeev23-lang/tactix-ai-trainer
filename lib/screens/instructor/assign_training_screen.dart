import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../app/user_session_scope.dart';
import '../../models/app_user.dart';
import '../../models/scenario.dart';
import '../../models/training_assignment.dart';
import '../../services/assignment_storage_service.dart';
import '../../services/storage_service.dart';
import '../../services/user_storage_service.dart';

class AssignTrainingScreen
    extends StatefulWidget {
  const AssignTrainingScreen({
    super.key,
  });

  @override
  State<AssignTrainingScreen> createState() =>
      _AssignTrainingScreenState();
}

class _AssignTrainingScreenState
    extends State<AssignTrainingScreen> {
  List<AppUser> _trainees = const [];
  List<TrainingScenario> _scenarios = const [];

  AppUser? _selectedTrainee;
  TrainingScenario? _selectedScenario;

  DateTime? _dueAt;

  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();

    _dueAt = DateTime.now().add(
      const Duration(days: 7),
    );

    _load();
  }

  Future<void> _load() async {
    final currentUser =
        UserSessionScope.read(context)
            .currentUser;

    final users =
        await UserStorageService.loadUsers();

    final scenarios =
        await ScenarioStorage.load();

    if (!mounted) return;

    final trainees = users
        .where(
          (user) =>
              user.id != currentUser?.id &&
              user.role == UserRole.trainee &&
              user.isActive,
        )
        .toList()
      ..sort(
        (a, b) => a.callsign
            .toLowerCase()
            .compareTo(
              b.callsign.toLowerCase(),
            ),
      );

    setState(() {
      _trainees = trainees;
      _scenarios = scenarios;

      if (_trainees.length == 1) {
        _selectedTrainee =
            _trainees.first;
      }

      if (_scenarios.length == 1) {
        _selectedScenario =
            _scenarios.first;
      }

      _loading = false;
    });
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

  Future<void> _pickDueDate() async {
    final now = DateTime.now();

    final selected =
        await showDatePicker(
      context: context,
      initialDate: _dueAt ??
          now.add(
            const Duration(days: 7),
          ),
      firstDate: DateTime(
        now.year,
        now.month,
        now.day,
      ),
      lastDate: DateTime(
        now.year + 2,
        12,
        31,
      ),
    );

    if (selected == null ||
        !mounted) {
      return;
    }

    setState(() {
      _dueAt = DateTime(
        selected.year,
        selected.month,
        selected.day,
        23,
        59,
      );
    });
  }

  Future<void> _assign() async {
    final instructor =
        UserSessionScope.read(context)
            .currentUser;

    final trainee =
        _selectedTrainee;

    final scenario =
        _selectedScenario;

    if (instructor == null) {
      return;
    }

    if (trainee == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Выберите обучаемого.',
          ),
        ),
      );
      return;
    }

    if (scenario == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Выберите сценарий.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _saving = true;
    });

    final assignment =
        TrainingAssignment.fromScenario(
      scenario: scenario,
      assignee: trainee,
      assignedBy: instructor,
      dueAt: _dueAt,
    );

    try {
      await AssignmentStorageService
          .upsert(
        assignment,
      );

      if (!mounted) return;

      Navigator.pop(
        context,
        assignment,
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _saving = false;
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Не удалось создать назначение: $e',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TactixTheme.bg,
      appBar: AppBar(
        title: const Text(
          'НАЗНАЧИТЬ ТРЕНИРОВКУ',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: .3),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _HeaderCard(
                        trainees: _trainees.length,
                        scenarios: _scenarios.length,
                      ),
                      const SizedBox(height: 18),
                      const _FormStep(title: '01  Обучаемый'),
                      if (_trainees.isEmpty)
                        const _MissingCard(
                          icon: Icons.groups_outlined,
                          title: 'НЕТ ОБУЧАЕМЫХ',
                          text: 'Сначала добавьте хотя бы одного обучаемого в режиме инструктора.',
                        )
                      else
                        DropdownButtonFormField<AppUser>(
                          isExpanded: true,
                          itemHeight: null,
                          initialValue: _selectedTrainee,
                          decoration: const InputDecoration(
                            labelText: 'Обучаемый',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                          items: _trainees
                              .map(
                                (user) => DropdownMenuItem(
                                  value: user,
                                  child: Text(user.callsign),
                                ),
                              )
                              .toList(),
                          onChanged: _saving
                              ? null
                              : (value) {
                                  setState(() {
                                    _selectedTrainee = value;
                                  });
                                },
                        ),
                      const SizedBox(height: 14),
                      const _FormStep(title: '02  Сценарий'),
                      if (_scenarios.isEmpty)
                        const _MissingCard(
                          icon: Icons.description_outlined,
                          title: 'НЕТ СЦЕНАРИЕВ',
                          text: 'Сначала сохраните учебный сценарий, затем назначьте его обучаемому.',
                        )
                      else
                        DropdownButtonFormField<TrainingScenario>(
                          isExpanded: true,
                          itemHeight: null,
                          initialValue: _selectedScenario,
                          decoration: const InputDecoration(
                            labelText: 'Сценарий',
                            prefixIcon: Icon(Icons.description_outlined),
                          ),
                          items: _scenarios
                              .map(
                                (scenario) => DropdownMenuItem(
                                  value: scenario,
                                  child: Text(scenario.title, softWrap: true),
                                ),
                              )
                              .toList(),
                          onChanged: _saving
                              ? null
                              : (value) {
                                  setState(() {
                                    _selectedScenario = value;
                                  });
                                },
                        ),
                      const SizedBox(height: 14),
                      if (_selectedScenario != null)
                        _ScenarioPreview(scenario: _selectedScenario!),
                      const SizedBox(height: 14),
                      const _FormStep(title: '03  Параметры'),
                      InkWell(
                        onTap: _saving ? null : _pickDueDate,
                        borderRadius: BorderRadius.circular(12),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Срок выполнения',
                            prefixIcon: Icon(Icons.event_outlined),
                          ),
                          child: Wrap(
                            spacing: 12,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(_formatDate(_dueAt)),
                              TextButton(
                                onPressed: _saving
                                    ? null
                                    : () {
                                        setState(() {
                                          _dueAt = null;
                                        });
                                      },
                                child: const Text('БЕЗ СРОКА'),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const _FormStep(title: '04  Назначить'),
                      FilledButton.icon(
                        onPressed:
                            _saving || _trainees.isEmpty || _scenarios.isEmpty
                            ? null
                            : _assign,
                        icon: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.assignment_turned_in_outlined),
                        label: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: Text(
                            _saving ? 'СОХРАНЕНИЕ...' : 'НАЗНАЧИТЬ ТРЕНИРОВКУ',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              letterSpacing: .7,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final int trainees;
  final int scenarios;

  const _HeaderCard({required this.trainees, required this.scenarios});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: TactixTheme.panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: TactixTheme.line),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.assignment_outlined,
            color: TactixTheme.gold,
            size: 28,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'НОВОЕ НАЗНАЧЕНИЕ',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    letterSpacing: .8,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '$trainees обучаемых • $scenarios сценариев',
                  style: const TextStyle(
                    color: TactixTheme.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScenarioPreview extends StatelessWidget {
  final TrainingScenario scenario;

  const _ScenarioPreview({required this.scenario});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TactixTheme.panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: TactixTheme.gold.withValues(alpha: .22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ПРЕДПРОСМОТР',
            style: TextStyle(
              color: TactixTheme.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: .3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            scenario.title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 7),
          Text(
            scenario.description,

            softWrap: true,
            style: const TextStyle(color: Colors.white70, height: 1.45),
          ),
          if (scenario.goal.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Цель: ${scenario.goal}',
              style: const TextStyle(
                color: TactixTheme.textMuted,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MissingCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;

  const _MissingCard({
    required this.icon,
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TactixTheme.panel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: TactixTheme.line),
      ),
      child: Row(
        children: [
          Icon(icon, color: TactixTheme.textMuted),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  text,
                  style: const TextStyle(
                    color: TactixTheme.textMuted,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FormStep extends StatelessWidget {
  final String title;
  const _FormStep({required this.title});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Divider(color: TactixTheme.line, height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: TactixTheme.gold,
            ),
          ),
        ],
      ),
    );
  }
}
