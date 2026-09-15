import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../app/user_session_scope.dart';
import '../../models/training_result.dart';
import '../../services/ai_service.dart';
import '../../services/result_storage_service.dart';
import '../../widgets/achievements_panel.dart';
import '../../widgets/common_widgets.dart';
import '../scenarios/ai_scenario_screen.dart';
import 'user_switcher_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  List<TrainingResult> results = const [];
  bool loading = true;
  bool aiOnline = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final loaded = await ResultStorageService.load();
    final online = await AIService.isServerAvailable();
    if (!mounted) return;
    setState(() {
      results = loaded;
      aiOnline = online;
      loading = false;
    });
  }

  int get xp => results.fold<int>(0, (sum, item) => sum + item.score);
  int get level => 1 + (xp ~/ 500);
  int get levelXp => xp % 500;
  double get progress => levelXp / 500;

  int _average(Iterable<int> values) {
    final list = values.toList();
    if (list.isEmpty) return 0;
    return (list.reduce((a, b) => a + b) / list.length).round();
  }

  int get average => _average(results.map((e) => e.score));
  int get best => results.isEmpty ? 0 : results.map((e) => e.score).reduce((a, b) => a > b ? a : b);
  int get adaptation => _average(results.map((e) => e.adaptationScore));
  int get stability => _average(results.map((e) => e.stabilityScore));
  int get resource => _average(results.map((e) => e.resourceScore));
  int get decisions => results.fold<int>(0, (sum, item) => sum + item.decisions);

  String get rank {
    if (level >= 10) return 'ELITE OPERATOR';
    if (level >= 7) return 'SENIOR OPERATOR';
    if (level >= 4) return 'TACTICAL OPERATOR';
    if (level >= 2) return 'OPERATOR';
    return 'CADET';
  }

  @override
  Widget build(BuildContext context) {
    final session = UserSessionScope.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final phone = width < 700;

    return Scaffold(
      backgroundColor: TactixTheme.bg,
      appBar: AppBar(
        backgroundColor: TactixTheme.bg,
        elevation: 0,
        title: const Text(
          'ПРОФИЛЬ',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2),
        ),
        actions: [
          if (!session.isServerUser)
            IconButton(
              tooltip: 'Switch local profile',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const UserSwitcherScreen(),
                ),
              ),
              icon: const Icon(
                Icons.switch_account_outlined,
                color: Colors.white70,
              ),
            ),
          if (session.isServerUser)
            IconButton(
              tooltip: 'Sign out',
              onPressed: () async {
                await session.signOut();
                if (context.mounted) {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                }
              },
              icon: const Icon(Icons.logout_rounded, color: Colors.white70),
            ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: loading ? null : _load,
            icon: const Icon(Icons.sync_rounded, color: Colors.white70),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        color: TactixTheme.gold,
        backgroundColor: TactixTheme.panel,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(phone ? 14 : 28, 12, phone ? 14 : 28, 28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1250),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (session.isServerUser) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: TactixTheme.panel,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: TactixTheme.line),
                      ),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          const Text(
                            'SERVER ACCOUNT',
                            style: TextStyle(
                              color: TactixTheme.textMuted,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            session.currentUser!.role.label,
                            style: const TextStyle(
                              color: TactixTheme.gold,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  _ProfileHero(
                    level: level,
                    xp: xp,
                    levelXp: levelXp,
                    progress: progress,
                    rank: rank,
                    aiOnline: aiOnline,
                  ),
                  const SizedBox(height: 16),
                  LayoutBuilder(builder: (context, c) {
                    final two = c.maxWidth >= 850;
                    final gap = 12.0;
                    final w = two ? (c.maxWidth - gap) / 2 : c.maxWidth;
                    return Wrap(
                      spacing: gap,
                      runSpacing: gap,
                      children: [
                        SizedBox(
                          width: w,
                          child: _ProfileOverviewCard(
                            trainings: results.length,
                            decisions: decisions,
                            average: average,
                            best: best,
                          ),
                        ),
                        SizedBox(
                          width: w,
                          child: _ProfileSkillsCard(
                            adaptation: adaptation,
                            stability: stability,
                            resource: resource,
                          ),
                        ),
                      ],
                    );
                  }),
                  const SizedBox(height: 16),
                  const SectionLabel('AI COACH'),
                  const SizedBox(height: 10),
                  _CoachCard(
                    results: results,
                    online: aiOnline,
                    average: average,
                    best: best,
                    adaptation: adaptation,
                    stability: stability,
                    resource: resource,
                  ),
                  const SizedBox(height: 16),
                  const SectionLabel('ДОСТИЖЕНИЯ'),
                  const SizedBox(height: 10),
                  AchievementsPanel(results: results),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileHero extends StatelessWidget {
  final int level;
  final int xp;
  final int levelXp;
  final double progress;
  final String rank;
  final bool aiOnline;

  const _ProfileHero({
    required this.level,
    required this.xp,
    required this.levelXp,
    required this.progress,
    required this.rank,
    required this.aiOnline,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            TactixTheme.panel2,
            TactixTheme.panel,
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: TactixTheme.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: TactixTheme.gold.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: TactixTheme.gold.withValues(alpha: 0.4)),
                ),
                child: const Icon(Icons.person_rounded, color: TactixTheme.gold, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'TACTIX OPERATOR',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 1.0),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      rank,
                      style: const TextStyle(color: TactixTheme.gold, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.3),
                    ),
                  ],
                ),
              ),
              if (aiOnline)
                const StatusChip(text: 'AI ONLINE', online: true)
              else
                const StatusChip(text: 'AI OFFLINE', online: false),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('LEVEL $level', style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.1)),
              Text('$levelXp / 500 XP', style: const TextStyle(color: TactixTheme.textMuted, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 9),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 9,
              backgroundColor: Colors.white10,
              color: TactixTheme.gold,
            ),
          ),
          const SizedBox(height: 10),
          Text('Всего XP: $xp', style: const TextStyle(color: TactixTheme.textMuted, fontSize: 12)),
        ],
      ),
    );
  }
}

