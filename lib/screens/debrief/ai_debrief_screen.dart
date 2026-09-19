import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../models/ai_chat_message.dart';
import '../../models/decision_record.dart';
import '../../models/training_debrief_data.dart';
import '../../services/replay_service.dart';
import '../ai/ai_chat_screen.dart';
import '../replay/tactix_replay_screen.dart';

class AIDebriefScreen extends StatelessWidget {
  final TrainingDebriefData data;

  const AIDebriefScreen({
    super.key,
    required this.data,
  });

  static const ReplayService _replayService = ReplayService();

  int _average(int Function(DecisionRecord item) selector) {
    if (data.history.isEmpty) return 0;
    final total = data.history.fold<int>(0, (sum, item) => sum + selector(item));
    return (total / data.history.length).round().clamp(0, 100);
  }

  Map<String, int> get _metrics => <String, int>{
    'Цель': _average((item) => item.goalScore),
    'Ресурсы': _average((item) => item.resourceScore),
    'Устойчивость': _average((item) => item.stabilityScore),
    'Неопределённость': _average((item) => item.uncertaintyScore),
    'Время': _average((item) => item.timeScore),
  };

  MapEntry<String, int>? get _strongest {
    if (_metrics.isEmpty) return null;
    return _metrics.entries.reduce((a, b) => a.value >= b.value ? a : b);
  }

  MapEntry<String, int>? get _weakest {
    if (_metrics.isEmpty) return null;
    return _metrics.entries.reduce((a, b) => a.value <= b.value ? a : b);
  }

  Color _scoreColor(int score) {
    if (score >= 85) return const Color(0xFF4EE39A);
    if (score >= 70) return TactixTheme.gold;
    if (score >= 55) return const Color(0xFFFF9F43);
    return const Color(0xFFFF5D6C);
  }

  String _level(int score) {
    if (score >= 85) return 'ОТЛИЧНО';
    if (score >= 70) return 'ХОРОШО';
    if (score >= 55) return 'УДОВЛЕТВОРИТЕЛЬНО';
    return 'ТРЕБУЕТ РАЗВИТИЯ';
  }

