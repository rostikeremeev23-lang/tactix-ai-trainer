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
                        maxLength: labels[i] == 'Title'
                            ? 200
                            : labels[i] == 'Source / reference'
                            ? 2000
                            : 4000,
                        decoration: InputDecoration(labelText: labels[i]),
                        validator: (v) =>
                            (v ?? '').trim().isEmpty &&
                                !(optionalLast && i == labels.length - 1)
                            ? 'Required'
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
            child: const Text('Cancel'),
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
            child: const Text('Save'),
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
    final values = await _form('Create Case', [
      'Title',
      'Why does this work exist?',
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
          ? 'Close with verified evidence'
          : 'Record status change',
      ['Reason'],
    );
    if (values == null || !mounted) return;
    await _perform(() async {
      await store.changeStatus(row['id'], status, values[0]);
      await store.sync();
      await store.loadEvents(row['id']);
    });
  }

  Future<void> _evidence(Map<String, dynamic> row) async {
    final values = await _form('Add evidence', [
      'Title',
      'Observed result / supporting context',
      'Source / reference',
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
            Text('ASK THREAD'),
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
                  'The answer is generated only from the current Case, confirmed timeline, evidence, and linked training records. Unverified evidence is not treated as fact.',
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
                    labelText: 'Question about this Case',
                    hintText: 'What is confirmed, what is missing, and what blocks closure?',
                  ),
                  validator: (value) => (value ?? '').trim().length < 2
                      ? 'Enter a question'
                      : null,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final prompt in const [
                      'What is confirmed?',
                      'What evidence is missing?',
                      'What blocks closure?',
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
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () {
              if (key.currentState!.validate()) {
                Navigator.pop(context, controller.text.trim());
              }
            },
            icon: const Icon(Icons.auto_awesome),
            label: const Text('Ask'),
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
    if (parsed == null) throw FormatException('Use YYYY-MM-DD or an ISO date/time');
    return parsed.toUtc().toIso8601String();
  }

  String _ownerLabel(List<Map<String, dynamic>> owners, String? id) {
    if (id == null) return 'Unassigned';
    for (final owner in owners) {
      if (owner['id'] == id) return owner['label']?.toString() ?? id;
    }
    return id;
  }

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
          title: const Text('Add Branch plan item'),
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
                      decoration: const InputDecoration(labelText: 'Task / action'),
                      validator: (v) => (v ?? '').trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: kind,
                      decoration: const InputDecoration(labelText: 'Type'),
                      items: const [
                        DropdownMenuItem(value: 'TASK', child: Text('Task')),
                        DropdownMenuItem(value: 'TRAINING', child: Text('Training')),
                        DropdownMenuItem(value: 'REVIEW', child: Text('Review')),
                      ],
                      onChanged: (v) => setLocal(() => kind = v ?? 'TASK'),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String?>(
                      initialValue: assignee,
                      decoration: const InputDecoration(labelText: 'Assignee'),
                      items: [
                        const DropdownMenuItem<String?>(value: null, child: Text('No assignee')),
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
                        labelText: 'Due date (optional)',
                        hintText: 'YYYY-MM-DD',
                      ),
                      validator: (value) {
                        if ((value ?? '').trim().isEmpty) return null;
                        try {
                          _branchDate(value!);
                          return null;
                        } catch (_) {
                          return 'Use YYYY-MM-DD or ISO date/time';
                        }
                      },
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: note,
                      minLines: 2,
                      maxLines: 4,
                      maxLength: 2000,
                      decoration: const InputDecoration(labelText: 'Planning note'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
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
              child: const Text('Add'),
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
      'Create TACTIX BRANCH',
      ['Variant name', 'Planning assumption / purpose'],
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
              Text('Edit TACTIX BRANCH'),
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
                        decoration: const InputDecoration(labelText: 'Variant name'),
                        validator: (v) => (v ?? '').trim().isEmpty ? 'Required' : null,
                      ),
                      TextFormField(
                        controller: branchNote,
                        maxLength: 2000,
                        minLines: 2,
                        maxLines: 3,
                        decoration: const InputDecoration(labelText: 'Variant assumption / note'),
                      ),
                      const SizedBox(height: 8),
                      Text('Proposed Case state', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: caseDescription,
                        minLines: 2,
                        maxLines: 5,
                        maxLength: 8000,
                        decoration: const InputDecoration(labelText: 'Proposed Case description'),
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
                              decoration: const InputDecoration(labelText: 'Priority'),
                              items: const [
                                DropdownMenuItem(value: 'LOW', child: Text('LOW')),
                                DropdownMenuItem(value: 'NORMAL', child: Text('NORMAL')),
                                DropdownMenuItem(value: 'HIGH', child: Text('HIGH')),
                                DropdownMenuItem(value: 'URGENT', child: Text('URGENT')),
                              ],
                              onChanged: (v) => setLocal(() => priority = v ?? priority),
                            ),
                          ),
                          SizedBox(
                            width: 250,
                            child: DropdownButtonFormField<String>(
                              initialValue: status,
                              decoration: const InputDecoration(labelText: 'Proposed status'),
                              items: [
                                for (final value in const [
                                  'OPEN', 'IN_REVIEW', 'ACTION_REQUIRED', 'IN_PROGRESS',
                                  'WAITING_FOR_EVIDENCE', 'TRAINING_REQUIRED',
                                  'WAITING_FOR_VERIFICATION', 'RESOLVED',
                                ])
                                  DropdownMenuItem(value: value, child: Text(value.replaceAll('_', ' '))),
                              ],
                              onChanged: (v) => setLocal(() => status = v ?? status),
                            ),
                          ),
                          SizedBox(
                            width: 260,
                            child: DropdownButtonFormField<String>(
                              initialValue: ownerId,
                              decoration: const InputDecoration(labelText: 'Proposed owner'),
                              items: [
                                for (final owner in owners)
                                  DropdownMenuItem<String>(
                                    value: owner['id'] as String,
                                    child: Text(owner['label']?.toString() ?? owner['id'].toString()),
                                  ),
                              ],
                              onChanged: (v) => setLocal(() => ownerId = v),
                              validator: (v) => v == null ? 'Select owner' : null,
                            ),
                          ),
                          SizedBox(
                            width: 210,
                            child: TextFormField(
                              controller: due,
                              decoration: const InputDecoration(
                                labelText: 'Case due date',
                                hintText: 'YYYY-MM-DD',
                              ),
                              validator: (value) {
                                if ((value ?? '').trim().isEmpty) return null;
                                try {
                                  _branchDate(value!);
                                  return null;
                                } catch (_) {
                                  return 'Use YYYY-MM-DD';
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(child: Text('Plan items', style: Theme.of(context).textTheme.titleMedium)),
                          OutlinedButton.icon(
                            onPressed: () async {
                              final item = await _planItemDialog(owners);
                              if (item != null) setLocal(() => planItems.add(item));
                            },
                            icon: const Icon(Icons.add_task_outlined),
                            label: const Text('Add item'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (planItems.isEmpty)
                        const Text(
                          'No additional plan items. You can compare only the Case-level proposal.',
                          style: TextStyle(color: TactixTheme.textMuted),
                        ),
                      for (final item in planItems)
                        Card(
                          child: ListTile(
                            leading: const Icon(Icons.checklist_outlined, color: TactixTheme.cyan),
                            title: Text(item['title']?.toString() ?? 'Plan item'),
                            subtitle: Text(
                              '${item['kind'] ?? 'TASK'} · ${_ownerLabel(owners, item['assignee_id']?.toString())}'
                              '${item['due_at'] == null ? '' : ' · ${item['due_at'].toString().split('T').first}'}',
                            ),
                            trailing: IconButton(
                              tooltip: 'Remove',
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
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
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
              label: const Text('Save variant'),
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
            const Expanded(child: Text('TACTIX BRANCH · Compare')),
            Chip(
              label: Text(comparison['can_merge'] == true ? 'MERGE READY' : 'REVIEW'),
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
                    'Base Case revision ${comparison['base_case_revision']} → live ${comparison['live_case_revision']}'
                    '${comparison['stale_base'] == true ? ' · live Case changed after fork' : ''}',
                    style: const TextStyle(color: TactixTheme.textMuted),
                  ),
                  const SizedBox(height: 16),
                  Text('Changes', style: Theme.of(context).textTheme.titleMedium),
                  if (changes.isEmpty) const Text('No Case-level changes.'),
                  for (final raw in changes)
                    Builder(builder: (_) {
                      final change = raw as Map;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.swap_horiz, color: TactixTheme.cyan),
                        title: Text(change['field'].toString()),
                        subtitle: SelectableText('${change['before']}  →  ${change['after']}'),
                      );
                    }),
                  const SizedBox(height: 12),
                  Text('Conflicts & warnings', style: Theme.of(context).textTheme.titleMedium),
                  if (conflicts.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('No conflicts detected.', style: TextStyle(color: TactixTheme.positive)),
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
                        title: Text('${conflict['severity']} · ${conflict['code']}'),
                        subtitle: Text(conflict['message']?.toString() ?? ''),
                      );
                    }),
                  const SizedBox(height: 12),
                  Text('Plan items', style: Theme.of(context).textTheme.titleMedium),
                  if (items.isEmpty) const Text('No additional plan items.'),
                  for (final raw in items)
                    Builder(builder: (_) {
                      final item = raw as Map;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.task_alt_outlined),
                        title: Text(item['title']?.toString() ?? 'Plan item'),
                        subtitle: Text('${item['kind'] ?? 'TASK'}${item['due_at'] == null ? '' : ' · ${item['due_at']}'}'),
                      );
                    }),
                ],
              ),
            ),
          ),
        ),
        actions: [
          FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
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
      warnings > 0 ? 'Merge Branch with $warnings warning(s)' : 'Merge Branch',
      ['Merge note'],
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
      state == 'VERIFIED' ? 'Verify evidence' : 'Reject evidence',
      ['Review note'],
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
        const SnackBar(content: Text('Create another Case before linking them.')),
      );
      return;
    }
    var targetId = options.first['id'] as String;
    var relationType = 'RELATED_TO';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create Thread relation'),
          content: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: targetId,
                  decoration: const InputDecoration(labelText: 'Related Case'),
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
                  decoration: const InputDecoration(labelText: 'Relationship'),
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
                        child: Text(value.replaceAll('_', ' ')),
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
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Link'),
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
        title: const Text('Review conflict'),
        content: Text(
          'Server revision ${row['revision']}\nCurrent state: ${row['status']}\n\nYour queued actions are shown in Pending actions. Review the evidence and timeline before applying them to the latest server revision.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep draft'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Apply my queued actions'),
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
        title: const Text('TACTIX THREAD'),
        actions: [
          IconButton(
            tooltip: 'Synchronize',
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
                    'Execution Intelligence',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    store.api == null
                        ? 'LOCAL DEMO · saved on this device · verification requires server access'
                        : store.syncing
                        ? 'Synchronizing · ${store.pending.length} queued actions'
                        : '${store.pending.length} queued actions · ${all.length} cached cases',
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
                        'Active',
                        all.where((c) => c['status'] != 'CLOSED').length,
                      ),
                      _metric(
                        'No evidence',
                        all
                            .where(
                              (c) =>
                                  c['status'] != 'CLOSED' &&
                                  (c['evidence'] as List).isEmpty,
                            )
                            .length,
                      ),
                      _metric(
                        'Verification',
                        all
                            .where(
                              (c) => c['status'] == 'WAITING_FOR_VERIFICATION',
                            )
                            .length,
                      ),
                      _metric(
                        'Closed',
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
                        label: Text('Cases'),
                      ),
                      ButtonSegment<int>(
                        value: 1,
                        icon: Icon(Icons.hub_outlined),
                        label: Text('Graph'),
                      ),
                      ButtonSegment<int>(
                        value: 2,
                        icon: Icon(Icons.monitor_heart_outlined),
                        label: Text('PULSE'),
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
                          label: const Text('Cases'),
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
            'PULSE is available to staff roles. It summarizes administrative and training process health without changing Case data.',
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
            'PULSE requires a server connection. Cached Case work remains available offline.',
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
          label: const Text('Load PULSE'),
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
      ('Active cases', '${metrics['active_cases'] ?? 0}', Icons.work_outline),
      ('Overdue', '${metrics['overdue_cases'] ?? 0}', Icons.schedule_outlined),
      ('Due soon', '${metrics['due_soon_cases'] ?? 0}', Icons.event_outlined),
      ('Stale', '${metrics['stale_cases'] ?? 0}', Icons.hourglass_bottom),
      ('Verification', '${metrics['waiting_for_verification'] ?? 0}', Icons.fact_check_outlined),
      ('Unverified evidence', '${metrics['unverified_evidence'] ?? 0}', Icons.attach_file),
      ('Draft branches', '${metrics['draft_branches'] ?? 0}', Icons.fork_right_outlined),
      ('Training pending', '${metrics['training_pending'] ?? 0}', Icons.school_outlined),
      ('Created · 7d', '${metrics['created_last_7d'] ?? 0}', Icons.add_chart_outlined),
      ('Closed · 7d', '${metrics['closed_last_7d'] ?? 0}', Icons.task_alt_outlined),
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
                    Text('TACTIX PULSE', style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 4),
                    const Text(
                      'Deterministic process intelligence · no AI recommendations',
                      style: TextStyle(color: TactixTheme.textMuted),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Refresh PULSE',
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
          Text('Attention', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          if (alerts.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('No overdue, stale, or verification alerts in the current window.'),
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
                  title: Text(alert['title']?.toString() ?? 'Case'),
                  subtitle: Text(
                    '${(alert['code'] ?? '').toString().replaceAll('_', ' ')} · ${(alert['status'] ?? '').toString().replaceAll('_', ' ')} · ${alert['age_hours'] ?? 0}h since update',
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
          Text('Process bottlenecks', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          if (bottlenecks.isEmpty)
            const Text('No active process stages to summarize.', style: TextStyle(color: TactixTheme.textMuted))
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
                              (item['status'] ?? '').toString().replaceAll('_', ' '),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Text('${item['count'] ?? 0} cases'),
                            Text(
                              'Average age: ${item['avg_age_hours'] ?? 0}h · max ${item['max_age_hours'] ?? 0}h',
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
              Expanded(child: Text('Event Stream', style: Theme.of(context).textTheme.titleLarge)),
              Text('${stream.length} recent', style: const TextStyle(color: TactixTheme.textMuted)),
            ],
          ),
          const SizedBox(height: 10),
          if (stream.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('No recent THREAD, Branch, relation, or training events.'),
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
                  title: Text(event['title']?.toString() ?? event['type']?.toString() ?? 'Event'),
                  subtitle: Text(
                    "${event['kind'] ?? 'EVENT'} · ${(event['type'] ?? '').toString().replaceAll('_', ' ')}\n${event['created_at'] ?? ''}",
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
            'Generated ${pulse['generated_at'] ?? ''} · ${method['source'] ?? 'authoritative records'}',
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
        'See why work exists, what happened, and what proves completion.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 20, height: 1.5),
      ),
      SizedBox(height: 24),
      Text(
        'TRACE  /  VERIFY  /  IMPROVE',
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
              label: const Text('Create Case'),
            ),
            const SizedBox(height: 12),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Search cached cases',
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
                      '${row['status']} ${queued ? '· pending sync' : ''}',
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
                  label: Text(confidence),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SelectableText(
              response['answer']?.toString() ?? 'No answer returned.',
              style: const TextStyle(height: 1.55),
            ),
            const SizedBox(height: 14),
            Text(
              'Sources · ${sources.length}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            if (sources.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                  'No source was approved by the verification pass.',
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
                          Chip(label: Text(source['ref']?.toString() ?? 'SOURCE')),
                          Chip(label: Text(source['kind']?.toString() ?? 'SOURCE')),
                          if (source['verification_state'] != null)
                            Chip(label: Text(source['verification_state'].toString())),
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
                            'Reference: ${source['source']}',
                            style: const TextStyle(color: TactixTheme.textMuted, fontSize: 12),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            if (unsupported.isNotEmpty) ...[
              const SizedBox(height: 14),
              const Text('Removed / unsupported', style: TextStyle(color: TactixTheme.warning)),
              for (final item in unsupported)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('• $item'),
                ),
            ],
            if (gaps.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text('Open questions', style: Theme.of(context).textTheme.titleSmall),
              for (final item in gaps)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('• $item'),
                ),
            ],
            const SizedBox(height: 12),
            Text(
              'Case revision ${response['case_revision'] ?? '?'} · ${response['passes'] ?? 2} AI passes · ${response['evidence_policy'] ?? 'verified-first'}',
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
          'Case ${row['id']}\nOwner ${row['owner_id']}',
          style: const TextStyle(color: TactixTheme.textMuted, fontSize: 12),
        ),
        const SizedBox(height: 16),
        SelectableText(row['description'], style: const TextStyle(height: 1.6)),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Chip(label: Text(row['status'])),
            Chip(label: Text(row['priority'])),
            if (!closed || store.staff)
              PopupMenuButton<String>(
                enabled: !_busy,
                tooltip: 'Change status',
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
                child: const Chip(label: Text('Change status')),
              ),
            if (!closed)
              OutlinedButton.icon(
                onPressed: _busy ? null : () => _evidence(row),
                icon: const Icon(Icons.attach_file),
                label: const Text('Add evidence'),
              ),
            if (store.api != null)
              FilledButton.tonalIcon(
                onPressed: _busy || pending.isNotEmpty
                    ? null
                    : () => _askThread(row),
                icon: const Icon(Icons.auto_awesome),
                label: const Text('ASK THREAD'),
              ),
            if (!closed && store.staff && store.api != null)
              FilledButton.tonalIcon(
                onPressed: _busy || pending.isNotEmpty ? null : () => _createBranch(row),
                icon: const Icon(Icons.fork_right_outlined),
                label: const Text('Create Branch'),
              ),
            if (!closed && store.staff && store.api != null)
              FilledButton.tonalIcon(
                onPressed: _busy ? null : () => _trainingAction(row),
                icon: const Icon(Icons.school_outlined),
                label: const Text('Create training action'),
              ),
            OutlinedButton.icon(
              onPressed: _busy ? null : () => _linkCase(row),
              icon: const Icon(Icons.hub_outlined),
              label: const Text('Link Case'),
            ),
            OutlinedButton.icon(
              onPressed: _busy
                  ? null
                  : () {
                      setState(() => _viewMode = 1);
                      unawaited(store.loadRelations(row['id'] as String));
                    },
              icon: const Icon(Icons.account_tree_outlined),
              label: const Text('Open graph'),
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
                label: const Text('Verify & close'),
              ),
          ],
        ),
        if (closed)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: SelectableText(
              'Closure: ${row['closure_reason']}\n${row['closed_at']}',
            ),
          ),
        if (pending.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(
            'Pending actions',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const Text(
            'Saved locally. Verification and closure require server acceptance.',
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
                child: const Text('Review conflict / retry'),
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
                child: Text('TACTIX BRANCH', style: Theme.of(context).textTheme.titleLarge),
              ),
              if (store.api != null)
                IconButton(
                  tooltip: 'Refresh variants',
                  onPressed: _busy ? null : () => _perform(() => store.loadBranches(row['id'] as String)),
                  icon: const Icon(Icons.refresh),
                ),
              if (!closed && store.api != null)
                FilledButton.tonalIcon(
                  onPressed: _busy || pending.isNotEmpty ? null : () => _createBranch(row),
                  icon: const Icon(Icons.add),
                  label: const Text('New variant'),
                ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Create an alternative administrative/training plan without changing the live Case. Compare uses a deterministic three-way merge and highlights overlapping changes before anything is applied.',
            style: TextStyle(color: TactixTheme.textMuted, height: 1.5),
          ),
          if (pending.isNotEmpty && store.api != null)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Text(
                'Synchronize pending Case changes before branching or merging.',
                style: TextStyle(color: TactixTheme.warning),
              ),
            ),
          if (branches.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Text(
                store.api == null
                    ? 'Server connection is required to create or compare Branch variants.'
                    : 'No planning variants for this Case yet.',
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
                            branch['name']?.toString() ?? 'Planning variant',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        Chip(label: Text(branch['status']?.toString() ?? 'DRAFT')),
                      ],
                    ),
                    if ((branch['description']?.toString() ?? '').isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(branch['description'].toString()),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      'Forked from Case r${branch['base_case_revision']} · Branch r${branch['revision']}',
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
                            label: const Text('Edit'),
                          ),
                        if (store.api != null)
                          OutlinedButton.icon(
                            onPressed: _busy ? null : () => _compareBranch(branch),
                            icon: const Icon(Icons.compare_arrows_outlined),
                            label: const Text('Compare'),
                          ),
                        if (branch['status'] == 'DRAFT' && store.api != null)
                          FilledButton.icon(
                            onPressed: _busy || pending.isNotEmpty ? null : () => _mergeBranch(row, branch),
                            icon: const Icon(Icons.merge_type_outlined),
                            label: const Text('Merge'),
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
                'ASK THREAD',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            if (store.api != null)
              FilledButton.tonalIcon(
                onPressed: _busy || pending.isNotEmpty
                    ? null
                    : () => _askThread(row),
                icon: const Icon(Icons.question_answer_outlined),
                label: const Text('Ask'),
              ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'Two-pass, evidence-constrained analysis. The server builds the source pack and removes fabricated source references before the answer reaches this device.',
          style: TextStyle(color: TactixTheme.textMuted, height: 1.5),
        ),
        if (store.api == null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Text('Server connection is required for ASK THREAD. Cached answers remain available offline.'),
          ),
        if (pending.isNotEmpty && store.api != null)
          const Padding(
            padding: EdgeInsets.only(top: 10),
            child: Text(
              'Synchronize pending Case changes before asking so the AI sees the same evidence you see.',
              style: TextStyle(color: TactixTheme.warning),
            ),
          ),
        if (latestAsk != null) ...[
          const SizedBox(height: 14),
          _askResultCard(latestAsk),
        ] else
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Text('No ASK THREAD analysis cached for this Case yet.'),
          ),
        const SizedBox(height: 28),
        Row(
          children: [
            Expanded(
              child: Text(
                'Linked training',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            if (store.api != null)
              IconButton(
                tooltip: 'Refresh linked training',
                onPressed: _busy
                    ? null
                    : () => _perform(() => store.loadTraining(row['id'] as String)),
                icon: const Icon(Icons.refresh),
              ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'Simulation Lab assignments linked to this Case. A submitted result can be imported as evidence and then verified.',
          style: TextStyle(color: TactixTheme.textMuted, height: 1.5),
        ),
        if (training.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Text(
              store.api == null
                  ? 'Server connection is required to link Simulation Lab training.'
                  : 'No training action is linked to this Case yet.',
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
                          item['title']?.toString() ?? 'Simulation Lab training',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      Chip(
                        label: Text(
                          (item['status'] ?? 'assigned').toString().replaceAll('_', ' ').toUpperCase(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Assignment ${item['id']}${item['due_at'] == null ? '' : '\nDue: ${item['due_at']}'}',
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
                          label: const Text('Attach result as evidence'),
                        ),
                      if (item['evidence_attached'] == true)
                        const Chip(
                          avatar: Icon(Icons.verified_outlined, size: 17),
                          label: Text('Result attached'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 28),
        Text(
          'Evidence · ${row['verification_state']}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        const Text(
          'Completed does not mean verified. Inspect the supporting context before accepting evidence.',
          style: TextStyle(color: TactixTheme.textMuted, height: 1.5),
        ),
        if (evidence.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text('No evidence attached. Closure is unavailable.'),
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
                      child: SelectableText('Source: ${item['source']}'),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    item['verification_state'],
                    style: TextStyle(
                      color: item['verification_state'] == 'VERIFIED'
                          ? TactixTheme.positive
                          : TactixTheme.warning,
                    ),
                  ),
                  if (item['verified_by'] != null)
                    SelectableText(
                      'Reviewer: ${item['verified_by']}\n${item['verified_at']}\n${item['verification_note']}',
                    ),
                  if (store.staff && !closed && item['pending'] != true)
                    Wrap(
                      spacing: 8,
                      children: [
                        TextButton(
                          onPressed: _busy || pending.isNotEmpty
                              ? null
                              : () => _verify(row, item, 'VERIFIED'),
                          child: const Text('Accept evidence'),
                        ),
                        TextButton(
                          onPressed: _busy || pending.isNotEmpty
                              ? null
                              : () => _verify(row, item, 'REJECTED'),
                          child: const Text('Reject evidence'),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 28),
        Text('Thread relations', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 10),
        if (store.relationsForCase(row['id'] as String).isEmpty)
          const Text(
            'No explicit links yet. Link this Case to another Case to build the Digital Thread.',
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
              (relation['relationship_type'] as String).replaceAll('_', ' '),
            ),
            subtitle: SelectableText(
              '${relation['from_type']}:${relation['from_id']}\n→ ${relation['to_type']}:${relation['to_id']}',
            ),
          ),
        const SizedBox(height: 28),
        Text('Case timeline', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        if (events.isEmpty)
          const Text(
            'No confirmed events cached. Local actions appear above until synchronized.',
          ),
        for (final event in events.reversed)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.history, color: TactixTheme.cyan),
            title: Text(event['type'].toString().replaceAll('_', ' ')),
            subtitle: SelectableText(
              '${event['created_at']}\nActor: ${event['actor_id']}\n${(event['details'] as Map).entries.map((e) => '${e.key}: ${e.value}').join('\n')}',
            ),
          ),
        if (store.api != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: _busy
                  ? null
                  : () => _perform(() => store.loadEvents(row['id'])),
              child: const Text('Load next events / refresh'),
            ),
          ),
      ],
    );
  }
}