class _ProfileOverviewCard extends StatelessWidget {
  final int trainings;
  final int decisions;
  final int average;
  final int best;

  const _ProfileOverviewCard({required this.trainings, required this.decisions, required this.average, required this.best});

  @override
  Widget build(BuildContext context) {
    return PanelCard(
      accent: TactixTheme.cyan,
      title: 'ОБЩАЯ СТАТИСТИКА',
      icon: Icons.query_stats_rounded,
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _MiniProfileStat('Тренировки', '$trainings'),
          _MiniProfileStat('Решения', '$decisions'),
          _MiniProfileStat('Средний балл', '$average'),
          _MiniProfileStat('Лучший результат', '$best'),
        ],
      ),
    );
  }
}

class _MiniProfileStat extends StatelessWidget {
  final String label;
  final String value;
  const _MiniProfileStat(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 145,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.025),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: TactixTheme.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: TactixTheme.textMuted, fontSize: 10)),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _ProfileSkillsCard extends StatelessWidget {
  final int adaptation;
  final int stability;
  final int resource;
  const _ProfileSkillsCard({required this.adaptation, required this.stability, required this.resource});

  @override
  Widget build(BuildContext context) {
    return PanelCard(
      accent: const Color(0xFFAD79FF),
      title: 'КЛЮЧЕВЫЕ НАВЫКИ',
      icon: Icons.tune_rounded,
      child: Column(
        children: [
          _SkillBar(label: 'Адаптация', value: adaptation),
          const SizedBox(height: 12),
          _SkillBar(label: 'Стабильность', value: stability),
          const SizedBox(height: 12),
          _SkillBar(label: 'Ресурсы', value: resource),
        ],
      ),
    );
  }
}

class _SkillBar extends StatelessWidget {
  final String label;
  final int value;
  const _SkillBar({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 90, child: Text(label, style: const TextStyle(color: TactixTheme.textMuted, fontSize: 11))),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: (value / 100).clamp(0.0, 1.0),
              minHeight: 7,
              backgroundColor: Colors.white10,
              color: TactixTheme.cyan,
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(width: 32, child: Text('$value', textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w800))),
      ],
    );
  }
}

class _CoachCard extends StatefulWidget {
  final List<TrainingResult> results;
  final bool online;
  final int average;
  final int best;
  final int adaptation;
  final int stability;
  final int resource;

  const _CoachCard({
    required this.results,
    required this.online,
    required this.average,
    required this.best,
    required this.adaptation,
    required this.stability,
    required this.resource,
  });

  @override
  State<_CoachCard> createState() => _CoachCardState();
}