  String _recommendation() {
    final weakest = _weakest;
    if (weakest == null) return 'Продолжайте накапливать данные тренировок.';

    switch (weakest.key) {
      case 'Ресурсы':
        return 'В следующем прохождении сравнивайте прирост прогресса с расходом условного ресурса перед каждым подтверждением решения.';
      case 'Устойчивость':
        return 'Проверяйте, не создаёт ли краткосрочный выигрыш дополнительную нестабильность для следующего хода.';
      case 'Неопределённость':
        return 'Перед решениями с высокой ценой ошибки уделяйте больше внимания снижению неопределённости.';
      case 'Время':
        return 'Сокращайте действия, которые расходуют время без сопоставимого продвижения к учебной цели.';
      default:
        return 'Сосредоточьтесь на решениях, которые напрямую продвигают учебную цель при приемлемом влиянии на остальные показатели.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final keyMoment = _replayService.keyMoment(data);
    final strongest = _strongest;
    final weakest = _weakest;
    final scoreColor = _scoreColor(data.score);

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI DEBRIEF'),
        actions: [
          IconButton(
            tooltip: 'TACTIX Replay',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => TactixReplayScreen(data: data),
                ),
              );
            },
            icon: const Icon(Icons.account_tree_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 900;
            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: wide ? 28 : 16,
                vertical: 18,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1180),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _HeroCard(
                        title: data.scenario.title,
                        score: data.score,
                        level: _level(data.score),
                        scoreColor: scoreColor,
                        decisions: data.history.length,
                      ),
                      const SizedBox(height: 16),
                      if (wide)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 3,
                              child: _MetricsPanel(metrics: _metrics),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              flex: 2,
                              child: _InsightPanel(
                                strongest: strongest,
                                weakest: weakest,
                              ),
                            ),
                          ],
                        )
                      else ...[
                        _MetricsPanel(metrics: _metrics),
                        const SizedBox(height: 16),
                        _InsightPanel(
                          strongest: strongest,
                          weakest: weakest,
                        ),
                      ],
                      const SizedBox(height: 16),
                      _KeyMomentCard(
                        frame: keyMoment,
                        finalScore: data.score,
                      ),
                      const SizedBox(height: 16),
                      _DecisionTimeline(data: data),
                      const SizedBox(height: 16),
                      _RecommendationCard(text: _recommendation()),
                      const SizedBox(height: 16),
                      _AarPreview(aar: data.aar),
                      const SizedBox(height: 18),
                      LayoutBuilder(
                        builder: (context, buttonConstraints) {
                          final compact = buttonConstraints.maxWidth < 620;
                          final aiButton = FilledButton.icon(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const AIChatScreen(
                                    initialContext: AIChatContextType.debrief,
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.auto_awesome_rounded),
                            label: const Padding(
                              padding: EdgeInsets.symmetric(vertical: 14),
                              child: Text(
                                'ОБСУДИТЬ С TACTIX AI',
                                style: TextStyle(fontWeight: FontWeight.w900),
                              ),
                            ),
                          );

                          final replayButton = OutlinedButton.icon(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => TactixReplayScreen(data: data),
                                ),
                              );
                            },
                            icon: const Icon(Icons.play_circle_outline_rounded),
                            label: const Padding(
                              padding: EdgeInsets.symmetric(vertical: 14),
                              child: Text(
                                'ОТКРЫТЬ TACTIX REPLAY',
                                style: TextStyle(fontWeight: FontWeight.w900),
                              ),
                            ),
                          );

                          if (compact) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                aiButton,
                                const SizedBox(height: 10),
                                replayButton,
                              ],
                            );
                          }

                          return Row(
                            children: [
                              Expanded(child: aiButton),
                              const SizedBox(width: 12),
                              Expanded(child: replayButton),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'TACTIX Score рассчитан локальным детерминированным движком. AI используется только для объяснения и учебного разбора.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: TactixTheme.textMuted,
                          fontSize: 10,
                          height: 1.45,
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

class _HeroCard extends StatelessWidget {
  final String title;
  final int score;
  final String level;
  final Color scoreColor;
  final int decisions;

  const _HeroCard({
    required this.title,
    required this.score,
    required this.level,
    required this.scoreColor,
    required this.decisions,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            TactixTheme.panel2,
            TactixTheme.cyan.withValues(alpha: .055),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: TactixTheme.cyan.withValues(alpha: .28)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 620;
          final scoreWidget = SizedBox(
            width: 128,
            height: 128,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 116,
                  height: 116,
                  child: CircularProgressIndicator(
                    value: score / 100,
                    strokeWidth: 9,
                    backgroundColor: Colors.white10,
                    color: scoreColor,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$score',
                      style: TextStyle(
                        color: scoreColor,
                        fontSize: 38,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      'TACTIX SCORE',
                      style: TextStyle(
                        color: TactixTheme.textMuted,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );

          final text = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ИНТЕЛЛЕКТУАЛЬНЫЙ РАЗБОР',
                style: TextStyle(
                  color: TactixTheme.cyan,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 9),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '$level • $decisions решения',
                style: const TextStyle(
                  color: TactixTheme.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Разбор показывает траекторию решений, сильные стороны и ключевую точку прохождения на основе фактических данных симуляции.',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ],
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: scoreWidget),
                const SizedBox(height: 18),
                text,
              ],
            );
          }

          return Row(
            children: [
              scoreWidget,
              const SizedBox(width: 24),
              Expanded(child: text),
            ],
          );
        },
      ),
    );
  }
}

class _MetricsPanel extends StatelessWidget {
  final Map<String, int> metrics;

  const _MetricsPanel({required this.metrics});

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'DECISION DNA',
      icon: Icons.hub_outlined,
      child: Column(
        children: metrics.entries
            .map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _MetricBar(label: entry.key, value: entry.value),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _InsightPanel extends StatelessWidget {
  final MapEntry<String, int>? strongest;
  final MapEntry<String, int>? weakest;

  const _InsightPanel({required this.strongest, required this.weakest});

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'КЛЮЧЕВЫЕ ВЫВОДЫ',
      icon: Icons.insights_outlined,
      child: Column(
        children: [
          _InsightRow(
            icon: Icons.trending_up_rounded,
            label: 'Сильная сторона',
            value: strongest == null
                ? 'Нет данных'
                : '${strongest!.key} • ${strongest!.value}/100',
            accent: const Color(0xFF4EE39A),
          ),
          const SizedBox(height: 12),
          _InsightRow(
            icon: Icons.center_focus_weak_rounded,
            label: 'Точка роста',
            value: weakest == null
                ? 'Нет данных'
                : '${weakest!.key} • ${weakest!.value}/100',
            accent: TactixTheme.gold,
          ),
        ],
      ),
    );
  }
}

