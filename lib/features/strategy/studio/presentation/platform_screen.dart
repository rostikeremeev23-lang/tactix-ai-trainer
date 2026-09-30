import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../data/platform_sync.dart';
import '../data/studio_store.dart';
import '../domain/scenario.dart';
import '../domain/city_scenarios.dart';
import '../domain/training_summary.dart';
import 'exercise_report.dart';

class StrategyPlatformScreen extends StatefulWidget {
  final PlatformSync sync;
  final StudioDocument current;
  final Future<void> Function(String assignmentId)? onAssignmentCreated;
  const StrategyPlatformScreen({
    super.key,
    required this.sync,
    required this.current,
    this.onAssignmentCreated,
  });
  @override
  State<StrategyPlatformScreen> createState() => _PlatformState();
}

class _PlatformState extends State<StrategyPlatformScreen> {
  PlatformSync get s => widget.sync;
  int tab = 0;
  String filter = 'all', learner = '', query = '';
  String? error;
  bool writing = false;
  final Set<String> compared = {};
  final ScrollController scroll = ScrollController();
  List<String> get tabs => [
    'Обзор',
    'Задания',
    'Результаты',
    if (s.staff) 'Участники',
    'Облако',
  ];
  List<IconData> get icons => [
    Icons.space_dashboard_outlined,
    Icons.assignment_outlined,
    Icons.bar_chart_rounded,
    if (s.staff) Icons.groups_outlined,
    Icons.cloud_outlined,
  ];
  List<Map<String, dynamic>> get scoped => s.assignments
      .where((a) => learner.isEmpty || a['learner_id'] == learner)
      .toList();
  TrainingSummary get summary =>
      TrainingSummary(tab == 0 ? s.assignments : scoped);
  @override
  void initState() {
    super.initState();
    s.addListener(update);
  }

