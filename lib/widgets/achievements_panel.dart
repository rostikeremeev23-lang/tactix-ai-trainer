import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../models/training_result.dart';

class AchievementsPanel extends StatelessWidget {
  final List<TrainingResult> results;

  const AchievementsPanel({
    super.key,
    required this.results,
  });

  @override
  Widget build(BuildContext context) {
    final achievements = _buildAchievements();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: TactixTheme.panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: TactixTheme.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.military_tech_outlined, color: TactixTheme.gold, size: 18),
              SizedBox(width: 8),
              Text(
                'ДОСТИЖЕНИЯ',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: achievements.map((item) {
              final unlocked = item.$3;
              return Container(
                width: 150,
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: unlocked
                      ? TactixTheme.gold.withValues(alpha: 0.07)
                      : Colors.white.withValues(alpha: 0.02),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                    color: unlocked
                        ? TactixTheme.gold.withValues(alpha: 0.28)
                        : Colors.white10,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      item.$1,
                      size: 20,
                      color: unlocked ? TactixTheme.gold : Colors.white24,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.$2,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: unlocked ? Colors.white : Colors.white38,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            unlocked ? 'ОТКРЫТО' : 'ЗАБЛОКИРОВАНО',
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w800,
                              letterSpacing: .7,
                              color: unlocked ? const Color(0xFF7FE7B8) : Colors.white24,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  List<(IconData, String, bool)> _buildAchievements() {
    final count = results.length;
    final best = results.isEmpty
        ? 0
        : results.map((e) => e.score).reduce((a, b) => a > b ? a : b);
    final average = results.isEmpty
        ? 0
        : (results.map((e) => e.score).reduce((a, b) => a + b) / count).round();
    final completedDecisions = results.fold<int>(
      0,
      (sum, item) => sum + item.decisions,
    );

    return [
      (Icons.flag_outlined, 'Первый запуск', count >= 1),
      (Icons.workspace_premium_outlined, '5 тренировок', count >= 5),
      (Icons.bolt_outlined, '10 решений', completedDecisions >= 10),
      (Icons.trending_up_rounded, 'Средний балл 80+', average >= 80),
      (Icons.emoji_events_outlined, 'Результат 90+', best >= 90),
      (Icons.auto_awesome_outlined, '10 тренировок', count >= 10),
    ];
  }
}

