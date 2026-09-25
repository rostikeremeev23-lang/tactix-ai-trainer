import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../features/strategy/domain/strategy_state.dart';
import '../../features/strategy/domain/strategy_session.dart';
import '../../features/strategy/domain/strategy_report.dart';
import '../../features/strategy/data/strategy_repository.dart';
import '../../features/strategy/presentation/strategy_editor.dart';
import '../../features/strategy/presentation/strategy_replay_controls.dart';

import '../../app/theme.dart';

class TactixStrategyScreen extends StatefulWidget {
  final String userId;
  const TactixStrategyScreen({super.key, required this.userId});

  @override
  State<TactixStrategyScreen> createState() => _TactixStrategyScreenState();
}

class _TactixStrategyScreenState extends State<TactixStrategyScreen> {
  int _stage = 0;
  StrategySession _session = StrategySession();
  late final _repository = StrategyRepository(widget.userId);
  String? _selectedUnitId;
  int? _replayIndex;
  bool _busy = false;
  StrategyState get _state =>
      _replayIndex == null ? _session.current : _session.history[_replayIndex!];
  int get _turn => _state.turn;
  int get control => _state.control;
  int get resources => _state.resources;
  int get stability => _state.stability;
  int get intel => _state.intel;
  int get time => _state.time;
  List<StrategyUnit> get _units => _state.units;
  List<String> get _log => _state.log;

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      await _repository.save(_session);
      _message('Strategy сохранена локально для текущего профиля.');
    } catch (_) {
      _message('Не удалось сохранить Strategy. Повторите попытку.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _load() async {
    setState(() => _busy = true);
    try {
      final loaded = await _repository.load();
      if (!mounted) return;
      if (loaded == null) {
        _message('Сохранение Strategy для этого профиля не найдено.');
        return;
      }
      final accepted = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Загрузить Strategy?'),
          content: const Text(
            'Текущие несохранённые изменения будут заменены сохранением.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Загрузить'),
            ),
          ],
        ),
      );
      if (!mounted || accepted != true) return;
      setState(() {
        _session = loaded;
        _replayIndex = null;
        _selectedUnitId = null;
        _stage = loaded.current.completed
            ? 3
            : loaded.started
            ? 2
            : 1;
      });
      _message(_repository.recoveryMessage ?? 'Strategy загружена.');
    } catch (_) {
      _message(
        'Сохранение повреждено или недоступно. Текущее состояние сохранено на экране.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _openReplay() => setState(() {
    _replayIndex = 0;
    _selectedUnitId = null;
    _stage = 2;
  });

  Future<void> _copyReport() async {
    try {
      await Clipboard.setData(
        ClipboardData(text: StrategyReport(_session.current).text),
      );
      _message('Отчёт скопирован.');
    } catch (_) {
      _message('Буфер обмена недоступен. Отчёт остаётся на экране.');
    }
  }

  static const _sectors = [
    _Sector('Северный сектор', Offset(0.23, 0.22)),
    _Sector('Центральный сектор', Offset(0.48, 0.32)),
    _Sector('Восточный сектор', Offset(0.73, 0.25)),
    _Sector('Точка A', Offset(0.26, 0.62)),
    _Sector('Точка B', Offset(0.52, 0.66)),
    _Sector('Точка C', Offset(0.77, 0.61)),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TactixTheme.bg,
      appBar: AppBar(
        actions: [
          IconButton(
            tooltip: 'Сохранить Strategy',
            onPressed: _busy ? null : _save,
            icon: const Icon(Icons.save_outlined),
          ),
          IconButton(
            tooltip: 'Загрузить Strategy',
            onPressed: _busy ? null : _load,
            icon: const Icon(Icons.folder_open),
          ),
        ],
        backgroundColor: const Color(0xFF081118),
        foregroundColor: Colors.white,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'TACTIX STRATEGY',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2),
            ),
            Text(
              'ASTANA DEMO',
              style: TextStyle(
                fontSize: 11,
                color: TactixTheme.cyan,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
      body: AbsorbPointer(
        absorbing: _busy,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          child: switch (_stage) {
            0 => _kazakhstanMap(),
            1 => _briefing(),
            2 => _battlefield(),
            _ => _result(),
          },
        ),
      ),
    );
  }

  Widget _kazakhstanMap() {
    return LayoutBuilder(
      key: const ValueKey('kz'),
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _eyebrow('СТРАТЕГИЧЕСКАЯ КАРТА'),
                  const SizedBox(height: 8),
                  const Text(
                    'Казахстан',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Выберите доступную учебную операцию.',
                    style: TextStyle(
                      color: TactixTheme.textMuted,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    height: compact ? 420 : 560,
                    decoration: _panelDecoration(),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: CustomPaint(painter: _KazakhstanPainter()),
                        ),
                        Positioned(
                          left: compact ? 70 : 520,
                          top: compact ? 120 : 155,
                          child: _MapCityMarker(
                            title: 'АСТАНА',
                            subtitle: 'ОПЕРАЦИЯ «ЩИТ СТОЛИЦЫ»',
                            active: true,
                            onTap: () => setState(() => _stage = 1),
                          ),
                        ),
                        Positioned(
                          left: compact ? 42 : 150,
                          bottom: compact ? 55 : 80,
                          child: const _MapCityMarker(
                            title: 'АЛМАТЫ',
                            subtitle: 'СКОРО',
                            active: false,
                          ),
                        ),
                        Positioned(
                          right: compact ? 24 : 125,
                          bottom: compact ? 90 : 115,
                          child: const _MapCityMarker(
                            title: 'ШЫМКЕНТ',
                            subtitle: 'СКОРО',
                            active: false,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Стилизованная учебная подложка. Спутниковые материалы не подключены. Сектора, объекты и маршруты вымышлены.',
                    style: TextStyle(
                      color: TactixTheme.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _briefing() {
    return SingleChildScrollView(
      key: const ValueKey('briefing'),
      padding: const EdgeInsets.all(18),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _eyebrow('МИССИЯ 01 • АСТАНА'),
              const SizedBox(height: 8),
              const Text(
                'Операция «Щит столицы»',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 16),
              _panel(
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ВВОДНАЯ',
                      style: TextStyle(
                        color: TactixTheme.cyan,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'В условном городском секторе нарушена координация. Необходимо сохранить управление, обеспечить безопасность гражданских и удержать три игровые контрольные точки до завершения учений.',
                      style: TextStyle(
                        color: Colors.white,
                        height: 1.5,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: const [
                  _BriefChip(
                    icon: Icons.timer_outlined,
                    title: '8 ХОДОВ',
                    value: 'Пошаговый режим',
                  ),
                  _BriefChip(
                    icon: Icons.groups_2_outlined,
                    title: '5 ГРУПП',
                    value: '2 единицы техники',
                  ),
                  _BriefChip(
                    icon: Icons.flag_outlined,
                    title: '3 ТОЧКИ',
                    value: 'A • B • C',
                  ),
                  _BriefChip(
                    icon: Icons.psychology_alt_outlined,
                    title: 'TACTIX SCORE',
                    value: 'Итоговая оценка',
                  ),
                ],
              ),
              const SizedBox(height: 22),
              StrategyEditor(
                session: _session,
                onChanged: () => setState(() {}),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: TactixTheme.gold,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                  ),
                  onPressed: () => setState(() {
                    _session.start();
                    _stage = 2;
                  }),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text(
                    'НАЧАТЬ МИССИЮ',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _battlefield() {
    return LayoutBuilder(
      key: const ValueKey('battle'),
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 980;
        final map = _battleMap();
        final sidebar = _battleSidebar();
        return Padding(
          padding: const EdgeInsets.all(12),
          child: wide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 7, child: map),
                    const SizedBox(width: 12),
                    SizedBox(width: 340, child: sidebar),
                  ],
                )
              : Column(
                  children: [
                    Expanded(flex: 7, child: map),
                    const SizedBox(height: 10),
                    Expanded(flex: 5, child: sidebar),
                  ],
                ),
        );
      },
    );
  }

  Widget _battleMap() {
    return Container(
      decoration: _panelDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            color: const Color(0xFF0C171F),
            child: Wrap(
              spacing: 12,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'ХОД $_turn / 8',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                _miniMetric('CTRL', control),
                _miniMetric('RES', resources),
                _miniMetric('STB', stability),
              ],
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(painter: _AstanaBattlePainter()),
                    ),
                    ...List.generate(_sectors.length, (index) {
                      final s = _sectors[index];
                      final left = s.pos.dx * constraints.maxWidth;
                      final top = s.pos.dy * constraints.maxHeight;
                      return Positioned(
                        left: left - 44,
                        top: top - 30,
                        child: _SectorNode(
                          label: s.name,
                          selected:
                              _selectedUnitId != null && _replayIndex == null,
                          onTap: () => _moveSelectedTo(index),
                        ),
                      );
                    }),
                    ..._units.map((u) {
                      final s = _sectors[u.sector];
                      final sameSector = _units
                          .where((x) => x.sector == u.sector)
                          .toList();
                      final idx = sameSector.indexWhere((x) => x.id == u.id);
                      final offset = Offset(
                        (idx % 3) * 24.0 - 20,
                        40 + (idx ~/ 3) * 24.0,
                      );
                      final left = s.pos.dx * constraints.maxWidth + offset.dx;
                      final top = s.pos.dy * constraints.maxHeight + offset.dy;
                      return Positioned(
                        left: left,
                        top: top,
                        child: _UnitToken(
                          unit: u,
                          selected: _selectedUnitId == u.id,
                          onTap: () {
                            if (_replayIndex == null) {
                              setState(() => _selectedUnitId = u.id);
                            }
                          },
                        ),
                      );
                    }),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _battleSidebar() {
    final selected = _selectedUnitId == null
        ? null
        : _units.firstWhere((u) => u.id == _selectedUnitId);
    return Container(
      decoration: _panelDecoration(),
      padding: const EdgeInsets.all(14),
      child: ListView(
        children: [
          const Text(
            'Стилизованная учебная подложка. Спутниковые материалы не подключены.',
            style: TextStyle(color: TactixTheme.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 10),
          if (_replayIndex != null)
            StrategyReplayControls(
              count: _session.history.length,
              index: _replayIndex!,
              onChanged: (index) => setState(() => _replayIndex = index),
              onClose: () => setState(() {
                _replayIndex = null;
                if (_session.current.completed) _stage = 3;
              }),
            )
          else
            TextButton.icon(
              onPressed: _openReplay,
              icon: const Icon(Icons.history),
              label: const Text('Воспроизвести историю'),
            ),
          _eyebrow(_replayIndex == null ? 'КОМАНДОВАНИЕ' : 'ПРОСМОТР ИСТОРИИ'),
          const SizedBox(height: 10),
          if (selected == null)
            const Text(
              'Выберите подразделение на карте.',
              style: TextStyle(color: Colors.white70),
            )
          else ...[
            Text(
              selected.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${selected.type} • ${_sectors[selected.sector].name}',
              style: const TextStyle(color: TactixTheme.textMuted),
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: selected.strength / 100,
              minHeight: 7,
              borderRadius: BorderRadius.circular(99),
            ),
            const SizedBox(height: 7),
            Text(
              'Состояние ${selected.strength}%',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 14),
            const Text(
              'Нажмите на сектор на карте, чтобы переместить выбранную группу.',
              style: TextStyle(color: Colors.white70, height: 1.4),
            ),
          ],
          const SizedBox(height: 18),
          const Divider(color: Colors.white12),
          const SizedBox(height: 10),
          _statRow('Контроль', control),
          _statRow('Ресурсы', resources),
          _statRow('Устойчивость', stability),
          _statRow('Информация', intel),
          _statRow('Время', time),
          const SizedBox(height: 16),
          const Text(
            'ЖУРНАЛ СОБЫТИЙ',
            style: TextStyle(
              color: TactixTheme.cyan,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          ..._log.reversed
              .take(4)
              .map(
                (e) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    e,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ),
              ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _replayIndex != null || _busy ? null : _nextTurn,
            style: FilledButton.styleFrom(
              backgroundColor: TactixTheme.gold,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 15),
            ),
            icon: const Icon(Icons.skip_next_rounded),
            label: Text(
              _turn >= 8 ? 'ЗАВЕРШИТЬ МИССИЮ' : 'ЗАВЕРШИТЬ ХОД',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }

  void _moveSelectedTo(int sector) {
    if (_selectedUnitId == null || _replayIndex != null || _busy) return;
    final moved = _session.move(_selectedUnitId!, sector);
    if (!moved) _message('Перемещение недоступно: проверьте сектор и ресурсы.');
    setState(() {});
  }

  void _nextTurn() {
    if (_replayIndex != null || _busy) return;
    setState(() {
      _session.nextTurn();
      _selectedUnitId = null;
      if (_session.current.completed) _stage = 3;
    });
  }

  Widget _result() {
    final report = StrategyReport(_session.current);
    final held = report.held;
    final objective = report.objective;
    final civil = report.civil;
    final force = report.force;
    final coordination = report.coordination;
    final resource = report.resource;
    final total = report.total;

    return SingleChildScrollView(
      key: const ValueKey('result'),
      padding: const EdgeInsets.all(18),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _eyebrow('МИССИЯ ЗАВЕРШЕНА'),
              const SizedBox(height: 8),
              const Text(
                'After Action Review',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 18),
              _panel(
                child: Row(
                  children: [
                    Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: TactixTheme.gold, width: 7),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '$total',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'TACTIX STRATEGY SCORE',
                            style: TextStyle(
                              color: TactixTheme.gold,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Контрольных точек удержано: $held / 3',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Остаток ресурсов: $resources%',
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _scoreLine('Выполнение задач', objective, 30),
              _scoreLine('Безопасность гражданских', civil, 25),
              _scoreLine('Сохранение подразделений', force, 15),
              _scoreLine('Связь и координация', coordination, 15),
              _scoreLine('Использование ресурсов', resource, 15),
              const SizedBox(height: 18),
              const Text(
                'Учебная оценка по правилам модели. AI-анализ не подключён.',
                style: TextStyle(color: Colors.white70),
              ),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _openReplay,
                    icon: const Icon(Icons.history),
                    label: const Text('Воспроизвести историю'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _copyReport,
                    icon: const Icon(Icons.copy),
                    label: const Text('Копировать отчёт'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ..._log.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    entry,
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => setState(() {
                    _stage = 0;
                    _session = StrategySession();
                    _replayIndex = null;
                    _selectedUnitId = null;
                  }),
                  icon: const Icon(Icons.replay_rounded),
                  label: const Text('ВЕРНУТЬСЯ НА КАРТУ КАЗАХСТАНА'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _scoreLine(String title, int score, int max) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Container(
      decoration: _panelDecoration(),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: const TextStyle(color: Colors.white)),
          ),
          Text(
            '$score / $max',
            style: const TextStyle(
              color: TactixTheme.gold,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _panel({required Widget child}) => Container(
    decoration: _panelDecoration(),
    padding: const EdgeInsets.all(16),
    child: child,
  );

  BoxDecoration _panelDecoration() => BoxDecoration(
    color: TactixTheme.panel,
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: TactixTheme.line),
  );

  Widget _eyebrow(String text) => Text(
    text,
    style: const TextStyle(
      color: TactixTheme.cyan,
      fontSize: 11,
      fontWeight: FontWeight.w900,
      letterSpacing: 1.1,
    ),
  );

  Widget _miniMetric(String label, int value) => Text(
    '$label $value',
    style: const TextStyle(
      color: Colors.white70,
      fontSize: 11,
      fontWeight: FontWeight.w800,
    ),
  );

  Widget _statRow(String title, int value) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        Expanded(
          child: Text(title, style: const TextStyle(color: Colors.white70)),
        ),
        Text(
          '$value%',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    ),
  );
}

class _Sector {
  final String name;
  final Offset pos;
  const _Sector(this.name, this.pos);
}

class _MapCityMarker extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool active;
  final VoidCallback? onTap;

  const _MapCityMarker({
    required this.title,
    required this.subtitle,
    required this.active,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: active ? onTap : null,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF102630) : const Color(0xFF111820),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: active ? TactixTheme.cyan : Colors.white12),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: TactixTheme.cyan.withValues(alpha: 0.18),
                    blurRadius: 24,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              active ? Icons.location_on_rounded : Icons.lock_outline_rounded,
              color: active ? TactixTheme.cyan : Colors.white38,
            ),
            const SizedBox(width: 7),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: active ? Colors.white : Colors.white54,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: active ? TactixTheme.textMuted : Colors.white24,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BriefChip extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  const _BriefChip({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: TactixTheme.panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: TactixTheme.line),
      ),
      child: Row(
        children: [
          Icon(icon, color: TactixTheme.cyan),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    color: TactixTheme.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectorNode extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _SectorNode({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 88,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xD915252E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? TactixTheme.gold : Colors.white24,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _UnitToken extends StatelessWidget {
  final StrategyUnit unit;
  final bool selected;
  final VoidCallback onTap;
  const _UnitToken({
    required this.unit,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: selected ? TactixTheme.gold : const Color(0xFF1D98B5),
          border: Border.all(color: Colors.white, width: selected ? 2.5 : 1),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: TactixTheme.gold.withValues(alpha: 0.35),
                    blurRadius: 14,
                  ),
                ]
              : null,
        ),
        child: Icon(
          unit.type == 'Техника'
              ? Icons.directions_car_filled_rounded
              : Icons.person_rounded,
          size: 17,
          color: selected ? Colors.black : Colors.white,
        ),
      ),
    );
  }
}

class _KazakhstanPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = const Color(0xFF09141B);
    canvas.drawRect(Offset.zero & size, bg);

    final grid = Paint()
      ..color = const Color(0xFF17313B)
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 48) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (double y = 0; y < size.height; y += 48) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    final path = Path()
      ..moveTo(size.width * .10, size.height * .48)
      ..lineTo(size.width * .18, size.height * .30)
      ..lineTo(size.width * .34, size.height * .22)
      ..lineTo(size.width * .47, size.height * .29)
      ..lineTo(size.width * .58, size.height * .20)
      ..lineTo(size.width * .74, size.height * .25)
      ..lineTo(size.width * .88, size.height * .40)
      ..lineTo(size.width * .82, size.height * .55)
      ..lineTo(size.width * .70, size.height * .61)
      ..lineTo(size.width * .62, size.height * .75)
      ..lineTo(size.width * .44, size.height * .70)
      ..lineTo(size.width * .33, size.height * .78)
      ..lineTo(size.width * .18, size.height * .68)
      ..close();

    canvas.drawPath(path, Paint()..color = const Color(0xFF102730));
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = TactixTheme.cyan.withValues(alpha: .65),
    );

    final glow = Paint()..color = TactixTheme.cyan.withValues(alpha: .06);
    canvas.drawCircle(
      Offset(size.width * .58, size.height * .34),
      math.min(size.width, size.height) * .22,
      glow,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _AstanaBattlePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF0A171D),
    );

    final blockPaint = Paint()..color = const Color(0xFF15252D);
    final road = Paint()
      ..color = const Color(0xFF33434A)
      ..strokeWidth = 15
      ..strokeCap = StrokeCap.round;
    final roadLine = Paint()
      ..color = Colors.white.withValues(alpha: .08)
      ..strokeWidth = 1.5;
    final river = Paint()
      ..color = const Color(0xFF0C4A5A)
      ..strokeWidth = 38
      ..strokeCap = StrokeCap.round;

    for (int r = 0; r < 5; r++) {
      for (int c = 0; c < 7; c++) {
        final rect = Rect.fromLTWH(
          35 + c * (size.width / 7.5),
          35 + r * (size.height / 5.8),
          60,
          42,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(6)),
          blockPaint,
        );
      }
    }

    final riverPath = Path()
      ..moveTo(-20, size.height * .72)
      ..quadraticBezierTo(
        size.width * .35,
        size.height * .48,
        size.width * .55,
        size.height * .58,
      )
      ..quadraticBezierTo(
        size.width * .78,
        size.height * .68,
        size.width + 20,
        size.height * .44,
      );
    canvas.drawPath(riverPath, river);

    canvas.drawLine(
      Offset(size.width * .1, size.height * .18),
      Offset(size.width * .9, size.height * .72),
      road,
    );
    canvas.drawLine(
      Offset(size.width * .18, size.height * .82),
      Offset(size.width * .83, size.height * .14),
      road,
    );
    canvas.drawLine(
      Offset(size.width * .05, size.height * .47),
      Offset(size.width * .95, size.height * .47),
      road,
    );

    canvas.drawLine(
      Offset(size.width * .1, size.height * .18),
      Offset(size.width * .9, size.height * .72),
      roadLine,
    );
    canvas.drawLine(
      Offset(size.width * .18, size.height * .82),
      Offset(size.width * .83, size.height * .14),
      roadLine,
    );
    canvas.drawLine(
      Offset(size.width * .05, size.height * .47),
      Offset(size.width * .95, size.height * .47),
      roadLine,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
