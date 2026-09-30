import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';
import '../data/pdf_report_service.dart';


import '../../../../app/theme.dart';
import '../domain/engine.dart';
import '../domain/scenario.dart';
import '../data/ai_review_adapter.dart';

class ExerciseReport extends StatefulWidget {
  final ExerciseEngine engine;
  const ExerciseReport({super.key, required this.engine});
  @override
  State<ExerciseReport> createState() => _ExerciseReportState();
}

class _ExerciseReportState extends State<ExerciseReport> {
  bool _busy = false, _aiConsent = false;
  String? _review;
  @override
  Widget build(BuildContext context) {
    final e = widget.engine;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Разбор занятия'),
        actions: [
          IconButton(tooltip: 'PDF', icon: const Icon(Icons.picture_as_pdf_outlined), onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => _ExercisePdfPreview(engine: e)))),
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
              if (e.completed)
                Text(
                  e.succeeded
                      ? 'Условия успеха выполнены'
                      : 'Есть пространство для улучшения',
                  style: const TextStyle(color: TactixTheme.cyan, fontSize: 18),
                ),
              const SizedBox(height: 16),
              for (final goal in e.scenario.objects.where(
                (o) => o.kind == ObjectKind.objective,
              ))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    e.current.reached.contains(goal.id)
                        ? Icons.check_circle_outline
                        : Icons.radio_button_unchecked,
                    color: TactixTheme.gold,
                  ),
                  title: Text(goal.name),
                  subtitle: Text(
                    e.current.reached.contains(goal.id)
                        ? 'Посещена действующим жетоном'
                        : 'Не достигнута — проверьте распределение команд',
                  ),
                ),
              Text(
                'Удержание всех целей: ${e.current.holdTicks} / ${e.scenario.duration} тактов. Ресурсы: ${e.current.resources} / ${e.scenario.resources}.',
              ),
              const SizedBox(height: 20),
              const Text(
                'ВОПРОСЫ ДЛЯ РЕФЛЕКСИИ',
                style: TextStyle(color: TactixTheme.gold),
              ),
              const SizedBox(height: 8),
              Text(
                e.current.cohesion < 90
                    ? 'Какие решения снизили согласованность? Найдите их в журнале и сравните альтернативную попытку.'
                    : 'Какие ресурсы вы потратили для сохранения согласованности? Можно ли достичь целей с меньшим расходом?',
              ),
              const Text(
                'Как изменится результат при другом распределении жетонов? Сохраните тот же seed и проверьте одну гипотезу за попытку.',
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
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _aiConsent,
                onChanged: _busy
                    ? null
                    : (value) => setState(() => _aiConsent = value ?? false),
                title: const Text(
                  'Разрешаю отправить игровой журнал настроенному AI-сервису',
                ),
                subtitle: const Text(
                  'Название, подтверждённые события и игровые показатели. Внешний сервис определяется настройками AI.',
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: _busy || !_aiConsent || !e.completed
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


class _ExercisePdfPreview extends StatelessWidget {
  final ExerciseEngine engine;
  const _ExercisePdfPreview({required this.engine});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Отчёт TACTIX · PDF')),
    body: PdfPreview(build: (_) => PdfReportService().createExerciseReport(engine), pdfFileName: 'TACTIX-report.pdf', allowPrinting: true, allowSharing: true, canChangeOrientation: false, canChangePageFormat: false),
  );
}
