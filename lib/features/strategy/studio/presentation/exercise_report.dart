import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme.dart';
import '../domain/engine.dart';
import '../data/ai_review_adapter.dart';

class ExerciseReport extends StatefulWidget {
  final ExerciseEngine engine;
  const ExerciseReport({super.key, required this.engine});
  @override
  State<ExerciseReport> createState() => _ExerciseReportState();
}

class _ExerciseReportState extends State<ExerciseReport> {
  bool _busy = false;
  String? _review;
  @override
  Widget build(BuildContext context) {
    final e = widget.engine;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Разбор занятия'),
        actions: [
          IconButton(
            tooltip: 'Копировать отчёт',
            icon: const Icon(Icons.copy),
            onPressed: () async {
              try {
                await Clipboard.setData(ClipboardData(text: e.report));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Отчёт скопирован')),
                  );
                }
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Буфер недоступен. Текст можно выделить ниже.',
                      ),
                    ),
                  );
                }
              }
            },
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Text(
                'AFTER ACTION REVIEW',
                style: TextStyle(color: TactixTheme.cyan, letterSpacing: 2),
              ),
              const SizedBox(height: 16),
              Text(
                e.scenario.name,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 20),
              Text(
                '${e.score} / 100',
                style: const TextStyle(
                  color: TactixTheme.gold,
                  fontSize: 64,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                e.completed
                    ? 'Учебное занятие завершено'
                    : 'Промежуточный результат',
              ),
              const SizedBox(height: 24),
              const Text(
                'ПРОЗРАЧНЫЕ ПРАВИЛА ОЦЕНКИ',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(e.objectiveRule),
              const Text(
                'Безопасность ×0,2 + согласованность ×0,2 + оставшиеся ресурсы ×0,1. '
                'Все показатели условные; результат вычислен программным движком.',
              ),
              const SizedBox(height: 24),
              FilledButton.tonalIcon(
                onPressed: _busy
                    ? null
                    : () async {
                        setState(() => _busy = true);
                        try {
                          final text = await StrategyAIReviewAdapter().review(
                            e,
                          );
                          if (mounted) setState(() => _review = text);
                        } catch (_) {
                          if (mounted) {
                            setState(
                              () => _review = 'AI недоступен. Ниже остаётся полный отчёт движка.',
                            );
                          }
                        } finally {
                          if (mounted) setState(() => _busy = false);
                        }
                      },
                icon: const Icon(Icons.auto_awesome),
                label: Text(
                  _busy ? 'Подготовка комментария…' : 'Комментарий TACTIX AI',
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'AI получает подтверждённый журнал и показатели. Его комментарий не меняет оценку. '
                'Доступность внешней модели зависит от настроек подключения.',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              if (_review != null) ...[
                const SizedBox(height: 16),
                const Text(
                  'ВСПОМОГАТЕЛЬНЫЙ КОММЕНТАРИЙ',
                  style: TextStyle(color: TactixTheme.cyan),
                ),
                SelectableText(_review!),
              ],
              const Divider(height: 40),
              SelectableText(
                e.report,
                key: const ValueKey('verified-report'),
                style: const TextStyle(height: 1.6, color: Colors.white70),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