class _KeyMomentCard extends StatelessWidget {
  final ReplayFrame? frame;
  final int finalScore;

  const _KeyMomentCard({required this.frame, required this.finalScore});

  @override
  Widget build(BuildContext context) {
    final value = frame;
    final distance = value == null ? 0 : value.record.score - finalScore;
    final sign = distance > 0 ? '+$distance' : '$distance';

    return _Panel(
      title: 'КЛЮЧЕВОЙ МОМЕНТ',
      icon: Icons.bolt_rounded,
      accent: TactixTheme.gold,
      child: value == null
          ? const Text(
              'Недостаточно данных для определения ключевого момента.',
              style: TextStyle(color: TactixTheme.textMuted),
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 54,
                  height: 54,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: TactixTheme.gold.withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: TactixTheme.gold.withValues(alpha: .30),
                    ),
                  ),
                  child: Text(
                    '${value.record.turn}',
                    style: const TextStyle(
                      color: TactixTheme.gold,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ход ${value.record.turn} • вариант ${value.record.decision}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Оценка этого решения ${value.record.score}/100. Отклонение от итоговой средней оценки: $sign.',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 7),
                      const Text(
                        'Ключевой момент определяется локально как решение с наибольшим отклонением от итоговой траектории.',
                        style: TextStyle(
                          color: TactixTheme.textMuted,
                          fontSize: 9,
                          height: 1.4,
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

class _DecisionTimeline extends StatelessWidget {
  final TrainingDebriefData data;

  const _DecisionTimeline({required this.data});

  @override
  Widget build(BuildContext context) {
    const service = ReplayService();
    final frames = service.buildFrames(data);

    return _Panel(
      title: 'ТРАЕКТОРИЯ РЕШЕНИЙ',
      icon: Icons.timeline_rounded,
      child: Column(
        children: frames.map((frame) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: TactixTheme.cyan.withValues(alpha: .11),
                        border: Border.all(
                          color: TactixTheme.cyan.withValues(alpha: .35),
                        ),
                      ),
                      child: Text(
                        '${frame.record.turn}',
                        style: const TextStyle(
                          color: TactixTheme.cyan,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    if (frame.index < frames.length - 1)
                      Container(
                        width: 1,
                        height: 34,
                        color: TactixTheme.line,
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .022),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: TactixTheme.line),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Вариант ${frame.record.decision} • ${service.decisionLabel(frame.record.decision)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                'Прогресс ${_delta(frame.record.delta['progress'] ?? 0)} • Ресурсы ${_delta(frame.record.delta['resources'] ?? 0)} • Неопределённость ${_delta(frame.record.delta['uncertainty'] ?? 0)}',
                                style: const TextStyle(
                                  color: TactixTheme.textMuted,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '${frame.record.score}',
                          style: const TextStyle(
                            color: TactixTheme.gold,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
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

  static String _delta(int value) => value > 0 ? '+$value' : '$value';
}

class _RecommendationCard extends StatelessWidget {
  final String text;

  const _RecommendationCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'РЕКОМЕНДАЦИЯ ДЛЯ СЛЕДУЮЩЕЙ ТРЕНИРОВКИ',
      icon: Icons.lightbulb_outline_rounded,
      accent: TactixTheme.gold,
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 12,
          height: 1.55,
        ),
      ),
    );
  }
}

class _AarPreview extends StatelessWidget {
  final String aar;

  const _AarPreview({required this.aar});

  @override
  Widget build(BuildContext context) {
    final trimmed = aar.trim();
    final preview = trimmed.length > 1000 ? '${trimmed.substring(0, 1000)}…' : trimmed;
    return _Panel(
      title: 'AFTER ACTION REVIEW',
      icon: Icons.description_outlined,
      child: SelectableText(
        preview.isEmpty ? 'AAR пока недоступен.' : preview,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 11,
          height: 1.55,
        ),
      ),
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

class _MetricBar extends StatelessWidget {
  final String label;
  final int value;

  const _MetricBar({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              '$value/100',
              style: const TextStyle(
                color: TactixTheme.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: value / 100,
            minHeight: 7,
            backgroundColor: Colors.white10,
            color: value >= 70 ? TactixTheme.cyan : TactixTheme.gold,
          ),
        ),
      ],
    );
  }
}

class _InsightRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  const _InsightRow({
    required this.icon,
    required this.label,
    required this.value,
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accent, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: const TextStyle(
                    color: TactixTheme.textMuted,
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .8,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    height: 1.35,
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
