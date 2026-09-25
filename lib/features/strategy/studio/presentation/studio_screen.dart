import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../../../screens/strategy/legacy_strategy_screen.dart';
import '../domain/scenario.dart';
import 'studio_controller.dart';
import 'terrain_view.dart';
import 'scenario_editor.dart';
import 'context_panel.dart';
import 'exercise_timeline.dart';
import 'exercise_report.dart';

class StrategyStudioScreen extends StatefulWidget {
  final String userId;
  const StrategyStudioScreen({super.key, required this.userId});
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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    c.addListener(_listen);
    unawaited(c.restore());
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
    if (state != AppLifecycleState.resumed) {
      c.pause();
      if (c.revision > 0) unawaited(c.save());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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

  Future<void> _newScenario() async {
    if (!await _confirm(
      'Создать сценарий?',
      'Текущее автосохранение будет заменено новым черновиком. Скопируйте нужный отчёт перед продолжением.',
    )) {
      return;
    }
    if (!mounted) return;
    final scenario = await editScenario(context, StudioScenario.blank());
    if (!mounted) return;
    if (scenario == null) return;
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
          drawer: c.editing
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
          endDrawer: Drawer(
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
              'TACTIX / STRATEGY',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
            actions: [
              IconButton(
                tooltip: 'Сохранить Strategy',
                onPressed: c.loading ? null : c.save,
                icon: const Icon(Icons.save_outlined),
              ),
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
              PopupMenuButton<String>(
                tooltip: 'Сценарии',
                enabled: !c.loading,
                onSelected: (value) async {
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
                    'Текущее занятие в автосохранении будет заменено. Для сохранения итогов скопируйте отчёт.',
                  )) {
                    if (!mounted) return;
                    c.newScenario(demo: value == 'demo');
                    _terrain.currentState?.fit();
                    _scaffold.currentState?.openDrawer();
                  }
                },
                itemBuilder: (_) => [
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
          body: c.loading
              ? const Center(child: CircularProgressIndicator())
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
                                  frame: c.frame,
                                  selectedId: c.selectedId,
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
                            'Запись текущего прохождения будет заменена. '
                                'Исходная обстановка сохранится для новой попытки.',
                          )) {
                            c.reset();
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
