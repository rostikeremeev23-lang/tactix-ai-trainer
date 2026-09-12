import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../app/responsive.dart';
import '../../models/scenario.dart';
import '../../services/storage_service.dart';
import '../../widgets/common_widgets.dart';
import 'trainee_roster_screen.dart';
import 'assign_training_screen.dart';
import 'instructor_assignments_screen.dart';

class InstructorModeScreen extends StatefulWidget {
  final Widget Function(TrainingScenario scenario) runScreenBuilder;

  const InstructorModeScreen({
    super.key,
    required this.runScreenBuilder,
  });

  @override
  State<InstructorModeScreen> createState() =>
      _InstructorModeScreenState();
}

class _InstructorModeScreenState extends State<InstructorModeScreen> {
  final titleController = TextEditingController(
    text: 'Автономный учебный центр',
  );
  final descriptionController = TextEditingController(
    text:
        'После отказа внешней инфраструктуры учебный центр должен продолжить работу автономно. Необходимо распределить ограниченные условные ресурсы, сохранить устойчивость и выполнить основную задачу в установленное время.',
  );
  final goalController = TextEditingController(
    text:
        'Выполнить учебную задачу, сохранив достаточный резерв ресурсов и устойчивость системы.',
  );
  final timeController = TextEditingController(text: '45');
  final resourcesController = TextEditingController(text: '70');
  final conditionsController = TextEditingController(
    text:
        'Внешняя сеть недоступна. Доступны только локальные данные и встроенный движок TACTIX.',
  );
  final optionAController = TextEditingController(
    text:
        'Ускорить выполнение основной задачи, допустив повышенный расход условного ресурса.',
  );
  final optionBController = TextEditingController(
    text:
        'Сохранить сбалансированный режим и распределять ресурс равномерно.',
  );
  final optionCController = TextEditingController(
    text:
        'Сначала снизить неопределённость и уточнить доступные локальные данные.',
  );
  final criteriaController = TextEditingController(
    text:
        'Достижение цели\nЭффективность ресурсов\nУстойчивость\nРабота с неопределённостью\nИспользование времени',
  );

  bool saving = false;

  List<String> _criteria() {
    return criteriaController.text
        .split(RegExp(r'[\n;,]+'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .take(5)
        .toList();
  }

  TrainingScenario _buildScenario() {
    return TrainingScenario(
      title: titleController.text.trim(),
      description: descriptionController.text.trim(),
      time: timeController.text.trim(),
      resources: resourcesController.text.trim(),
      conditions: conditionsController.text.trim(),
      optionA: optionAController.text.trim(),
      optionB: optionBController.text.trim(),
      optionC: optionCController.text.trim(),
      goal: goalController.text.trim(),
      criteria: _criteria(),
    );
  }

  bool _isValid(TrainingScenario scenario) {
    return scenario.title.isNotEmpty &&
        scenario.description.isNotEmpty &&
        scenario.goal.isNotEmpty &&
        scenario.optionA.isNotEmpty &&
        scenario.optionB.isNotEmpty &&
        scenario.optionC.isNotEmpty &&
        scenario.criteria.length >= 3;
  }

  Future<void> _saveScenario() async {
    final scenario = _buildScenario();

    if (!_isValid(scenario)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Заполните название, описание, цель, варианты A/B/C и минимум 3 критерия.',
          ),
        ),
      );
      return;
    }

    setState(() => saving = true);