  void update() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    s.removeListener(update);
    scroll.dispose();
    super.dispose();
  }

  String name(String id) {
    for (final p in s.participants) {
      if (p['id'] == id) return '${p['callsign']} · ${p['name']}';
    }
    return s.staff
        ? 'Участник ${id.length > 8 ? id.substring(0, 8) : id}'
        : 'Моё занятие';
  }

  String date(dynamic value) {
    final d = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    return d == null
        ? 'Не задан'
        : '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year} · ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  String label(String value) => switch (value) {
    'assigned' => 'Назначено',
    'in_progress' => 'В процессе',
    'submitted' => 'Сдано',
    'cancelled' => 'Отменено',
    _ => value,
  };
  void navigate(int index) {
    setState(() => tab = index);
    if (scroll.hasClients) scroll.jumpTo(0);
  }

  Future<void> act(Future<void> Function() operation) async {
    if (writing || !s.ready) return;
    setState(() {
      writing = true;
      error = null;
    });
    try {
      await operation();
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'Не удалось сохранить действие. Повторите попытку.',
        );
      }
    } finally {
      if (mounted) setState(() => writing = false);
    }
  }

  Future<bool> confirm(String title, String text) async =>
      await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          content: Text(text),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Подтвердить'),
            ),
          ],
        ),
      ) ??
      false;

  Future<DateTime?> pickDeadline([DateTime? initial]) async {
    final now = DateTime.now();
    final chosen = await showDatePicker(
      context: context,
      initialDate: initial ?? now.add(const Duration(days: 7)),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: 'Срок занятия',
      cancelText: 'Отмена',
      confirmText: 'Выбрать',
    );
    if (chosen == null || !mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: initial == null
          ? const TimeOfDay(hour: 18, minute: 0)
          : TimeOfDay.fromDateTime(initial),
      helpText: 'Время на этом устройстве',
      cancelText: 'Отмена',
      confirmText: 'Выбрать',
    );
    return time == null
        ? null
        : DateTime(
            chosen.year,
            chosen.month,
            chosen.day,
            time.hour,
            time.minute,
          );
  }

  Future<void> assign() async {
    final managed = s.participants.where((p) => p['managed'] == true).toList();
    if (managed.isEmpty) {
      navigate(tabs.indexOf('Участники'));
      return;
    }
    String person = managed.first['id'];
    int scenarioIndex = 0;
    DateTime? due;
    final scenarios = [
      for (var i = 0; i < 3; i++) CityScenarios.create(i),
      if (widget.current.scenario.launchProblem == null)
        widget.current.scenario,
    ];
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: const Text('Новое назначение'),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: person,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Обучаемый'),
                    items: managed
                        .map(
                          (p) => DropdownMenuItem<String>(
                            value: p['id'],
                            child: Text(
                              name(p['id']),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => set(() => person = v!),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    initialValue: scenarioIndex,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Вымышленный сценарий',
                    ),
                    items: [
                      for (var i = 0; i < scenarios.length; i++)
                        DropdownMenuItem(
                          value: i,
                          child: Text(
                            '${i == 3 ? 'С карты · ' : ''}${scenarios[i].name}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (v) => set(() => scenarioIndex = v!),
                  ),
                  const SizedBox(height: 16),
                  Text(scenarios[scenarioIndex].briefing),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.event_outlined),
                    label: Text(
                      due == null
                          ? 'Установить срок'
                          : date(due!.toIso8601String()),
                    ),
                    onPressed: () async {
                      final value = await pickDeadline(due);
                      if (ctx.mounted && value != null) set(() => due = value);
                    },
                  ),
                  if (due != null)
                    TextButton(
                      onPressed: () => set(() => due = null),
                      child: const Text('Без срока'),
                    ),
                  const Text(
                    'Время отображается в часовом поясе устройства. Просрочка не запрещает сдачу.',
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Назначить'),
            ),
          ],
        ),
      ),
    );
    if (result == true && mounted) {
      final assignmentId = platformId();
      var queued = false;
      await act(() async {
        await s.enqueue('POST', '/assignments', {
          'id': assignmentId,
          'learner_id': person,
          'scenario': scenarios[scenarioIndex].toJson(),
          'due_at': due?.toUtc().toIso8601String(),
        });
        queued = true;
      });
      if (queued && mounted && widget.onAssignmentCreated != null) {
        try {
          await widget.onAssignmentCreated!(assignmentId);
        } catch (_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Задание сохранено, но связь с THREAD не создана. Её можно добавить позже.',
                ),
              ),
            );
          }
        }
      }
      if (mounted) navigate(1);
    }
  }

  Future<void> feedback(Map<String, dynamic> a) async {
    final controller = TextEditingController(text: a['feedback'] ?? '');
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Обратная связь'),
        content: SizedBox(
          width: 480,
          child: TextField(
            controller: controller,
            maxLength: 4000,
            minLines: 4,
            maxLines: 8,
            decoration: const InputDecoration(
              labelText: 'Учебные наблюдения и рекомендации',
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Сохранить отзыв'),
          ),
        ],
      ),
    );
    // Let the route's closing animation release its text field.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    controller.dispose();
    if (value != null && mounted) {
      await act(
        () => s.enqueue('PATCH', '/assignments/${a['id']}/feedback', {
          'base_revision': a['revision'],
          'feedback': value,
        }),
      );
    }
  }

  void report(Map<String, dynamic> a) {
    final doc = StudioDocument.read(Map<String, dynamic>.from(a['submission']));
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ExerciseReport(engine: doc.engine!),
      ),
    );
  }

  Widget panel(Widget child) => Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: TactixTheme.panel,
      border: Border.all(color: TactixTheme.line),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Material(type: MaterialType.transparency, child: child),
  );
  Widget heading(String title, [String? subtitle]) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(subtitle, style: const TextStyle(color: TactixTheme.textMuted)),
        ],
      ],
    ),
  );
  Widget empty(String text) => panel(
    Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Text(text),
    ),
  );
  Widget assignmentCard(Map<String, dynamic> a) {
    final pending = s.assignmentPending(a['id']);
    final enabled = s.ready && !writing && !pending;
    final active = a['status'] == 'assigned' || a['status'] == 'in_progress';
    final due = DateTime.tryParse(a['due_at'] ?? '');
    final overdue = active && due != null && due.isBefore(DateTime.now());
    return panel(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(
                label: Text(label(a['status'])),
                visualDensity: VisualDensity.compact,
              ),
              if (overdue) const Chip(label: Text('Срок прошёл')),
              if (TrainingSummary.needsFeedback(a))
                const Chip(label: Text('Ожидает отзыва')),
              if (pending) const Chip(label: Text('В очереди отправки')),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            a['scenario']['name'],
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          Text('${name(a['learner_id'])} · срок: ${date(a['due_at'])}'),
          const SizedBox(height: 14),
          LinearProgressIndicator(
            value: TrainingSummary.progress(a),
            minHeight: 4,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 8),
          Text(
            'Пройдено тактов: ${a['metrics']?['tick'] ?? 0} / ${a['scenario']['duration']}'
            '${a['metrics'] == null ? '' : ' · ${a['metrics']['score']} / 100'}',
          ),
          if ((a['feedback'] as String? ?? '').isNotEmpty) ...[
            const Divider(height: 28),
            const Text(
              'ОБРАТНАЯ СВЯЗЬ',
              style: TextStyle(color: TactixTheme.gold, letterSpacing: 1.4),
            ),
            const SizedBox(height: 8),
            SelectableText(a['feedback']),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (!s.staff && active)
                FilledButton.tonal(
                  onPressed: () {
                    final doc = widget.current.assignmentId == a['id']
                        ? widget.current
                        : a['submission'] == null
                        ? StudioDocument(
                            StudioScenario.read(
                              Map<String, dynamic>.from(a['scenario']),
                            ),
                            null,
                            a['id'],
                          )
                        : StudioDocument.read(
                            Map<String, dynamic>.from(a['submission']),
                          );
                    Navigator.pop(context, doc);
                  },
                  child: const Text('Открыть задание'),
                ),
              if (!s.staff &&
                  active &&
                  widget.current.assignmentId == a['id'] &&
                  widget.current.engine != null)
                FilledButton(
                  onPressed: enabled
                      ? () => act(
                          () => s.enqueue(
                            'POST',
                            '/assignments/${a['id']}/submit',
                            {
                              'base_revision': a['revision'],
                              'document': widget.current.toJson(),
                            },
                          ),
                        )
                      : null,
                  child: Text(
                    widget.current.engine!.completed
                        ? 'Сдать результат'
                        : 'Отправить прогресс',
                  ),
                ),
              if (a['submission'] != null)
                TextButton(
                  onPressed: () => report(a),
                  child: const Text('Посмотреть результат'),
                ),
              if (s.staff)
                TextButton(
                  onPressed: enabled ? () => feedback(a) : null,
                  child: const Text('Написать отзыв'),
                ),
              if (s.staff && active)
                TextButton(
                  onPressed: enabled
                      ? () async {
                          final value = await pickDeadline(due?.toLocal());
                          if (value != null && mounted) {
                            await act(
                              () => s.enqueue(
                                'PATCH',
                                '/assignments/${a['id']}/deadline',
                                {
                                  'base_revision': a['revision'],
                                  'due_at': value.toUtc().toIso8601String(),
                                },
                              ),
                            );
                          }
                        }
                      : null,
                  child: const Text('Изменить срок'),
                ),
              if (s.staff && active && due != null)
                TextButton(
                  onPressed: enabled
                      ? () async {
                          if (await confirm(
                                'Убрать срок?',
                                'Задание останется активным без срока сдачи.',
                              ) &&
                              mounted) {
                            await act(
                              () => s.enqueue(
                                'PATCH',
                                '/assignments/${a['id']}/deadline',
                                {
                                  'base_revision': a['revision'],
                                  'due_at': null,
                                },
                              ),
                            );
                          }
                        }
                      : null,
                  child: const Text('Без срока'),
                ),
              if (s.staff && active)
                TextButton(
                  onPressed: enabled
                      ? () async {
                          if (await confirm(
                                'Отменить назначение?',
                                'Сохранённые результаты и история останутся доступны.',
                              ) &&
                              mounted) {
                            await act(
                              () => s.enqueue(
                                'PATCH',
                                '/assignments/${a['id']}/feedback',
                                {
                                  'base_revision': a['revision'],
                                  'feedback': a['feedback'],
                                  'cancel': true,
                                },
                              ),
                            );
                          }
                        }
                      : null,
                  child: const Text('Отменить назначение'),
                ),
            ],
          ),
          if ((a['history'] as List? ?? []).isNotEmpty)
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('История занятия'),
              children: [
                for (final e in (a['history'] as List).reversed)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(switch (e['kind']) {
                      'assigned' => 'Назначение создано',
                      'progress' => 'Прогресс получен',
                      'submitted' => 'Результат сдан',
                      'feedback' =>
                        e['payload']?['cancel'] == true
                            ? 'Назначение отменено'
                            : 'Отзыв обновлён',
                      'deadline' => 'Срок изменён',
                      _ => 'Занятие обновлено',
                    }),
                    subtitle: Text(
                      '${date(e['at'])}${e['kind'] == 'feedback' ? '\n${e['payload']?['feedback'] ?? ''}' : ''}',
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget overview() {
    final recent = [...summary.completed]
      ..sort(
        (a, b) => TrainingSummary.time(b).compareTo(TrainingSummary.time(a)),
      );
    final metrics = <String, String>{
      if (s.staff)
        'Мои обучаемые':
            '${s.participants.where((p) => p['managed'] == true).length}',
      'Активные': '${summary.active}',
      'Завершены': '${summary.completed.length}',
      'Ожидают отзыва': '${summary.awaitingFeedback}',
      'Выполнение': '${(summary.completion * 100).round()}%',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          margin: const EdgeInsets.only(bottom: 24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: TactixTheme.gold.withValues(alpha: .25)),
            gradient: const LinearGradient(
              colors: [Color(0xFF23313A), TactixTheme.panel],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'TACTIX / LEARNING OPERATIONS',
                style: TextStyle(
                  color: TactixTheme.gold,
                  letterSpacing: 2,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 16),
              heading(
                s.staff ? 'Пространство развития' : 'Мой учебный маршрут',
                'Вымышленные сценарии. Понятный прогресс. Обратная связь по каждому занятию.',
              ),
              if (s.staff)
                FilledButton.icon(
                  onPressed: s.ready && !writing ? assign : null,
                  icon: const Icon(Icons.add),
                  label: const Text('Новое назначение'),
                )
              else
                FilledButton(
                  onPressed: () => navigate(1),
                  child: const Text('Перейти к заданиям'),
                ),
            ],
          ),
        ),
        LayoutBuilder(
          builder: (_, c) {
            final columns = c.maxWidth >= 800
                ? 5
                : c.maxWidth >= 500
                ? 3
                : 2;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: metrics.entries
                  .map(
                    (e) => SizedBox(
                      width: (c.maxWidth - (columns - 1) * 12) / columns,
                      child: panel(
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              e.value,
                              style: const TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w700,
                                color: TactixTheme.gold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(e.key),
                          ],
                        ),
                      ),
                    ),
                  )
                  .toList(),
            );
          },
        ),
        heading(
          'Последние результаты',
          'Подтверждённые сервером учебные сессии',
        ),
        if (recent.isEmpty)
          empty(
            'Сданных занятий пока нет. Здесь появятся результаты после синхронизации.',
          ),
        for (final a in recent.take(5)) assignmentCard(a),
      ],
    );
  }

  Widget assignments() {
    final items = scoped
        .where(
          (a) =>
              (filter == 'all' ||
                  a['status'] == filter ||
                  (filter == 'feedback' && TrainingSummary.needsFeedback(a))) &&
              ('${a['scenario']['name']} ${name(a['learner_id'])}')
                  .toLowerCase()
                  .contains(query.toLowerCase()),
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        heading(
          'Назначения',
          'Прогресс и отзывы доступны офлайн после синхронизации.',
        ),
        if (s.staff)
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: s.ready && !writing ? assign : null,
              icon: const Icon(Icons.add),
              label: const Text('Новое назначение'),
            ),
          ),
        const SizedBox(height: 16),
        TextField(
          decoration: const InputDecoration(
            labelText: 'Поиск по сценарию или участнику',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (v) => setState(() => query = v),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: [
            for (final f in [
              'all',
              'assigned',
              'in_progress',
              'submitted',
              'feedback',
              'cancelled',
            ])
              ChoiceChip(
                label: Text(
                  f == 'all'
                      ? 'Все'
                      : f == 'feedback'
                      ? 'Без отзыва'
                      : label(f),
                ),
                selected: filter == f,
                onSelected: (_) => setState(() => filter = f),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (items.isEmpty) empty('Нет назначений по выбранным условиям.'),
        for (final a in items) assignmentCard(a),
      ],
    );
  }

  Widget roster() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      heading(
        'Учебный состав',
        'Добавьте участника организации в свой список для назначения сценариев.',
      ),
      if (s.participants.isEmpty)
        empty(
          'Нет доступных участников. Приглашения доступны в профиле инструктора.',
        ),
      for (final p in s.participants)
        panel(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name(p['id']),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Завершено: ${TrainingSummary(s.assignments.where((a) => a['learner_id'] == p['id']).toList()).completed.length}',
              ),
              Wrap(
                spacing: 8,
                children: [
                  TextButton(
                    onPressed: s.ready && !writing
                        ? () => act(
                            () => s.enqueue(
                              p['managed'] == true ? 'DELETE' : 'PUT',
                              '/participants/${p['id']}',
                              {},
                            ),
                          )
                        : null,
                    child: Text(
                      p['managed'] == true
                          ? 'Убрать из списка'
                          : 'Добавить в список',
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() => learner = p['id']);
                      navigate(2);
                    },
                    child: const Text('Учебная история'),
                  ),
                ],
              ),
            ],
          ),
        ),
    ],
  );
  void compare() {
    final selected = summary.completed
        .where((a) => compared.contains(a['id']))
        .toList();
    if (selected.length != 2) return;
    final a = selected[0], b = selected[1];
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Сравнение занятий'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Разные сценарии и стартовые настройки влияют на результат. Баллы описывают учебную игру, а не профессиональную пригодность.',
              ),
              const SizedBox(height: 12),
              for (final row in [
                ['Участник', name(a['learner_id']), name(b['learner_id'])],
                ['Сценарий', a['scenario']['name'], b['scenario']['name']],
                [
                  'Seed',
                  a['scenario']['seed'] ?? 0,
                  b['scenario']['seed'] ?? 0,
                ],
                [
                  'Длительность',
                  a['scenario']['duration'],
                  b['scenario']['duration'],
                ],
                [
                  'Стартовые ресурсы',
                  a['scenario']['resources'],
                  b['scenario']['resources'],
                ],
                [
                  'Баллы / 100',
                  a['metrics']?['score'] ?? '—',
                  b['metrics']?['score'] ?? '—',
                ],
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text('${row[0]}\nA: ${row[1]}\nB: ${row[2]}'),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }

  Widget analytics() {
    final complete = [...summary.completed]
      ..sort(
        (a, b) => TrainingSummary.time(a).compareTo(TrainingSummary.time(b)),
      );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        heading(
          'Динамика обучения',
          'Баллы детерминированной игры · 0–100. Подтверждённые сервером результаты.',
        ),
        Text(
          'Выполнение: ${summary.completed.length} из ${summary.eligible} (${(summary.completion * 100).round()}%). Отменённые назначения исключены.',
        ),
        const SizedBox(height: 12),
        const Text(
          'График показывает последние 12 сданных занятий по времени сдачи. Разные сценарии не являются контролируемым сравнением.',
        ),
        const SizedBox(height: 16),
        if (complete.isEmpty) empty('Для графика нужны завершённые занятия.'),
        for (final a in complete.skip(
          complete.length > 12 ? complete.length - 12 : 0,
        ))
          panel(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${date(a['submitted_at'] ?? a['updated_at'])} · ${a['scenario']['name']}',
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        label: 'Учебный балл',
                        value: '${a['metrics']?['score'] ?? 0} из 100',
                        child: LinearProgressIndicator(
                          value: ((a['metrics']?['score'] as num? ?? 0) / 100)
                              .clamp(0.0, 1.0),
                          minHeight: 12,
                          borderRadius: BorderRadius.circular(6),
                          color: TactixTheme.cyan,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text('${a['metrics']?['score'] ?? 0} / 100'),
                  ],
                ),
              ],
            ),
          ),
        const SizedBox(height: 12),
        FilledButton.tonal(
          onPressed: compared.length == 2 ? compare : null,
          child: Text('Сравнить (${compared.length}/2)'),
        ),
        const SizedBox(height: 12),
        for (final a in complete.reversed)
          panel(
            Column(
              children: [
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(a['scenario']['name']),
                  subtitle: Text(
                    '${name(a['learner_id'])} · ${date(a['submitted_at'] ?? a['updated_at'])}',
                  ),
                  value: compared.contains(a['id']),
                  onChanged: (v) => setState(() {
                    if (v == false) {
                      compared.remove(a['id']);
                    } else if (compared.length < 2) {
                      compared.add(a['id']);
                    }
                  }),
                ),
                TextButton(
                  onPressed: () => report(a),
                  child: const Text('Посмотреть результат'),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget cloud() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      heading(
        'Облачный архив',
        'Планы и записи всех устройств. При конфликте сохраняются обе версии.',
      ),
      if (s.records.isEmpty) empty('Записей пока нет.'),
      for (final r in s.records.values.where(
        (r) => r['deleted'] != true || r['conflict'] != null,
      ))
        panel(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                r['document']?['scenario']?['name'] ?? 'Удалённая запись',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text(
                'Версия ${r['revision']} · ${r['dirty'] == true ? 'ожидает отправки' : 'синхронизировано'}',
              ),
              if (r['error'] != null) ...[
                Text(r['error']),
                TextButton(
                  onPressed: () => act(() => s.retryRecord(r['id'])),
                  child: const Text('Повторить отправку'),
                ),
              ],
              if (r['conflict'] != null)
                Text('Конфликт с версией ${r['conflict']['revision']}'),
              Wrap(
                spacing: 8,
                children: [
                  if (r['document'] != null)
                    TextButton(
                      onPressed: () => Navigator.pop(
                        context,
                        StudioDocument.read(
                          Map<String, dynamic>.from(r['document']),
                        ),
                      ),
                      child: const Text('Открыть запись'),
                    ),
                  if (r['conflict'] != null) ...[
                    TextButton(
                      onPressed: () =>
                          act(() => s.resolve(r['id'], keepLocal: true)),
                      child: const Text('Оставить локальную'),
                    ),
                    TextButton(
                      onPressed: () =>
                          act(() => s.resolve(r['id'], keepLocal: false)),
                      child: const Text('Принять серверную'),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
    ],
  );
  Widget queue() => Column(
    children: [
      for (final a in s.actions)
        panel(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                a['error'] ??
                    'Действие сохранено на устройстве · ожидает отправки',
                style: const TextStyle(color: TactixTheme.gold),
              ),
              Text(
                (a['path'] as String).endsWith('/feedback')
                    ? 'Обратная связь'
                    : (a['path'] as String).endsWith('/submit')
                    ? 'Отправка результата'
                    : (a['path'] as String).endsWith('/deadline')
                    ? 'Изменение срока'
                    : a['path'] == '/assignments'
                    ? 'Новое назначение'
                    : 'Список участников',
              ),
              if (a['body']['feedback'] != null)
                SelectableText('Ваш отзыв: ${a['body']['feedback']}'),
              if (a['body']['scenario'] != null)
                Text('Сценарий: ${a['body']['scenario']['name']}'),
              if (a['error'] != null)
                Wrap(
                  spacing: 8,
                  children: [
                    TextButton(
                      onPressed: () async {
                        final conflict =
                            a['errorStatus'] == 409 &&
                            a['body']['base_revision'] != null;
                        if (conflict) {
                          final id = (a['path'] as String)
                              .split('/')
                              .elementAtOrNull(2);
                          final matches = s.assignments.where(
                            (v) => v['id'] == id,
                          );
                          if (matches.isEmpty) return;
                          final remote = matches.first;
                          if (!await confirm(
                                'Повторить поверх текущей версии?',
                                'На сервере: ${label(remote['status'])}\nОтзыв: ${remote['feedback']}\nСрок: ${date(remote['due_at'])}\nВаше действие остаётся в очереди до подтверждения.',
                              ) ||
                              !mounted) {
                            return;
                          }
                        }
                        await act(
                          () => s.retryAction(
                            a['id'],
                            useLatestRevision: conflict,
                          ),
                        );
                      },
                      child: const Text('Повторить'),
                    ),
                    TextButton(
                      onPressed: () async {
                        if (await confirm(
                              'Убрать действие из очереди?',
                              'Неотправленное действие будет удалено только после подтверждения.',
                            ) &&
                            mounted) {
                          await act(() => s.dismissAction(a['id']));
                        }
                      },
                      child: const Text('Убрать'),
                    ),
                  ],
                ),
            ],
          ),
        ),
    ],
  );
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth >= 900;
      final page = switch (tab) {
        0 => overview(),
        1 => assignments(),
        2 => analytics(),
        _ => s.staff && tab == 3 ? roster() : cloud(),
      };
      return Scaffold(
        backgroundColor: TactixTheme.bg,
        appBar: AppBar(
          title: Text(s.staff ? 'Центр инструктора' : 'Учебная платформа'),
          actions: [
            IconButton(
              tooltip: 'Синхронизировать',
              onPressed: s.busy ? null : s.sync,
              icon: const Icon(Icons.sync),
            ),
          ],
        ),
        bottomNavigationBar: wide
            ? null
            : NavigationBar(
                selectedIndex: tab,
                onDestinationSelected: navigate,
                destinations: [
                  for (var i = 0; i < tabs.length; i++)
                    NavigationDestination(icon: Icon(icons[i]), label: tabs[i]),
                ],
              ),
        body: Row(
          children: [
            if (wide)
              NavigationRail(
                selectedIndex: tab,
                onDestinationSelected: navigate,
                extended: constraints.maxWidth >= 1200,
                labelType: constraints.maxWidth >= 1200
                    ? NavigationRailLabelType.none
                    : NavigationRailLabelType.all,
                destinations: [
                  for (var i = 0; i < tabs.length; i++)
                    NavigationRailDestination(
                      icon: Icon(icons[i]),
                      label: Text(tabs[i]),
                    ),
                ],
              ),
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1120),
                  child: ListView(
                    controller: scroll,
                    padding: EdgeInsets.all(wide ? 28 : 16),
                    children: [
                      if (s.busy) const LinearProgressIndicator(minHeight: 2),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16, top: 8),
                        child: Text(
                          '${s.status} · очередь ${s.pending} · конфликты ${s.conflicts}',
                          style: const TextStyle(color: TactixTheme.textMuted),
                        ),
                      ),
                      if (error != null)
                        Text(
                          error!,
                          style: const TextStyle(color: Colors.orangeAccent),
                        ),
                      queue(),
                      if (s.staff && (tab == 1 || tab == 2)) ...[
                        DropdownButtonFormField<String>(
                          key: ValueKey(learner),
                          initialValue: learner,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Учебная история участника',
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: '',
                              child: Text('Все участники'),
                            ),
                            for (final id in {
                              ...s.participants.map((p) => p['id'] as String),
                              ...s.assignments.map(
                                (a) => a['learner_id'] as String,
                              ),
                            })
                              DropdownMenuItem(
                                value: id,
                                child: Text(
                                  name(id),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: (v) => setState(() {
                            learner = v!;
                            compared.clear();
                          }),
                        ),
                        const SizedBox(height: 16),
                      ],
                      page,
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}
