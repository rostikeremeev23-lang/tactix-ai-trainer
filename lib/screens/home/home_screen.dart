import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../app/user_session_scope.dart';
import '../../app/assignment_scope.dart';
import '../../models/scenario.dart';
import '../../models/training_result.dart';
import '../../services/environment_service.dart';
import '../../services/ai_service.dart';
import '../../services/result_storage_service.dart';
import '../../widgets/achievements_panel.dart';
import '../../widgets/common_widgets.dart';

import '../analytics/statistics_screen.dart';
import '../ai/ai_chat_screen.dart';
import '../assignments/assignments_screen.dart';
import '../demo/tactix_command_center_screen.dart';
import '../instructor/instructor_mode_screen.dart';
import '../profile/profile_screen.dart';
import '../settings/ai_mode_screen.dart';
import '../scenarios/ai_scenario_screen.dart';
import '../scenarios/create_scenario_screen.dart';
import '../scenarios/my_scenarios_screen.dart';
import '../training/scenario_run_screen.dart';

// =====================================================
// HOME
// =====================================================

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<TrainingResult> results = const [];
  bool loading = true;
  bool aiOnline = false;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    if (mounted) {
      setState(() {
        loading = true;
      });
    }

    try {
      final loaded = await ResultStorageService.load();
      final online = await AIService.isServerAvailable();

      if (!mounted) return;

      setState(() {
        results = loaded;
        aiOnline = online;
        loading = false;
      });
    } catch (_) {
      final online = await AIService.isServerAvailable();

      if (!mounted) return;

      setState(() {
        results = const [];
        aiOnline = online;
        loading = false;
      });
    }
  }

  Future<void> _open(BuildContext context, Widget page) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
    await _loadDashboard();
  }

  int _averageScore() {
    if (results.isEmpty) return 0;
    final total = results.fold<int>(0, (sum, item) => sum + item.score);
    return (total / results.length).round().clamp(0, 100);
  }

  int _bestScore() {
    if (results.isEmpty) return 0;
    return results.map((e) => e.score).reduce((a, b) => a > b ? a : b);
  }

  int _averageMetric(
    int Function(TrainingResult) getter,
  ) {
    final values = results
        .map(getter)
        .where((value) => value > 0)
        .toList();

    if (values.isEmpty) return 0;

    final total =
        values.fold<int>(
      0,
      (sum, value) => sum + value,
    );

    return (total / values.length)
        .round()
        .clamp(0, 100);
  }

  int _averageGoal() =>
      _averageMetric(
        (item) => item.goalScore,
      );

  int _averageResource() =>
      _averageMetric(
        (item) => item.resourceScore,
      );

  int _averageStability() =>
      _averageMetric(
        (item) => item.stabilityScore,
      );

  int _averageUncertainty() =>
      _averageMetric(
        (item) => item.uncertaintyScore,
      );

  int _averageTime() =>
      _averageMetric(
        (item) => item.timeScore,
      );

  int _xp() => results.fold<int>(0, (sum, item) => sum + item.score);

  int _level() => 1 + (_xp() ~/ 500);

  int _levelXp() => _xp() % 500;

  double _levelProgress() => _levelXp() / 500;

  TrainingScenario _offlineDemoScenario() {
    return const TrainingScenario(
      title: 'OFFLINE DEMO • АВТОНОМНЫЙ ЦЕНТР',
      description:
          'После масштабного сбоя инфраструктуры учебный координационный центр работает без внешней сети. Необходимо распределить ограниченные ресурсы, стабилизировать ситуацию и выполнить основную задачу за ограниченное время.',
      time: '50',
      resources: '70',
      conditions:
          'Интернет недоступен. Внешние сервисы отключены. Доступны только локальные данные и встроенный движок TACTIX.',
      optionA:
          'Ускорить выполнение основной задачи, направив больше условного ресурса на быстрый прогресс.',
      optionB:
          'Сохранить сбалансированный режим: контролировать ресурс, устойчивость и темп выполнения.',
      optionC:
          'Сначала снизить неопределённость и уточнить локальные данные перед дальнейшими действиями.',
      goal:
          'Выполнить учебную задачу, сохранив устойчивость системы и достаточный резерв ресурсов.',
      criteria: [
        'Достижение цели',
        'Эффективность ресурсов',
        'Устойчивость',
        'Работа с неопределённостью',
        'Использование времени',
      ],
    );
  }

  Future<void> _openCommandCenter(BuildContext context) async {
    await _open(
      context,
      TactixCommandCenterScreen(
        demoScenario: _offlineDemoScenario(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= 1180;
    final isPhone = width < 700;
    final contentPadding = isPhone ? 14.0 : (isWide ? 28.0 : 20.0);

    return Scaffold(
      backgroundColor: TactixTheme.bg,
      appBar: _buildTopBar(context, isPhone),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1540),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                contentPadding,
                14,
                contentPadding,
                isPhone ? 18 : 26,
              ),
              child: isWide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          width: 212,
                          child: _DesktopSidebar(onOpen: _open),
                        ),
                        const SizedBox(width: 18),
                        Expanded(
                          child: _mainWorkspace(context, isPhone: false),
                        ),
                        const SizedBox(width: 18),
                        SizedBox(
                          width: 290,
                          child: _IntelligencePanel(
                            onOpen: _open,
                            aiOnline: aiOnline,
                            loading: loading,
                            level: _level(),
                            xp: _levelXp(),
                            average: _averageScore(),
                            best: _bestScore(),
                            goal: _averageGoal(),
                            resource: _averageResource(),
                            stability: _averageStability(),
                            uncertainty: _averageUncertainty(),
                            time: _averageTime(),
                            scenarioCount: results.length,
                            levelProgress: _levelProgress(),
                          ),
                        ),
                      ],
                    )
                  : _mainWorkspace(context, isPhone: isPhone),
            ),
          ),
        ),
      ),
      bottomNavigationBar: isWide
          ? null
          : NavigationBar(
              height: isPhone ? 66 : 70,
              backgroundColor: const Color(0xFF081118),
              indicatorColor: TactixTheme.gold.withValues(alpha: 0.16),
              selectedIndex: 0,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.dashboard_outlined),
                  selectedIcon: Icon(Icons.dashboard),
                  label: 'Главная',
                ),
                NavigationDestination(
                  icon: Icon(Icons.description_outlined),
                  selectedIcon: Icon(Icons.description),
                  label: 'Сценарии',
                ),
                NavigationDestination(
                  icon: Icon(Icons.analytics_outlined),
                  selectedIcon: Icon(Icons.analytics),
                  label: 'Аналитика',
                ),
                NavigationDestination(
                  icon: Icon(Icons.forum_outlined),
                  selectedIcon: Icon(Icons.forum),
                  label: 'AI',
                ),
              ],
              onDestinationSelected: (index) {
                if (index == 1) {
                  _open(context, MyScenariosScreen(
                      aiScreenBuilder: () => const AIScenarioScreen(),
                      runScreenBuilder: (scenario) => ScenarioRunScreen(
                        scenario: scenario,
                      ),
                    ));
                } else if (index == 2) {
                  _open(context, const StatisticsScreen());
                } else if (index == 3) {
                  _open(context, const AIChatScreen());
                }
              },
            ),
    );
  }

  PreferredSizeWidget _buildTopBar(BuildContext context, bool compact) {
    return AppBar(
      backgroundColor: TactixTheme.bg,
      toolbarHeight: compact ? 60 : 70,
      titleSpacing: compact ? 12 : 22,
      title: Row(
        children: [
          const _TacticMark(),
          const SizedBox(width: 10),
          const Text(
            'TACTIX',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.0,
            ),
          ),
          if (!compact) ...[
            const SizedBox(width: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: TactixTheme.cyan.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: TactixTheme.cyan.withValues(alpha: 0.28),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.circle,
                    size: 7,
                    color: aiOnline
                        ? const Color(0xFF4EE39A)
                        : const Color(0xFFFFC857),
                  ),
                  const SizedBox(width: 7),
                  Text(
                    AIService.statusLabel,
                    style: TextStyle(
                      color: aiOnline
                          ? const Color(0xFF7FE7B8)
                          : const Color(0xFFFFC857),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${AIService.modeLabel}  |  ${AIService.providerLabel}',
                    style: const TextStyle(
                      color: TactixTheme.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'AI режим',
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const AIModeScreen(),
              ),
            );
            await _loadDashboard();
          },
          icon: const Icon(Icons.hub_outlined, color: Colors.white70),
        ),
        if (!compact)
          IconButton(
            tooltip: 'Обновить данные',
            onPressed: loading ? null : _loadDashboard,
            icon: const Icon(Icons.sync_rounded, color: Colors.white70),
          ),
        IconButton(
          tooltip: 'Уведомления',
onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Новых уведомлений нет.')),
            );
          },
          icon: const Icon(Icons.notifications_none_rounded, color: Colors.white70),
        ),
        Padding(
          padding: EdgeInsets.only(right: compact ? 10 : 20),
          child: IconButton(
            tooltip: 'Профиль',
            onPressed: () => _open(context, const ProfileScreen()),
            style: IconButton.styleFrom(
              backgroundColor: TactixTheme.panel2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.all(8),
            ),
            icon: const Icon(
              Icons.person_outline_rounded,
              size: 20,
              color: Colors.white70,
            ),
          ),
        ),
      ],
    );
  }

  Widget _mainWorkspace(BuildContext context, {required bool isPhone}) {
    final canManageTraining =
        UserSessionScope.of(context).canManageTraining;

    final assignments =
        AssignmentScope.of(context);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HeroCard(
            onTap: () => _open(context, const AIScenarioScreen()),
          ),
          const SizedBox(height: 18),
          _CommandTile(
            icon: Icons.hub_rounded,
            title: 'NU STEP • COMMAND CENTER',
            subtitle: 'Live Demo • Replay • What If • AI Debrief',
            accent: TactixTheme.gold,
            onTap: () => _openCommandCenter(context),
          ),
          const SizedBox(height: 18),
          const SectionLabel('ЖИВЫЕ ДАННЫЕ'),
          const SizedBox(height: 10),
          _DashboardMetrics(
            loading: loading,
            trainings: results.length,
            average: _averageScore(),
            best: _bestScore(),
            goal: _averageGoal(),
            resource: _averageResource(),
            stability: _averageStability(),
            uncertainty: _averageUncertainty(),
            time: _averageTime(),
            level: _level(),
            xp: _levelXp(),
          ),
          const SizedBox(height: 18),
          const SectionLabel('БЫСТРЫЙ ДОСТУП'),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 1120
                  ? 4
                  : constraints.maxWidth >= 650
                      ? 2
                      : 1;
              final tileWidth =
                  (constraints.maxWidth - ((columns - 1) * 12)) / columns;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: tileWidth,
                    child: _CommandTile(
                      icon: Icons.play_arrow_rounded,
                      title: 'ТРЕНИРОВКА',
                      subtitle: results.isEmpty
                          ? 'Запустить первый сценарий'
                          : '${results.length} завершённых тренировок',
                      accent: TactixTheme.gold,
                      onTap: () => _open(context, MyScenariosScreen(
                      aiScreenBuilder: () => const AIScenarioScreen(),
                      runScreenBuilder: (scenario) => ScenarioRunScreen(
                        scenario: scenario,
                      ),
                    )),
                    ),
                  ),
                  SizedBox(
                    width: tileWidth,
                    child: _CommandTile(
                      icon: Icons.assignment_outlined,
                      title: 'НАЗНАЧЕНИЯ',
                      subtitle: assignments.activeCount == 0
                          ? 'Активных заданий нет'
                          : 'Активных: ${assignments.activeCount}',
                      accent: const Color(0xFF4EE39A),
                      onTap: () => _open(
                        context,
                        const AssignmentsScreen(),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: tileWidth,
                    child: _CommandTile(
                      icon: Icons.auto_awesome,
                      title: 'AI СЦЕНАРИЙ',
                      subtitle: 'Создать учебную ситуацию',
                      accent: TactixTheme.cyan,
                      onTap: () => _open(context, const AIScenarioScreen()),
                    ),
                  ),
                  SizedBox(
                    width: tileWidth,
                    child: _CommandTile(
                      icon: Icons.forum_outlined,
                      title: 'TACTIX AI',
                      subtitle: 'Чат • Тренер • Разбор результата',
                      accent: const Color(0xFF74E6FF),
                      onTap: () => _open(context, const AIChatScreen()),
                    ),
                  ),
                  if (canManageTraining)
                    SizedBox(
                      width: tileWidth,
                      child: _CommandTile(
                        icon: Icons.school_outlined,
                        title: 'ИНСТРУКТОР',
                        subtitle: 'Создать и запустить учебную задачу',
                        accent: const Color(0xFFFFC857),
                        onTap: () => _open(
                          context,
                          InstructorModeScreen(
                            runScreenBuilder: (scenario) =>
                                ScenarioRunScreen(
                              scenario: scenario,
                              forceOffline: true,
                            ),
                          ),
                        ),
                      ),
                    ),
                  SizedBox(
                    width: tileWidth,
                    child: _CommandTile(
                      icon: Icons.query_stats_rounded,
                      title: 'АНАЛИТИКА',
                      subtitle: results.isEmpty
                          ? 'Пока нет результатов'
                          : 'Средний балл ${_averageScore()} / 100',
                      accent: const Color(0xFFAD79FF),
                      onTap: () => _open(context, const StatisticsScreen()),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          const SectionLabel('ВНЕШНЯЯ СРЕДА'),
          const SizedBox(height: 10),
          const _EnvironmentDashboard(),
          const SizedBox(height: 18),
          const SectionLabel('ПРОФИЛЬ И ПРОГРЕСС'),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final gap = 12.0;
              final twoColumns = constraints.maxWidth >= 860;
              final cardWidth = twoColumns
                  ? (constraints.maxWidth - gap) / 2
                  : constraints.maxWidth;

              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  SizedBox(
                    width: cardWidth,
                    child: _ProfilePanel(
                      level: _level(),
                      totalXp: _xp(),
                      levelXp: _levelXp(),
                      levelProgress: _levelProgress(),
                      trainings: results.length,
                      average: _averageScore(),
                      best: _bestScore(),
                      goal: _averageGoal(),
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: AchievementsPanel(results: results),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          const SectionLabel('ДИНАМИКА РЕЗУЛЬТАТОВ'),
          const SizedBox(height: 10),
          _ProgressHistoryChart(results: results),
          const SizedBox(height: 18),
          const SectionLabel('РАБОЧАЯ ОБЛАСТЬ'),
          const SizedBox(height: 10),
          _ActivityPanel(
            onOpen: _open,
            results: results,
            loading: loading,
          ),
        ],
      ),
    );
  }
}


// =====================================================
// COMPETITION DEMO
// =====================================================

class _ProfilePanel extends StatelessWidget {
  final int level;
  final int totalXp;
  final int levelXp;
  final double levelProgress;
  final int trainings;
  final int average;
  final int best;
  final int goal;

  const _ProfilePanel({
    required this.level,
    required this.totalXp,
    required this.levelXp,
    required this.levelProgress,
    required this.trainings,
    required this.average,
    required this.best,
    required this.goal,
  });

  @override
  Widget build(BuildContext context) {
    final progress = levelProgress.clamp(0.0, 1.0).toDouble();
    const primary = TactixTheme.textMuted;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: TactixTheme.panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: TactixTheme.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: primary.withValues(alpha: 0.10),
                  border: Border.all(
                    color: primary.withValues(alpha: 0.16),
                  ),
                ),
                child: Center(
                  child: Text(
                    level.toString(),
                    style: TextStyle(
                      color: primary,
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ПРОФИЛЬ',
                      style: TextStyle(
                        color: TactixTheme.textMuted,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'TACTIX OPERATOR',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .5,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '$totalXp XP',
                style: TextStyle(
                  color: primary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'ПРОГРЕСС УРОВНЯ',
                style: TextStyle(
                  color: TactixTheme.textMuted,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
              ),
              Text(
                '$levelXp / 500 XP',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              backgroundColor: TactixTheme.line,
              color: TactixTheme.textMuted,
            ),
          ),
          const SizedBox(height: 15),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _ProfileStat(label: 'ТРЕНИРОВКИ', value: '$trainings'),
              _ProfileStat(label: 'СРЕДНИЙ', value: '$average'),
              _ProfileStat(label: 'ЛУЧШИЙ', value: '$best'),
              _ProfileStat(label: 'ЦЕЛЬ', value: '$goal%'),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfileStat extends StatelessWidget {
  final String label;
  final String value;

  const _ProfileStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 105,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.028),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: TactixTheme.textMuted,
              fontSize: 8,
              fontWeight: FontWeight.w800,
              letterSpacing: .7,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressHistoryChart extends StatelessWidget {
  final List<TrainingResult> results;

  const _ProgressHistoryChart({required this.results});

  @override
  Widget build(BuildContext context) {
    final values = results.reversed.take(8).map((e) => e.score).toList().reversed.toList();

    return Container(
      height: values.length < 2 ? 120 : 235,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: TactixTheme.panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: TactixTheme.line),
      ),
      child: values.length < 2
          ? _empty(context)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.show_chart_rounded, size: 18, color: TactixTheme.cyan),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'ПОСЛЕДНИЕ РЕЗУЛЬТАТЫ',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    Text(
                      '${values.last}/100',
                      style: const TextStyle(
                        color: TactixTheme.cyan,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: CustomPaint(
                    painter: _ScoreChartPainter(
                      values: values,
                      lineColor: TactixTheme.cyan,
                      gridColor: TactixTheme.line,
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _empty(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.show_chart_outlined, size: 26, color: Colors.white24),
          const SizedBox(height: 9),
          Text(
            'Нужно минимум 2 завершённые тренировки',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: TactixTheme.textMuted,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreChartPainter extends CustomPainter {
  final List<int> values;
  final Color lineColor;
  final Color gridColor;

  const _ScoreChartPainter({
    required this.values,
    required this.lineColor,
    required this.gridColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final chart = Rect.fromLTWH(32, 8, size.width - 44, size.height - 28);
    final gridPaint = Paint()
      ..color = gridColor.withValues(alpha: .55)
      ..strokeWidth = 1;
    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final dotPaint = Paint()..color = lineColor;

    for (int i = 0; i <= 4; i++) {
      final y = chart.top + chart.height * i / 4;
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), gridPaint);
      final label = '${100 - i * 25}';
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(color: Colors.white38, fontSize: 8),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(0, y - 5));
    }

    final step = values.length == 1 ? 0 : chart.width / (values.length - 1);
    final path = Path();
    final points = <Offset>[];

    for (int i = 0; i < values.length; i++) {
      final v = values[i].clamp(0, 100);
      final x = chart.left + step * i;
      final y = chart.bottom - (v / 100) * chart.height;
      final point = Offset(x, y);
      points.add(point);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, linePaint);

    for (int i = 0; i < points.length; i++) {
      canvas.drawCircle(points[i], 4.5, dotPaint);
      final tp = TextPainter(
        text: TextSpan(
          text: values[i].toString(),
          style: const TextStyle(color: Colors.white70, fontSize: 8, fontWeight: FontWeight.w700),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(points[i].dx - tp.width / 2, points[i].dy - 17));
    }
  }

  @override
  bool shouldRepaint(covariant _ScoreChartPainter oldDelegate) {
    return oldDelegate.values != values;
  }
}

class _DashboardMetrics extends StatelessWidget {
  final bool loading;
  final int trainings;
  final int average;
  final int best;
  final int goal;
  final int resource;
  final int stability;
  final int uncertainty;
  final int time;
  final int level;
  final int xp;

  const _DashboardMetrics({
    required this.loading,
    required this.trainings,
    required this.average,
    required this.best,
    required this.goal,
    required this.resource,
    required this.stability,
    required this.uncertainty,
    required this.time,
    required this.level,
    required this.xp,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const SizedBox(
        height: 180,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _liveCard('ТРЕНИРОВКИ', '$trainings', Icons.track_changes_rounded, TactixTheme.gold),
        _liveCard('СРЕДНИЙ БАЛЛ', '$average', Icons.insights_rounded, TactixTheme.cyan),
        _liveCard('ЛУЧШИЙ РЕЗУЛЬТАТ', '$best', Icons.emoji_events_outlined, const Color(0xFF4EE39A)),
        _liveCard('ЦЕЛЬ', '$goal%', Icons.flag_outlined, const Color(0xFFAD79FF)),
        _liveCard('РЕСУРСЫ', '$resource%', Icons.battery_4_bar_outlined, const Color(0xFF7AB8FF)),
        _liveCard('УСТОЙЧИВОСТЬ', '$stability%', Icons.shield_outlined, const Color(0xFF69D5C5)),
        _liveCard('НЕОПРЕДЕЛЁННОСТЬ', '$uncertainty%', Icons.psychology_outlined, const Color(0xFFFF9E67)),
        _liveCard('ВРЕМЯ', '$time%', Icons.schedule_outlined, const Color(0xFFFFC857)),
        _liveCard('УРОВЕНЬ', '$level', Icons.military_tech_outlined, TactixTheme.gold),
      ],
    );
  }

  Widget _liveCard(String title, String value, IconData icon, Color accent) {
    return SizedBox(
      width: 150,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: TactixTheme.panel,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: TactixTheme.line),
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: accent, size: 19),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: TactixTheme.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DesktopSidebar extends StatelessWidget {
  final void Function(BuildContext, Widget) onOpen;

  const _DesktopSidebar({required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final canManageTraining =
        UserSessionScope.of(context).canManageTraining;

    return Container(
      decoration: BoxDecoration(
        color: TactixTheme.panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: TactixTheme.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 18, 16, 12),
            child: Text(
              'NAVIGATION',
              style: TextStyle(
                color: TactixTheme.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ),
          _nav(context, Icons.dashboard_rounded, 'Главная', true, null),
          _nav(
            context,
            Icons.track_changes_rounded,
            'Тренировка',
            false,
            MyScenariosScreen(
                      aiScreenBuilder: () => const AIScenarioScreen(),
                      runScreenBuilder: (scenario) => ScenarioRunScreen(
                        scenario: scenario,
                      ),
                    ),
          ),
          _nav(
            context,
            Icons.auto_awesome_rounded,
            'AI Сценарий',
            false,
            const AIScenarioScreen(),
          ),
          if (canManageTraining)
            _nav(
              context,
              Icons.add_box_outlined,
              'Создать',
              false,
              const CreateScenarioScreen(),
            ),
          _nav(
            context,
            Icons.description_outlined,
            'Сценарии',
            false,
            MyScenariosScreen(
                      aiScreenBuilder: () => const AIScenarioScreen(),
                      runScreenBuilder: (scenario) => ScenarioRunScreen(
                        scenario: scenario,
                      ),
                    ),
          ),
          _nav(
            context,
            Icons.bar_chart_rounded,
            'Аналитика',
            false,
            const StatisticsScreen(),
          ),
          const Spacer(),
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: TactixTheme.cyan.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: TactixTheme.cyan.withValues(alpha: 0.18),
              ),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.hub_outlined, size: 16, color: TactixTheme.cyan),
                    SizedBox(width: 8),
                    Text(
                      'SYSTEM STATUS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  'Система готова к тренировке',
                  style: TextStyle(fontSize: 11, color: Colors.white70),
                ),
                SizedBox(height: 8),
                LinearProgressIndicator(value: 1, minHeight: 4),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _nav(
    BuildContext context,
    IconData icon,
    String title,
    bool active,
    Widget? target,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: target == null ? null : () => onOpen(context, target),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 11),
          decoration: BoxDecoration(
            color: active
                ? TactixTheme.gold.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: active
                  ? TactixTheme.gold.withValues(alpha: 0.38)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 19,
                color: active ? TactixTheme.gold : Colors.white60,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: active ? Colors.white : Colors.white70,
                    fontSize: 13,
                    fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                  ),
                ),
              ),
              if (active)
                Container(
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(
                    color: TactixTheme.gold,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}


class _EnvironmentDashboard extends StatefulWidget {
  const _EnvironmentDashboard();

  @override
  State<_EnvironmentDashboard> createState() => _EnvironmentDashboardState();
}

class _EnvironmentDashboardState extends State<_EnvironmentDashboard> {
  EnvironmentData? data;
  bool loading = true;
  bool syncedOnline = false;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        loading = true;
        error = null;
      });
    }

    try {
      final value = await EnvironmentService.fetch();

      if (!mounted) return;

      setState(() {
        data = value;
        loading = false;
        syncedOnline = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        loading = false;
        syncedOnline = false;
        error = 'Локальные данные среды недоступны.';
      });
    }
  }

  Future<void> _sync() async {
    if (mounted) {
      setState(() {
        loading = true;
        error = null;
      });
    }

    final value = await EnvironmentService.syncRemote();

    if (!mounted) return;

    setState(() {
      data = value;
      loading = false;
      syncedOnline = true;
    });
  }

  String _timeLabel(DateTime time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    return PanelCard(
      title: 'ENVIRONMENT MONITOR',
      icon: Icons.public_rounded,
      accent: TactixTheme.textMuted,
      trailing: TextButton.icon(
        onPressed: loading ? null : _sync,
        icon: const Icon(Icons.refresh_rounded, size: 15),
        label: const Text('SYNC'),
        style: TextButton.styleFrom(
          foregroundColor: TactixTheme.cyan,
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
      child: data == null && loading
          ? const SizedBox(
              height: 90,
              child: Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          : data == null
              ? Row(
                  children: [
                    const Icon(Icons.cloud_off_rounded, color: TactixTheme.textMuted),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        error ?? 'Внешние данные пока недоступны.',
                        style: const TextStyle(color: TactixTheme.textMuted, height: 1.4),
                      ),
                    ),
                    FilledButton.tonal(
                      onPressed: _load,
                      child: const Text('ПОВТОРИТЬ'),
                    ),
                  ],
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 620;
                    final weather = data!;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                EnvironmentService.zoneName,
                                style: const TextStyle(
                                  color: TactixTheme.textMuted,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.1,
                                ),
                              ),
                            ),
                            StatusChip(
                              text: syncedOnline
                                  ? 'LIVE • ${_timeLabel(weather.updatedAt)}'
                                  : 'LOCAL • ${_timeLabel(weather.updatedAt)}',
                              online: syncedOnline,
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            _EnvironmentMetric(
                              icon: weather.isDay ? Icons.wb_sunny_outlined : Icons.nightlight_outlined,
                              label: 'ТЕМПЕРАТУРА',
                              value: '${weather.temperature.toStringAsFixed(1)}°C',
                              accent: TactixTheme.gold,
                            ),
                            _EnvironmentMetric(
                              icon: Icons.water_drop_outlined,
                              label: 'ВЛАЖНОСТЬ',
                              value: '${weather.humidity}%',
                              accent: TactixTheme.cyan,
                            ),
                            _EnvironmentMetric(
                              icon: Icons.air_rounded,
                              label: 'ВЕТЕР',
                              value: '${weather.windKmh.toStringAsFixed(0)} км/ч',
                              accent: const Color(0xFFAD79FF),
                            ),
                            _EnvironmentMetric(
                              icon: Icons.visibility_outlined,
                              label: 'ВИДИМОСТЬ',
                              value: weather.visibilityLabel,
                              accent: const Color(0xFF4EE39A),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.025),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: TactixTheme.line),
                          ),
                          child: compact
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(weather.weatherLabel, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
                                    const SizedBox(height: 5),
                                    const Text(
                                      'Внешние параметры доступны для следующего шага — адаптивной сложности сценариев.',
                                      style: TextStyle(color: TactixTheme.textMuted, fontSize: 11, height: 1.4),
                                    ),
                                  ],
                                )
                              : Row(
                                  children: [
                                    Icon(
                                      weather.isDay ? Icons.wb_sunny_rounded : Icons.nightlight_round,
                                      color: TactixTheme.gold,
                                      size: 22,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(weather.weatherLabel, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
                                          const SizedBox(height: 4),
                                          const Text(
                                            'Внешние параметры доступны для следующего шага — адаптивной сложности сценариев.',
                                            style: TextStyle(color: TactixTheme.textMuted, fontSize: 11, height: 1.4),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ],
                    );
                  },
                ),
    );
  }
}

class _EnvironmentMetric extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  const _EnvironmentMetric({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: TactixTheme.panel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: TactixTheme.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accent.withValues(alpha: 0.65), size: 16),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              color: TactixTheme.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: .7,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _IntelligencePanel extends StatelessWidget {
  final void Function(BuildContext, Widget) onOpen;
  final bool aiOnline;
  final bool loading;
  final int level;
  final int xp;
  final int average;
  final int best;
  final int goal;
  final int resource;
  final int stability;
  final int uncertainty;
  final int time;
  final int scenarioCount;
  final double levelProgress;

  const _IntelligencePanel({
    required this.onOpen,
    required this.aiOnline,
    required this.loading,
    required this.level,
    required this.xp,
    required this.average,
    required this.best,
    required this.goal,
    required this.resource,
    required this.stability,
    required this.uncertainty,
    required this.time,
    required this.scenarioCount,
    required this.levelProgress,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          PanelCard(
            title: 'AI СТАТУС',
            icon: Icons.auto_awesome,
            accent: TactixTheme.cyan,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.circle,
                      size: 8,
                      color: aiOnline
                          ? const Color(0xFF4EE39A)
                          : const Color(0xFFFFC857),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      AIService.statusLabel,
                      style: TextStyle(
                        color: aiOnline
                            ? const Color(0xFF70E6AF)
                            : const Color(0xFFFFC857),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Text(
                  '${AIService.modeLabel}  •  ${AIService.providerLabel}',
                  style: const TextStyle(
                    color: TactixTheme.textMuted,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 16),
                _metric('СРЕДНИЙ БАЛЛ', '$average%', TactixTheme.cyan),
                const SizedBox(height: 10),
                _metric('ЛУЧШИЙ РЕЗУЛЬТАТ', '$best%', TactixTheme.gold),
                const SizedBox(height: 10),
                _metric('ЦЕЛЬ', '$goal%', const Color(0xFFAD79FF)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          PanelCard(
            title: 'ПРОГРЕСС',
            icon: Icons.insights_rounded,
            accent: TactixTheme.gold,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Уровень $level',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                    ),
                    const Spacer(),
                    Text(
                      '$xp / 500 XP',
                      style: const TextStyle(color: TactixTheme.textMuted, fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: LinearProgressIndicator(
                    value: levelProgress.clamp(0.0, 1.0),
                    minHeight: 7,
                    backgroundColor: Colors.white10,
                  ),
                ),
                const SizedBox(height: 14),
                _MetricPair(left: 'Тренировок', right: '$scenarioCount'),
                const SizedBox(height: 8),
                _MetricPair(left: 'Цель', right: '$goal%'),
                const SizedBox(height: 8),
                _MetricPair(left: 'Ресурсы', right: '$resource%'),
                const SizedBox(height: 8),
                _MetricPair(left: 'Устойчивость', right: '$stability%'),
                const SizedBox(height: 8),
                _MetricPair(left: 'Неопределённость', right: '$uncertainty%'),
                const SizedBox(height: 8),
                _MetricPair(left: 'Время', right: '$time%'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          PanelCard(
            title: 'БЫСТРАЯ ДИАГНОСТИКА',
            icon: Icons.monitor_heart_outlined,
            accent: const Color(0xFF4EE39A),
            child: Column(
              children: [
                _DiagnosticRow(
                  label: 'Backend',
                  value: aiOnline ? 'ONLINE' : 'OFFLINE',
                  ok: aiOnline,
                ),
                _DiagnosticRow(label: 'Ollama', value: aiOnline ? 'ONLINE' : 'CHECK', ok: aiOnline),
                _DiagnosticRow(
                  label: 'Данные',
                  value: loading ? 'SYNC...' : '$scenarioCount результатов',
                  ok: !loading,
                ),
                _DiagnosticRow(label: 'Отчёты', value: 'READY', ok: true),
              ],
            ),
          ),
          const SizedBox(height: 12),
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => onOpen(context, const AIScenarioScreen()),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1B2025), Color(0xFF11171D)],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: TactixTheme.gold.withValues(alpha: 0.30),
                ),
              ),
              child: const Row(
                children: [
                  Icon(Icons.auto_awesome, color: TactixTheme.gold, size: 22),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Запусти AI-сценарий\nдля новой тренировки',
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.35,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios_rounded, size: 14),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metric(String label, String value, Color accent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: TactixTheme.panel,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: TactixTheme.line),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: TactixTheme.textMuted,
                fontSize: 11,
                letterSpacing: 0.2,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: accent.withValues(alpha: 0.8),
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricPair extends StatelessWidget {
  final String left;
  final String right;

  const _MetricPair({required this.left, required this.right});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            left,
            style: const TextStyle(color: TactixTheme.textMuted, fontSize: 12),
          ),
        ),
        Text(
          right,
          style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _DiagnosticRow extends StatelessWidget {
  final String label;
  final String value;
  final bool ok;

  const _DiagnosticRow({required this.label, required this.value, required this.ok});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: TactixTheme.textMuted, fontSize: 12),
            ),
          ),
          Icon(
            Icons.circle,
            size: 7,
            color: ok ? const Color(0xFF4EE39A) : Colors.redAccent,
          ),
          const SizedBox(width: 6),
          Text(
            value,
            style: TextStyle(
              color: ok ? TactixTheme.textMuted : Colors.redAccent,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityPanel extends StatelessWidget {
  final void Function(BuildContext, Widget) onOpen;
  final List<TrainingResult> results;
  final bool loading;

  const _ActivityPanel({
    required this.onOpen,
    required this.results,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Container(
        height: 180,
        decoration: BoxDecoration(
          color: TactixTheme.panel,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: TactixTheme.line),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    final recent = List<TrainingResult>.from(results)
      ..sort((a, b) => b.date.compareTo(a.date));
    final visibleRecent = recent.take(5).toList();

    return Container(
      decoration: BoxDecoration(
        color: TactixTheme.panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: TactixTheme.line),
      ),
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 15, 16, 11),
            child: Row(
              children: [
                Text(
                  'ПОСЛЕДНЯЯ АКТИВНОСТЬ',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
                Spacer(),
                Text(
                  'РЕАЛЬНЫЕ ДАННЫЕ',
                  style: TextStyle(
                    color: TactixTheme.textMuted,
                    fontSize: 9,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: TactixTheme.line),
          if (visibleRecent.isEmpty)
            const Padding(
              padding: EdgeInsets.all(28),
              child: Column(
                children: [
                  Icon(Icons.insights_outlined, size: 34, color: Colors.white38),
                  SizedBox(height: 10),
                  Text(
                    'Пока нет завершённых тренировок',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'После прохождения сценария результаты появятся здесь автоматически.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: TactixTheme.textMuted, fontSize: 10, height: 1.4),
                  ),
                ],
              ),
            )
          else
            ...visibleRecent.asMap().entries.map((entry) {
              final result = entry.value;
              final last = entry.key == visibleRecent.length - 1;
              return _resultRow(context, result, last: last);
            }),
        ],
      ),
    );
  }

  Widget _resultRow(
    BuildContext context,
    TrainingResult result, {
    required bool last,
  }) {
    final score = result.score;
    final color = score >= 85
        ? const Color(0xFF4EE39A)
        : score >= 65
            ? TactixTheme.gold
            : const Color(0xFFFF7E7E);

    return InkWell(
      onTap: () => onOpen(context, const StatisticsScreen()),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          border: last
              ? null
              : const Border(bottom: BorderSide(color: TactixTheme.line)),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.09),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: color.withValues(alpha: 0.22)),
              ),
              child: Icon(Icons.track_changes_rounded, size: 17, color: color),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result.scenarioTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${result.decisions} решений  •  ${result.durationSeconds ~/ 60} мин ${result.durationSeconds % 60} с',
                    style: const TextStyle(color: TactixTheme.textMuted, fontSize: 9),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$score/100',
                style: TextStyle(
                  color: color,
                  fontSize: 8.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_ios_rounded, size: 11, color: Colors.white30),
          ],
        ),
      ),
    );
  }
}

class _TacticMark extends StatelessWidget {
  const _TacticMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: TactixTheme.gold.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: TactixTheme.gold.withValues(alpha: 0.45)),
      ),
      child: const Icon(Icons.shield_outlined, size: 19, color: TactixTheme.gold),
    );
  }
}

class _HeroCard extends StatelessWidget {
  final VoidCallback onTap;

  const _HeroCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isPhone = MediaQuery.sizeOf(context).width < 700;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: EdgeInsets.all(isPhone ? 16 : 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [TactixTheme.panel2, TactixTheme.panel],
          ),
          border: Border.all(color: TactixTheme.gold.withValues(alpha: 0.24)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _HeroContent(),
            const SizedBox(height: 16),
            _heroButton(),
          ],
        ),
      ),
    );
  }

  Widget _heroButton() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 220;

        return Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 10 : 16,
            vertical: 16,
          ),
          decoration: BoxDecoration(
            color: TactixTheme.gold,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: TactixTheme.gold.withValues(alpha: 0.42),
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.play_arrow_rounded,
                color: TactixTheme.bg,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  compact ? 'НАЧАТЬ' : 'НАЧАТЬ ТРЕНИРОВКУ',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: TactixTheme.bg,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.arrow_forward_rounded,
                color: TactixTheme.bg,
                size: 17,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HeroContent extends StatelessWidget {
  const _HeroContent();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'TACTIX',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
        SizedBox(height: 5),
        Text(
          'ИНТЕЛЛЕКТУАЛЬНАЯ ПЛАТФОРМА\nДЛЯ ТРЕНИРОВОК И ПРИНЯТИЯ РЕШЕНИЙ',
          style: TextStyle(
            fontSize: 14,
            height: 1.35,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Сценарии • AI-анализ • симуляция • статистика',
          style: TextStyle(
            color: TactixTheme.textMuted,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _CommandTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback onTap;

  const _CommandTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        constraints: const BoxConstraints(minHeight: 88),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: TactixTheme.panel,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: TactixTheme.line),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: accent, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: TactixTheme.textMuted,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.arrow_forward_rounded,
              color: TactixTheme.textMuted,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================
// INSTRUCTOR MODE
// =====================================================

// =====================================================
// MANUAL SCENARIO CREATOR
// =====================================================

// =====================================================
// MY SCENARIOS
// =====================================================

// =====================================================
// TRAINING
// =====================================================
