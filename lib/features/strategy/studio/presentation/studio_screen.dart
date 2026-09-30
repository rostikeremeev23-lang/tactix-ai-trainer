import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../../../app/user_session_scope.dart';
import '../../../../models/app_user.dart';
import '../data/platform_sync.dart';
import 'platform_screen.dart';
import '../../../../screens/strategy/legacy_strategy_screen.dart';
import '../domain/scenario.dart';
import 'studio_controller.dart';
import 'terrain_view.dart';
import 'scenario_editor.dart';
import 'context_panel.dart';
import 'exercise_timeline.dart';
import 'exercise_report.dart';
import 'city_library.dart';
import 'archive_screen.dart';
import '../data/studio_store.dart';

class StrategyStudioScreen extends StatefulWidget {
  final String userId;
  final bool startInLibrary;
  final bool startInPlatform;
  final PlatformSync? platform;
  const StrategyStudioScreen({
    super.key,
    required this.userId,
    this.startInLibrary = false,
    this.startInPlatform = false,
    this.platform,
  });
  @override
  State<StrategyStudioScreen> createState() => _StrategyStudioScreenState();
}

class _StrategyStudioScreenState extends State<StrategyStudioScreen>
    with WidgetsBindingObserver {
  late final StudioController c = StudioController(widget.userId);
  final _scaffold = GlobalKey<ScaffoldState>();
  final _terrain = GlobalKey<TerrainViewState>();
  bool _labels = true, _routes = true, _zones = true, _wide = true;
  String? _lastInject;
  late bool _library = widget.startInLibrary;
  bool _switching = false;
  PlatformSync? _sync;
  PlatformApi? _api;
  bool _platformInitialized = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    c.addListener(_listen);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_platformInitialized) return;
    _platformInitialized = true;
    _sync = widget.platform;
    final session = context
        .dependOnInheritedWidgetOfExactType<UserSessionScope>()
        ?.notifier;
    final user = session?.currentUser;
    if (_sync == null && user?.id == widget.userId && user?.serverId != null) {
      _api = PlatformApi(session!, widget.userId);
      _sync = PlatformSync(
        widget.userId,
        _api!,
        staff:
            user!.serverRole == UserRole.instructor ||
            user.serverRole == UserRole.admin,
      );
    }
    _sync?.addListener(_platformChanged);
    unawaited(_restore());
  }

  void _platformChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _restore() async {
    await c.restore();
    final sync = _sync;
    if (!mounted || sync == null) return;
    try {
      await sync.restore(autoSync: false);
      if (!mounted || !sync.ready) return;
      c.onSaved = (document) =>
          sync.stage('current_${sync.deviceId}', document);
      c.onArchiveChanged = () async =>
          sync.captureArchive(await c.archive.load());
      final saved = await c.store.load();
      if (!mounted) return;
      if (saved != null) await c.onSaved!(saved);
      await c.onArchiveChanged!();
      if (mounted) {
        sync.start();
        if (widget.startInPlatform) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) unawaited(_platform());
          });
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Локальные данные сохранены. Не удалось подготовить синхронизацию.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _platform() async {
    final sync = _sync;
    if (sync == null || c.loading) return;
    c.pause();
    final document = await Navigator.push<StudioDocument>(
      context,
      MaterialPageRoute(
        builder: (_) => StrategyPlatformScreen(sync: sync, current: c.document),
      ),
    );
    if (!mounted || document == null || _switching) return;
    _switching = true;
    try {
      if (!await c.archiveCurrent() || !mounted) return;
      c.openDocument(document);
      setState(() => _library = false);
    } finally {
      _switching = false;
    }
  }

  void _listen() {
    if (!mounted) return;
    final pending = c.replay ? null : c.frame?.pending?.id;
    if (pending != null && pending != _lastInject && !_wide) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scaffold.currentState?.openEndDrawer();
      });
    }
    _lastInject = pending;
    if (c.message != null) {
      final text = c.message!;
      c.message = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(text)));
        }
      });
    }
    setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_sync?.sync());
    } else {
      c.pause();
      if (c.revision > 0) unawaited(c.save());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sync?.removeListener(_platformChanged);
    if (widget.platform == null) _sync?.dispose();
    _api?.dispose();
    c.removeListener(_listen);
    c.dispose();
    super.dispose();
  }

  Future<bool> _confirm(String title, String text) async {
    c.pause();
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(text),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Отмена'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Продолжить'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _closeDrawer() {
    if (_scaffold.currentState?.isDrawerOpen ?? false) {
      _scaffold.currentState?.closeDrawer();
    }
    if (_scaffold.currentState?.isEndDrawerOpen ?? false) {
      _scaffold.currentState?.closeEndDrawer();
    }
  }

  Widget _context() => ExerciseContextPanel(
    scenario: c.scenario,
    frame: c.frame,
    selected: c.selected,
    editing: c.editing,
    replay: c.replay,
    onMove: () {
      c.armMove();
      _closeDrawer();
    },
    onFocus: () {
      if (c.selected != null) {
        _terrain.currentState?.focus(c.selected!.position);
      }
      _closeDrawer();
    },
    onDelete: c.deleteSelected,
    onEdit: c.updateObject,
    onDecision: c.decide,
  );
  void _report() {
    if (c.engine == null) return;
    c.pause();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ExerciseReport(engine: c.engine!),
      ),
    );
  }

  Future<void> _archive() async {
    c.pause();
    final document = await Navigator.push<StudioDocument>(
      context,
      MaterialPageRoute(
        builder: (_) => StudioArchiveScreen(archive: c.archive),
      ),
    );
    if (mounted && _sync?.ready == true) {
      try {
        await c.onArchiveChanged?.call();
      } catch (_) {}
    }
    if (document == null || !mounted || _switching) return;
    _switching = true;
    try {
      if (!await c.archiveCurrent() || !mounted) return;
      c.openDocument(document);
      setState(() => _library = false);
    } finally {
      _switching = false;
    }
  }

  Future<void> _openCity(StudioScenario scenario) async {
    if (_switching) return;
    _switching = true;
    c.pause();
    try {
      if (!await c.archiveCurrent() || !mounted) return;
      c.openDocument(StudioDocument(scenario));
      setState(() => _library = false);
    } finally {
      _switching = false;
    }
  }

  Future<void> _newScenario() async {
    if (!await _confirm(
      'Создать сценарий?',
      'Текущее занятие будет сохранено в архив устройства перед созданием черновика.',
    )) {
      return;
    }
    if (!mounted) return;
    final scenario = await editScenario(context, StudioScenario.blank());
    if (!mounted) return;
    if (scenario == null) return;
    if (!await c.archiveCurrent() || !mounted) return;
    c.newScenario();
    c.configure(scenario);
    _scaffold.currentState?.openDrawer();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      _wide = constraints.maxWidth >= 1100;
      return PopScope(
        canPop: !c.running,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) c.pause();
        },
        child: Scaffold(
          key: _scaffold,
          backgroundColor: TactixTheme.bg,
          drawer: c.editing && !_library
              ? Drawer(
                  width: 340,
                  backgroundColor: TactixTheme.panel,
                  surfaceTintColor: Colors.transparent,
                  child: SafeArea(
                    child: ScenarioEditor(
                      scenario: c.scenario,
                      onChanged: c.configure,
                      onAdd: (kind) {
                        c.armAdd(kind);
                        _closeDrawer();
                      },
                      onSelect: (id) {
                        c.select(id);
                        _terrain.currentState?.focus(c.selected!.position);
                        _closeDrawer();
                      },
                    ),
                  ),
                )
              : null,
          endDrawer: _library
              ? null
              : Drawer(
                  width: 330,
                  backgroundColor: TactixTheme.panel,
                  surfaceTintColor: Colors.transparent,
                  child: SafeArea(child: _context()),
                ),
          appBar: AppBar(
            automaticallyImplyLeading: false,
            leading: IconButton(
              tooltip: 'Назад',
              icon: const Icon(Icons.arrow_back),
              onPressed: () async {
                c.pause();
                if (c.revision > 0) await c.save();
                if (context.mounted) Navigator.maybePop(context);
              },
            ),
            title: const Text(
              'SIMULATION LAB',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
            actions: [
              if (!_library)
                IconButton(
                  tooltip: 'Библиотека сценариев',
                  icon: const Icon(Icons.grid_view),
                  onPressed: () {
                    c.pause();
                    setState(() => _library = true);
                  },
                ),
              if (!_library && constraints.maxWidth >= 600)
                IconButton(
                  tooltip: 'Архив планов и результатов',
                  icon: const Icon(Icons.inventory_2_outlined),
                  onPressed: c.loading ? null : _archive,
                ),
              if (!_library)
                IconButton(
                  tooltip: 'Сохранить Strategy',
                  onPressed: c.loading ? null : c.save,
                  icon: const Icon(Icons.save_outlined),
                ),
              if (!_library)
                PopupMenuButton<String>(
                  tooltip: 'Слои карты',
                  icon: const Icon(Icons.layers_outlined),
                  onSelected: (v) => setState(() {
                    if (v == 'labels') _labels = !_labels;
                    if (v == 'routes') _routes = !_routes;
                    if (v == 'zones') _zones = !_zones;
                  }),
                  itemBuilder: (_) => [
                    CheckedPopupMenuItem(
                      value: 'labels',
                      checked: _labels,
                      child: const Text('Названия объектов'),
                    ),
                    CheckedPopupMenuItem(
                      value: 'routes',
                      checked: _routes,
                      child: const Text('Маршруты'),
                    ),
                    CheckedPopupMenuItem(
                      value: 'zones',
                      checked: _zones,
                      child: const Text('Зоны целей'),
                    ),
                  ],
                ),
              if (!_library)
                PopupMenuButton<String>(
                  tooltip: 'Сценарии',
                  enabled: !c.loading,
                  onSelected: (value) async {
                    if (value == 'archive') {
                      await _archive();
                      return;
                    }
                    if (value == 'archive-save') {
                      await c.archiveCurrent();
                      return;
                    }
                    if (value == 'new') {
                      await _newScenario();
                      return;
                    }
                    if (value == 'legacy') {
                      c.pause();
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              LegacyTactixStrategyScreen(userId: widget.userId),
                        ),
                      );
                      return;
                    }
                    if (await _confirm(
                      'Открыть другой сценарий?',
                      'Текущее занятие сначала сохранится в архив устройства.',
                    )) {
                      if (!mounted) return;
                      if (!await c.archiveCurrent() || !mounted) return;
                      c.newScenario(demo: value == 'demo');
                      _terrain.currentState?.fit();
                      _scaffold.currentState?.openDrawer();
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'archive',
                      child: Text('Мои планы и результаты'),
                    ),
                    const PopupMenuItem(
                      value: 'archive-save',
                      child: Text('Сохранить план / запись в архив'),
                    ),
                    const PopupMenuItem(
                      value: 'new',
                      child: Text('Создать сценарий'),
                    ),
                    const PopupMenuItem(
                      value: 'demo',
                      child: Text('Демонстрация «Северная»'),
                    ),
                    const PopupMenuItem(
                      value: 'legacy',
                      child: Text('Архив Strategy v1'),
                    ),
                  ],
                ),
            ],
          ),
          bottomNavigationBar: _sync == null
              ? null
              : SafeArea(
                  top: false,
                  child: ListTile(
                    dense: true,
                    leading: Icon(
                      _sync!.conflicts > 0
                          ? Icons.sync_problem
                          : Icons.cloud_outlined,
                    ),
                    title: Text(
                      _sync!.status,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      _sync!.staff
                          ? 'Центр инструктора · очередь: ${_sync!.pending}'
                          : 'Учебная платформа · очередь: ${_sync!.pending}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: c.loading ? null : _platform,
                  ),
                ),
          body: c.loading
              ? const Center(child: CircularProgressIndicator())
              : _library
              ? CityLibrary(
                  currentName: c.scenario.name,
                  onResume: () => setState(() => _library = false),
                  onArchive: _archive,
                  onOpen: _openCity,
                )
              : SafeArea(
                  child: Column(
                    children: [
                      _header(),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: TerrainView(
                                  key: _terrain,
                                  objects: c.objects,
                                  cityMap: c.scenario.cityMap,
                                  onDragObject: c.editing ? c.dragObject : null,
                                  frame: c.frame,
                                  selectedId: c.selectedId,
                                  selectedIds: c.selectedIds,
                                  instruction: c.instruction,
                                  labels: _labels,
                                  routes: _routes,
                                  zones: _zones,
                                  onMapTap: c.tapMap,
                                  onSelect: (id) {
                                    c.select(id);
                                    if (!_wide) {
                                      _scaffold.currentState?.openEndDrawer();
                                    }
                                  },
                                ),
                              ),
                              if (_wide) ...[
                                const SizedBox(width: 10),
                                SizedBox(
                                  width: 320,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: TactixTheme.panel,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: _context(),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      ExerciseTimeline(
                        tick: c.frame?.tick ?? 0,
                        duration: c.scenario.duration,
                        speed: c.speed,
                        index: c.replayIndex ?? 0,
                        count: c.engine?.frames.length ?? 0,
                        running: c.running,
                        editing: c.editing,
                        completed: c.engine?.completed ?? false,
                        replay: c.replay,
                        awaitingDecision: c.frame?.pending != null,
                        injects: c.scenario.injects,
                        onPlay: c.play,
                        onStep: c.step,
                        onSpeed: c.setSpeed,
                        onSeek: c.seek,
                        onReset: () async {
                          if (await _confirm(
                            'Повторить занятие?',
                            'Запись сохранится в архив устройства. '
                                'Исходная обстановка откроется для новой попытки.',
                          )) {
                            if (await c.archiveCurrent() && mounted) c.reset();
                          }
                        },
                        onReplay: c.toggleReplay,
                        onReport: _report,
                      ),
                    ],
                  ),
                ),
        ),
      );
    },
  );

  Future<void> _nameGroup() async {
    final selected = c.objects.where((o) => c.selectedIds.contains(o.id)).toList();
    if (selected.isEmpty) return;
    final existing = selected.map((o) => o.group).where((g) => g.isNotEmpty).toSet();
    final controller = TextEditingController(text: existing.length == 1 ? existing.first : '');
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('\u0413\u0440\u0443\u043f\u043f\u0430 \u0436\u0435\u0442\u043e\u043d\u043e\u0432'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 30,
          decoration: const InputDecoration(labelText: '\u041d\u0430\u0437\u0432\u0430\u043d\u0438\u0435 \u0433\u0440\u0443\u043f\u043f\u044b'),
          onSubmitted: (value) => Navigator.pop(dialogContext, value.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('\u041e\u0442\u043c\u0435\u043d\u0430')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, controller.text.trim()), child: const Text('\u041e\u0442\u043c\u0435\u043d\u0430???')),
        ],
      ),
    );
    controller.dispose();
    if (name != null && name.trim().isNotEmpty) c.groupSelected(name.trim());
  }

  Widget _header() => Padding(
    padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
    child: Row(
      children: [
        if (c.editing)
          IconButton(
            tooltip: 'Конструктор сценария',
            icon: const Icon(Icons.add_box_outlined),
            onPressed: () => _scaffold.currentState?.openDrawer(),
          ),
        if (c.editing) ...[
          IconButton(tooltip: c.multiSelect ? '\u0417\u0430\u0432\u0435\u0440\u0448\u0438\u0442\u044c \u0432\u044b\u0431\u043e\u0440' : '\u0412\u044b\u0431\u0440\u0430\u0442\u044c \u043d\u0435\u0441\u043a\u043e\u043b\u044c\u043a\u043e', isSelected: c.multiSelect, onPressed: c.toggleMultiSelect, icon: Icon(c.multiSelect ? Icons.checklist : Icons.library_add_check_outlined)),
          if (c.multiSelect && c.selectedIds.isNotEmpty) IconButton(tooltip: '\u0421\u043e\u0437\u0434\u0430\u0442\u044c \u0433\u0440\u0443\u043f\u043f\u0443', onPressed: _nameGroup, icon: const Icon(Icons.groups_2_outlined)),
          if (c.multiSelect) PopupMenuButton<String>(tooltip: '\u0412\u044b\u0431\u0440\u0430\u0442\u044c \u0433\u0440\u0443\u043f\u043f\u0443', icon: const Icon(Icons.group_work_outlined), onSelected: c.selectGroup, itemBuilder: (_) => c.objects.map((o) => o.group).where((g) => g.isNotEmpty).toSet().map((name) => PopupMenuItem(value: name, child: Text(name))).toList()),

          IconButton(
            tooltip: 'Отменить изменение',
            onPressed: c.canUndo ? c.undo : null,
            icon: const Icon(Icons.undo),
          ),
          IconButton(
            tooltip: 'Повторить изменение',
            onPressed: c.canRedo ? c.redo : null,
            icon: const Icon(Icons.redo),
          ),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                c.scenario.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                c.saveStatus,
                style: const TextStyle(
                  color: TactixTheme.textMuted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        if (MediaQuery.sizeOf(context).width >= 800)
          TextButton.icon(
            onPressed: c.loading ? null : _newScenario,
            icon: const Icon(Icons.add),
            label: const Text('Создать'),
          ),
        if (c.instruction != null)
          IconButton(
            tooltip: 'Отменить размещение',
            onPressed: c.cancelTool,
            icon: const Icon(Icons.close, color: TactixTheme.gold),
          ),
        PopupMenuButton<String>(
          tooltip: 'Выбрать объект',
          icon: const Icon(Icons.list_alt),
          onSelected: (id) {
            c.select(id);
            _terrain.currentState?.focus(c.selected!.position);
            if (!_wide) _scaffold.currentState?.openEndDrawer();
          },
          itemBuilder: (_) => c.objects
              .map(
                (o) => PopupMenuItem(
                  value: o.id,
                  child: Row(
                    children: [
                      Icon(
                        objectIcon(o.kind),
                        size: 18,
                        color: objectColor(o.kind),
                      ),
                      const SizedBox(width: 8),
                      Flexible(child: Text(o.name)),
                    ],
                  ),
                ),
              )
              .toList(),
        ),
        if (!_wide)
          IconButton(
            tooltip: 'Объект и журнал',
            icon: const Icon(Icons.view_sidebar_outlined),
            onPressed: () => _scaffold.currentState?.openEndDrawer(),
          ),
      ],
    ),
  );
}