class _CoachCardState extends State<_CoachCard> {
  bool generating = false;
  String? aiText;
  String? aiError;

  String get recommendedDifficulty {
    if (widget.average >= 90 && widget.adaptation >= 85 && widget.stability >= 80) {
      return 'CHALLENGE';
    }
    if (widget.average >= 80 && widget.adaptation >= 70) {
      return 'ADVANCED';
    }
    if (widget.average >= 60) {
      return 'INTERMEDIATE';
    }
    return 'BEGINNER';
  }

  String get recommendedFocus {
    if (widget.adaptation < 60) return 'АДАПТАЦИЯ';
    if (widget.stability < 65) return 'СТАБИЛЬНОСТЬ';
    if (widget.resource < 65) return 'РЕСУРСЫ';
    return 'АНАЛИТИКА';
  }

  String _localPlan() {
    if (widget.results.isEmpty) {
      return 'Проведи первую учебную тренировку. После неё TACTIX сможет построить персональный план развития.';
    }
    final focus = recommendedFocus;
    final difficulty = recommendedDifficulty;
    final action = switch (focus) {
      'АДАПТАЦИЯ' => 'тренировка с быстро меняющимися условиями среды',
      'СТАБИЛЬНОСТЬ' => 'тренировка с несколькими последовательными решениями без потери качества',
      'РЕСУРСЫ' => 'тренировка с ограниченным запасом учебных ресурсов',
      _ => 'тренировка на точность оценки и последовательность решений',
    };
    return 'ТЕКУЩАЯ ФОРМА: ${widget.average}/100.\n'
        'СИЛЬНАЯ СТОРОНА: ${widget.stability >= widget.adaptation ? 'стабильность' : 'адаптация'}.\n'
        'ЗОНА РОСТА: $focus.\n'
        'СЛЕДУЮЩИЙ ШАГ: $action.\n'
        'РЕКОМЕНДУЕМАЯ СЛОЖНОСТЬ: $difficulty.';
  }

  List<dynamic> _historyForCoach() {
    final recent = widget.results.reversed.take(8).toList().reversed;
    return recent.map((result) => {
      'scenario': result.scenarioTitle,
      'score': result.score,
      'decisions': result.decisions,
      'durationSeconds': result.durationSeconds,
      'resource': result.resourceScore,
      'stability': result.stabilityScore,
      'progress': result.progressScore,
      'adaptation': result.adaptationScore,
    }).toList();
  }

  Future<void> _generateCoach() async {
    if (widget.results.isEmpty) {
      setState(() {
        aiText = _localPlan();
        aiError = 'История пока пуста. Локальный план станет персональным после первой тренировки.';
      });
      return;
    }

    setState(() {
      generating = true;
      aiError = null;
    });

    try {
      final recent = widget.results.reversed.take(8).toList();
      int avg(List<int> values) => values.isEmpty
          ? 0
          : (values.reduce((a, b) => a + b) / values.length).round();

      final avgResource = avg(recent.map((e) => e.resourceScore).toList());
      final avgStability = avg(recent.map((e) => e.stabilityScore).toList());
      final avgProgress = avg(recent.map((e) => e.progressScore).toList());
      final avgAdaptation = avg(recent.map((e) => e.adaptationScore).toList());

      final simulation = SimulationData(
        time: recent.isEmpty
            ? 0
            : avg(recent.map((e) => e.durationSeconds.clamp(0, 1000)).toList()),
        resources: avgResource,
        stability: avgStability,
        progress: avgProgress,
        uncertainty: (100 - avgAdaptation).clamp(0, 100),
      );

      final prompt = '''Ты персональный AI Coach в приложении TACTIX.
Проанализируй последние учебные тренировки оператора и составь краткий персональный план развития.
Все ситуации являются учебными и вымышленными.

Профиль:
Средний балл: ${widget.average}/100
Лучший результат: ${widget.best}/100
Тренировок: ${widget.results.length}
Адаптация: ${widget.adaptation}/100
Стабильность: ${widget.stability}/100
Ресурсы: ${widget.resource}/100

Рекомендованная зона внимания: $recommendedFocus
Рекомендуемая сложность: $recommendedDifficulty

Ответ строго в формате:
1. СИЛЬНАЯ СТОРОНА — одна конкретная сильная сторона.
2. ЗОНА РОСТА — одна конкретная проблема.
3. СЛЕДУЮЩАЯ ТРЕНИРОВКА — одна конкретная учебная задача.
4. СЛОЖНОСТЬ — BEGINNER, INTERMEDIATE, ADVANCED или CHALLENGE.
5. ОЦЕНКА ПРОГРЕССА — один короткий вывод.

Не выдумывай показатели. Используй только профиль и историю.
История: ${_historyForCoach()}''';

      final text = await AIService.analyze(
        situation: prompt,
        decision: 'Сформировать персональный план следующей учебной тренировки.',
        goal: 'Улучшить следующий учебный результат оператора.',
        criteria: const [
          'Опора на статистику',
          'Конкретность',
          'Персонализация',
        ],
        simulation: simulation,
        history: _historyForCoach(),
      );

      if (!mounted) return;
      setState(() {
        aiText = text.trim();
        generating = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        generating = false;
        aiText = _localPlan();
        aiError = 'AI недоступен. Показан локальный персональный план.';
      });
    }
  }

