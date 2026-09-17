import 'package:flutter/material.dart';

import '../../app/responsive.dart';
import '../../app/theme.dart';
import '../../models/scenario.dart';
import '../../services/ai_service.dart';
import '../../services/environment_service.dart';
import '../../services/storage_service.dart';
import '../../widgets/common_widgets.dart';
import '../training/scenario_run_screen.dart';

class AIScenarioScreen extends StatefulWidget {
  final String? initialIdea;
  final String initialDifficulty;
  final String initialFocus;

  const AIScenarioScreen({
    super.key,
    this.initialIdea,
    this.initialDifficulty = 'INTERMEDIATE',
    this.initialFocus = 'АДАПТАЦИЯ',
  });

  @override
  State<AIScenarioScreen> createState() => _AIScenarioScreenState();
}

class _AIScenarioScreenState extends State<AIScenarioScreen> {
  final ideaController = TextEditingController();
  final titleController = TextEditingController();
  final descriptionController = TextEditingController();
  final timeController = TextEditingController();
  final resourcesController = TextEditingController();
  final conditionsController = TextEditingController();
  final optionAController = TextEditingController();
  final optionBController = TextEditingController();
  final optionCController = TextEditingController();

  GeneratedScenario? generated;
  bool loading = false;
  bool saving = false;
  String? error;

  late String difficulty;
  late String focus;

  @override
  void initState() {
    super.initState();
    difficulty = widget.initialDifficulty;
    focus = widget.initialFocus;
    if (widget.initialIdea != null && widget.initialIdea!.trim().isNotEmpty) {
      ideaController.text = widget.initialIdea!.trim();
    }
  }

