import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../app/user_session_scope.dart';
import '../../models/app_user.dart';
import '../../screens/strategy/strategy_screen.dart';
import '../strategy/studio/data/platform_sync.dart';
import 'thread_graph.dart';
import 'thread_store.dart';

class ThreadScreen extends StatefulWidget {
  const ThreadScreen({super.key, this.store});
  final ThreadStore? store;
  @override
  State<ThreadScreen> createState() => _ThreadScreenState();
}

class _ThreadScreenState extends State<ThreadScreen>
    with WidgetsBindingObserver {
  ThreadStore? _store;
  PlatformApi? _api;
  String? _selected;
  String _search = '';
  bool _busy = false;
  int _viewMode = 0; // 0 Cases, 1 Graph, 2 PULSE
  ThreadStore get store => _store!;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_store != null) return;
    if (widget.store != null) {
      _store = widget.store;
    } else {
      final session = UserSessionScope.of(context);
      final user = session.currentUser!;
      if (session.isServerUser) {
        _api = PlatformApi(session, user.id, apiPrefix: '/v1/thread');
      }
      _store = ThreadStore(
        user.id,
        api: _api,
        staff:
            user.serverRole == UserRole.instructor ||
            user.serverRole == UserRole.admin,
      );
    }
    store.addListener(_changed);
    if (!store.ready) unawaited(_perform(() => store.restore()));
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(store.sync());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _store?.removeListener(_changed);
    if (widget.store == null) {
      _store?.dispose();
      _api?.dispose();
    }
    super.dispose();
  }

  Future<void> _perform(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<List<String>?> _form(
    String title,
    List<String> labels, {
    bool optionalLast = false,
  }) async {
    final controllers = labels.map((_) => TextEditingController()).toList();
    final key = GlobalKey<FormState>();
    final result = await showDialog<List<String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 480,
          child: Form(
            key: key,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < labels.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: TextFormField(
                        controller: controllers[i],
                        autofocus: i == 0,
                        minLines: 1,
                        maxLines: i == 1 ? 4 : 2,
                        maxLength: labels[i] == 'Название'
                            ? 200
                            : labels[i] == 'Источник / ссылка'
                            ? 2000
                            : 4000,
                        decoration: InputDecoration(labelText: labels[i]),
                        validator: (v) =>
                            (v ?? '').trim().isEmpty &&
                                !(optionalLast && i == labels.length - 1)
                            ? 'Обязательное поле'
                            : null,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              if (key.currentState!.validate()) {
                Navigator.pop(
                  context,
                  controllers.map((c) => c.text.trim()).toList(),
                );
              }
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    // Dialog transition may still own its fields during reverse animation.
    await Future<void>.delayed(const Duration(milliseconds: 250));
    for (final c in controllers) {
      c.dispose();
    }
    return result;
  }

  Future<void> _create() async {
    final values = await _form('Создать дело', [
      'Название',
      'Причина и цель работы',
    ]);
    if (values == null || !mounted) return;
    await _perform(() async {
      _selected = await store.create(values[0], values[1]);
    });
  }

  Future<void> _select(String id) async {
    setState(() => _selected = id);
    await _perform(() async {
      await store.loadEvents(id);
      await store.loadRelations(id);
      await store.loadTraining(id);
      await store.loadBranches(id);
    });
  }

  Future<void> _status(Map<String, dynamic> row, String status) async {
    final values = await _form(
      status == 'CLOSED'
          ? 'Закрыть после проверки подтверждений'
          : 'Изменить статус',
      ['Основание'],
    );
    if (values == null || !mounted) return;
    await _perform(() async {
      await store.changeStatus(row['id'], status, values[0]);
      await store.sync();
      await store.loadEvents(row['id']);
    });
  }

  Future<void> _evidence(Map<String, dynamic> row) async {
    final values = await _form('Добавить подтверждение', [
      'Название',
      'Наблюдаемый результат / подтверждающий контекст',
      'Источник / ссылка',
    ], optionalLast: true);
    if (values == null || !mounted) return;
    await _perform(() async {
      await store.addEvidence(row['id'], values[0], values[1], values[2]);
      await store.sync();
      await store.loadEvents(row['id']);
    });
  }

  Future<void> _askThread(Map<String, dynamic> row) async {
    if (store.api == null) return;
    final controller = TextEditingController();
    final key = GlobalKey<FormState>();
    final question = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.auto_awesome, color: TactixTheme.gold),
            SizedBox(width: 10),
            Text('АНАЛИЗ TACTIX'),
          ],
        ),
        content: SizedBox(
          width: 560,
          child: Form(
            key: key,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ответ формируется только по данным текущего дела: подтверждённой хронологии, материалам и связанным результатам подготовки. Непроверенные материалы не считаются установленным фактом.',
                  style: TextStyle(color: TactixTheme.textMuted, height: 1.45),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: controller,
                  autofocus: true,
                  minLines: 2,
                  maxLines: 5,
                  maxLength: 1600,
                  decoration: const InputDecoration(
                    labelText: 'Вопрос по текущему делу',
                    hintText: 'Что подтверждено, чего не хватает и что мешает закрыть дело?',
                  ),
                  validator: (value) => (value ?? '').trim().length < 2
                      ? 'Введите вопрос'
                      : null,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final prompt in const [
                      'Что уже подтверждено?',
                      'Каких подтверждений не хватает?',
                      'Что мешает закрыть дело?',
                    ])
                      ActionChip(
                        label: Text(prompt),
                        onPressed: () => controller.text = prompt,
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
            child: const Text('Отмена'),
          ),
          FilledButton.icon(
            onPressed: () {
              if (key.currentState!.validate()) {
                Navigator.pop(context, controller.text.trim());
              }
            },
            icon: const Icon(Icons.auto_awesome),
            label: const Text('Анализировать'),
          ),
        ],
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 250));
    controller.dispose();
    if (question == null || !mounted) return;
    await _perform(() => store.askThread(row['id'] as String, question));
  }

  String? _branchDate(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return null;
    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
      return '${value}T23:59:00Z';
    }
    final parsed = DateTime.tryParse(value);
    if (parsed == null) throw FormatException('Используйте формат ГГГГ-ММ-ДД или ISO дату/время');
    return parsed.toUtc().toIso8601String();
  }

  String _ownerLabel(List<Map<String, dynamic>> owners, String? id) {
    if (id == null) return 'Не назначен';
    for (final owner in owners) {
      if (owner['id'] == id) return owner['label']?.toString() ?? id;
    }
    return id;
  }


  String _statusLabel(Object? raw) => switch (raw?.toString()) {
    'OPEN' => 'Открыто',
    'IN_REVIEW' => 'На рассмотрении',
    'ACTION_REQUIRED' => 'Требуются действия',
    'IN_PROGRESS' => 'В работе',
    'WAITING_FOR_EVIDENCE' => 'Ожидает подтверждений',
    'TRAINING_REQUIRED' => 'Требуется подготовка',
    'WAITING_FOR_VERIFICATION' => 'Ожидает проверки',
    'RESOLVED' => 'Решено',
    'CLOSED' => 'Закрыто',
    'DRAFT' => 'Черновик',
    'MERGED' => 'Применён',
    'ARCHIVED' => 'Архив',
    'assigned' => 'Назначено',
    'in_progress' => 'Выполняется',
    'submitted' => 'Результат отправлен',
    'completed' => 'Завершено',
    'cancelled' => 'Отменено',
    null => '—',
    '' => '—',
    final value => value.replaceAll('_', ' '),
  };

  String _priorityLabel(Object? raw) => switch (raw?.toString()) {
    'LOW' => 'Низкий',
    'NORMAL' => 'Обычный',
    'HIGH' => 'Высокий',
    'URGENT' => 'Срочный',
    null => '—',
    '' => '—',
    final value => value,
  };

  String _verificationLabel(Object? raw) => switch (raw?.toString()) {
    'VERIFIED' => 'Проверено',
    'REJECTED' => 'Отклонено',
    'PENDING' => 'Ожидает проверки',
    'UNVERIFIED' => 'Не проверено',
    null => 'Не проверено',
    '' => 'Не проверено',
    final value => value.replaceAll('_', ' '),
  };

  String _kindLabel(Object? raw) => switch (raw?.toString()) {
    'TASK' => 'Задача',
    'TRAINING' => 'Подготовка',
    'REVIEW' => 'Проверка',
    'CASE' => 'Дело',
    'BRANCH' => 'Вариант плана',
    'RELATION' => 'Связь',
    'EVENT' => 'Событие',
    null => '—',
    '' => '—',
    final value => value.replaceAll('_', ' '),
  };

  String _relationshipLabel(Object? raw) => switch (raw?.toString()) {
    'RELATED_TO' => 'Связано с',
    'REQUIRES' => 'Требует',
    'CREATED_FROM' => 'Создано из',
    'RESULTED_IN' => 'Привело к',
    'SUPERSEDES' => 'Заменяет',
    'SUPPORTED_BY' => 'Подтверждается',
    'TRAINED_BY' => 'Подготовка по',
    'PRODUCED' => 'Сформировало',
    null => '—',
    '' => '—',
    final value => value.replaceAll('_', ' '),
  };

  String _confidenceLabel(Object? raw) => switch (raw?.toString()) {
    'HIGH' => 'Высокая уверенность',
    'MEDIUM' => 'Средняя уверенность',
    'LOW' => 'Низкая уверенность',
    null => 'Не определена',
    '' => 'Не определена',
    final value => value,
  };

  String _fieldLabel(Object? raw) => switch (raw?.toString()) {
    'description' => 'Описание',
    'priority' => 'Приоритет',
    'status' => 'Статус',
    'owner_id' => 'Ответственный',
    'due_date' => 'Срок',
    'plan_items' => 'Пункты плана',
    null => 'Поле',
    '' => 'Поле',
    final value => value.replaceAll('_', ' '),
  };

  String _severityLabel(Object? raw) => switch (raw?.toString()) {
    'BLOCKING' => 'Блокирующий конфликт',
    'WARNING' => 'Предупреждение',
    'INFO' => 'Информация',
    null => 'Проверка',
    '' => 'Проверка',
    final value => value.replaceAll('_', ' '),
  };

  String _conflictCodeLabel(Object? raw) => switch (raw?.toString()) {
    'FIELD_DIVERGED' => 'поле изменено в двух версиях',
    'CASE_CLOSED' => 'дело уже закрыто',
    'OWNER_INACTIVE' => 'ответственный недоступен',
    'ASSIGNEE_INACTIVE' => 'исполнитель недоступен',
    'INVALID_DATE' => 'некорректная дата',
    'PAST_DUE' => 'срок уже прошёл',
    'DUPLICATE_PLAN_ITEM' => 'дублирующий пункт плана',
    'PLAN_AFTER_CASE_DUE' => 'пункт выходит за срок дела',
    'TRAINING_AFTER_CASE_DUE' => 'подготовка выходит за срок дела',
    null => 'требуется проверка',
    '' => 'требуется проверка',
    final value => value.replaceAll('_', ' ').toLowerCase(),
  };

  String _alertCodeLabel(Object? raw) => switch (raw?.toString()) {
    'OVERDUE' => 'Просрочено',
    'STALE' => 'Давно без изменений',
    'WAITING_FOR_VERIFICATION' => 'Ожидает проверки',
    'DUE_SOON' => 'Срок приближается',
    'UNVERIFIED_EVIDENCE' => 'Есть непроверенные подтверждения',
    null => 'Требует внимания',
    '' => 'Требует внимания',
    final value => value.replaceAll('_', ' '),
  };

  String _eventTypeLabel(Object? raw) => switch (raw?.toString()) {
    'CASE_CREATED' => 'Дело создано',
    'CASE_UPDATED' => 'Дело обновлено',
    'STATUS_CHANGED' => 'Статус изменён',
    'EVIDENCE_ADDED' => 'Добавлено подтверждение',
    'EVIDENCE_VERIFIED' => 'Подтверждение проверено',
    'EVIDENCE_REJECTED' => 'Подтверждение отклонено',
    'RELATION_CREATED' => 'Создана связь',
    'BRANCH_CREATED' => 'Создан вариант плана',
    'BRANCH_UPDATED' => 'Вариант плана обновлён',
    'BRANCH_MERGED' => 'Вариант плана применён',
    'TRAINING_LINKED' => 'Подготовка связана с делом',
    'TRAINING_COMPLETED' => 'Подготовка завершена',
    'RESULT_IMPORTED' => 'Результат добавлен в дело',
    null => 'Событие',
    '' => 'Событие',
    final value => value.replaceAll('_', ' '),
  };

  Future<Map<String, dynamic>?> _planItemDialog(
    List<Map<String, dynamic>> owners,
  ) async {
    final title = TextEditingController();
    final due = TextEditingController();
    final note = TextEditingController();
    var kind = 'TASK';
    String? assignee = owners.isEmpty ? null : owners.first['id'] as String?;
    final key = GlobalKey<FormState>();
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Добавить пункт варианта плана'),
          content: SizedBox(
            width: 520,
            child: Form(
              key: key,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: title,
                      autofocus: true,
                      maxLength: 240,
                      decoration: const InputDecoration(labelText: 'Задача / действие'),
                      validator: (v) => (v ?? '').trim().isEmpty ? 'Обязательное поле' : null,
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: kind,
                      decoration: const InputDecoration(labelText: 'Тип'),
                      items: const [
                        DropdownMenuItem(value: 'TASK', child: Text('Задача')),
                        DropdownMenuItem(value: 'TRAINING', child: Text('Подготовка')),
                        DropdownMenuItem(value: 'REVIEW', child: Text('Проверка')),
                      ],
                      onChanged: (v) => setLocal(() => kind = v ?? 'TASK'),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String?>(
                      initialValue: assignee,
                      decoration: const InputDecoration(labelText: 'Исполнитель'),
                      items: [
                        const DropdownMenuItem<String?>(value: null, child: Text('Без исполнителя')),
                        for (final owner in owners)
                          DropdownMenuItem<String?>(
                            value: owner['id'] as String,
                            child: Text(owner['label']?.toString() ?? owner['id'].toString()),
                          ),
                      ],
                      onChanged: (v) => setLocal(() => assignee = v),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: due,
                      decoration: const InputDecoration(
                        labelText: 'Срок (необязательно)',
                        hintText: 'ГГГГ-ММ-ДД',
                      ),
                      validator: (value) {
                        if ((value ?? '').trim().isEmpty) return null;
                        try {
                          _branchDate(value!);
                          return null;
                        } catch (_) {
                          return 'Используйте ГГГГ-ММ-ДД или ISO дату/время';
                        }
                      },
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: note,
                      minLines: 2,
                      maxLines: 4,
                      maxLength: 2000,
                      decoration: const InputDecoration(labelText: 'Примечание к плану'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
            FilledButton(
              onPressed: () {
                if (!key.currentState!.validate()) return;
                Navigator.pop(context, {
                  'id': platformId(),
                  'title': title.text.trim(),
                  'kind': kind,
                  'assignee_id': assignee,
                  'due_at': _branchDate(due.text),
                  'note': note.text.trim(),
                });
              },
              child: const Text('Добавить'),
            ),
          ],
        ),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 250));
    title.dispose();
    due.dispose();
    note.dispose();
    return result;
  }

  Future<void> _createBranch(Map<String, dynamic> row) async {
    if (!store.staff || store.api == null) return;
    final values = await _form(
      'Создать вариант плана',
      ['Название варианта', 'Замысел / цель варианта'],
      optionalLast: true,
    );
    if (values == null || !mounted) return;
    await _perform(() async {
      await store.createBranch(row['id'] as String, values[0], values[1]);
      await store.loadBranches(row['id'] as String);
    });
  }

  Future<void> _editBranch(
    Map<String, dynamic> row,
    Map<String, dynamic> branch,
  ) async {
    final caseId = row['id'] as String;
    if (store.branchOwnersForCase(caseId).isEmpty) {
      await _perform(() => store.loadBranches(caseId));
      if (!mounted) return;
    }
    final owners = store.branchOwnersForCase(caseId);
    final rawDraft = Map<String, dynamic>.from(branch['draft_snapshot'] as Map);
    final name = TextEditingController(text: branch['name']?.toString() ?? '');
    final branchNote = TextEditingController(text: branch['description']?.toString() ?? '');
    final caseDescription = TextEditingController(text: rawDraft['description']?.toString() ?? '');
    final due = TextEditingController(
      text: rawDraft['due_date'] == null
          ? ''
          : rawDraft['due_date'].toString().split('T').first,
    );
    var priority = rawDraft['priority']?.toString() ?? 'NORMAL';
    var status = rawDraft['status']?.toString() ?? 'OPEN';
    String? ownerId = rawDraft['owner_id']?.toString();
    if (owners.isNotEmpty && !owners.any((o) => o['id'] == ownerId)) {
      ownerId = owners.first['id'] as String;
    }
    final planItems = ((rawDraft['plan_items'] ?? const <dynamic>[]) as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final key = GlobalKey<FormState>();
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.fork_right_outlined, color: TactixTheme.cyan),
              SizedBox(width: 10),
              Text('Редактировать вариант плана'),
            ],
          ),
          content: SizedBox(
            width: 720,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 620),
              child: Form(
                key: key,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: name,
                        maxLength: 160,
                        decoration: const InputDecoration(labelText: 'Название варианта'),
                        validator: (v) => (v ?? '').trim().isEmpty ? 'Обязательное поле' : null,
                      ),
                      TextFormField(
                        controller: branchNote,
                        maxLength: 2000,
                        minLines: 2,
                        maxLines: 3,
                        decoration: const InputDecoration(labelText: 'Замысел / примечание'),
                      ),
                      const SizedBox(height: 8),
                      Text('Предлагаемое состояние дела', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: caseDescription,
                        minLines: 2,
                        maxLines: 5,
                        maxLength: 8000,
                        decoration: const InputDecoration(labelText: 'Предлагаемое описание дела'),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          SizedBox(
                            width: 210,
                            child: DropdownButtonFormField<String>(
                              initialValue: priority,
                              decoration: const InputDecoration(labelText: 'Приоритет'),
                              items: const [
                                DropdownMenuItem(value: 'LOW', child: Text('Низкий')),
                                DropdownMenuItem(value: 'NORMAL', child: Text('Обычный')),
                                DropdownMenuItem(value: 'HIGH', child: Text('Высокий')),
                                DropdownMenuItem(value: 'URGENT', child: Text('Срочный')),
                              ],
                              onChanged: (v) => setLocal(() => priority = v ?? priority),
                            ),
                          ),
                          SizedBox(
                            width: 250,
                            child: DropdownButtonFormField<String>(
                              initialValue: status,
                              decoration: const InputDecoration(labelText: 'Предлагаемый статус'),
                              items: [
                                for (final value in const [
                                  'OPEN', 'IN_REVIEW', 'ACTION_REQUIRED', 'IN_PROGRESS',
                                  'WAITING_FOR_EVIDENCE', 'TRAINING_REQUIRED',
                                  'WAITING_FOR_VERIFICATION', 'RESOLVED',
                                ])
                                  DropdownMenuItem(value: value, child: Text(_statusLabel(value))),
                              ],
                              onChanged: (v) => setLocal(() => status = v ?? status),
                            ),
                          ),
                          SizedBox(
                            width: 260,
                            child: DropdownButtonFormField<String>(
                              initialValue: ownerId,
                              decoration: const InputDecoration(labelText: 'Предлагаемый ответственный'),
                              items: [
                                for (final owner in owners)
                                  DropdownMenuItem<String>(
                                    value: owner['id'] as String,
                                    child: Text(owner['label']?.toString() ?? owner['id'].toString()),
                                  ),
                              ],
                              onChanged: (v) => setLocal(() => ownerId = v),
                              validator: (v) => v == null ? 'Выберите ответственного' : null,
                            ),
                          ),
                          SizedBox(
                            width: 210,
                            child: TextFormField(
                              controller: due,
                              decoration: const InputDecoration(
                                labelText: 'Срок по делу',
                                hintText: 'ГГГГ-ММ-ДД',
                              ),
                              validator: (value) {
                                if ((value ?? '').trim().isEmpty) return null;
                                try {
                                  _branchDate(value!);
                                  return null;
                                } catch (_) {
                                  return 'Используйте формат ГГГГ-ММ-ДД';
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(child: Text('Пункты плана', style: Theme.of(context).textTheme.titleMedium)),
                          OutlinedButton.icon(
                            onPressed: () async {
                              final item = await _planItemDialog(owners);
                              if (item != null) setLocal(() => planItems.add(item));
                            },
                            icon: const Icon(Icons.add_task_outlined),
                            label: const Text('Добавить пункт'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (planItems.isEmpty)
                        const Text(
                          'Дополнительных пунктов нет. Можно сравнить только изменения самого дела.',
                          style: TextStyle(color: TactixTheme.textMuted),
                        ),
                      for (final item in planItems)
                        Card(
                          child: ListTile(
                            leading: const Icon(Icons.checklist_outlined, color: TactixTheme.cyan),
                            title: Text(item['title']?.toString() ?? 'Пункт плана'),
                            subtitle: Text(
                              '${_kindLabel(item['kind'])} · ${_ownerLabel(owners, item['assignee_id']?.toString())}'
                              '${item['due_at'] == null ? '' : ' · ${item['due_at'].toString().split('T').first}'}',
                            ),
                            trailing: IconButton(
                              tooltip: 'Удалить',
                              onPressed: () => setLocal(() => planItems.remove(item)),
                              icon: const Icon(Icons.close),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
            FilledButton.icon(
              onPressed: () {
                if (!key.currentState!.validate()) return;
                Navigator.pop(context, {
                  'name': name.text.trim(),
                  'description': branchNote.text.trim(),
                  'draft': {
                    'description': caseDescription.text.trim(),
                    'priority': priority,
                    'status': status,
                    'owner_id': ownerId,
                    'due_date': _branchDate(due.text),
                    'plan_items': planItems,
                  },
                });
              },
              icon: const Icon(Icons.save_outlined),
              label: const Text('Сохранить вариант'),
            ),
          ],
        ),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 250));
    name.dispose();
    branchNote.dispose();
    caseDescription.dispose();
    due.dispose();
    if (result == null || !mounted) return;
    await _perform(() async {
      await store.updateBranch(
        caseId,
        branch['id'] as String,
        baseRevision: branch['revision'] as int,
        name: result['name'] as String,
        description: result['description'] as String,
        draft: Map<String, dynamic>.from(result['draft'] as Map),
      );
      await store.loadBranches(caseId);
    });
  }

  Future<void> _showBranchCompare(Map<String, dynamic> comparison) async {
    final changes = (comparison['changes'] as List?) ?? const <dynamic>[];
    final conflicts = (comparison['conflicts'] as List?) ?? const <dynamic>[];
    final items = (comparison['plan_items'] as List?) ?? const <dynamic>[];
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.compare_arrows_outlined, color: TactixTheme.cyan),
            const SizedBox(width: 10),
            const Expanded(child: Text('ВАРИАНТ ПЛАНА · Сравнение')),
            Chip(
              label: Text(comparison['can_merge'] == true ? 'ГОТОВО К ПРИМЕНЕНИЮ' : 'ТРЕБУЕТ ПРОВЕРКИ'),
            ),
          ],
        ),
        content: SizedBox(
          width: 700,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 600),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Базовая версия дела r${comparison['base_case_revision']} → текущая r${comparison['live_case_revision']}'
                    '${comparison['stale_base'] == true ? ' · после создания варианта основное дело изменилось' : ''}',
                    style: const TextStyle(color: TactixTheme.textMuted),
                  ),
                  const SizedBox(height: 16),
                  Text('Изменения', style: Theme.of(context).textTheme.titleMedium),
                  if (changes.isEmpty) const Text('Изменений в самом деле нет.'),
                  for (final raw in changes)
                    Builder(builder: (_) {
                      final change = raw as Map;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.swap_horiz, color: TactixTheme.cyan),
                        title: Text(_fieldLabel(change['field'])),
                        subtitle: SelectableText('${change['before']}  →  ${change['after']}'),
                      );
                    }),
                  const SizedBox(height: 12),
                  Text('Конфликты и предупреждения', style: Theme.of(context).textTheme.titleMedium),
                  if (conflicts.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('Конфликты не обнаружены.', style: TextStyle(color: TactixTheme.positive)),
                    ),
                  for (final raw in conflicts)
                    Builder(builder: (_) {
                      final conflict = raw as Map;
                      final blocking = conflict['severity'] == 'BLOCKING';
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          blocking ? Icons.block_outlined : Icons.warning_amber_outlined,
                          color: blocking ? TactixTheme.warning : TactixTheme.gold,
                        ),
                        title: Text('${_severityLabel(conflict['severity'])} · ${_conflictCodeLabel(conflict['code'])}'),
                        subtitle: Text(conflict['message']?.toString() ?? ''),
                      );
                    }),
                  const SizedBox(height: 12),
                  Text('Пункты плана', style: Theme.of(context).textTheme.titleMedium),
                  if (items.isEmpty) const Text('Дополнительных пунктов плана нет.'),
                  for (final raw in items)
                    Builder(builder: (_) {
                      final item = raw as Map;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.task_alt_outlined),
                        title: Text(item['title']?.toString() ?? 'Пункт плана'),
                        subtitle: Text('${_kindLabel(item['kind'])}${item['due_at'] == null ? '' : ' · ${item['due_at']}'}'),
                      );
                    }),
                ],
              ),
            ),
          ),
        ),
        actions: [
          FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Закрыть')),
        ],
      ),
    );
  }

  Future<void> _compareBranch(Map<String, dynamic> branch) async {
    Map<String, dynamic>? comparison;
    await _perform(() async {
      comparison = await store.compareBranch(branch['id'] as String);
    });
    if (comparison != null && mounted) await _showBranchCompare(comparison!);
  }

  Future<void> _mergeBranch(
    Map<String, dynamic> row,
    Map<String, dynamic> branch,
  ) async {
    Map<String, dynamic>? comparison;
    await _perform(() async {
      comparison = await store.compareBranch(branch['id'] as String);
    });
    if (comparison == null || !mounted) return;
    if (comparison!['can_merge'] != true) {
      await _showBranchCompare(comparison!);
      return;
    }
    final warnings = comparison!['warnings'] as int? ?? 0;
    final values = await _form(
      warnings > 0 ? 'Применить вариант с предупреждениями: $warnings' : 'Применить вариант',
      ['Комментарий к применению'],
    );
    if (values == null || !mounted) return;
    await _perform(() async {
      await store.mergeBranch(
        row['id'] as String,
        branch['id'] as String,
        baseRevision: branch['revision'] as int,
        note: values[0],
      );
      await store.loadBranches(row['id'] as String);
      await store.loadEvents(row['id'] as String);
    });
  }

  Future<void> _trainingAction(Map<String, dynamic> row) async {
    if (!store.staff || store.api == null) return;
    final caseId = row['id'] as String;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => SimulationLabScreen(
          userId: store.userId,
          startInLibrary: false,
          startInPlatform: true,
          onAssignmentCreated: (assignmentId) async {
            await store.linkTraining(caseId, assignmentId);
            await store.sync();
            await store.loadRelations(caseId);
            await store.loadTraining(caseId);
            await store.loadEvents(caseId);
          },
        ),
      ),
    );
    if (!mounted) return;
    await _perform(() async {
      await store.sync();
      await store.loadRelations(caseId);
      await store.loadTraining(caseId);
      await store.loadEvents(caseId);
    });
  }

  Future<void> _importTrainingResult(
    Map<String, dynamic> row,
    Map<String, dynamic> training,
  ) async {
    await _perform(() async {
      final caseId = row['id'] as String;
      await store.importTrainingResult(caseId, training['id'] as String);
      await store.sync();
      await store.loadTraining(caseId);
      await store.loadRelations(caseId);
      await store.loadEvents(caseId);
    });
  }

  Future<void> _verify(
    Map<String, dynamic> row,
    Map evidence,
    String state,
  ) async {
    final values = await _form(
      state == 'VERIFIED' ? 'Подтвердить материал' : 'Отклонить',
      ['Комментарий проверяющего'],
    );
    if (values == null || !mounted) return;
    await _perform(() async {
      await store.verify(row['id'], evidence['id'], state, values[0]);
      await store.sync();
      await store.loadEvents(row['id']);
    });
  }

  Future<void> _linkCase(Map<String, dynamic> row) async {
    final options = store.cases.where((c) => c['id'] != row['id']).toList();
    if (options.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Создайте ещё одно дело, прежде чем связывать их.')),
      );
      return;
    }
    var targetId = options.first['id'] as String;
    var relationType = 'RELATED_TO';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Создать связь цифрового контура'),
          content: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: targetId,
                  decoration: const InputDecoration(labelText: 'Связанное дело'),
                  items: [
                    for (final item in options)
                      DropdownMenuItem<String>(
                        value: item['id'] as String,
                        child: Text(
                          item['title'] as String,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) setDialogState(() => targetId = value);
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: relationType,
                  decoration: const InputDecoration(labelText: 'Тип связи'),
                  items: [
                    for (final value in [
                      'RELATED_TO',
                      'REQUIRES',
                      'CREATED_FROM',
                      'RESULTED_IN',
                      'SUPERSEDES',
                    ])
                      DropdownMenuItem<String>(
                        value: value,
                        child: Text(_statusLabel(value)),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => relationType = value);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Связать'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    await _perform(() async {
      await store.createRelation(
        row['id'] as String,
        fromType: 'CASE',
        fromId: row['id'] as String,
        toType: 'CASE',
        toId: targetId,
        relationshipType: relationType,
      );
      await store.sync();
      await store.loadRelations(row['id'] as String);
    });
  }

  Future<void> _retry(String id) async {
    await _perform(() async {
      await store.sync();
      await store.loadEvents(id);
    });
    if (!mounted) return;
    final row = store.confirmedCase(id)!;
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Проверка конфликта синхронизации'),
        content: Text(
          'Версия сервера: ${row['revision']}\nТекущее состояние: ${_statusLabel(row['status'])}\n\nВаши ожидающие действия показаны в разделе «Ожидающие изменения». Перед применением проверьте подтверждения и хронологию.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Оставить черновик'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Применить мои ожидающие изменения'),
          ),
        ],
      ),
    );
    if (yes == true && mounted) {
      await _perform(
        () => store.retryAfterReview(
          id,
          reviewedRevision: row['revision'] as int,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final all = store.cases;
    final rows = all
        .where(
          (c) => '${c['title']} ${c['description']} ${c['status']}'
              .toLowerCase()
              .contains(_search.toLowerCase()),
        )
        .toList();
    final selected = _selected == null ? null : store.caseById(_selected!);
    return Scaffold(
      appBar: AppBar(
        title: const Text('ЦИФРОВОЙ КОНТУР'),
        actions: [
          IconButton(
            tooltip: 'Синхронизировать',
            onPressed: store.syncing || _busy
                ? null
                : () => _perform(store.sync),
            icon: const Icon(Icons.sync),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Контроль исполнения',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    store.api == null
                        ? 'ЛОКАЛЬНЫЙ РЕЖИМ · данные на устройстве · проверка требует сервера'
                        : store.syncing
                        ? 'Синхронизация · ожидающих изменений: ${store.pending.length}'
                        : 'Ожидающих действий: ${store.pending.length} · сохранённых дел: ${all.length}',
                    style: const TextStyle(color: TactixTheme.textMuted),
                  ),
                  if (store.recoveryWarning != null)
                    Text(
                      store.recoveryWarning!,
                      style: const TextStyle(color: TactixTheme.warning),
                    ),
                  if (store.error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        store.error!,
                        style: const TextStyle(color: TactixTheme.warning),
                      ),
                    ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _metric(
                        'Активные',
                        all.where((c) => c['status'] != 'CLOSED').length,
                      ),
                      _metric(
                        'Без подтверждений',
                        all
                            .where(
                              (c) =>
                                  c['status'] != 'CLOSED' &&
                                  (c['evidence'] as List).isEmpty,
                            )
                            .length,
                      ),
                      _metric(
                        'На проверке',
                        all
                            .where(
                              (c) => c['status'] == 'WAITING_FOR_VERIFICATION',
                            )
                            .length,
                      ),
                      _metric(
                        'Закрытые',
                        all.where((c) => c['status'] == 'CLOSED').length,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SegmentedButton<int>(
                    segments: const [
                      ButtonSegment<int>(
                        value: 0,
                        icon: Icon(Icons.view_list_outlined),
                        label: Text('Дела'),
                      ),
                      ButtonSegment<int>(
                        value: 1,
                        icon: Icon(Icons.hub_outlined),
                        label: Text('Связи'),
                      ),
                      ButtonSegment<int>(
                        value: 2,
                        icon: Icon(Icons.monitor_heart_outlined),
                        label: Text('Контроль'),
                      ),
                    ],
                    selected: {_viewMode},
                    onSelectionChanged: (value) {
                      final mode = value.first;
                      setState(() => _viewMode = mode);
                      if (mode == 2 &&
                          store.staff &&
                          store.api != null &&
                          !_busy) {
                        unawaited(_perform(() => store.loadPulse()));
                      }
                    },
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            if (!store.ready && store.error == null)
              const LinearProgressIndicator(),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (_viewMode == 2) return _pulseView();
                  if (_viewMode == 1) {
                    return ThreadGraphView(
                      store: store,
                      selectedCaseId: _selected,
                      onOpenCase: (id) {
                        setState(() {
                          _selected = id;
                          _viewMode = 0;
                        });
                        unawaited(_select(id));
                      },
                    );
                  }
                  final wide = constraints.maxWidth >= 850;
                  final list = _caseList(rows);
                  if (wide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          width: constraints.maxWidth >= 1200 ? 330 : 280,
                          child: list,
                        ),
                        const VerticalDivider(width: 1),
                        Expanded(
                          child: selected == null
                              ? _welcome()
                              : _detail(selected),
                        ),
                      ],
                    );
                  }
                  if (selected == null) return list;
                  return Column(
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () => setState(() => _selected = null),
                          icon: const Icon(Icons.arrow_back),
                          label: const Text('Дела'),
                        ),
                      ),
                      Expanded(child: _detail(selected)),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metric(String label, int count) =>
      Chip(label: Text('$count  $label'));

  Widget _pulseView() {
    if (!store.staff) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'Контроль процессов доступен руководителям и инструкторам. Он показывает состояние административных и учебных процессов, не изменяя данные дел.',
            textAlign: TextAlign.center,
            style: TextStyle(color: TactixTheme.textMuted, height: 1.5),
          ),
        ),
      );
    }
    if (store.api == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'Для контроля процессов требуется соединение с сервером. Сохранённые дела остаются доступны офлайн.',
            textAlign: TextAlign.center,
            style: TextStyle(color: TactixTheme.textMuted, height: 1.5),
          ),
        ),
      );
    }
    final pulse = store.pulse;
    if (pulse == null) {
      return Center(
        child: FilledButton.icon(
          onPressed: _busy ? null : () => _perform(() => store.loadPulse()),
          icon: const Icon(Icons.refresh),
          label: const Text('Загрузить контроль процессов'),
        ),
      );
    }
    final metrics = Map<String, dynamic>.from(
      (pulse['metrics'] as Map?) ?? const <String, dynamic>{},
    );
    final bottlenecks = ((pulse['bottlenecks'] ?? const <dynamic>[]) as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final alerts = ((pulse['alerts'] ?? const <dynamic>[]) as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final stream = store.eventStream.take(40).toList();
    final method = Map<String, dynamic>.from(
      (pulse['method'] as Map?) ?? const <String, dynamic>{},
    );
    final cards = <(String, String, IconData)>[
      ('Активные дела', '${metrics['active_cases'] ?? 0}', Icons.work_outline),
      ('Просрочено', '${metrics['overdue_cases'] ?? 0}', Icons.schedule_outlined),
      ('Срок скоро', '${metrics['due_soon_cases'] ?? 0}', Icons.event_outlined),
      ('Давно без изменений', '${metrics['stale_cases'] ?? 0}', Icons.hourglass_bottom),
      ('На проверке', '${metrics['waiting_for_verification'] ?? 0}', Icons.fact_check_outlined),
      ('Непроверенные подтверждения', '${metrics['unverified_evidence'] ?? 0}', Icons.attach_file),
      ('Черновики вариантов', '${metrics['draft_branches'] ?? 0}', Icons.fork_right_outlined),
      ('Ожидает подготовка', '${metrics['training_pending'] ?? 0}', Icons.school_outlined),
      ('Создано · 7 дн.', '${metrics['created_last_7d'] ?? 0}', Icons.add_chart_outlined),
      ('Закрыто · 7 дн.', '${metrics['closed_last_7d'] ?? 0}', Icons.task_alt_outlined),
    ];
    return RefreshIndicator(
      onRefresh: () => store.loadPulse(),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('КОНТРОЛЬ ПРОЦЕССОВ', style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 4),
                    const Text(
                      'Объективные показатели процесса · без ИИ-рекомендаций',
                      style: TextStyle(color: TactixTheme.textMuted),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Обновить контроль процессов',
                onPressed: _busy ? null : () => _perform(() => store.loadPulse()),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final card in cards)
                SizedBox(
                  width: 176,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(card.$3, color: TactixTheme.cyan, size: 20),
                          const SizedBox(height: 14),
                          Text(
                            card.$2,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            card.$1,
                            style: const TextStyle(color: TactixTheme.textMuted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
          Text('Требует внимания', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          if (alerts.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Просрочек, зависших дел и ожидания проверки в текущем периоде нет.'),
              ),
            )
          else
            for (final alert in alerts.take(12))
              Card(
                child: ListTile(
                  leading: Icon(
                    alert['severity'] == 'HIGH' ? Icons.error_outline : Icons.info_outline,
                    color: alert['severity'] == 'HIGH' ? TactixTheme.warning : TactixTheme.gold,
                  ),
                  title: Text(alert['title']?.toString() ?? 'Дело'),
                  subtitle: Text(
                    '${_alertCodeLabel(alert['code'])} · ${_statusLabel(alert['status'])} · ${alert['age_hours'] ?? 0} ч. без обновления',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    final id = alert['case_id']?.toString();
                    if (id == null || id.isEmpty) return;
                    setState(() {
                      _selected = id;
                      _viewMode = 0;
                    });
                    unawaited(_select(id));
                  },
                ),
              ),
          const SizedBox(height: 24),
          Text('Узкие места процесса', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          if (bottlenecks.isEmpty)
            const Text('Нет активных этапов для анализа.', style: TextStyle(color: TactixTheme.textMuted))
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final item in bottlenecks)
                  SizedBox(
                    width: 250,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _statusLabel(item['status']),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Text('Дел: ${item['count'] ?? 0}'),
                            Text(
                              'Среднее ожидание: ${item['avg_age_hours'] ?? 0} ч. · максимум ${item['max_age_hours'] ?? 0} ч.',
                              style: const TextStyle(color: TactixTheme.textMuted),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: Text('Лента событий', style: Theme.of(context).textTheme.titleLarge)),
              Text('Последних событий: ${stream.length}', style: const TextStyle(color: TactixTheme.textMuted)),
            ],
          ),
          const SizedBox(height: 10),
          if (stream.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Нет недавних событий по делам, вариантам планов, связям или подготовке.'),
              ),
            )
          else
            for (final event in stream)
              Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: TactixTheme.panel2,
                    child: Icon(_eventIcon(event['kind']?.toString()), color: TactixTheme.cyan, size: 19),
                  ),
                  title: Text(event['title']?.toString() ?? event['type']?.toString() ?? 'Событие'),
                  subtitle: Text(
                    "${_kindLabel(event['kind'])} · ${_eventTypeLabel(event['type'])}\n${event['created_at'] ?? ''}",
                  ),
                  isThreeLine: true,
                  onTap: event['case_id'] == null
                      ? null
                      : () {
                          final id = event['case_id'].toString();
                          setState(() {
                            _selected = id;
                            _viewMode = 0;
                          });
                          unawaited(_select(id));
                        },
                ),
              ),
          const SizedBox(height: 12),
          Text(
            'Сформировано: ${pulse['generated_at'] ?? ''} · источник: ${method['source'] ?? 'подтверждённые записи'}',
            style: const TextStyle(color: TactixTheme.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }

  IconData _eventIcon(String? kind) => switch (kind) {
    'CASE' => Icons.work_outline,
    'BRANCH' => Icons.fork_right_outlined,
    'RELATION' => Icons.hub_outlined,
    'TRAINING' => Icons.school_outlined,
    _ => Icons.bolt_outlined,
  };

  Widget _welcome() => ListView(
    padding: const EdgeInsets.all(24),
    children: const [
      Icon(Icons.account_tree_outlined, size: 48, color: TactixTheme.cyan),
      SizedBox(height: 20),
      Text(
        'Понимайте, почему возникла задача, что было сделано и чем подтверждён результат.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 20, height: 1.5),
      ),
      SizedBox(height: 24),
      Text(
        'ПРОСЛЕДИТЬ  /  ПРОВЕРИТЬ  /  УЛУЧШИТЬ',
        textAlign: TextAlign.center,
        style: TextStyle(color: TactixTheme.textMuted),
      ),
    ],
  );

  Widget _caseList(List<Map<String, dynamic>> rows) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            FilledButton.icon(
              onPressed: !store.ready || _busy ? null : _create,
              icon: const Icon(Icons.add),
              label: const Text('Создать дело'),
            ),
            const SizedBox(height: 12),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Поиск по сохранённым делам',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
          ],
        ),
      ),
      Expanded(
        child: rows.isEmpty
            ? _welcome()
            : ListView.builder(
                itemCount: rows.length,
                itemBuilder: (context, index) {
                  final row = rows[index];
                  final queued = store.pending.any(
                    (p) => p['case_id'] == row['id'],
                  );
                  return ListTile(
                    selected: row['id'] == _selected,
                    leading: Icon(
                      row['status'] == 'CLOSED'
                          ? Icons.verified_outlined
                          : Icons.radio_button_unchecked,
                      color: row['status'] == 'CLOSED'
                          ? TactixTheme.positive
                          : TactixTheme.cyan,
                    ),
                    title: Text(row['title']),
                    subtitle: Text(
                      '${_statusLabel(row['status'])} ${queued ? '· ожидает синхронизации' : ''}',
                    ),
                    onTap: () => _select(row['id']),
                  );
                },
              ),
      ),
    ],
  );

  Widget _askResultCard(Map<String, dynamic> entry) {
    final response = Map<String, dynamic>.from(entry['response'] as Map);
    final sources = ((response['sources'] ?? const <dynamic>[]) as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final gaps = ((response['open_questions'] ?? const <dynamic>[]) as List)
        .map((e) => e.toString())
        .toList();
    final unsupported =
        ((response['unsupported_claims'] ?? const <dynamic>[]) as List)
            .map((e) => e.toString())
            .toList();
    final confidence = (response['confidence'] ?? 'LOW').toString();
    final confidenceColor = confidence == 'HIGH'
        ? TactixTheme.positive
        : confidence == 'MEDIUM'
        ? TactixTheme.gold
        : TactixTheme.warning;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: SelectableText(
                    'Q: ${entry['question']}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Chip(
                  avatar: Icon(Icons.shield_outlined, size: 17, color: confidenceColor),
                  label: Text(_confidenceLabel(confidence)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SelectableText(
              response['answer']?.toString() ?? 'Ответ не получен.',
              style: const TextStyle(height: 1.55),
            ),
            const SizedBox(height: 14),
            Text(
              'Источники · ${sources.length}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            if (sources.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                  'После проверки не подтверждён ни один источник.',
                  style: TextStyle(color: TactixTheme.warning),
                ),
              ),
            for (final source in sources)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: TactixTheme.line),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          Chip(label: Text(source['ref']?.toString() ?? 'ИСТОЧНИК')),
                          Chip(label: Text(_kindLabel(source['kind']))),
                          if (source['verification_state'] != null)
                            Chip(label: Text(_verificationLabel(source['verification_state']))),
                        ],
                      ),
                      Text(
                        source['label']?.toString() ?? '',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      SelectableText(
                        source['excerpt']?.toString() ?? '',
                        style: const TextStyle(color: TactixTheme.textMuted, height: 1.4),
                      ),
                      if ((source['source'] ?? '').toString().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: SelectableText(
                            'Источник: ${source['source']}',
                            style: const TextStyle(color: TactixTheme.textMuted, fontSize: 12),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            if (unsupported.isNotEmpty) ...[
              const SizedBox(height: 14),
              const Text('Исключено / не подтверждено', style: TextStyle(color: TactixTheme.warning)),
              for (final item in unsupported)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('• $item'),
                ),
            ],
            if (gaps.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text('Открытые вопросы', style: Theme.of(context).textTheme.titleSmall),
              for (final item in gaps)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('• $item'),
                ),
            ],
            const SizedBox(height: 12),
            Text(
              'Версия дела ${response['case_revision'] ?? '?'} · проходов ИИ: ${response['passes'] ?? 2} · политика: ${response['evidence_policy'] ?? 'сначала проверенные данные'}',
              style: const TextStyle(color: TactixTheme.textMuted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detail(Map<String, dynamic> row) {
    final evidence = row['evidence'] as List;
    final events = store.events(row['id']);
    final training = store.trainingForCase(row['id'] as String);
    final branches = store.branchesForCase(row['id'] as String);
    final askHistory = store.askHistoryForCase(row['id'] as String);
    final latestAsk = askHistory.isEmpty ? null : askHistory.last;
    final pending = store.pending
        .where((p) => p['case_id'] == row['id'])
        .toList();
    final closed = row['status'] == 'CLOSED';
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        SelectableText(
          row['title'],
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        SelectableText(
          'Дело ${row['id']}\nОтветственный ${row['owner_id']}',
          style: const TextStyle(color: TactixTheme.textMuted, fontSize: 12),
        ),
        const SizedBox(height: 16),
        SelectableText(row['description'], style: const TextStyle(height: 1.6)),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Chip(label: Text(_statusLabel(row['status']))),
            Chip(label: Text(_priorityLabel(row['priority']))),
            if (!closed || store.staff)
              PopupMenuButton<String>(
                enabled: !_busy,
                tooltip: 'Изменить статус',
                onSelected: (status) => _status(row, status),
                itemBuilder: (_) => [
                  for (final status in [
                    'OPEN',
                    'IN_REVIEW',
                    'ACTION_REQUIRED',
                    'IN_PROGRESS',
                    'WAITING_FOR_EVIDENCE',
                    'TRAINING_REQUIRED',
                    'WAITING_FOR_VERIFICATION',
                    'RESOLVED',
                  ])
                    PopupMenuItem(
                      value: status,
                      child: Text(status.replaceAll('_', ' ')),
                    ),
                ],
                child: const Chip(label: Text('Изменить статус')),
              ),
            if (!closed)
              OutlinedButton.icon(
                onPressed: _busy ? null : () => _evidence(row),
                icon: const Icon(Icons.attach_file),
                label: const Text('Добавить подтверждение'),
              ),
            if (store.api != null)
              FilledButton.tonalIcon(
                onPressed: _busy || pending.isNotEmpty
                    ? null
                    : () => _askThread(row),
                icon: const Icon(Icons.auto_awesome),
                label: const Text('АНАЛИЗ TACTIX'),
              ),
            if (!closed && store.staff && store.api != null)
              FilledButton.tonalIcon(
                onPressed: _busy || pending.isNotEmpty ? null : () => _createBranch(row),
                icon: const Icon(Icons.fork_right_outlined),
                label: const Text('Создать вариант'),
              ),
            if (!closed && store.staff && store.api != null)
              FilledButton.tonalIcon(
                onPressed: _busy ? null : () => _trainingAction(row),
                icon: const Icon(Icons.school_outlined),
                label: const Text('Назначить подготовку'),
              ),
            OutlinedButton.icon(
              onPressed: _busy ? null : () => _linkCase(row),
              icon: const Icon(Icons.hub_outlined),
              label: const Text('Связать дело'),
            ),
            OutlinedButton.icon(
              onPressed: _busy
                  ? null
                  : () {
                      setState(() => _viewMode = 1);
                      unawaited(store.loadRelations(row['id'] as String));
                    },
              icon: const Icon(Icons.account_tree_outlined),
              label: const Text('Открыть связи'),
            ),
            if (!closed && store.staff && store.api != null)
              FilledButton.icon(
                onPressed:
                    _busy ||
                        pending.isNotEmpty ||
                        row['verification_state'] != 'VERIFIED'
                    ? null
                    : () => _status(row, 'CLOSED'),
                icon: const Icon(Icons.verified_outlined),
                label: const Text('Проверить и закрыть'),
              ),
          ],
        ),
        if (closed)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: SelectableText(
              'Закрытие: ${row['closure_reason']}\n${row['closed_at']}',
            ),
          ),
        if (pending.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(
            'Ожидающие изменения',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const Text(
            'Сохранено локально. Для проверки и закрытия требуется подтверждение сервером.',
            style: TextStyle(color: TactixTheme.warning),
          ),
          for (final op in pending)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.schedule, color: TactixTheme.warning),
              title: Text(
                '${op['body']['status'] ?? op['body']['state'] ?? op['body']['title'] ?? op['path']}',
              ),
              subtitle: Text(
                '${op['body']['note'] ?? op['body']['description'] ?? ''}${op['error'] == null ? '' : '\n${op['error']}'}',
              ),
            ),
          if (pending.any((e) => e['error'] != null && e['path'] != '/cases'))
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton(
                onPressed: _busy ? null : () => _retry(row['id']),
                child: const Text('Проверить конфликт / повторить'),
              ),
            ),
        ],
        if (store.staff) ...[
          const SizedBox(height: 28),
          Row(
            children: [
              const Icon(Icons.fork_right_outlined, color: TactixTheme.cyan),
              const SizedBox(width: 10),
              Expanded(
                child: Text('ВАРИАНТЫ ПЛАНА', style: Theme.of(context).textTheme.titleLarge),
              ),
              if (store.api != null)
                IconButton(
                  tooltip: 'Обновить варианты',
                  onPressed: _busy ? null : () => _perform(() => store.loadBranches(row['id'] as String)),
                  icon: const Icon(Icons.refresh),
                ),
              if (!closed && store.api != null)
                FilledButton.tonalIcon(
                  onPressed: _busy || pending.isNotEmpty ? null : () => _createBranch(row),
                  icon: const Icon(Icons.add),
                  label: const Text('Новый вариант'),
                ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Создайте альтернативный административный или учебный план без изменения действующего дела. Сравнение показывает пересекающиеся изменения до их применения.',
            style: TextStyle(color: TactixTheme.textMuted, height: 1.5),
          ),
          if (pending.isNotEmpty && store.api != null)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Text(
                'Синхронизируйте ожидающие изменения дела перед созданием или применением варианта.',
                style: TextStyle(color: TactixTheme.warning),
              ),
            ),
          if (branches.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Text(
                store.api == null
                    ? 'Для создания и сравнения вариантов плана требуется соединение с сервером.'
                    : 'Для этого дела пока нет вариантов плана.',
              ),
            ),
          for (final branch in branches)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.account_tree_outlined, color: TactixTheme.cyan),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            branch['name']?.toString() ?? 'Вариант плана',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        Chip(label: Text(_statusLabel(branch['status'] ?? 'DRAFT'))),
                      ],
                    ),
                    if ((branch['description']?.toString() ?? '').isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(branch['description'].toString()),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      'Создано от версии дела r${branch['base_case_revision']} · версия варианта r${branch['revision']}',
                      style: const TextStyle(color: TactixTheme.textMuted, fontSize: 12),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (branch['status'] == 'DRAFT' && store.api != null)
                          OutlinedButton.icon(
                            onPressed: _busy ? null : () => _editBranch(row, branch),
                            icon: const Icon(Icons.edit_outlined),
                            label: const Text('Изменить'),
                          ),
                        if (store.api != null)
                          OutlinedButton.icon(
                            onPressed: _busy ? null : () => _compareBranch(branch),
                            icon: const Icon(Icons.compare_arrows_outlined),
                            label: const Text('Сравнить'),
                          ),
                        if (branch['status'] == 'DRAFT' && store.api != null)
                          FilledButton.icon(
                            onPressed: _busy || pending.isNotEmpty ? null : () => _mergeBranch(row, branch),
                            icon: const Icon(Icons.merge_type_outlined),
                            label: const Text('Применить'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
        const SizedBox(height: 28),
        Row(
          children: [
            const Icon(Icons.auto_awesome, color: TactixTheme.gold),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'АНАЛИЗ TACTIX',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            if (store.api != null)
              FilledButton.tonalIcon(
                onPressed: _busy || pending.isNotEmpty
                    ? null
                    : () => _askThread(row),
                icon: const Icon(Icons.question_answer_outlined),
                label: const Text('Анализировать'),
              ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'Двухэтапный анализ по подтверждённым данным. Сервер формирует пакет источников и исключает неподтверждённые ссылки до выдачи ответа.',
          style: TextStyle(color: TactixTheme.textMuted, height: 1.5),
        ),
        if (store.api == null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Text('Для анализа TACTIX требуется соединение с сервером. Сохранённые результаты анализа остаются доступны офлайн.'),
          ),
        if (pending.isNotEmpty && store.api != null)
          const Padding(
            padding: EdgeInsets.only(top: 10),
            child: Text(
              'Перед анализом синхронизируйте изменения, чтобы ИИ видел те же подтверждения, что и вы.',
              style: TextStyle(color: TactixTheme.warning),
            ),
          ),
        if (latestAsk != null) ...[
          const SizedBox(height: 14),
          _askResultCard(latestAsk),
        ] else
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Text('Для этого дела ещё нет сохранённого анализа TACTIX.'),
          ),
        const SizedBox(height: 28),
        Row(
          children: [
            Expanded(
              child: Text(
                'Связанная подготовка',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            if (store.api != null)
              IconButton(
                tooltip: 'Обновить связанную подготовку',
                onPressed: _busy
                    ? null
                    : () => _perform(() => store.loadTraining(row['id'] as String)),
                icon: const Icon(Icons.refresh),
              ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'Учебные назначения, связанные с этим делом. Полученный результат можно прикрепить как подтверждение и затем проверить.',
          style: TextStyle(color: TactixTheme.textMuted, height: 1.5),
        ),
        if (training.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Text(
              store.api == null
                  ? 'Для привязки учебного назначения требуется соединение с сервером.'
                  : 'К этому делу пока не привязана подготовка.',
            ),
          ),
        for (final item in training)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.school_outlined, color: TactixTheme.gold),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          item['title']?.toString() ?? 'Учебное назначение',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      Chip(
                        label: Text(
                          _statusLabel(item['status'] ?? 'assigned'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Назначение ${item['id']}${item['due_at'] == null ? '' : '\nСрок: ${item['due_at']}'}',
                    style: const TextStyle(color: TactixTheme.textMuted),
                  ),
                  if (item['metrics'] is Map && (item['metrics'] as Map).isNotEmpty) ...[
                    const SizedBox(height: 8),
                    SelectableText(
                      (item['metrics'] as Map).entries
                          .map((e) => '${e.key}: ${e.value}')
                          .join(' · '),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (store.staff &&
                          !closed &&
                          item['status'] == 'submitted' &&
                          item['has_submission'] == true &&
                          item['evidence_attached'] != true)
                        FilledButton.icon(
                          onPressed: _busy
                              ? null
                              : () => _importTrainingResult(row, item),
                          icon: const Icon(Icons.fact_check_outlined),
                          label: const Text('Прикрепить результат как подтверждение'),
                        ),
                      if (item['evidence_attached'] == true)
                        const Chip(
                          avatar: Icon(Icons.verified_outlined, size: 17),
                          label: Text('Результат прикреплён'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 28),
        Text(
          'Подтверждения · ${_verificationLabel(row['verification_state'])}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        const Text(
          'Выполнено — не значит проверено. Перед подтверждением необходимо проверить основание и контекст.',
          style: TextStyle(color: TactixTheme.textMuted, height: 1.5),
        ),
        if (evidence.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text('Подтверждения не приложены. Закрытие дела недоступно.'),
          ),
        for (final item in evidence)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['title'],
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  SelectableText(item['description']),
                  if ((item['source'] ?? '') != '')
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: SelectableText('Источник: ${item['source']}'),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    _verificationLabel(item['verification_state']),
                    style: TextStyle(
                      color: item['verification_state'] == 'VERIFIED'
                          ? TactixTheme.positive
                          : TactixTheme.warning,
                    ),
                  ),
                  if (item['verified_by'] != null)
                    SelectableText(
                      'Проверил: ${item['verified_by']}\n${item['verified_at']}\n${item['verification_note']}',
                    ),
                  if (store.staff && !closed && item['pending'] != true)
                    Wrap(
                      spacing: 8,
                      children: [
                        TextButton(
                          onPressed: _busy || pending.isNotEmpty
                              ? null
                              : () => _verify(row, item, 'VERIFIED'),
                          child: const Text('Подтвердить'),
                        ),
                        TextButton(
                          onPressed: _busy || pending.isNotEmpty
                              ? null
                              : () => _verify(row, item, 'REJECTED'),
                          child: const Text('Отклонить'),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 28),
        Text('Связи цифрового контура', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 10),
        if (store.relationsForCase(row['id'] as String).isEmpty)
          const Text(
            'Явных связей пока нет. Свяжите это дело с другим, чтобы сформировать цифровой контур.',
            style: TextStyle(color: TactixTheme.textMuted),
          ),
        for (final relation in store.relationsForCase(row['id'] as String))
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              relation['pending'] == true
                  ? Icons.schedule_outlined
                  : Icons.hub_outlined,
              color: relation['pending'] == true
                  ? TactixTheme.warning
                  : TactixTheme.cyan,
            ),
            title: Text(
              _relationshipLabel(relation['relationship_type']),
            ),
            subtitle: SelectableText(
              '${relation['from_type']}:${relation['from_id']}\n→ ${relation['to_type']}:${relation['to_id']}',
            ),
          ),
        const SizedBox(height: 28),
        Text('Хронология дела', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        if (events.isEmpty)
          const Text(
            'Подтверждённых событий пока нет. Локальные действия отображаются выше до синхронизации.',
          ),
        for (final event in events.reversed)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.history, color: TactixTheme.cyan),
            title: Text(_eventTypeLabel(event['type'])),
            subtitle: SelectableText(
              '${event['created_at']}\nИнициатор: ${event['actor_id']}\n${(event['details'] as Map).entries.map((e) => '${e.key}: ${e.value}').join('\n')}',
            ),
          ),
        if (store.api != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: _busy
                  ? null
                  : () => _perform(() => store.loadEvents(row['id'])),
              child: const Text('Загрузить события / обновить'),
            ),
          ),
      ],
    );
  }
}
