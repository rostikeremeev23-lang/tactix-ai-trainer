import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../models/scenario.dart';
import '../../models/training_result.dart';
import '../../services/ai_service.dart';
import '../../services/result_storage_service.dart';
import '../ai/ai_chat_screen.dart';
import '../analytics/statistics_screen.dart';
import '../settings/ai_mode_screen.dart';
import '../training/scenario_run_screen.dart';
import 'competition_demo_screen.dart';

class TactixCommandCenterScreen extends StatefulWidget {
  final TrainingScenario demoScenario;

  const TactixCommandCenterScreen({
    super.key,
    required this.demoScenario,
  });

  @override
  State<TactixCommandCenterScreen> createState() =>
      _TactixCommandCenterScreenState();
}

class _TactixCommandCenterScreenState
    extends State<TactixCommandCenterScreen> {
  List<TrainingResult> _results = const [];
  bool _loading = true;
  bool _aiAvailable = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() => _loading = true);
    }

    try {
      final results = await ResultStorageService.load();
      if (!mounted) return;
      setState(() {
        _results = results;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _results = const [];
        _loading = false;
      });
    }

    unawaited(_refreshAiStatus());
  }

  Future<void> _refreshAiStatus() async {
    final aiAvailable = await AIService.isServerAvailable();
    if (!mounted) return;
    setState(() => _aiAvailable = aiAvailable);
  }

  TrainingResult? get _latest => _results.isEmpty ? null : _results.first;

  int get _average {
    if (_results.isEmpty) return 0;
    final total = _results.fold<int>(0, (sum, item) => sum + item.score);
    return (total / _results.length).round().clamp(0, 100);
  }

  int get _best {
    if (_results.isEmpty) return 0;
    return _results.map((item) => item.score).reduce((a, b) => a > b ? a : b);
  }

  int _metricAverage(int Function(TrainingResult item) pick) {
    final values = _results.map(pick).where((value) => value > 0).toList();
    if (values.isEmpty) return 0;
    final total = values.fold<int>(0, (sum, item) => sum + item);
    return (total / values.length).round().clamp(0, 100);
  }

  Map<String, int> get _decisionDna => {
        'Цель': _metricAverage((item) => item.goalScore),
        'Ресурсы': _metricAverage((item) => item.resourceScore),
        'Устойчивость': _metricAverage((item) => item.stabilityScore),
        'Неопределённость': _metricAverage((item) => item.uncertaintyScore),
        'Время': _metricAverage((item) => item.timeScore),
      };

  Future<void> _open(Widget page) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => page),
    );
    await _load();
  }

  Future<void> _startDemo() async {
    await _open(
      CompetitionDemoScreen(
        scenario: widget.demoScenario,
        runScreenBuilder: (scenario) => ScenarioRunScreen(
          scenario: scenario,
          forceOffline: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TactixTheme.bg,
      appBar: AppBar(
        title: const Text(
          'TACTIX • COMMAND CENTER',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: .8),
        ),
        actions: [
          IconButton(
            tooltip: 'Обновить статус',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.sync_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 1050;
            final horizontal = constraints.maxWidth < 700 ? 14.0 : 26.0;

            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(horizontal, 16, horizontal, 28),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1380),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _CommandHero(
                        aiAvailable: _aiAvailable,
                        mode: AIService.modeLabel,
                        provider: AIService.providerLabel,
                        onStartDemo: _startDemo,
                        onOpenAI: () => _open(const AIChatScreen()),
                      ),
                      const SizedBox(height: 16),
                      _SystemRail(
                        aiAvailable: _aiAvailable,
                        mode: AIService.modeLabel,
                        provider: AIService.providerLabel,
                      ),
                      const SizedBox(height: 16),
                      if (wide)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 6,
                              child: Column(
                                children: [
                                  _LiveIntelligenceCard(
                                    loading: _loading,
                                    latest: _latest,
                                    average: _average,
                                    best: _best,
                                    total: _results.length,
                                  ),
                                  const SizedBox(height: 16),
                                  _DemoSequenceCard(onStart: _startDemo),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              flex: 4,
                              child: Column(
                                children: [
                                  _DecisionDnaCard(metrics: _decisionDna),
                                  const SizedBox(height: 16),
                                  _CapabilityCard(
                                    onOpenAI: () => _open(const AIChatScreen()),
                                    onOpenAnalytics: () =>
                                        _open(const StatisticsScreen()),
                                    onOpenAiMode: () =>
                                        _open(const AIModeScreen()),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                      else ...[
                        _LiveIntelligenceCard(
                          loading: _loading,
                          latest: _latest,
                          average: _average,
                          best: _best,
                          total: _results.length,
                        ),
                        const SizedBox(height: 16),
                        _DecisionDnaCard(metrics: _decisionDna),
                        const SizedBox(height: 16),
                        _DemoSequenceCard(onStart: _startDemo),
                        const SizedBox(height: 16),
                        _CapabilityCard(
                          onOpenAI: () => _open(const AIChatScreen()),
                          onOpenAnalytics: () => _open(const StatisticsScreen()),
                          onOpenAiMode: () => _open(const AIModeScreen()),
                        ),
                      ],
                      const SizedBox(height: 16),
                      const _ArchitectureStrip(),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _CommandHero extends StatelessWidget {
  final bool aiAvailable;
  final String mode;
  final String provider;
  final VoidCallback onStartDemo;
  final VoidCallback onOpenAI;

  const _CommandHero({
    required this.aiAvailable,
    required this.mode,
    required this.provider,
    required this.onStartDemo,
    required this.onOpenAI,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: TactixTheme.gold.withValues(alpha: .34)),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF151D22), Color(0xFF07151E), Color(0xFF10120F)],
        ),
        boxShadow: [
          BoxShadow(
            color: TactixTheme.cyan.withValues(alpha: .06),
            blurRadius: 40,
            spreadRadius: 2,
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 780;
          final copy = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  const _Pill(
                    icon: Icons.bolt_rounded,
                    text: 'NU STeP • LIVE DEMO',
                    color: TactixTheme.gold,
                  ),
                  _Pill(
                    icon: aiAvailable
                        ? Icons.cloud_done_outlined
                        : Icons.memory_rounded,
                    text: aiAvailable
                        ? '$mode • $provider'
                        : 'OFFLINE CORE READY',
                    color: aiAvailable
                        ? const Color(0xFF4EE39A)
                        : TactixTheme.cyan,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Text(
                'DECISION INTELLIGENCE\nCOMMAND CENTER',
                style: TextStyle(
                  fontSize: 31,
                  height: 1.02,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Один экран показывает полный цикл TACTIX: сценарий → решение → '
                'локальная симуляция → детерминированный Score → Replay → AI Debrief.',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  height: 1.55,
                ),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton.icon(
                    onPressed: onStartDemo,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 13),
                      child: Text(
                        'ЗАПУСТИТЬ LIVE DEMO',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: onOpenAI,
                    icon: const Icon(Icons.auto_awesome_rounded),
                    label: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 13),
                      child: Text(
                        'ОТКРЫТЬ TACTIX AI',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );

          final core = const _CoreVisual();

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                copy,
                const SizedBox(height: 24),
                const SizedBox(height: 230, child: _CoreVisual()),
              ],
            );
          }

          return Row(
            children: [
              Expanded(flex: 6, child: copy),
              const SizedBox(width: 24),
              Expanded(flex: 4, child: core),
            ],
          );
        },
      ),
    );
  }
}

class _CoreVisual extends StatelessWidget {
  const _CoreVisual();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (context, value, _) {
          return SizedBox(
            width: 215,
            height: 215,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 210,
                  height: 210,
                  child: CircularProgressIndicator(
                    value: value,
                    strokeWidth: 2,
                    color: TactixTheme.cyan.withValues(alpha: .45),
                    backgroundColor: TactixTheme.line.withValues(alpha: .35),
                  ),
                ),
                SizedBox(
                  width: 165,
                  height: 165,
                  child: CircularProgressIndicator(
                    value: value,
                    strokeWidth: 8,
                    color: TactixTheme.gold,
                    backgroundColor: TactixTheme.line,
                  ),
                ),
                Container(
                  width: 126,
                  height: 126,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: TactixTheme.panel2,
                    border: Border.all(
                      color: TactixTheme.cyan.withValues(alpha: .35),
                    ),
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.hub_rounded,
                        color: TactixTheme.cyan,
                        size: 30,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'TACTIX',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.6,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'CORE ONLINE',
                        style: TextStyle(
                          color: TactixTheme.textMuted,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SystemRail extends StatelessWidget {
  final bool aiAvailable;
  final String mode;
  final String provider;

  const _SystemRail({
    required this.aiAvailable,
    required this.mode,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cards = [
          const _StatusModule(
            icon: Icons.memory_rounded,
            title: 'OFFLINE ENGINE',
            status: 'READY',
            accent: Color(0xFF4EE39A),
          ),
          const _StatusModule(
            icon: Icons.calculate_outlined,
            title: 'SCORE ENGINE',
            status: 'LOCAL',
            accent: TactixTheme.gold,
          ),
          _StatusModule(
            icon: Icons.auto_awesome_rounded,
            title: 'AI LAYER',
            status: aiAvailable ? '$mode • $provider' : 'FALLBACK READY',
            accent: aiAvailable ? TactixTheme.cyan : const Color(0xFFFFC857),
          ),
          const _StatusModule(
            icon: Icons.account_tree_outlined,
            title: 'REPLAY + WHAT IF',
            status: 'READY',
            accent: Color(0xFF9D8CFF),
          ),
          const _StatusModule(
            icon: Icons.fact_check_outlined,
            title: 'AI DEBRIEF',
            status: 'READY',
            accent: Color(0xFF74E6FF),
          ),
        ];

        final columns = constraints.maxWidth >= 1120
            ? 5
            : constraints.maxWidth >= 700
                ? 3
                : 1;
        final width =
            (constraints.maxWidth - ((columns - 1) * 10)) / columns;

        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: cards
              .map((card) => SizedBox(width: width, child: card))
              .toList(),
        );
      },
    );
  }
}

class _StatusModule extends StatelessWidget {
  final IconData icon;
  final String title;
  final String status;
  final Color accent;

  const _StatusModule({
    required this.icon,
    required this.title,
    required this.status,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: TactixTheme.panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: .24)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 19, color: accent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 9,
                    color: TactixTheme.textMuted,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  status,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: accent,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
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

class _LiveIntelligenceCard extends StatelessWidget {
  final bool loading;
  final TrainingResult? latest;
  final int average;
  final int best;
  final int total;

  const _LiveIntelligenceCard({
    required this.loading,
    required this.latest,
    required this.average,
    required this.best,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'LIVE DECISION INTELLIGENCE',
      icon: Icons.insights_rounded,
      child: loading
          ? const SizedBox(
              height: 150,
              child: Center(child: CircularProgressIndicator()),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 560;
                    final cards = [
                      _MetricBox(label: 'ТРЕНИРОВОК', value: '$total'),
                      _MetricBox(label: 'СРЕДНИЙ SCORE', value: '$average'),
                      _MetricBox(label: 'ЛУЧШИЙ SCORE', value: '$best'),
                    ];
                    if (compact) {
                      return Column(
                        children: cards
                            .map((card) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: card,
                                ))
                            .toList(),
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: cards[0]),
                        const SizedBox(width: 8),
                        Expanded(child: cards[1]),
                        const SizedBox(width: 8),
                        Expanded(child: cards[2]),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 14),
                if (latest == null)
                  const _EmptyLatest()
                else
                  _LatestResult(result: latest!),
              ],
            ),
    );
  }
}

class _MetricBox extends StatelessWidget {
  final String label;
  final String value;

  const _MetricBox({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: TactixTheme.panel2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: TactixTheme.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: TactixTheme.textMuted,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: .6,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: const TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _LatestResult extends StatelessWidget {
  final TrainingResult result;

  const _LatestResult({required this.result});

  Color _scoreColor(int score) {
    if (score >= 85) return const Color(0xFF4EE39A);
    if (score >= 70) return TactixTheme.gold;
    if (score >= 55) return const Color(0xFFFF9F43);
    return const Color(0xFFFF5D6C);
  }

  @override
  Widget build(BuildContext context) {
    final color = _scoreColor(result.score);
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFF09131A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: .24)),
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: .10),
              border: Border.all(color: color.withValues(alpha: .45), width: 2),
            ),
            child: Text(
              '${result.score}',
              style: TextStyle(
                color: color,
                fontSize: 23,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ПОСЛЕДНЯЯ СЕССИЯ',
                  style: TextStyle(
                    color: TactixTheme.textMuted,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .8,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  result.scenarioTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 5),
                Text(
                  '${result.decisions} решений • ${result.level.isEmpty ? 'TACTIX Score' : result.level}',
                  style: const TextStyle(
                    color: TactixTheme.textMuted,
                    fontSize: 10,
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

class _EmptyLatest extends StatelessWidget {
  const _EmptyLatest();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TactixTheme.panel2,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: TactixTheme.line),
      ),
      child: const Row(
        children: [
          Icon(Icons.play_circle_outline_rounded, color: TactixTheme.gold),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Данных ещё нет. Запустите LIVE DEMO — после завершения здесь появится реальный профиль результата.',
              style: TextStyle(color: Colors.white70, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _DecisionDnaCard extends StatelessWidget {
  final Map<String, int> metrics;

  const _DecisionDnaCard({required this.metrics});

  @override
  Widget build(BuildContext context) {
    final hasData = metrics.values.any((value) => value > 0);
    return _Panel(
      title: 'DECISION DNA',
      icon: Icons.fingerprint_rounded,
      child: Column(
        children: metrics.entries.map((entry) {
          final value = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        entry.key,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      hasData ? '$value' : '—',
                      style: const TextStyle(
                        color: TactixTheme.gold,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: hasData ? value / 100 : 0),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeOutCubic,
                  builder: (context, progress, _) => ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: TactixTheme.line.withValues(alpha: .45),
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _DemoSequenceCard extends StatelessWidget {
  final VoidCallback onStart;

  const _DemoSequenceCard({required this.onStart});

  @override
  Widget build(BuildContext context) {
    const steps = [
      ('01', 'СЦЕНАРИЙ', 'Запуск автономной учебной ситуации.'),
      ('02', '3 РЕШЕНИЯ', 'Пользователь принимает последовательные решения.'),
      ('03', 'TACTIX SCORE', 'Локальный движок рассчитывает итог.'),
      ('04', 'REPLAY + WHAT IF', 'Разбор хода решений и альтернатив.'),
      ('05', 'AI DEBRIEF', 'AI объясняет уже рассчитанные данные.'),
    ];

    return _Panel(
      title: '60-SECOND DEMO FLOW',
      icon: Icons.route_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...steps.map(
            (step) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: TactixTheme.gold.withValues(alpha: .10),
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(
                        color: TactixTheme.gold.withValues(alpha: .24),
                      ),
                    ),
                    child: Text(
                      step.$1,
                      style: const TextStyle(
                        color: TactixTheme.gold,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          step.$2,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          step.$3,
                          style: const TextStyle(
                            color: TactixTheme.textMuted,
                            fontSize: 10,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          FilledButton.icon(
            onPressed: onStart,
            icon: const Icon(Icons.rocket_launch_rounded),
            label: const Padding(
              padding: EdgeInsets.symmetric(vertical: 13),
              child: Text(
                'НАЧАТЬ ДЕМОНСТРАЦИЮ',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CapabilityCard extends StatelessWidget {
  final VoidCallback onOpenAI;
  final VoidCallback onOpenAnalytics;
  final VoidCallback onOpenAiMode;

  const _CapabilityCard({
    required this.onOpenAI,
    required this.onOpenAnalytics,
    required this.onOpenAiMode,
  });

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'QUICK CONTROL',
      icon: Icons.tune_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ControlButton(
            icon: Icons.auto_awesome_rounded,
            title: 'TACTIX AI',
            subtitle: 'Общий • Тренер • Разбор',
            onTap: onOpenAI,
          ),
          const SizedBox(height: 8),
          _ControlButton(
            icon: Icons.analytics_outlined,
            title: 'АНАЛИТИКА',
            subtitle: 'История и динамика результатов',
            onTap: onOpenAnalytics,
          ),
          const SizedBox(height: 8),
          _ControlButton(
            icon: Icons.hub_outlined,
            title: 'AI MODE',
            subtitle: 'AUTO • CLOUD • LOCAL • OFFLINE',
            onTap: onOpenAiMode,
          ),
        ],
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ControlButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: TactixTheme.panel2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: TactixTheme.line),
        ),
        child: Row(
          children: [
            Icon(icon, color: TactixTheme.cyan, size: 20),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: TactixTheme.textMuted,
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.white38),
          ],
        ),
      ),
    );
  }
}

class _ArchitectureStrip extends StatelessWidget {
  const _ArchitectureStrip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: const Color(0xFF071219),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: TactixTheme.cyan.withValues(alpha: .20)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 720;
          final nodes = [
            const _ArchitectureNode(icon: Icons.person_outline_rounded, text: 'DECISION'),
            const _ArchitectureNode(icon: Icons.settings_suggest_outlined, text: 'SIMULATION'),
            const _ArchitectureNode(icon: Icons.calculate_outlined, text: 'SCORE'),
            const _ArchitectureNode(icon: Icons.account_tree_outlined, text: 'REPLAY'),
            const _ArchitectureNode(icon: Icons.auto_awesome_rounded, text: 'AI DEBRIEF'),
          ];

          if (compact) {
            return Wrap(spacing: 8, runSpacing: 8, children: nodes);
          }

          final row = <Widget>[];
          for (var i = 0; i < nodes.length; i++) {
            row.add(Expanded(child: nodes[i]));
            if (i < nodes.length - 1) {
              row.add(const Padding(
                padding: EdgeInsets.symmetric(horizontal: 7),
                child: Icon(Icons.arrow_forward_rounded, size: 16, color: TactixTheme.textMuted),
              ));
            }
          }
          return Row(children: row);
        },
      ),
    );
  }
}

class _ArchitectureNode extends StatelessWidget {
  final IconData icon;
  final String text;

  const _ArchitectureNode({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: TactixTheme.panel2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: TactixTheme.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: TactixTheme.gold),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: .5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _Pill({required this.icon, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: .27)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: .7,
            ),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _Panel({required this.title, required this.icon, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TactixTheme.panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: TactixTheme.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: TactixTheme.gold, size: 18),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .7,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          child,
        ],
      ),
    );
  }
}
