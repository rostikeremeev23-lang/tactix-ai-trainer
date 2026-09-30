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
  bool _graphMode = false;
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
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment<bool>(
                        value: false,
                        icon: Icon(Icons.view_list_outlined),
                        label: Text('Cases'),
                      ),
                      ButtonSegment<bool>(
                        value: true,
                        icon: Icon(Icons.hub_outlined),
                        label: Text('Graph'),
                      ),
                    ],
                    selected: {_graphMode},
                    onSelectionChanged: (value) =>
                        setState(() => _graphMode = value.first),
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
                  if (_graphMode) {
                    return ThreadGraphView(
                      store: store,
                      selectedCaseId: _selected,
                      onOpenCase: (id) {
                        setState(() {
                          _selected = id;
                          _graphMode = false;
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

  Widget _detail(Map<String, dynamic> row) {
    final evidence = row['evidence'] as List;
    final events = store.events(row['id']);
    final training = store.trainingForCase(row['id'] as String);
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
                      setState(() => _graphMode = true);
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
