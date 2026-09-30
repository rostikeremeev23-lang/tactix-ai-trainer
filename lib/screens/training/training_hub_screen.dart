import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../app/user_session_scope.dart';
import '../../features/decision_simulation/presentation/episode_library_screen.dart';
import '../assignments/assignments_screen.dart';
import '../scenarios/ai_scenario_screen.dart';
import '../scenarios/my_scenarios_screen.dart';
import '../strategy/strategy_screen.dart';
import 'scenario_run_screen.dart';

/// Training owns simulation navigation; simulator storage and routes stay intact.
class TrainingHubScreen extends StatelessWidget {
  const TrainingHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = UserSessionScope.of(context);
    final user = session.currentUser!;
    void open(Widget screen) =>
        Navigator.of(context)
            .push(MaterialPageRoute<void>(builder: (_) => screen));
    final entries =
        <({String title, String detail, IconData icon, VoidCallback open})>[
          (
            title: 'SIMULATION LAB',
            detail: 'Сценарии, карты, сохранённые сессии, повторы и разбор результатов.',
            icon: Icons.public_rounded,
            open: () => open(SimulationLabScreen(userId: user.id)),
          ),
          (
            title: 'Сценарии',
            detail: 'Продолжить подготовку по существующим сценариям.',
            icon: Icons.description_outlined,
            open: () => open(
              MyScenariosScreen(
                aiScreenBuilder: () => const AIScenarioScreen(),
                runScreenBuilder: (scenario) =>
                    ScenarioRunScreen(scenario: scenario),
              ),
            ),
          ),
          (
            title: 'Мои задания',
            detail: 'Назначенные тренировки и текущий прогресс.',
            icon: Icons.assignment_outlined,
            open: () => open(const AssignmentsScreen()),
          ),
          (
            title: 'Интерактивные истории',
            detail: 'Практика принятия решений и последствия выбора.',
            icon: Icons.auto_stories_outlined,
            open: () => open(EpisodeLibraryScreen(userId: user.id)),
          ),
          if (session.isServerUser)
            (
              title: session.canManageTraining
                  ? 'Центр инструктора'
                  : 'Учебный маршрут',
              detail: 'Simulation Lab · задания, результаты и отзывы.',
              icon: Icons.school_outlined,
              open: () => open(
                SimulationLabScreen(userId: user.id, startInPlatform: true),
              ),
            ),
        ];
    return Scaffold(
      appBar: AppBar(title: const Text('TRAINING')),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 1100
                ? 3
                : constraints.maxWidth >= 700
                ? 2
                : 1;
            final width =
                (constraints.maxWidth.clamp(0, 1280) -
                    48 -
                    (columns - 1) * 16) /
                columns;
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1232),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Практика. Решения. Результат.',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Все инструменты подготовки в одном пространстве.',
                        style: TextStyle(color: TactixTheme.textMuted),
                      ),
                      const SizedBox(height: 28),
                      Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: entries
                            .map(
                              (entry) => SizedBox(
                                width: width,
                                child: Card(
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(12),
                                    onTap: entry.open,
                                    child: Padding(
                                      padding: const EdgeInsets.all(24),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Icon(
                                            entry.icon,
                                            color: TactixTheme.cyan,
                                            size: 30,
                                          ),
                                          const SizedBox(height: 20),
                                          Text(
                                            entry.title,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium,
                                          ),
                                          const SizedBox(height: 10),
                                          Text(
                                            entry.detail,
                                            style: const TextStyle(
                                              color: TactixTheme.textMuted,
                                              height: 1.5,
                                            ),
                                          ),
                                          const SizedBox(height: 20),
                                          const Icon(
                                            Icons.arrow_forward_rounded,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
