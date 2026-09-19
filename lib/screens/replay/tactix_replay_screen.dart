import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../models/training_debrief_data.dart';
import '../../services/replay_service.dart';
import '../../services/simulation_engine.dart';

class TactixReplayScreen extends StatefulWidget {
  final TrainingDebriefData data;

  const TactixReplayScreen({
    super.key,
    required this.data,
  });

  @override
  State<TactixReplayScreen> createState() => _TactixReplayScreenState();
}

class _TactixReplayScreenState extends State<TactixReplayScreen> {
  static const ReplayService _service = ReplayService();

  late final List<ReplayFrame> _frames;
  int _selectedIndex = 0;
  bool _playing = false;
  Timer? _timer;
  WhatIfResult? _whatIf;

  @override
  void initState() {
    super.initState();
    _frames = _service.buildFrames(widget.data);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _toggleReplay() {
    if (_frames.isEmpty) return;

    if (_playing) {
      _stopReplay();
      return;
    }

    setState(() {
      _playing = true;
      if (_selectedIndex >= _frames.length - 1) {
        _selectedIndex = 0;
      }
    });

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 1100), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_selectedIndex >= _frames.length - 1) {
        timer.cancel();
        setState(() => _playing = false);
        return;
      }

      setState(() => _selectedIndex++);
    });
  }

  void _stopReplay() {
    _timer?.cancel();
    if (mounted) {
      setState(() => _playing = false);
    }
  }

  void _step(int delta) {
    _stopReplay();
    if (_frames.isEmpty) return;
    setState(() {
      final next = _selectedIndex + delta;
      if (next < 0) {
        _selectedIndex = 0;
      } else if (next >= _frames.length) {
        _selectedIndex = _frames.length - 1;
      } else {
        _selectedIndex = next;
      }
    });
  }

  void _runWhatIf(String alternative) {
    _stopReplay();
    try {
      final result = _service.simulateAlternative(
        data: widget.data,
        changedIndex: _selectedIndex,
        alternativeDecision: alternative,
      );
      setState(() => _whatIf = result);
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('WHAT IF недоступен: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_frames.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('TACTIX REPLAY')),
        body: const Center(
          child: Text('Для этого прохождения нет данных Replay.'),
        ),
      );
    }

    final selected = _frames[_selectedIndex];
    final keyMoment = _service.keyMoment(widget.data);
    final actualEvolution = _service.scoreEvolution(widget.data);
    final alternativeEvolution = _whatIf?.frames
        .map((frame) => frame.runningScore)
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('TACTIX REPLAY'),
        actions: [
          IconButton(
            tooltip: _playing ? 'Пауза' : 'Воспроизвести',
            onPressed: _toggleReplay,
            icon: Icon(
              _playing
                  ? Icons.pause_circle_outline_rounded
                  : Icons.play_circle_outline_rounded,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final desktop = constraints.maxWidth >= 920;
            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: desktop ? 28 : 16,
                vertical: 18,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1240),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _ReplayHeader(
                        title: widget.data.scenario.title,
                        score: widget.data.score,
                        selected: _selectedIndex + 1,
                        total: _frames.length,
                        playing: _playing,
                      ),
                      const SizedBox(height: 16),
                      _ScoreEvolutionCard(
                        actual: actualEvolution,
                        alternative: alternativeEvolution,
                      ),
                      const SizedBox(height: 16),
                      if (desktop)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 355,
                              child: _TimelinePanel(
                                frames: _frames,
                                selectedIndex: _selectedIndex,
                                keyMomentIndex: keyMoment?.index,
                                onSelect: (index) {
                                  _stopReplay();
                                  setState(() {
                                    _selectedIndex = index;
                                    _whatIf = null;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                children: [
                                  _DecisionDetailCard(frame: selected),
                                  const SizedBox(height: 16),
                                  _WhatIfCard(
                                    selected: selected,
                                    whatIf: _whatIf,
                                    onSelect: _runWhatIf,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                      else ...[
                        _TimelinePanel(
                          frames: _frames,
                          selectedIndex: _selectedIndex,
                          keyMomentIndex: keyMoment?.index,
                          onSelect: (index) {
                            _stopReplay();
                            setState(() {
                              _selectedIndex = index;
                              _whatIf = null;
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        _DecisionDetailCard(frame: selected),
                        const SizedBox(height: 16),
                        _WhatIfCard(
                          selected: selected,
                          whatIf: _whatIf,
                          onSelect: _runWhatIf,
                        ),
                      ],
                      const SizedBox(height: 16),
                      _ReplayControls(
                        playing: _playing,
                        canBack: _selectedIndex > 0,
                        canNext: _selectedIndex < _frames.length - 1,
                        onBack: () => _step(-1),
                        onPlayPause: _toggleReplay,
                        onNext: () => _step(1),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'WHAT IF работает в локальной sandbox-симуляции. Исходный результат, история и TACTIX Score пользователя не изменяются.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: TactixTheme.textMuted,
                          fontSize: 10,
                          height: 1.4,
                        ),
                      ),
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

class _ReplayHeader extends StatelessWidget {
  final String title;
  final int score;
  final int selected;
  final int total;
  final bool playing;

  const _ReplayHeader({
    required this.title,
    required this.score,
    required this.selected,
    required this.total,
    required this.playing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            TactixTheme.panel2,
            TactixTheme.gold.withValues(alpha: .045),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: TactixTheme.gold.withValues(alpha: .25)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 620;
          final scoreWidget = Container(
            width: 92,
            height: 92,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: TactixTheme.gold.withValues(alpha: .08),
              border: Border.all(
                color: TactixTheme.gold.withValues(alpha: .35),
                width: 2,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$score',
                  style: const TextStyle(
                    color: TactixTheme.gold,
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'SCORE',
                  style: TextStyle(
                    color: TactixTheme.textMuted,
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          );

          final text = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'INTERACTIVE DECISION REPLAY',
                    style: TextStyle(
                      color: TactixTheme.gold,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.15,
                    ),
                  ),
                  if (playing) ...[
                    const SizedBox(width: 9),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4EE39A).withValues(alpha: .10),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: const Text(
                        'PLAYING',
                        style: TextStyle(
                          color: Color(0xFF4EE39A),
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Ход $selected из $total • выберите решение на timeline, чтобы увидеть состояние до и после.',
                style: const TextStyle(
                  color: TactixTheme.textMuted,
                  fontSize: 11,
                  height: 1.4,
                ),
              ),
            ],
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                scoreWidget,
                const SizedBox(height: 16),
                text,
              ],
            );
          }

          return Row(
            children: [
              scoreWidget,
              const SizedBox(width: 20),
              Expanded(child: text),
            ],
          );
        },
      ),
    );
  }
}

class _TimelinePanel extends StatelessWidget {
  final List<ReplayFrame> frames;
  final int selectedIndex;
  final int? keyMomentIndex;
  final ValueChanged<int> onSelect;

  const _TimelinePanel({
    required this.frames,
    required this.selectedIndex,
    required this.keyMomentIndex,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'DECISION TIMELINE',
      icon: Icons.account_tree_outlined,
      child: Column(
        children: List.generate(frames.length, (index) {
          final frame = frames[index];
          final selected = index == selectedIndex;
          final key = index == keyMomentIndex;

          return InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => onSelect(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              margin: EdgeInsets.only(bottom: index == frames.length - 1 ? 0 : 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: selected
                    ? TactixTheme.cyan.withValues(alpha: .08)
                    : Colors.white.withValues(alpha: .018),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected
                      ? TactixTheme.cyan.withValues(alpha: .42)
                      : TactixTheme.line,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected
                          ? TactixTheme.cyan.withValues(alpha: .12)
                          : Colors.white.withValues(alpha: .03),
                    ),
                    child: Text(
                      '${frame.record.turn}',
                      style: TextStyle(
                        color: selected ? TactixTheme.cyan : Colors.white70,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Вариант ${frame.record.decision}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            if (key)
                              const Icon(
                                Icons.bolt_rounded,
                                color: TactixTheme.gold,
                                size: 16,
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${frame.record.score}/100 • итог траектории ${frame.runningScore}',
                          style: const TextStyle(
                            color: TactixTheme.textMuted,
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _DecisionDetailCard extends StatelessWidget {
  final ReplayFrame frame;

  const _DecisionDetailCard({required this.frame});

  @override
  Widget build(BuildContext context) {
    const service = ReplayService();
    return _Panel(
      title: 'РАЗБОР ВЫБРАННОГО ХОДА',
      icon: Icons.analytics_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: TactixTheme.gold.withValues(alpha: .09),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: TactixTheme.gold.withValues(alpha: .25),
                  ),
                ),
                child: Text(
                  'ХОД ${frame.record.turn}',
                  style: const TextStyle(
                    color: TactixTheme.gold,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .8,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Вариант ${frame.record.decision} • ${service.decisionLabel(frame.record.decision)}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${frame.record.score}/100 • ${frame.record.level}',
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
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 640;
              final before = _StateSnapshot(title: 'ДО', state: frame.before);
              final after = _StateSnapshot(title: 'ПОСЛЕ', state: frame.after);
              if (compact) {
                return Column(
                  children: [
                    before,
                    const SizedBox(height: 10),
                    after,
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: before),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      color: TactixTheme.cyan,
                    ),
                  ),
                  Expanded(child: after),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _DeltaChip(label: 'Время', value: frame.record.delta['time'] ?? 0),
              _DeltaChip(
                label: 'Ресурсы',
                value: frame.record.delta['resources'] ?? 0,
              ),
              _DeltaChip(
                label: 'Устойчивость',
                value: frame.record.delta['stability'] ?? 0,
              ),
              _DeltaChip(
                label: 'Прогресс',
                value: frame.record.delta['progress'] ?? 0,
              ),
              _DeltaChip(
                label: 'Неопределённость',
                value: frame.record.delta['uncertainty'] ?? 0,
                inverse: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WhatIfCard extends StatelessWidget {
  final ReplayFrame selected;
  final WhatIfResult? whatIf;
  final ValueChanged<String> onSelect;

  const _WhatIfCard({
    required this.selected,
    required this.whatIf,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    const service = ReplayService();
    final alternatives = const ['A', 'B', 'C']
        .where((item) => item != selected.record.decision)
        .toList(growable: false);

    return _Panel(
      title: 'WHAT IF • А ЧТО ЕСЛИ?',
      icon: Icons.alt_route_rounded,
      accent: TactixTheme.gold,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Замените решение хода ${selected.record.turn}. TACTIX пересчитает альтернативную ветку локальным SimulationEngine и не изменит оригинал.',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: alternatives.map((decision) {
              return OutlinedButton.icon(
                onPressed: () => onSelect(decision),
                icon: const Icon(Icons.fork_right_rounded),
                label: Text(
                  '$decision • ${service.decisionLabel(decision)}',
                ),
              );
            }).toList(),
          ),
          if (whatIf != null) ...[
            const SizedBox(height: 18),
            _ComparisonResult(result: whatIf!),
          ],
        ],
      ),
    );
  }
}

class _ComparisonResult extends StatelessWidget {
  final WhatIfResult result;

  const _ComparisonResult({required this.result});

  @override
  Widget build(BuildContext context) {
    final delta = result.delta;
    final deltaText = delta > 0 ? '+$delta' : '$delta';
    final deltaColor = delta > 0
        ? const Color(0xFF4EE39A)
        : delta < 0
        ? const Color(0xFFFF5D6C)
        : TactixTheme.textMuted;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .025),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: TactixTheme.gold.withValues(alpha: .24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 540;
              final original = _ScoreBox(
                label: 'ОРИГИНАЛ',
                decision: result.originalDecision,
                score: result.originalFinalScore,
                accent: TactixTheme.cyan,
              );
              final alternative = _ScoreBox(
                label: 'АЛЬТЕРНАТИВА',
                decision: result.alternativeDecision,
                score: result.alternativeFinalScore,
                accent: TactixTheme.gold,
              );

              if (compact) {
                return Column(
                  children: [
                    original,
                    const SizedBox(height: 10),
                    alternative,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: original),
                  const SizedBox(width: 10),
                  Expanded(child: alternative),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'DELTA ',
                style: TextStyle(
                  color: TactixTheme.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .8,
                ),
              ),
              Text(
                deltaText,
                style: TextStyle(
                  color: deltaColor,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ScoreEvolutionCard extends StatelessWidget {
  final List<int> actual;
  final List<int>? alternative;

  const _ScoreEvolutionCard({required this.actual, required this.alternative});

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'ЭВОЛЮЦИЯ TACTIX SCORE',
      icon: Icons.show_chart_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 150,
            child: CustomPaint(
              painter: _ScoreChartPainter(
                actual: actual,
                alternative: alternative,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              const _LegendDot(label: 'Фактическая траектория', color: TactixTheme.cyan),
              if (alternative != null)
                const _LegendDot(
                  label: 'WHAT IF',
                  color: TactixTheme.gold,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ScoreChartPainter extends CustomPainter {
  final List<int> actual;
  final List<int>? alternative;

  const _ScoreChartPainter({required this.actual, required this.alternative});

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = TactixTheme.line.withValues(alpha: .65)
      ..strokeWidth = 1;

    for (var i = 0; i <= 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    _drawSeries(canvas, size, actual, TactixTheme.cyan);
    final alt = alternative;
    if (alt != null) {
      _drawSeries(canvas, size, alt, TactixTheme.gold);
    }
  }

  void _drawSeries(Canvas canvas, Size size, List<int> values, Color color) {
    if (values.isEmpty) return;

    final path = Path();
    final pointPaint = Paint()..color = color;
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    for (var index = 0; index < values.length; index++) {
      final x = values.length == 1
          ? size.width / 2
          : size.width * index / (values.length - 1);
      final y = size.height - (values[index].clamp(0, 100) / 100 * size.height);
      final point = Offset(x, y);

      if (index == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawCircle(point, 4.5, pointPaint);
    }

    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _ScoreChartPainter oldDelegate) {
    return oldDelegate.actual != actual || oldDelegate.alternative != alternative;
  }
}

class _ReplayControls extends StatelessWidget {
  final bool playing;
  final bool canBack;
  final bool canNext;
  final VoidCallback onBack;
  final VoidCallback onPlayPause;
  final VoidCallback onNext;

  const _ReplayControls({
    required this.playing,
    required this.canBack,
    required this.canNext,
    required this.onBack,
    required this.onPlayPause,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton.filledTonal(
          onPressed: canBack ? onBack : null,
          icon: const Icon(Icons.skip_previous_rounded),
        ),
        const SizedBox(width: 10),
        FilledButton.icon(
          onPressed: onPlayPause,
          icon: Icon(
            playing
                ? Icons.pause_rounded
                : Icons.play_arrow_rounded,
          ),
          label: Text(playing ? 'ПАУЗА' : 'ВОСПРОИЗВЕСТИ РАЗБОР'),
        ),
        const SizedBox(width: 10),
        IconButton.filledTonal(
          onPressed: canNext ? onNext : null,
          icon: const Icon(Icons.skip_next_rounded),
        ),
      ],
    );
  }
}

class _StateSnapshot extends StatelessWidget {
  final String title;
  final SimulationState state;

  const _StateSnapshot({required this.title, required this.state});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .02),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: TactixTheme.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: TactixTheme.textMuted,
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: .8,
            ),
          ),
          const SizedBox(height: 8),
          _MiniMetric(label: 'Время', value: state.time),
          _MiniMetric(label: 'Ресурс', value: state.resources),
          _MiniMetric(label: 'Устойчивость', value: state.stability),
          _MiniMetric(label: 'Прогресс', value: state.progress),
          _MiniMetric(label: 'Неопределённость', value: state.uncertainty),
        ],
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  final String label;
  final int value;

  const _MiniMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: TactixTheme.textMuted,
                fontSize: 10,
              ),
            ),
          ),
          Text(
            '$value',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _DeltaChip extends StatelessWidget {
  final String label;
  final int value;
  final bool inverse;

  const _DeltaChip({
    required this.label,
    required this.value,
    this.inverse = false,
  });

  @override
  Widget build(BuildContext context) {
    final good = inverse ? value <= 0 : value >= 0;
    final color = value == 0
        ? TactixTheme.textMuted
        : good
        ? const Color(0xFF4EE39A)
        : const Color(0xFFFF5D6C);
    final valueText = value > 0 ? '+$value' : '$value';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .06),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: .20)),
      ),
      child: Text(
        '$label $valueText',
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _ScoreBox extends StatelessWidget {
  final String label;
  final String decision;
  final int score;
  final Color accent;

  const _ScoreBox({
    required this.label,
    required this.decision,
    required this.score,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: .045),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: .18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: TactixTheme.textMuted,
              fontSize: 8,
              fontWeight: FontWeight.w900,
              letterSpacing: .8,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Вариант $decision',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            '$score',
            style: TextStyle(
              color: accent,
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final String label;
  final Color color;

  const _LegendDot({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: TactixTheme.textMuted,
            fontSize: 9,
          ),
        ),
      ],
    );
  }
}

class _Panel extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final Color accent;

  const _Panel({
    required this.title,
    required this.icon,
    required this.child,
    this.accent = TactixTheme.cyan,
  });

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
              Icon(icon, color: accent, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: accent,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .95,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}