  Future<void> generateScenario() async {
    final idea = ideaController.text.trim();

    if (idea.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Опишите учебную ситуацию.')),
      );
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      loading = true;
      error = null;
      generated = null;
    });

    try {
      // EnvironmentService.fetch() теперь работает offline-first:
      // берёт кэш или локальный безопасный профиль среды.
      final env = await EnvironmentService.fetch();

      final result = _generateLocalScenario(idea: idea, env: env);

      if (!mounted) return;

      setState(() {
        generated = result;
        titleController.text = result.title;
        descriptionController.text = result.description;
        timeController.text = result.time.toString();
        resourcesController.text = result.resources.toString();
        conditionsController.text = result.conditions;
        optionAController.text = result.optionA;
        optionBController.text = result.optionB;
        optionCController.text = result.optionC;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        loading = false;
        error = 'Не удалось создать локальный сценарий.\n\n$e';
      });
    }
  }

  GeneratedScenario _generateLocalScenario({
    required String idea,
    required EnvironmentData env,
  }) {
    int time;
    int resources;

    if (difficulty == 'BEGINNER') {
      time = 60;
      resources = 85;
    } else if (difficulty == 'ADVANCED') {
      time = 35;
      resources = 65;
    } else {
      time = 45;
      resources = 75;
    }

    String title;
    String goal;
    String optionA;
    String optionB;
    String optionC;

    switch (focus) {
      case 'СТАБИЛЬНОСТЬ':
        title = 'Сценарий устойчивого управления';
        goal = 'Выполнить учебную задачу, сохранив устойчивость системы и не допустив резкого ухудшения ключевых показателей.';
        optionA = 'Ускорить выполнение основной задачи, принимая повышенную нагрузку на устойчивость.';
        optionB = 'Сохранить сбалансированный темп и удерживать устойчивость на безопасном уровне.';
        optionC = 'Сначала стабилизировать состояние и только затем продолжить выполнение основной задачи.';
        break;

      case 'РЕСУРСЫ':
        title = 'Сценарий управления ресурсами';
        goal = 'Достичь учебной цели, сохранив достаточный резерв ресурсов до завершения сценария.';
        optionA = 'Направить больше условного ресурса на быстрый прогресс.';
        optionB =
            'Распределить ресурс равномерно между прогрессом и устойчивостью.';
        optionC = 'Снизить расход ресурса и сначала уточнить текущие условия.';
        break;

      case 'АНАЛИТИКА':
        title = 'Сценарий аналитического решения';
        goal = 'Выполнить учебную задачу, последовательно снижая неопределённость и проверяя последствия каждого решения.';
        optionA = 'Действовать быстро на основании текущих данных, принимая повышенную неопределённость.';
        optionB = 'Использовать сбалансированный вариант с контролем данных, ресурса и прогресса.';
        optionC = 'Сначала собрать и перепроверить больше информации, снизив неопределённость.';
        break;

      case 'АДАПТАЦИЯ':
      default:
        title = 'Адаптивный учебный сценарий';
        goal = 'Выполнить учебную задачу, адаптируясь к изменениям условий и сохраняя управляемость системы.';
        optionA = 'Ускорить продвижение по основной цели, принимая более высокую нагрузку.';
        optionB = 'Сохранить сбалансированный темп и адаптироваться по мере изменения условий.';
        optionC = 'Сначала снизить неопределённость и уточнить условия перед следующим действием.';
        break;
    }

    final environmentText =
        'Температура ${env.temperature.toStringAsFixed(1)}°C, '
        'влажность ${env.humidity}%, '
        'ветер ${env.windKmh.toStringAsFixed(0)} км/ч, '
        'видимость ${env.visibilityLabel}, '
        'условия: ${env.weatherLabel}.';

    final difficultyText = difficulty == 'BEGINNER'
        ? 'базовая'
        : difficulty == 'ADVANCED'
        ? 'повышенная'
        : 'средняя';

    return GeneratedScenario(
      title: title,
      description:
          '$idea\n\n'
          'Сложность: $difficultyText. Фокус: $focus. '
          'Ситуация развивается в три этапа. На каждом этапе необходимо '
          'оценивать состояние, выбирать один из вариантов A/B/C и учитывать '
          'изменение прогресса, ресурсов, устойчивости и неопределённости.',
      time: time,
      resources: resources,
      conditions:
          'Автономный режим TACTIX. $environmentText Все расчёты выполняются локально на устройстве.',
      optionA: optionA,
      optionB: optionB,
      optionC: optionC,
      criteria: const [
        'Достижение цели',
        'Эффективность ресурсов',
        'Устойчивость',
        'Работа с неопределённостью',
        'Использование времени',
      ],
      goal: goal,
    );
  }

  TrainingScenario buildScenario() {
    return TrainingScenario(
      title: titleController.text.trim(),
      description: descriptionController.text.trim(),
      time: timeController.text.trim(),
      resources: resourcesController.text.trim(),
      conditions: conditionsController.text.trim(),
      optionA: optionAController.text.trim(),
      optionB: optionBController.text.trim(),
      optionC: optionCController.text.trim(),
      goal: generated?.goal ?? '',
      criteria: generated?.criteria ?? const [],
    );
  }

  bool isValid(TrainingScenario scenario) {
    return scenario.title.isNotEmpty &&
        scenario.description.isNotEmpty &&
        scenario.optionA.isNotEmpty &&
        scenario.optionB.isNotEmpty &&
        scenario.optionC.isNotEmpty;
  }

  Future<void> saveScenario() async {
    final scenario = buildScenario();
    if (!isValid(scenario)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Заполните название, описание и варианты A/B/C.'),
        ),
      );
      return;
    }

    setState(() => saving = true);
    try {
      await ScenarioStorage.save(scenario);
      if (!mounted) return;
      setState(() => saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Сценарий сохранён.')));
    } catch (e) {
      if (!mounted) return;
      setState(() => saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    }
  }

  void startTraining() {
    final scenario = buildScenario();
    if (!isValid(scenario)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Проверьте основные поля.')));
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ScenarioRunScreen(scenario: scenario)),
    );
  }

  Widget _choiceChip(String text, bool selected, VoidCallback onTap) {
    return ChoiceChip(
      label: Text(text),
      selected: selected,
      onSelected: (_) => onTap(),
      showCheckmark: false,
      labelStyle: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w800,
        color: selected ? TactixTheme.bg : Colors.white70,
        letterSpacing: .7,
      ),
      backgroundColor: TactixTheme.panel2,
      selectedColor: TactixTheme.gold,
      side: BorderSide(color: selected ? TactixTheme.gold : TactixTheme.line),
    );
  }

  @override
  void dispose() {
    ideaController.dispose();
    titleController.dispose();
    descriptionController.dispose();
    timeController.dispose();
    resourcesController.dispose();
    conditionsController.dispose();
    optionAController.dispose();
    optionBController.dispose();
    optionCController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final env = EnvironmentService.lastData;

    return Scaffold(
      appBar: AppBar(title: const Text('ГЕНЕРАТОР СЦЕНАРИЕВ')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            TactixResponsive.horizontalPadding(context),
            18,
            TactixResponsive.horizontalPadding(context),
            28,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PanelCard(
                    accent: TactixTheme.cyan,
                    title: 'TACTIX SCENARIO GENERATOR',
                    icon: Icons.auto_awesome_rounded,
                    trailing: const Text(
                      'OFFLINE ENGINE',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Сценарий создаётся локально на устройстве с учётом сложности, фокуса и сохранённых данных среды.',
                          style: TextStyle(
                            color: TactixTheme.textMuted,
                            height: 1.45,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'СЛОЖНОСТЬ',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.1,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _choiceChip(
                              'BEGINNER',
                              difficulty == 'BEGINNER',
                              () => setState(() => difficulty = 'BEGINNER'),
                            ),
                            _choiceChip(
                              'INTERMEDIATE',
                              difficulty == 'INTERMEDIATE',
                              () => setState(() => difficulty = 'INTERMEDIATE'),
                            ),
                            _choiceChip(
                              'ADVANCED',
                              difficulty == 'ADVANCED',
                              () => setState(() => difficulty = 'ADVANCED'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'ФОКУС',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.1,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _choiceChip(
                              'АДАПТАЦИЯ',
                              focus == 'АДАПТАЦИЯ',
                              () => setState(() => focus = 'АДАПТАЦИЯ'),
                            ),
                            _choiceChip(
                              'СТАБИЛЬНОСТЬ',
                              focus == 'СТАБИЛЬНОСТЬ',
                              () => setState(() => focus = 'СТАБИЛЬНОСТЬ'),
                            ),
                            _choiceChip(
                              'РЕСУРСЫ',
                              focus == 'РЕСУРСЫ',
                              () => setState(() => focus = 'РЕСУРСЫ'),
                            ),
                            _choiceChip(
                              'АНАЛИТИКА',
                              focus == 'АНАЛИТИКА',
                              () => setState(() => focus = 'АНАЛИТИКА'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Icon(
                              Icons.public_rounded,
                              size: 16,
                              color: env == null
                                  ? Colors.white38
                                  : const Color(0xFF4EE39A),
                            ),
                            const SizedBox(width: 7),
                            Expanded(
                              child: Text(
                                env == null
                                    ? 'ENVIRONMENT DATA LOCAL'
                                    : 'ENVIRONMENT DATA LOCAL • ${env.weatherLabel}',
                                style: TextStyle(
                                  color: env == null
                                      ? Colors.white38
                                      : const Color(0xFF7FE7B8),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: .8,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 15),
                        TextField(
                          controller: ideaController,
                          maxLines: 5,
                          decoration: const InputDecoration(
                            labelText: 'Описание учебной задачи',
                            hintText: 'Например: ограниченное время, изменяющиеся условия и необходимость сохранить высокий уровень стабильности.',
                          ),
                        ),
                        const SizedBox(height: 14),
                        FilledButton.icon(
                          onPressed: loading ? null : generateScenario,
                          icon: loading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.auto_awesome, size: 18),
                          label: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            child: Text(
                              loading ? 'СОЗДАНИЕ...' : 'СОЗДАТЬ СЦЕНАРИЙ',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 14),
                    PanelCard(
                      accent: Colors.redAccent,
                      title: 'GENERATION ERROR',
                      icon: Icons.error_outline,
                      child: Text(
                        error!,
                        style: const TextStyle(
                          color: Colors.redAccent,
                          height: 1.45,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                  if (generated != null) ...[
                    const SizedBox(height: 14),
                    PanelCard(
                      accent: TactixTheme.gold,
                      title: 'ЛОКАЛЬНЫЙ СЦЕНАРИЙ',
                      icon: Icons.extension_rounded,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Профиль генерации: $difficulty • $focus',
                            style: const TextStyle(
                              color: TactixTheme.textMuted,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 12),
                          AppTextField(
                            controller: titleController,
                            label: 'Название',
                          ),
                          AppTextField(
                            controller: descriptionController,
                            label: 'Описание',
                            maxLines: 6,
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: AppTextField(
                                  controller: timeController,
                                  label: 'Время',
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: AppTextField(
                                  controller: resourcesController,
                                  label: 'Ресурсы',
                                ),
                              ),
                            ],
                          ),
                          AppTextField(
                            controller: conditionsController,
                            label: 'Условия',
                            maxLines: 3,
                          ),
                          AppTextField(
                            controller: optionAController,
                            label: 'Вариант A',
                            maxLines: 4,
                          ),
                          AppTextField(
                            controller: optionBController,
                            label: 'Вариант B',
                            maxLines: 4,
                          ),
                          AppTextField(
                            controller: optionCController,
                            label: 'Вариант C',
                            maxLines: 4,
                          ),
                          if (generated!.criteria.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            const Text(
                              'КРИТЕРИИ ОЦЕНКИ',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.1,
                              ),
                            ),
                            const SizedBox(height: 9),
                            ...generated!.criteria.map(
                              (item) => Padding(
                                padding: const EdgeInsets.only(bottom: 7),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(
                                      Icons.check_circle_outline,
                                      size: 18,
                                      color: TactixTheme.cyan,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        item,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Colors.white70,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 15),
                          FilledButton.icon(
                            onPressed: startTraining,
                            icon: const Icon(Icons.play_arrow_rounded),
                            label: const Padding(
                              padding: EdgeInsets.symmetric(vertical: 13),
                              child: Text('НАЧАТЬ ТРЕНИРОВКУ'),
                            ),
                          ),
                          const SizedBox(height: 9),
                          OutlinedButton.icon(
                            onPressed: saving ? null : saveScenario,
                            icon: const Icon(Icons.save_outlined),
                            label: const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Text('СОХРАНИТЬ СЦЕНАРИЙ'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
