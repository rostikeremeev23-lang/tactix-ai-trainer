import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../data/studio_archive.dart';
import '../data/studio_store.dart';
import 'exercise_report.dart';

class StudioArchiveScreen extends StatefulWidget {
  final StudioArchive archive;
  const StudioArchiveScreen({super.key, required this.archive});
  @override
  State<StudioArchiveScreen> createState() => _StudioArchiveScreenState();
}

class _StudioArchiveScreenState extends State<StudioArchiveScreen> {
  List<ArchivedExercise>? _items;
  String? _error;
  final Set<String> _selected = {};
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await widget.archive.load();
      if (mounted) {
        setState(() {
          _items = items;
          _error = widget.archive.recoveryMessage;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Не удалось прочитать архив: $e');
    }
  }

  void _compare() {
    final entries = _items!.where((i) => _selected.contains(i.id)).toList();
    if (entries.length != 2) return;
    final a = entries[0].document.engine!, b = entries[1].document.engine!;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Сравнение попыток'),
        content: SingleChildScrollView(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'A и B — выбранные завершённые записи. Разные настройки влияют на результат.',
                ),
                DataTable(
                  columns: const [
                    DataColumn(label: Text('Показатель')),
                    DataColumn(label: Text('A')),
                    DataColumn(label: Text('B')),
                  ],
                  rows: [
                    _row('Сценарий', a.scenario.name, b.scenario.name),
                    _row('Seed', a.scenario.seed, b.scenario.seed),
                    _row(
                      'Такты / стартовые ресурсы',
                      '${a.scenario.duration} / ${a.scenario.resources}',
                      '${b.scenario.duration} / ${b.scenario.resources}',
                    ),
                    _row('Баллы', a.score, b.score),
                    _row(
                      'Цели достигнуты',
                      a.current.reached.length,
                      b.current.reached.length,
                    ),
                    _row(
                      'Такты удержания',
                      a.current.holdTicks,
                      b.current.holdTicks,
                    ),
                    _row(
                      'Ресурсы в остатке',
                      a.current.resources,
                      b.current.resources,
                    ),
                    _row(
                      'Согласованность',
                      a.current.cohesion,
                      b.current.cohesion,
                    ),
                    _row('Устойчивость', a.current.safety, b.current.safety),
                    _row(
                      'Условия успеха',
                      a.succeeded ? 'Да' : 'Нет',
                      b.succeeded ? 'Да' : 'Нет',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }

  DataRow _row(String label, Object a, Object b) => DataRow(
    cells: [DataCell(Text(label)), DataCell(Text('$a')), DataCell(Text('$b'))],
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Планы и результаты')),
    body: _items == null && _error == null
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                'АРХИВ НА УСТРОЙСТВЕ',
                style: TextStyle(color: TactixTheme.gold, letterSpacing: 2),
              ),
              const SizedBox(height: 12),
              const Text(
                'Откройте сохранённый план или продолжите запись. Для сравнения выберите две завершённые попытки. Максимум 40 записей.',
              ),
              const SizedBox(height: 12),
              if (_error != null)
                Text(
                  _error!,
                  style: const TextStyle(color: Colors.orangeAccent),
                ),
              FilledButton.tonalIcon(
                onPressed: _selected.length == 2 ? _compare : null,
                icon: const Icon(Icons.compare_arrows),
                label: Text('Сравнить (${_selected.length}/2)'),
              ),
              const SizedBox(height: 16),
              if (_items?.isEmpty == true)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Архив пуст. Сохраните план из меню карты; завершённые попытки добавляются автоматически.',
                  ),
                ),
              for (final entry in _items ?? <ArchivedExercise>[])
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.document.scenario.name,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${entry.savedAt.toLocal().toString().substring(0, 16)} · ${entry.document.engine == null
                                ? 'План'
                                : entry.document.engine!.completed
                                ? '${entry.document.engine!.score} / 100'
                                : 'На паузе · T+${entry.document.engine!.current.tick}'}',
                            style: const TextStyle(
                              color: TactixTheme.textMuted,
                            ),
                          ),
                          Wrap(
                            spacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              if (entry.document.engine?.completed == true)
                                Checkbox(
                                  value: _selected.contains(entry.id),
                                  onChanged: (v) => setState(() {
                                    if (v == false) {
                                      _selected.remove(entry.id);
                                    } else if (_selected.length < 2) {
                                      _selected.add(entry.id);
                                    }
                                  }),
                                ),
                              TextButton(
                                onPressed: () => Navigator.pop<StudioDocument>(
                                  context,
                                  entry.document,
                                ),
                                child: const Text('Открыть'),
                              ),
                              if (entry.document.engine != null)
                                TextButton(
                                  onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute<void>(
                                      builder: (_) => ExerciseReport(
                                        engine: entry.document.engine!,
                                      ),
                                    ),
                                  ),
                                  child: const Text('Разбор'),
                                ),
                              IconButton(
                                tooltip: 'Удалить запись',
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () async {
                                  final confirmed = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text(
                                        'Удалить запись из архива?',
                                      ),
                                      content: Text(
                                        entry.document.scenario.name,
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, false),
                                          child: const Text('Отмена'),
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, true),
                                          child: const Text('Удалить'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirmed != true) return;
                                  try {
                                    await widget.archive.remove(entry.id);
                                    _selected.remove(entry.id);
                                    await _load();
                                  } catch (e) {
                                    if (mounted) {
                                      setState(
                                        () => _error =
                                            'Удаление не выполнено: $e',
                                      );
                                    }
                                  }
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
  );
}