    try {
      await ScenarioStorage.save(scenario);
      if (!mounted) return;
      setState(() => saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Учебная задача сохранена.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка сохранения: $e')),
      );
    }
  }

  Future<void> _startTraining() async {
    final scenario = _buildScenario();

    if (!_isValid(scenario)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Заполните название, описание, цель, варианты A/B/C и минимум 3 критерия.',
          ),
        ),
      );
      return;
    }

    setState(() => saving = true);

    try {
      await ScenarioStorage.save(scenario);
      if (!mounted) return;
      setState(() => saving = false);

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => widget.runScreenBuilder(
            scenario,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка запуска: $e')),
      );
    }
  }

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    goalController.dispose();
    timeController.dispose();
    resourcesController.dispose();
    conditionsController.dispose();
    optionAController.dispose();
    optionBController.dispose();
    optionCController.dispose();
    criteriaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final horizontal = TactixResponsive.horizontalPadding(context);

    return Scaffold(
      backgroundColor: TactixTheme.bg,
      appBar: AppBar(
        title: const Text(
          'РЕЖИМ ИНСТРУКТОРА',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: 1.0,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Контроль назначений',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const InstructorAssignmentsScreen(),
                ),
              );
            },
            icon: const Icon(
              Icons.fact_check_outlined,
            ),
          ),
          IconButton(
            tooltip: 'Назначить тренировку',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const AssignTrainingScreen(),
                ),
              );
            },
            icon: const Icon(
              Icons.assignment_outlined,
            ),
          ),
          IconButton(
            tooltip: 'Обучаемые',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const TraineeRosterScreen(),
                ),
              );
            },
            icon: const Icon(
              Icons.groups_outlined,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(horizontal, 14, horizontal, 28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: TactixTheme.gold.withValues(alpha: .07),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: TactixTheme.gold.withValues(alpha: .28),
                      ),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.school_outlined, color: TactixTheme.gold),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'INSTRUCTOR CONSOLE • LOCAL',
                                style: TextStyle(
                                  color: TactixTheme.gold,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.1,
                                  fontSize: 11,
                                ),
                              ),
                              SizedBox(height: 6),
                              Text(
                                'Инструктор задаёт вводную, цель, ограничения и критерии оценки. Тренировка запускается локально и не требует внешней сети.',
                                style: TextStyle(
                                  color: Colors.white70,
                                  height: 1.45,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  const SectionTitle(text: 'УЧЕБНАЯ ЗАДАЧА'),
                  const SizedBox(height: 12),
                  AppTextField(
                    controller: titleController,
                    label: 'Название сценария',
                  ),
                  AppTextField(
                    controller: descriptionController,
                    label: 'Вводная',
                    maxLines: 5,
                  ),
                  AppTextField(
                    controller: goalController,
                    label: 'Цель',
                    maxLines: 3,
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: AppTextField(
                          controller: timeController,
                          label: 'Время',
                          hint: '45',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: AppTextField(
                          controller: resourcesController,
                          label: 'Ресурсы',
                          hint: '70',
                        ),
                      ),
                    ],
                  ),
                  AppTextField(
                    controller: conditionsController,
                    label: 'Ограничения / условия',
                    maxLines: 3,
                  ),
                  const SizedBox(height: 10),
                  const SectionTitle(text: 'ВАРИАНТЫ РЕШЕНИЯ'),
                  const SizedBox(height: 12),
                  AppTextField(
                    controller: optionAController,
                    label: 'Вариант A',
                    maxLines: 3,
                  ),
                  AppTextField(
                    controller: optionBController,
                    label: 'Вариант B',
                    maxLines: 3,
                  ),
                  AppTextField(
                    controller: optionCController,
                    label: 'Вариант C',
                    maxLines: 3,
                  ),
                  const SizedBox(height: 10),
                  const SectionTitle(text: 'КРИТЕРИИ ОЦЕНКИ'),
                  const SizedBox(height: 12),
                  AppTextField(
                    controller: criteriaController,
                    label: '3–5 критериев, каждый с новой строки',
                    maxLines: 6,
                  ),
                  const SizedBox(height: 14),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxWidth < 620;
                      final save = OutlinedButton.icon(
                        onPressed: saving ? null : _saveScenario,
                        icon: const Icon(Icons.save_outlined),
                        label: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 14),
                          child: Text('СОХРАНИТЬ ЗАДАЧУ'),
                        ),
                      );
                      final start = FilledButton.icon(
                        onPressed: saving ? null : _startTraining,
                        icon: saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.play_arrow_rounded),
                        label: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 14),
                          child: Text('ЗАПУСТИТЬ ТРЕНИРОВКУ'),
                        ),
                      );

                      if (compact) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            save,
                            const SizedBox(height: 10),
                            start,
                          ],
                        );
                      }

                      return Row(
                        children: [
                          Expanded(child: save),
                          const SizedBox(width: 10),
                          Expanded(child: start),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