  void _startRecommendedTraining() {
    final idea = switch (recommendedFocus) {
      'АДАПТАЦИЯ' => 'Изменяющиеся условия среды и необходимость быстро адаптировать решение.',
      'СТАБИЛЬНОСТЬ' => 'Последовательные изменения условий при необходимости сохранять стабильность решений.',
      'РЕСУРСЫ' => 'Ограниченные учебные ресурсы и необходимость распределять их на протяжении сценария.',
      _ => 'Аналитическая учебная задача с несколькими вариантами решений и неполной информацией.',
    };

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AIScenarioScreen(
          initialIdea: idea,
          initialDifficulty: recommendedDifficulty == 'CHALLENGE'
              ? 'ADVANCED'
              : recommendedDifficulty,
          initialFocus: recommendedFocus,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayText = aiText ?? _localPlan();
    final live = aiText != null && widget.online;

    return PanelCard(
      accent: TactixTheme.gold,
      title: live ? 'AI COACH • LIVE' : 'AI COACH',
      icon: Icons.auto_awesome_rounded,
      trailing: Text(
        widget.online ? 'GEMMA 3 4B' : 'LOCAL',
        style: const TextStyle(
          color: Colors.white54,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _CoachMetric(label: 'FORM', value: '${widget.average}'),
              _CoachMetric(label: 'ADAPTATION', value: '${widget.adaptation}'),
              _CoachMetric(label: 'STABILITY', value: '${widget.stability}'),
              _CoachMetric(label: 'RESOURCES', value: '${widget.resource}'),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.psychology_rounded, color: TactixTheme.gold, size: 25),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  displayText,
                  style: const TextStyle(
                    color: Colors.white70,
                    height: 1.55,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          if (aiError != null) ...[
            const SizedBox(height: 10),
            Text(
              aiError!,
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 520;
              return compact
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _coachGenerateButton(),
                        const SizedBox(height: 9),
                        _coachStartButton(),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(child: _coachGenerateButton()),
                        const SizedBox(width: 9),
                        Expanded(child: _coachStartButton()),
                      ],
                    );
            },
          ),
        ],
      ),
    );
  }

  Widget _coachGenerateButton() {
    return FilledButton.icon(
      onPressed: generating ? null : _generateCoach,
      icon: generating
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.auto_awesome, size: 18),
      label: Text(
        generating ? 'AI АНАЛИЗИРУЕТ...' : 'ОБНОВИТЬ AI АНАЛИЗ',
      ),
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(44),
        backgroundColor: TactixTheme.gold.withValues(alpha: 0.14),
        foregroundColor: TactixTheme.gold,
        side: BorderSide(color: TactixTheme.gold.withValues(alpha: 0.35)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _coachStartButton() {
    return OutlinedButton.icon(
      onPressed: _startRecommendedTraining,
      icon: const Icon(Icons.play_arrow_rounded, size: 18),
      label: const Text('СЛЕДУЮЩАЯ ТРЕНИРОВКА'),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(44),
        foregroundColor: TactixTheme.cyan,
        side: BorderSide(color: TactixTheme.cyan.withValues(alpha: 0.35)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

class _CoachMetric extends StatelessWidget {
  final String label;
  final String value;

  const _CoachMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.025),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: TactixTheme.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: TactixTheme.textMuted,
              fontSize: 8,
              fontWeight: FontWeight.w800,
              letterSpacing: .7,
            ),
          ),
          const SizedBox(width: 7),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

