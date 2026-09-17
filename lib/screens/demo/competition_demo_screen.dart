import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../models/scenario.dart';
import '../../widgets/common_widgets.dart';
import '../../app/user_session_scope.dart';

class CompetitionDemoScreen extends StatelessWidget {
  final TrainingScenario scenario;
  final Widget Function(TrainingScenario scenario) runScreenBuilder;

  const CompetitionDemoScreen({
    super.key,
    required this.scenario,
    required this.runScreenBuilder,
  });

  Widget _badge(IconData icon, String title, String subtitle) {
    return Container(
      width: 205,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: TactixTheme.panel2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: TactixTheme.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: TactixTheme.gold, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .8,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: TactixTheme.textMuted,
                    fontSize: 9,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TactixTheme.bg,
      appBar: AppBar(
        backgroundColor: TactixTheme.bg,
        title: const Text(
          'TACTIX • COMPETITION DEMO',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.0),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [TactixTheme.panel2, TactixTheme.panel],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: TactixTheme.gold.withValues(alpha: .35),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4EE39A)
                                  .withValues(alpha: .10),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFF4EE39A)
                                    .withValues(alpha: .35),
                              ),
                            ),
                            child: const Text(
                              'OFFLINE READY',
                              style: TextStyle(
                                color: Color(0xFF7FE7B8),
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: TactixTheme.gold.withValues(alpha: .08),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: TactixTheme.gold.withValues(alpha: .28),
                              ),
                            ),
                            child: const Text(
                              'DETERMINISTIC SCORE',
                              style: TextStyle(
                                color: TactixTheme.gold,
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'ДЕМОНСТРАЦИЯ ДЛЯ ЖЮРИ',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          letterSpacing: .7,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Гарантированный сценарий для защиты: три решения, '
                        'локальная симуляция последствий, прозрачный TACTIX Score '
                        'и финальный After Action Review.',
                        style: TextStyle(
                          color: TactixTheme.textMuted,
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _badge(
                      Icons.wifi_off_rounded,
                      'БЕЗ ИНТЕРНЕТА',
                      'Сценарий проходит без внешней сети.',
                    ),
                    _badge(
                      Icons.calculate_outlined,
                      'ЛОКАЛЬНЫЙ SCORE',
                      'Числовой балл не генерируется AI.',
                    ),
                    _badge(
                      Icons.alt_route_rounded,
                      'РОВНО 3 ХОДА',
                      'Короткая и предсказуемая демонстрация.',
                    ),
                    _badge(
                      Icons.description_outlined,
                      'AAR REPORT',
                      'Финальный разбор и готовый отчёт.',
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                PanelCard(
                  title: 'СЦЕНАРИЙ ДЕМО',
                  icon: Icons.view_in_ar_outlined,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        scenario.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        scenario.description,
                        style: const TextStyle(
                          color: Colors.white70,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Цель: ${scenario.goal}',
                        style: const TextStyle(
                          color: TactixTheme.textMuted,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                OutlinedButton.icon(
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Завершить DEMO?'),
                        content: const Text(
                          'Демонстрационная сессия будет завершена, и вы будете перенаправлены на экран авторизации.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Отмена'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Выйти'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true && context.mounted) {
                      UserSessionScope.of(context).signOut();
                    }
                  },
                  icon: const Icon(Icons.exit_to_app_rounded),
                  label: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'ЗАВЕРШИТЬ СЕССИЮ',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .7,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => runScreenBuilder(scenario),
                      ),
                    );
                  },
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'НАЧАТЬ ДЕМОНСТРАЦИЮ',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .7,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Для эффектной защиты можно физически отключить интернет '
                  'перед нажатием кнопки — демонстрация продолжит работать.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: TactixTheme.textMuted,
                    fontSize: 10,
                    height: 1.4,
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
