import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/responsive.dart';
import '../../app/theme.dart';
import '../../models/decision_record.dart';
import '../../models/scenario.dart';
import '../../models/training_result.dart';
import '../../services/ai_service.dart';
import '../../services/environment_service.dart';
import '../../services/result_storage_service.dart';
import '../../services/simulation_engine.dart';
import '../../services/storage_service.dart';
import '../../widgets/common_widgets.dart';

class ScenarioRunScreen
    extends StatefulWidget {
  final TrainingScenario scenario;
  final bool forceOffline;

  final Future<void> Function(
    int score,
  )? onCompleted;

  const ScenarioRunScreen({
    super.key,
    required this.scenario,
    this.forceOffline = false,
    this.onCompleted,
  });

  @override
  State<ScenarioRunScreen> createState() =>
      _ScenarioRunScreenState();
}

class _EnvironmentImpactPanel extends StatelessWidget {
  final EnvironmentData? data;
  final bool loading;
  final String impactLabel;
  final int difficultyScore;

  const _EnvironmentImpactPanel({
    required this.data,
    required this.loading,
    required this.impactLabel,
    required this.difficultyScore,
  });

  @override
  Widget build(BuildContext context) {
    final env = data;

    return PanelCard(
      title: 'ADAPTIVE ENVIRONMENT',
      icon: Icons.tune_rounded,
      accent: TactixTheme.gold,
      trailing: Text(
        loading ? 'SYNC...' : impactLabel,
        style: const TextStyle(
          color: TactixTheme.gold,
          fontSize: 9,
          fontWeight: FontWeight.w900,
          letterSpacing: .8,
        ),
      ),
      child: loading && env == null
          ? const SizedBox(
              height: 55,
              child: Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          : env == null
              ? const Text(
                  'Внешние параметры пока недоступны. Симуляция работает в базовом режиме.',
                  style: TextStyle(
                    color: TactixTheme.textMuted,
                    fontSize: 11,
                    height: 1.4,
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'СРЕДА ВЛИЯЕТ НА СИМУЛЯЦИЮ',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: .9,
                            ),
                          ),
                        ),
                        Text(
                          '$difficultyScore / 43',
                          style: const TextStyle(
                            color: TactixTheme.textMuted,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: (difficultyScore / 43).clamp(0.0, 1.0),
                        minHeight: 7,
                        backgroundColor: Colors.white10,
                        color: TactixTheme.gold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Ветер ${env.windKmh.toStringAsFixed(0)} км/ч • Видимость ${env.visibilityLabel} • ${env.weatherLabel}',
                      style: const TextStyle(
                        color: TactixTheme.textMuted,
                        fontSize: 11,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      'Параметры среды увеличивают неопределённость и/или ресурсную нагрузку в учебной симуляции.',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 10,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _ScenarioRunScreenState
    extends State<ScenarioRunScreen> {
  final ScrollController scrollController =
      ScrollController();

  late SimulationState state;

  final List<DecisionRecord>
      history = [];

  Timer? timer;

  int elapsedSeconds = 0;

  String? selectedOption;

  String currentSituation = '';

  String currentEvent = '';

  String currentFocus = '';

  String currentOptionA = '';
  String currentOptionB = '';
  String currentOptionC = '';

  int runVersion = 0;

  String? aiAnalysis;

  String? aiSummary;

  DecisionScore? lastDecisionScore;
  StateDelta? lastStateDelta;

  List<String> lastEvents = [];

  bool processing = false;

  bool completed = false;

  bool showResult = false;

  EnvironmentData? environment;
  bool environmentLoading = false;

  @override
  void initState() {
    super.initState();

    state = SimulationState(
      time: parseNumber(
        widget.scenario.time,
        45,
      ).clamp(0, 120),
      resources:
          parseNumber(
        widget.scenario.resources,
        80,
      ).clamp(0, 100),
      stability: 75,
      progress: 20,
      uncertainty: 25,
      turn: 1,
    );

    currentSituation =
        widget.scenario.description;

    currentOptionA =
        widget.scenario.optionA;
    currentOptionB =
        widget.scenario.optionB;
    currentOptionC =
        widget.scenario.optionC;

    if (!widget.forceOffline) {
      _loadTrainingEnvironment();
    }

    timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        if (!mounted ||
            completed) {
          return;
        }

        setState(() {
          elapsedSeconds++;
        });
      },
    );
  }

  Future<void> _loadTrainingEnvironment() async {
    if (mounted) {
      setState(() {
        environmentLoading = true;
      });
    }

    final cached = EnvironmentService.lastData;

    try {
      final value = await EnvironmentService.fetch();

      if (!mounted) return;

      setState(() {
        environment = value;
        environmentLoading = false;
      });

      _applyEnvironmentToCurrentState(value);
    } catch (_) {
      if (!mounted) return;

      setState(() {
        environment = cached;
        environmentLoading = false;
      });

      if (cached != null) {
        _applyEnvironmentToCurrentState(cached);
      }
    }
  }

  int _environmentUncertaintyDelta(EnvironmentData value) {
    int delta = 0;

    if (value.windKmh >= 35) {
      delta += 10;
    } else if (value.windKmh >= 20) {
      delta += 6;
    } else if (value.windKmh >= 12) {
      delta += 2;
    }

    if (value.visibilityMeters > 0) {
      if (value.visibilityMeters < 2000) {
        delta += 10;
      } else if (value.visibilityMeters < 5000) {
        delta += 5;
      }
    }

    if ([45, 48, 51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 71, 73, 75, 77, 80, 81, 82].contains(value.weatherCode)) {
      delta += 3;
    }

    if ([95, 96, 99].contains(value.weatherCode)) {
      delta += 8;
    }

    if (value.temperature >= 35 || value.temperature <= -15) {
      delta += 4;
    }

    return delta.clamp(0, 25);
  }

  int _environmentResourceDelta(EnvironmentData value) {
    int delta = 0;

    if (value.windKmh >= 35) {
      delta += 8;
    } else if (value.windKmh >= 20) {
      delta += 4;
    } else if (value.windKmh >= 12) {
      delta += 2;
    }

    if (value.visibilityMeters > 0 && value.visibilityMeters < 2000) {
      delta += 5;
    } else if (value.visibilityMeters > 0 && value.visibilityMeters < 5000) {
      delta += 2;
    }

    if ([95, 96, 99].contains(value.weatherCode)) {
      delta += 5;
    } else if ([61, 63, 65, 66, 67, 71, 73, 75, 77, 80, 81, 82, 85, 86].contains(value.weatherCode)) {
      delta += 2;
    }

    if (value.temperature >= 35 || value.temperature <= -15) {
      delta += 3;
    }

    return delta.clamp(0, 18);
  }

  SimulationState _applyEnvironmentModifiers(
    SimulationState value,
    EnvironmentData env,
  ) {
    final uncertaintyDelta = _environmentUncertaintyDelta(env);
    final resourceDelta = _environmentResourceDelta(env);

    return SimulationState(
      time: value.time,
      resources: (value.resources - resourceDelta).clamp(0, 100),
      stability: (value.stability - (uncertaintyDelta ~/ 3)).clamp(0, 100),
      progress: value.progress,
      uncertainty: (value.uncertainty + uncertaintyDelta).clamp(0, 100),
      turn: value.turn,
    );
  }

  void _applyEnvironmentToCurrentState(EnvironmentData env) {
    final adjusted = _applyEnvironmentModifiers(state, env);

    if (!mounted) return;

    setState(() {
      state = adjusted;
      currentFocus = _environmentFocus(env);
    });
  }

  String _environmentFocus(EnvironmentData env) {
    final uncertainty = _environmentUncertaintyDelta(env);
    final resource = _environmentResourceDelta(env);

    if (uncertainty >= 15) {
      return 'Внешняя среда повышает неопределённость. Рекомендуется принимать решения с дополнительной проверкой условий.';
    }

    if (resource >= 8) {
      return 'Внешняя среда увеличивает ресурсную нагрузку. Удерживайте сбалансированный темп.';
    }

    if (uncertainty > 0 || resource > 0) {
      return 'Условия среды умеренно влияют на неопределённость и ресурсную нагрузку.';
    }

    return 'Условия среды стабильны. Дополнительная адаптация не требуется.';
  }

  int environmentDifficultyScore() {
    final value = environment;
    if (value == null) return 0;
    return (_environmentUncertaintyDelta(value) +
            _environmentResourceDelta(value))
        .clamp(0, 43);
  }

  String environmentImpactLabel() {
    final score = environmentDifficultyScore();

    if (score >= 25) return 'HIGH LOAD';
    if (score >= 12) return 'MODERATE';
    if (score > 0) return 'LOW IMPACT';
    return 'STABLE';
  }

  int parseNumber(
    String text,
    int fallback,
  ) {
    final match =
        RegExp(r'\d+').firstMatch(text);

    if (match == null) {
      return fallback;
    }

    return int.tryParse(
          match.group(0)!,
        ) ??
        fallback;
  }

  String formatTime() {
    final minutes =
        elapsedSeconds ~/ 60;

    final seconds =
        elapsedSeconds % 60;

    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  List<String> historyForAI() {
    return history
        .map(
          (record) =>
              'Ход ${record.turn}: решение ${record.decision}, оценка ${record.score}/100',
        )
        .toList();
  }

  String decisionText(
    String choice,
  ) {
    switch (choice) {
      case 'A':
        return currentOptionA;
      case 'B':
        return currentOptionB;
      case 'C':
        return currentOptionC;
      default:
        return '';
    }
  }

  String buildAISituation() {
    return '''
Сценарий:
${widget.scenario.title}

Исходное описание:
${widget.scenario.description}

Условия:
${widget.scenario.conditions}

Текущая учебная вводная:
$currentSituation

Текущее событие:
$currentEvent

Текущий фокус:
$currentFocus

Текущие варианты:
A: $currentOptionA
B: $currentOptionB
C: $currentOptionC

Текущий ход:
${state.turn}
''';
  }

  void updateDynamicOptions(
    SimulationState value,
  ) {
    final variant = runVersion % 3;

    if (value.turn <= 1) {
      if (variant == 0) {
        currentOptionA =
            'Ускорить продвижение по основной учебной цели, принимая более высокую нагрузку.';
        currentOptionB =
            'Сохранить сбалансированный темп и равномерно распределить условный ресурс.';
        currentOptionC =
            'Сначала уточнить ситуацию и уменьшить неопределённость.';
      } else if (variant == 1) {
        currentOptionA =
            'Сделать ставку на быстрый прогресс, допустив больший расход ресурса.';
        currentOptionB =
            'Выбрать умеренный темп с контролем устойчивости и ресурса.';
        currentOptionC =
            'Сначала получить дополнительную информацию и снизить неопределённость.';
      } else {
        currentOptionA =
            'Приоритетно продвинуть учебную задачу, принимая повышенную нагрузку.';
        currentOptionB =
            'Поддерживать равновесие между прогрессом, ресурсом и устойчивостью.';
        currentOptionC =
            'Сделать паузу для уточнения условий и уменьшения неопределённости.';
      }
      return;
    }

    if (value.turn == 2) {
      if (variant == 0) {
        currentOptionA =
            'Ускорить продвижение по основной учебной цели, принимая более высокую нагрузку.';
        currentOptionB =
            'Сохранить сбалансированный темп и распределить условный ресурс равномерно.';
        currentOptionC =
            'Сначала уточнить ситуацию и уменьшить неопределённость.';
      } else if (variant == 1) {
        currentOptionA =
            'Сконцентрировать больше условных ресурсов на ускорении прогресса.';
        currentOptionB =
            'Сохранить устойчивый режим и не допустить резкого расхода ресурса.';
        currentOptionC =
            'Снизить неопределённость перед следующим решением.';
      } else {
        currentOptionA =
            'Продолжить активное продвижение, увеличив допустимую нагрузку.';
        currentOptionB =
            'Удерживать сбалансированный режим с умеренным прогрессом.';
        currentOptionC =
            'Отдать приоритет уточнению условий перед дальнейшим продвижением.';
      }
      return;
    }

    if (value.turn >= 3) {
      if (variant == 0) {
        currentOptionA =
            'Завершить основную учебную задачу с максимальным темпом.';
        currentOptionB =
            'Выбрать наиболее устойчивый путь завершения сценария.';
        currentOptionC =
            'Проверить остаточные риски и затем завершить учебную задачу.';
      } else if (variant == 1) {
        currentOptionA =
            'Сделать финальный рывок к учебной цели, используя более высокий темп.';
        currentOptionB =
            'Завершить сценарий через наиболее устойчивый и сбалансированный вариант.';
        currentOptionC =
            'Сначала перепроверить оставшиеся риски и после этого завершить задачу.';
      } else {
        currentOptionA =
            'Поставить завершение цели выше сохранения части ресурса.';
        currentOptionB =
            'Закрыть задачу через контролируемый и устойчивый вариант.';
        currentOptionC =
            'Уточнить остаточные риски перед окончательным решением.';
      }
    }
  }

  int calculateTurnScore(
    SimulationState value,
  ) {
    double score = 0;

    score +=
        value.resources * 0.25;

    score +=
        value.stability * 0.25;

    score +=
        value.progress * 0.35;

    score +=
        (100 -
                value.uncertainty) *
            0.15;

    return score
        .round()
        .clamp(0, 100);
  }

  int averageScore(
    List<DecisionRecord> values,
  ) {
    if (values.isEmpty) {
      return 0;
    }

    final total =
        values.fold<int>(
      0,
      (sum, item) =>
          sum + item.score,
    );

    return (total /
            values.length)
        .round()
        .clamp(0, 100);
  }

  int averageDecisionMetric(
    List<DecisionRecord> values,
    int Function(DecisionRecord item) selector,
  ) {
    if (values.isEmpty) {
      return 0;
    }

    final total = values.fold<int>(
      0,
      (sum, item) => sum + selector(item),
    );

    return (total / values.length)
        .round()
        .clamp(0, 100);
  }

  Future<void> makeDecision(
    String decision,
  ) async {
    if (processing ||
        completed) {
      return;
    }

    setState(() {
      processing = true;
      showResult = false;
      aiAnalysis = null;
      aiSummary = null;
    });

    try {
      // ==========================================
      // 1. SIMULATION
      // ==========================================

      final engine =
          SimulationEngine();

      final result =
          engine.applyDecision(
        state,
        decision,
      );

      final rawState = result.state;
      final newState = environment == null
          ? rawState
          : _applyEnvironmentModifiers(rawState, environment!);

      // TACTIX Score считается локально и детерминированно.
      // Если внешняя среда изменила состояние, пересчитываем
      // оценку уже по фактическому состоянию после всех модификаторов.
      final decisionScore = engine.scoreDecision(
        before: state,
        after: newState,
      );

      final stateDelta = StateDelta(
        time: newState.time - state.time,
        resources: newState.resources - state.resources,
        stability: newState.stability - state.stability,
        progress: newState.progress - state.progress,
        uncertainty: newState.uncertainty - state.uncertainty,
      );

      final chosenDecisionText = decisionText(decision);
      final chosenSituation = buildAISituation();

      updateDynamicOptions(newState);

      final simulationData =
          SimulationData(
        time:
            newState.time,
        resources:
            newState.resources,
        stability:
            newState.stability,
        progress:
            newState.progress,
        uncertainty:
            newState.uncertainty,
      );

      // ==========================================
      // 2. AI / LOCAL OFFLINE EXPLANATION
      // ==========================================

      String analysis;
      String summary;
      bool aiAvailableForTurn = false;

      if (widget.forceOffline) {
        analysis =
            AIService.localObjectiveScoreExplanation(
          decision:
              '$decision: $chosenDecisionText',
          objectiveScore:
              decisionScore.total,
          level:
              decisionScore.level,
          scoreBreakdown: {
            'goal': decisionScore.goal,
            'resources': decisionScore.resources,
            'stability': decisionScore.stability,
            'uncertainty': decisionScore.uncertainty,
            'time': decisionScore.time,
          },
          stateDelta:
              stateDelta.toJson(),
        );

        summary =
            AIService.localSummary(
          simulation:
              simulationData,
          events:
              result.events,
        );
      } else {
        analysis =
            AIService.localObjectiveScoreExplanation(
          decision:
              '$decision: $chosenDecisionText',
          objectiveScore:
              decisionScore.total,
          level:
              decisionScore.level,
          scoreBreakdown: {
            'goal': decisionScore.goal,
            'resources': decisionScore.resources,
            'stability': decisionScore.stability,
            'uncertainty': decisionScore.uncertainty,
            'time': decisionScore.time,
          },
          stateDelta:
              stateDelta.toJson(),
        );

        summary =
            AIService.localSummary(
          simulation:
              simulationData,
          events:
              result.events,
        );

        aiAvailableForTurn = await AIService.isServerAvailable();

        if (aiAvailableForTurn) {
          try {
            analysis =
                await AIService.explainObjectiveScore(
              situation:
                  chosenSituation,
              decision:
                  '$decision: $chosenDecisionText',
              goal:
                  widget.scenario.goal,
              criteria:
                  widget.scenario.criteria,
              objectiveScore:
                  decisionScore.total,
              level:
                  decisionScore.level,
              scoreBreakdown: {
                'goal': decisionScore.goal,
                'resources': decisionScore.resources,
                'stability': decisionScore.stability,
                'uncertainty': decisionScore.uncertainty,
                'time': decisionScore.time,
              },
              stateDelta:
                  stateDelta.toJson(),
              simulation:
                  simulationData,
              history:
                  historyForAI(),
            );
          } catch (_) {
            aiAvailableForTurn = false;
          }
        }

        if (aiAvailableForTurn) {
          try {
            summary =
                await AIService
                    .generateSituationSummary(
              situation:
                  chosenSituation,
              simulation:
                  simulationData,
              events:
                  result.events,
              history:
                  historyForAI(),
            );
          } catch (_) {
            aiAvailableForTurn = false;
          }
        }
      }

      // ==========================================
      // 3. RECORD
      // ==========================================

      final record =
          DecisionRecord(
        turn:
            state.turn,
        decision:
            decision,
        score:
            decisionScore.total,
        goalScore:
            decisionScore.goal,
        resourceScore:
            decisionScore.resources,
        stabilityScore:
            decisionScore.stability,
        uncertaintyScore:
            decisionScore.uncertainty,
        timeScore:
            decisionScore.time,
        level:
            decisionScore.level,
        delta:
            stateDelta.toJson(),
      );

      final updatedHistory =
          List<DecisionRecord>.from(
        history,
      )..add(record);

      final isCompleted =
          result.completed;

      // ==========================================
      // 4. NEXT SITUATION
      // ==========================================

      String nextSituation =
          result.summary;

      String nextEvent =
          result.events.isNotEmpty
              ? result.events.last
              : '';

      String nextFocus =
          environment == null
              ? 'Следите за изменением состояния симуляции.'
              : _environmentFocus(environment!);

      if (!isCompleted && !widget.forceOffline && aiAvailableForTurn) {
        try {
          final next =
              await AIService
                  .generateNextSituation(
            scenario:
                widget.scenario
                    .description,
            history:
                updatedHistory
                    .map(
                      (item) =>
                          'Ход ${item.turn}: решение ${item.decision}',
                    )
                    .toList(),
            events:
                result.events,
            simulation:
                simulationData,
            turn:
                newState.turn,
          );

          nextSituation =
              next.situation;

          nextEvent =
              next.event;

          nextFocus =
              next.focus;
        } catch (_) {
          // Остаёмся на локальной вводной.
        }
      }

      // ==========================================
      // 5. SAVE RESULT
      // ==========================================

      if (isCompleted) {
        final finalScore =
            averageScore(
          updatedHistory,
        );

        final finalResult =
            TrainingResult(
          scenarioTitle:
              widget.scenario.title,
          date:
              DateTime.now(),
          score:
              finalScore,
          decisions:
              updatedHistory.length,
          durationSeconds:
              elapsedSeconds,
          resourceScore:
              averageDecisionMetric(
            updatedHistory,
            (item) => item.resourceScore,
          ),
          stabilityScore:
              averageDecisionMetric(
            updatedHistory,
            (item) => item.stabilityScore,
          ),
          progressScore:
              newState.progress,
          adaptationScore:
              (100 -
                      newState
                          .uncertainty)
                  .clamp(0, 100),
          goalScore:
              averageDecisionMetric(
            updatedHistory,
            (item) => item.goalScore,
          ),
          uncertaintyScore:
              averageDecisionMetric(
            updatedHistory,
            (item) => item.uncertaintyScore,
          ),
          timeScore:
              averageDecisionMetric(
            updatedHistory,
            (item) => item.timeScore,
          ),
          level:
              finalScore >= 85
                  ? 'Отлично'
                  : finalScore >= 70
                      ? 'Хорошо'
                      : finalScore >= 55
                          ? 'Удовлетворительно'
                          : 'Требует развития',
          outcome:
              result.outcome,
          decisionHistory:
              updatedHistory
                  .map(
                    (item) =>
                        'Ход ${item.turn}: ${item.decision} — ${item.score}/100 (${item.level})',
                  )
                  .toList(),
        );

        await ResultStorageService.save(
          finalResult,
        );

        if (widget.onCompleted != null) {
          await widget.onCompleted!(
            finalScore,
          );
        }
      }

      if (!mounted) return;

      setState(() {
        state = newState;

        history
          ..clear()
          ..addAll(
            updatedHistory,
          );

        lastEvents =
            result.events;

        aiAnalysis =
            analysis;

        aiSummary =
            summary;

        lastDecisionScore =
            decisionScore;
        lastStateDelta =
            stateDelta;

        currentSituation =
            nextSituation;

        currentEvent =
            nextEvent;

        currentFocus =
            nextFocus;

        completed =
            isCompleted;

        selectedOption =
            null;

        showResult = true;
        processing = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        processing = false;
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content:
              Text('Ошибка: $e'),
        ),
      );
    }
  }

  Future<void> saveCurrentScenario() async {
    try {
      final savedScenario =
          TrainingScenario(
        title:
            widget.scenario.title,
        description:
            widget.scenario.description,
        time:
            widget.scenario.time,
        resources:
            widget.scenario.resources,
        conditions:
            widget.scenario.conditions,
        optionA:
            currentOptionA.isNotEmpty
                ? currentOptionA
                : widget.scenario.optionA,
        optionB:
            currentOptionB.isNotEmpty
                ? currentOptionB
                : widget.scenario.optionB,
        optionC:
            currentOptionC.isNotEmpty
                ? currentOptionC
                : widget.scenario.optionC,
        goal:
            widget.scenario.goal,
        criteria:
            widget.scenario.criteria,
      );

      await ScenarioStorage.save(
        savedScenario,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Сценарий сохранён.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content:
              Text('Ошибка сохранения: $e'),
        ),
      );
    }
  }

  void resetTraining() {
    setState(() {
      runVersion++;

      state = SimulationState(
        time:
            parseNumber(
          widget.scenario.time,
          45,
        ).clamp(0, 120),
        resources:
            parseNumber(
          widget.scenario.resources,
          80,
        ).clamp(0, 100),
        stability: 75,
        progress: 20,
        uncertainty: 25,
        turn: 1,
      );

      history.clear();

      elapsedSeconds = 0;

      currentSituation =
          widget.scenario.description;

      currentOptionA = '';
      currentOptionB = '';
      currentOptionC = '';

      updateDynamicOptions(
        SimulationState(
          time: parseNumber(
            widget.scenario.time,
            45,
          ).clamp(0, 120),
          resources: parseNumber(
            widget.scenario.resources,
            80,
          ).clamp(0, 100),
          stability: 75,
          progress: 20,
          uncertainty: 25,
          turn: 1,
        ),
      );

      currentEvent = '';
      currentFocus = '';

      aiAnalysis = null;
      aiSummary = null;
      lastDecisionScore = null;
      lastStateDelta = null;
      lastEvents = [];

      selectedOption = null;

      processing = false;
      completed = false;
      showResult = false;
    });

    if (environment != null) {
      _applyEnvironmentToCurrentState(environment!);
    } else {
      _loadTrainingEnvironment();
    }
  }

  Future<void> nextTurn() async {
    if (processing || completed) {
      return;
    }

    setState(() {
      showResult = false;
      selectedOption = null;
      aiAnalysis = null;
      aiSummary = null;
      lastDecisionScore = null;
      lastStateDelta = null;
      lastEvents = [];
    });

    await Future.delayed(
      const Duration(
        milliseconds: 100,
      ),
    );

    if (!mounted) return;

    await scrollController.animateTo(
      0,
      duration:
          const Duration(
        milliseconds: 350,
      ),
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    timer?.cancel();
    scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final score =
        averageScore(history);
    final progress =
        (history.length / 3)
            .clamp(0.0, 1.0);
    final primary =
        Theme.of(context)
            .colorScheme
            .primary;

    return Scaffold(
      appBar: AppBar(
        title:
            const Text(
          'ЦЕНТР ТРЕНИРОВКИ',
        ),
        actions: [
          IconButton(
            onPressed:
                processing
                    ? null
                    : saveCurrentScenario,
            tooltip:
                'Сохранить сценарий',
            icon:
                const Icon(
              Icons.save_outlined,
            ),
          ),
          IconButton(
            onPressed:
                processing
                    ? null
                    : resetTraining,
            tooltip:
                'Начать заново',
            icon:
                const Icon(
              Icons.restart_alt,
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          controller:
              scrollController,
          padding: EdgeInsets.fromLTRB(
            TactixResponsive.horizontalPadding(context),
            12,
            TactixResponsive.horizontalPadding(context),
            28,
          ),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.stretch,
            children: [
              Container(
                padding:
                    EdgeInsets.all(widget.forceOffline ? 18 : 14),
                decoration: BoxDecoration(
                  borderRadius:
                      BorderRadius.circular(
                    20,
                  ),
                  border:
                      Border.all(
                    color: Colors.white12,
                  ),
                  gradient:
                      LinearGradient(
                    begin:
                        Alignment.topLeft,
                    end:
                        Alignment.bottomRight,
                    colors: [
                      primary.withValues(
                        alpha: widget.forceOffline ? .20 : .06,
                      ),
                      Colors.white.withValues(
                        alpha: .04,
                      ),
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: widget.forceOffline ? 46 : 38,
                          height: widget.forceOffline ? 46 : 38,
                          decoration:
                              BoxDecoration(
                            borderRadius:
                                BorderRadius
                                    .circular(
                              14,
                            ),
                            color:
                                primary
                                    .withValues(
                              alpha: .18,
                            ),
                          ),
                          child: Icon(
                            Icons
                                .psychology_alt_outlined,
                            color:
                                primary,
                          ),
                        ),
                        const SizedBox(
                          width: 12,
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment
                                    .start,
                            children: [
                              Text(
                                widget.scenario.title,
                                maxLines: 2,
                                overflow:
                                    TextOverflow.ellipsis,
                                style:
                                    const TextStyle(
                                  fontSize: 21,
                                  fontWeight:
                                      FontWeight.w800,
                                ),
                              ),
                              const SizedBox(
                                height: 4,
                              ),
                              Text(
                                completed
                                    ? 'ТРЕНИРОВКА ЗАВЕРШЕНА'
                                    : 'АДАПТИВНАЯ СИМУЛЯЦИЯ',
                                style:
                                    TextStyle(
                                  color:
                                      primary,
                                  fontSize: 11,
                                  fontWeight:
                                      FontWeight.w800,
                                  letterSpacing:
                                      1.1,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _StatusPill(
                          preserveDemo: widget.forceOffline,
                          label:
                              completed
                                  ? 'ГОТОВО'
                                  : processing
                                      ? 'AI'
                                      : 'LIVE',
                          icon:
                              completed
                                  ? Icons
                                      .check_circle_outline
                                  : processing
                                      ? Icons
                                          .auto_awesome
                                      : Icons
                                          .circle,
                        ),
                      ],
                    ),
                    SizedBox(
                      height: widget.forceOffline ? 18 : 12,
                    ),
                    Row(
                      children: [
                        Text(
                          'ЭТАП ${state.turn.clamp(1, 3)} ИЗ 3',
                          style:
                              const TextStyle(
                            fontSize: 12,
                            fontWeight:
                                FontWeight.w800,
                            letterSpacing: .8,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          formatTime(),
                          style:
                              const TextStyle(
                            fontFeatures: [
                              FontFeature
                                  .tabularFigures(),
                            ],
                            fontWeight:
                                FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(
                      height: 9,
                    ),
                    ClipRRect(
                      borderRadius:
                          BorderRadius.circular(
                        99,
                      ),
                      child:
                          LinearProgressIndicator(
                        minHeight: widget.forceOffline ? 7 : 4,
                        value: progress,
                        backgroundColor:
                            Colors.white10,
                      ),
                    ),
                    const SizedBox(
                      height: 8,
                    ),
                    const Text(
                      'ПРОГРЕСС ПО ХОДАМ',
                      style: TextStyle(
                        color:
                            Colors.white54,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              if (widget.scenario.goal.isNotEmpty ||
                  widget.scenario.conditions.isNotEmpty) ...[
                PanelCard(
                  title:
                      'БРИФИНГ СЦЕНАРИЯ',
                  icon: Icons
                      .assignment_turned_in_outlined,
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .stretch,
                    children: [
                      if (widget.scenario.goal.isNotEmpty) ...[
                        _MiniLabel(
                          preserveDemo: widget.forceOffline,
                          text: 'ЦЕЛЬ',
                        ),
                        const SizedBox(
                          height: 5,
                        ),
                        Text(
                          widget.scenario.goal,
                          style:
                              const TextStyle(
                            fontSize: 14,
                            height: 1.45,
                            fontWeight:
                                FontWeight.w700,
                          ),
                        ),
                      ],
                      if (widget.scenario.goal.isNotEmpty &&
                          widget.scenario.conditions.isNotEmpty)
                        const SizedBox(
                          height: 12,
                        ),
                      if (widget.scenario.conditions.isNotEmpty) ...[
                        _MiniLabel(
                          preserveDemo: widget.forceOffline,
                          text:
                              'УЧЕБНЫЕ УСЛОВИЯ',
                        ),
                        const SizedBox(
                          height: 5,
                        ),
                        Text(
                          widget.scenario.conditions,
                          style:
                              const TextStyle(
                            fontSize: 14,
                            height: 1.45,
                            color:
                                Colors.white70,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              const SectionTitle(
                text:
                    'МОНИТОРИНГ СОСТОЯНИЯ',
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 9,
                runSpacing: 9,
                children: [
                  _TrainingMetricCard(
                    preserveDemo: widget.forceOffline,
                    title: 'Время',
                    value:
                        '${state.time} мин',
                    icon: Icons
                        .schedule_outlined,
                    progress:
                        (state.time / 120)
                            .clamp(0.0, 1.0),
                  ),
                  _TrainingMetricCard(
                    preserveDemo: widget.forceOffline,
                    title: 'Ресурсы',
                    value:
                        '${state.resources}%',
                    icon: Icons
                        .battery_4_bar_outlined,
                    progress:
                        state.resources / 100,
                  ),
                  _TrainingMetricCard(
                    preserveDemo: widget.forceOffline,
                    title:
                        'Стабильность',
                    value:
                        '${state.stability}%',
                    icon: Icons
                        .shield_outlined,
                    progress:
                        state.stability / 100,
                  ),
                  _TrainingMetricCard(
                    preserveDemo: widget.forceOffline,
                    title: 'Прогресс',
                    value:
                        '${state.progress}%',
                    icon: Icons.trending_up,
                    progress:
                        state.progress / 100,
                  ),
                  _TrainingMetricCard(
                    preserveDemo: widget.forceOffline,
                    title:
                        'Неопределённость',
                    value:
                        '${state.uncertainty}%',
                    icon:
                        Icons.help_outline,
                    progress:
                        state.uncertainty /
                            100,
                    inverted: true,
                  ),
                ],
              ),
              if (environment != null || environmentLoading) ...[
                _EnvironmentImpactPanel(
                  data: environment,
                  loading: environmentLoading,
                  impactLabel: environmentImpactLabel(),
                  difficultyScore: environmentDifficultyScore(),
                ),
                const SizedBox(height: 16),
              ],
              const SizedBox(height: 16),
              PanelCard(
                title:
                    'ТЕКУЩАЯ УЧЕБНАЯ ВВОДНАЯ',
                icon:
                    Icons.radar_outlined,
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .stretch,
                  children: [
                    Text(
                      currentSituation,
                      style:
                          const TextStyle(
                        fontSize: 15,
                        height: 1.55,
                      ),
                    ),
                    if (currentEvent.isNotEmpty) ...[
                      const SizedBox(
                        height: 14,
                      ),
                      _SignalBlock(
                        preserveDemo: widget.forceOffline,
                        title:
                            'НОВОЕ СОБЫТИЕ',
                        icon: Icons.bolt,
                        text:
                            currentEvent,
                      ),
                    ],
                    if (currentFocus.isNotEmpty) ...[
                      const SizedBox(
                        height: 10,
                      ),
                      _SignalBlock(
                        preserveDemo: widget.forceOffline,
                        title: 'ФОКУС',
                        icon: Icons
                            .center_focus_strong,
                        text:
                            currentFocus,
                      ),
                    ],
                  ],
                ),
              ),
              if (history.isNotEmpty) ...[
                const SizedBox(height: 16),
                PanelCard(
                  title:
                      'ЖУРНАЛ РЕШЕНИЙ',
                  icon:
                      Icons.route_outlined,
                  accent: widget.forceOffline ? null : TactixTheme.textMuted,
                  trailing: Text(
                    'Средняя оценка: $score',
                    style:
                        const TextStyle(
                      fontSize: 12,
                      color:
                          Colors.white60,
                    ),
                  ),
                  child: Column(
                    children:
                        history.map(
                      (item) => Padding(
                        padding:
                            EdgeInsets.only(
                          bottom:
                              item ==
                                      history
                                          .last
                                  ? 0
                                  : 8,
                        ),
                        child:
                            _HistoryRow(
                          preserveDemo: widget.forceOffline,
                          item: item,
                        ),
                      ),
                    ).toList(),
                  ),
                ),
              ],
              const SizedBox(height: 18),
              Row(
                children: [
                  const Expanded(
                    child: SectionTitle(
                      text:
                          'ПРИНЯТИЕ РЕШЕНИЯ',
                    ),
                  ),
                  if (selectedOption !=
                      null)
                    _StatusPill(
                          preserveDemo: widget.forceOffline,
                      label:
                          'ВЫБОР ${selectedOption!}',
                      icon:
                          Icons.touch_app_outlined,
                    ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Выберите один вариант. После подтверждения симуляция рассчитает последствия и AI сформирует разбор.',
                style: TextStyle(
                  color:
                      Colors.white54,
                  fontSize: 12,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 12),
              widget.forceOffline
                  ? DecisionButton(
                letter: 'A',
                text: currentOptionA,
                selected:
                    selectedOption == 'A',
                enabled:
                    !processing &&
                        !completed,
                onTap: () => setState(
                  () => selectedOption = 'A',
                ),
              )
                  : Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Material(
                        color: selectedOption == 'A'
                            ? TactixTheme.gold.withValues(alpha: 0.06)
                            : TactixTheme.panel,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: selectedOption == 'A'
                                ? TactixTheme.gold
                                : TactixTheme.line,
                            width: selectedOption == 'A' ? 2 : 1,
                          ),
                        ),
                        child: InkWell(
                          onTap: !processing && !completed
                              ? () => setState(
                                    () => selectedOption = 'A',
                                  )
                              : null,
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: selectedOption == 'A'
                                        ? TactixTheme.gold
                                        : TactixTheme.panel2,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    'A',
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      color: selectedOption == 'A'
                                          ? TactixTheme.bg
                                          : Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Text(
                                    currentOptionA,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      height: 1.5,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Icon(
                                  selectedOption == 'A'
                                      ? Icons.check_circle
                                      : Icons.radio_button_unchecked,
                                  size: 22,
                                  color: selectedOption == 'A'
                                      ? TactixTheme.gold
                                      : TactixTheme.textMuted,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
              widget.forceOffline
                  ? DecisionButton(
                letter: 'B',
                text: currentOptionB,
                selected:
                    selectedOption == 'B',
                enabled:
                    !processing &&
                        !completed,
                onTap: () => setState(
                  () => selectedOption = 'B',
                ),
              )
                  : Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Material(
                        color: selectedOption == 'B'
                            ? TactixTheme.gold.withValues(alpha: 0.06)
                            : TactixTheme.panel,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: selectedOption == 'B'
                                ? TactixTheme.gold
                                : TactixTheme.line,
                            width: selectedOption == 'B' ? 2 : 1,
                          ),
                        ),
                        child: InkWell(
                          onTap: !processing && !completed
                              ? () => setState(
                                    () => selectedOption = 'B',
                                  )
                              : null,
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: selectedOption == 'B'
                                        ? TactixTheme.gold
                                        : TactixTheme.panel2,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    'B',
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      color: selectedOption == 'B'
                                          ? TactixTheme.bg
                                          : Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Text(
                                    currentOptionB,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      height: 1.5,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Icon(
                                  selectedOption == 'B'
                                      ? Icons.check_circle
                                      : Icons.radio_button_unchecked,
                                  size: 22,
                                  color: selectedOption == 'B'
                                      ? TactixTheme.gold
                                      : TactixTheme.textMuted,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
              widget.forceOffline
                  ? DecisionButton(
                letter: 'C',
                text: currentOptionC,
                selected:
                    selectedOption == 'C',
                enabled:
                    !processing &&
                        !completed,
                onTap: () => setState(
                  () => selectedOption = 'C',
                ),
              )
                  : Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Material(
                        color: selectedOption == 'C'
                            ? TactixTheme.gold.withValues(alpha: 0.06)
                            : TactixTheme.panel,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: selectedOption == 'C'
                                ? TactixTheme.gold
                                : TactixTheme.line,
                            width: selectedOption == 'C' ? 2 : 1,
                          ),
                        ),
                        child: InkWell(
                          onTap: !processing && !completed
                              ? () => setState(
                                    () => selectedOption = 'C',
                                  )
                              : null,
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: selectedOption == 'C'
                                        ? TactixTheme.gold
                                        : TactixTheme.panel2,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    'C',
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      color: selectedOption == 'C'
                                          ? TactixTheme.bg
                                          : Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Text(
                                    currentOptionC,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      height: 1.5,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Icon(
                                  selectedOption == 'C'
                                      ? Icons.check_circle
                                      : Icons.radio_button_unchecked,
                                  size: 22,
                                  color: selectedOption == 'C'
                                      ? TactixTheme.gold
                                      : TactixTheme.textMuted,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
              const SizedBox(height: 4),
              FilledButton.icon(
                style: widget.forceOffline
                    ? null
                    : FilledButton.styleFrom(
                        backgroundColor: TactixTheme.gold,
                        foregroundColor: TactixTheme.bg,
                        disabledBackgroundColor: TactixTheme.panel2,
                        disabledForegroundColor: TactixTheme.textMuted,
                        elevation: 0,
                        minimumSize: const Size.fromHeight(56),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                onPressed:
                    selectedOption ==
                                null ||
                            processing ||
                            completed
                        ? null
                        : () => makeDecision(
                              selectedOption!,
                            ),
                icon: processing
                    ? const SizedBox(
                        width: 19,
                        height: 19,
                        child:
                            CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(
                        Icons.check_circle_outline,
                      ),
                label: Padding(
                  padding:
                      const EdgeInsets.symmetric(
                    vertical: 15,
                  ),
                  child: Text(
                    processing
                        ? (widget.forceOffline
                            ? 'LOCAL ENGINE ОБРАБАТЫВАЕТ…'
                            : 'AI ОБРАБАТЫВАЕТ РЕШЕНИЕ…')
                        : 'ПОДТВЕРДИТЬ РЕШЕНИЕ',
                    style:
                        const TextStyle(
                      fontWeight:
                          FontWeight.w800,
                      letterSpacing: .3,
                    ),
                  ),
                ),
              ),
              if (showResult) ...[
                const SizedBox(height: 20),
                PanelCard(
                  title:
                      completed
                          ? 'ФИНАЛЬНЫЙ РЕЗУЛЬТАТ'
                          : 'РЕЗУЛЬТАТ ХОДА',
                  icon:
                      completed
                          ? Icons
                              .emoji_events_outlined
                          : Icons
                              .insights_outlined,
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .stretch,
                    children: [
                      if (lastDecisionScore != null &&
                          lastStateDelta != null) ...[
                        _TactixDecisionScoreCard(
                          preserveDemo: widget.forceOffline,
                          score: lastDecisionScore!,
                          delta: lastStateDelta!,
                        ),
                        const SizedBox(height: 14),
                      ],
                      if (lastEvents.isNotEmpty)
                        ...lastEvents.map(
                          (event) =>
                              Padding(
                            padding:
                                const EdgeInsets
                                    .only(
                              bottom: 8,
                            ),
                            child: Row(
                              crossAxisAlignment:
                                  CrossAxisAlignment
                                      .start,
                              children: [
                                const Padding(
                                  padding:
                                      EdgeInsets.only(
                                    top: 3,
                                  ),
                                  child:
                                      Icon(
                                    Icons
                                        .chevron_right,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(
                                  width: 4,
                                ),
                                Expanded(
                                  child: Text(
                                    event,
                                    style:
                                        const TextStyle(
                                      height:
                                          1.45,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (aiSummary != null) ...[
                        const SizedBox(
                          height: 12,
                        ),
                        _SignalBlock(
                        preserveDemo: widget.forceOffline,
                          title:
                              'AI-СВОДКА',
                          icon: Icons
                              .auto_awesome,
                          text:
                              aiSummary!,
                        ),
                      ],
                      if (aiAnalysis != null) ...[
                        const SizedBox(
                          height: 10,
                        ),
                        ExpansionTile(
                          tilePadding:
                              EdgeInsets.zero,
                          childrenPadding:
                              const EdgeInsets
                                  .fromLTRB(
                            0,
                            0,
                            0,
                            4,
                          ),
                          title:
                              const Text(
                            'AI-АНАЛИЗ',
                          ),
                          leading:
                              const Icon(
                            Icons
                                .analytics_outlined,
                          ),
                          children: [
                            Align(
                              alignment:
                                  Alignment
                                      .centerLeft,
                              child:
                                  SelectableText(
                                aiAnalysis!,
                                style:
                                    const TextStyle(
                                  height:
                                      1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                if (completed)
                  FinishCard(
                    score: score,
                    history: history,
                    state: state,
                    scenarioTitle: widget.scenario.title,
                    goal: widget.scenario.goal,
                    durationSeconds: elapsedSeconds,
                    aiExplanation: aiAnalysis ?? '',
                    onRestart:
                        resetTraining,
                  )
                else
                  OutlinedButton.icon(
                    onPressed:
                        processing
                            ? null
                            : nextTurn,
                    icon: const Icon(
                      Icons
                          .arrow_forward_rounded,
                    ),
                    label: Padding(
                      padding:
                          const EdgeInsets
                              .symmetric(
                        vertical: 13,
                      ),
                      child: Text(
                        'ПРОДОЛЖИТЬ в†’ ХОД ${state.turn}',
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}


// TACTIX SCORE CARD


class _TactixDecisionScoreCard extends StatelessWidget {
  final DecisionScore score;
  final StateDelta delta;
  final bool preserveDemo;

  const _TactixDecisionScoreCard({
    required this.score,
    required this.delta,
    this.preserveDemo = false,
  });

  String _delta(int value) {
    if (value > 0) return '+$value';
    return '$value';
  }

  Color _scoreColor(int value) {
    if (value >= 85) return const Color(0xFF4EE39A);
    if (value >= 70) return TactixTheme.gold;
    if (value >= 55) return const Color(0xFFFF9F43);
    return const Color(0xFFFF5D6C);
  }

  @override
  Widget build(BuildContext context) {
    final color = _scoreColor(score.total);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: preserveDemo ? color.withValues(alpha: 0.06) : TactixTheme.panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: color.withValues(alpha: preserveDemo ? 0.30 : 0.22),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      preserveDemo ? 'TACTIX SCORE' : 'TACTIX SCORE\nScore этого хода',
                      style: TextStyle(
                        color: TactixTheme.textMuted,
                        fontSize: preserveDemo ? 9 : 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: preserveDemo ? 1.5 : 0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      score.level.toUpperCase(),
                      style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .8,
                      ),
                    ),
                  ],
                ),
              ),
              Text.rich(
                TextSpan(
                  text: '${score.total}',
                  style: TextStyle(
                    color: color,
                    fontSize: preserveDemo ? 30 : 46,
                    fontWeight: FontWeight.w900,
                  ),
                  children: [
                    TextSpan(
                      text: '/100',
                      style: preserveDemo
                          ? null
                          : const TextStyle(
                              color: TactixTheme.textMuted,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _TactixMetricChip(preserveDemo: preserveDemo, label: 'ЦЕЛЬ', value: score.goal),
              _TactixMetricChip(preserveDemo: preserveDemo, label: 'РЕСУРСЫ', value: score.resources),
              _TactixMetricChip(preserveDemo: preserveDemo, label: 'УСТОЙЧИВОСТЬ', value: score.stability),
              _TactixMetricChip(preserveDemo: preserveDemo, label: preserveDemo ? 'НЕОПРЕД.' : 'НЕОПРЕДЕЛЁННОСТЬ', value: score.uncertainty),
              _TactixMetricChip(preserveDemo: preserveDemo, label: 'ВРЕМЯ', value: score.time),
            ],
          ),
          Container(
            height: preserveDemo ? 14 : 1,
            margin: preserveDemo ? EdgeInsets.zero : const EdgeInsets.symmetric(vertical: 16),
            color: preserveDemo ? null : TactixTheme.line,
          ),
          Text(
            'ИЗМЕНЕНИЕ СОСТОЯНИЯ',
            style: TextStyle(
              color: TactixTheme.textMuted,
              fontSize: preserveDemo ? 9 : 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 7,
            children: [
              Text('Время ${_delta(delta.time)}'),
              Text('Ресурс ${_delta(delta.resources)}'),
              Text('Устойчивость ${_delta(delta.stability)}'),
              Text('Прогресс ${_delta(delta.progress)}'),
              Text('Неопределённость ${_delta(delta.uncertainty)}'),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Оценка рассчитана локально. AI только объясняет результат.',
            style: TextStyle(
              color: Colors.white54,
              fontSize: preserveDemo ? 10 : 12,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _TactixMetricChip extends StatelessWidget {
  final String label;
  final int value;
  final bool preserveDemo;

  const _TactixMetricChip({
    required this.label,
    required this.value,
    this.preserveDemo = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: Colors.white10),
      ),
      child: Text(
        '$label  $value',
        style: TextStyle(
          fontSize: preserveDemo ? 9 : 13,
          fontWeight: preserveDemo ? FontWeight.w800 : FontWeight.w600,
        ),
      ),
    );
  }
}

// FINISH CARD

class FinishCard
    extends StatelessWidget {
  final int score;
  final List<DecisionRecord> history;
  final SimulationState state;
  final String scenarioTitle;
  final String goal;
  final int durationSeconds;
  final String aiExplanation;
  final VoidCallback onRestart;

  const FinishCard({
    super.key,
    required this.score,
    required this.history,
    required this.state,
    required this.scenarioTitle,
    required this.goal,
    required this.durationSeconds,
    required this.aiExplanation,
    required this.onRestart,
  });

  Color _scoreColor(int value) {
    if (value >= 85) return const Color(0xFF4EE39A);
    if (value >= 70) return TactixTheme.gold;
    if (value >= 55) return const Color(0xFFFF9F43);
    return const Color(0xFFFF5D6C);
  }

  String _level(int value) {
    if (value >= 85) return 'ОТЛИЧНО';
    if (value >= 70) return 'ХОРОШО';
    if (value >= 55) return 'УДОВЛЕТВОРИТЕЛЬНО';
    return 'ТРЕБУЕТ РАЗВИТИЯ';
  }

  String decisionLabel(String value) {
    switch (value) {
      case 'A':
        return 'Интенсивный подход';
      case 'B':
        return 'Сбалансированный подход';
      case 'C':
        return 'Осторожный подход';
      default:
        return 'Решение';
    }
  }

  int _averageMetric(
    int Function(DecisionRecord item) selector,
  ) {
    if (history.isEmpty) return 0;

    final total = history.fold<int>(
      0,
      (sum, item) => sum + selector(item),
    );

    return (total / history.length)
        .round()
        .clamp(0, 100);
  }

  Map<String, int> get _criteria => {
        'Достижение цели': _averageMetric(
          (item) => item.goalScore,
        ),
        'Эффективность ресурсов': _averageMetric(
          (item) => item.resourceScore,
        ),
        'Устойчивость': _averageMetric(
          (item) => item.stabilityScore,
        ),
        'Контроль неопределённости': _averageMetric(
          (item) => item.uncertaintyScore,
        ),
        'Использование времени': _averageMetric(
          (item) => item.timeScore,
        ),
      };

  MapEntry<String, int>? get _strongestCriterion {
    if (_criteria.isEmpty) return null;
    return _criteria.entries.reduce(
      (a, b) => a.value >= b.value ? a : b,
    );
  }

  MapEntry<String, int>? get _weakestCriterion {
    if (_criteria.isEmpty) return null;
    return _criteria.entries.reduce(
      (a, b) => a.value <= b.value ? a : b,
    );
  }

  DecisionRecord? get _bestDecision {
    if (history.isEmpty) return null;
    return history.reduce(
      (a, b) => a.score >= b.score ? a : b,
    );
  }

  DecisionRecord? get _weakestDecision {
    if (history.isEmpty) return null;
    return history.reduce(
      (a, b) => a.score <= b.score ? a : b,
    );
  }

  int _aggregateDelta(String key) {
    return history.fold<int>(
      0,
      (sum, item) => sum + (item.delta[key] ?? 0),
    );
  }

  String _deltaText(int value) {
    if (value > 0) return '+$value';
    return '$value';
  }

  String _duration() {
    final minutes = durationSeconds ~/ 60;
    final seconds = durationSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String finalVerdict() {
    if (score >= 85) {
      return 'Решения обеспечили сильный баланс между достижением цели, сохранением ресурсов и контролем неопределённости.';
    }
    if (score >= 70) {
      return 'Цель проходилась уверенно, однако отдельные решения снизили общую эффективность.';
    }
    if (score >= 55) {
      return 'Базовая задача выполнена на приемлемом уровне, но видны конкретные зоны для развития.';
    }
    return 'Результат показывает необходимость улучшить последовательность решений и контроль ключевых ограничений.';
  }

  String improvementAdvice() {
    final weakest = _weakestCriterion;
    if (weakest == null) {
      return 'Недостаточно данных для рекомендации.';
    }

    switch (weakest.key) {
      case 'Контроль неопределённости':
        return 'При следующем прохождении удели больше внимания снижению неопределённости до принятия решений с высокой ценой ошибки.';
      case 'Эффективность ресурсов':
        return 'Старайся не расходовать условный ресурс быстрее, чем растёт прогресс по основной цели.';
      case 'Устойчивость':
        return 'Оценивай не только краткосрочный выигрыш, но и влияние решения на устойчивость системы в следующих ходах.';
      case 'Использование времени':
        return 'Сокращай лишние действия и выбирай решения, которые дают достаточный прогресс при меньших временных затратах.';
      default:
        return 'Повышай долю решений, которые прямо продвигают основную учебную цель без критической потери остальных показателей.';
    }
  }

  String _buildAarReport() {
    final strongest = _strongestCriterion;
    final weakest = _weakestCriterion;
    final best = _bestDecision;
    final weakDecision = _weakestDecision;
    final generatedAt = DateTime.now();

    String two(int value) =>
        value.toString().padLeft(2, '0');

    final dateText =
        '${two(generatedAt.day)}.${two(generatedAt.month)}.${generatedAt.year} '
        '${two(generatedAt.hour)}:${two(generatedAt.minute)}';

    final buffer = StringBuffer()
      ..writeln('TACTIX — AFTER ACTION REVIEW')
      ..writeln('========================================')
      ..writeln('Учебный отчёт • локальная оценка')
      ..writeln('Сформирован: $dateText')
      ..writeln()
      ..writeln('СЦЕНАРИЙ')
      ..writeln(scenarioTitle)
      ..writeln();

    if (goal.trim().isNotEmpty) {
      buffer
        ..writeln('ЦЕЛЬ')
        ..writeln(goal.trim())
        ..writeln();
    }

    buffer
      ..writeln('ИТОГ')
      ..writeln('TACTIX SCORE: $score/100')
      ..writeln('Уровень: ${_level(score)}')
      ..writeln('Ходов: ${history.length}')
      ..writeln('Продолжительность: ${_duration()}')
      ..writeln()
      ..writeln('СТРУКТУРА TACTIX SCORE');

    for (final entry in _criteria.entries) {
      buffer.writeln('- ${entry.key}: ${entry.value}/100');
    }

    buffer
      ..writeln()
      ..writeln('КЛЮЧЕВЫЕ ВЫВОДЫ')
      ..writeln(
        '- Сильная сторона: ${strongest == null ? 'Нет данных' : '${strongest.key} — ${strongest.value}/100'}',
      )
      ..writeln(
        '- Зона развития: ${weakest == null ? 'Нет данных' : '${weakest.key} — ${weakest.value}/100'}',
      )
      ..writeln()
      ..writeln('СУММАРНЫЕ ИЗМЕНЕНИЯ СОСТОЯНИЯ')
      ..writeln(
        '- Ресурсы: ${_deltaText(_aggregateDelta('resources'))}',
      )
      ..writeln(
        '- Устойчивость: ${_deltaText(_aggregateDelta('stability'))}',
      )
      ..writeln(
        '- Прогресс: ${_deltaText(_aggregateDelta('progress'))}',
      )
      ..writeln(
        '- Неопределённость: ${_deltaText(_aggregateDelta('uncertainty'))}',
      )
      ..writeln(
        '- Время: ${_deltaText(_aggregateDelta('time'))}',
      )
      ..writeln()
      ..writeln('ФИНАЛЬНОЕ СОСТОЯНИЕ')
      ..writeln('- Ресурсы: ${state.resources}%')
      ..writeln('- Устойчивость: ${state.stability}%')
      ..writeln('- Прогресс: ${state.progress}%')
      ..writeln(
        '- Контроль неопределённости: ${(100 - state.uncertainty).clamp(0, 100)}%',
      )
      ..writeln()
      ..writeln('ТРАЕКТОРИЯ РЕШЕНИЙ');

    for (final item in history) {
      buffer
        ..writeln(
          'Ход ${item.turn}: вариант ${item.decision} — ${item.score}/100',
        )
        ..writeln(
          '  Цель ${item.goalScore} | '
          'Ресурсы ${item.resourceScore} | '
          'Устойчивость ${item.stabilityScore} | '
          'Неопределённость ${item.uncertaintyScore} | '
          'Время ${item.timeScore}',
        );
    }

    buffer
      ..writeln()
      ..writeln(
        'Лучший ход: ${best == null ? 'Нет данных' : 'ход ${best.turn}, вариант ${best.decision} — ${best.score}/100'}',
      )
      ..writeln(
        'Самый слабый ход: ${weakDecision == null ? 'Нет данных' : 'ход ${weakDecision.turn}, вариант ${weakDecision.decision} — ${weakDecision.score}/100'}',
      )
      ..writeln()
      ..writeln('ИТОГОВЫЙ ВЫВОД')
      ..writeln(finalVerdict())
      ..writeln()
      ..writeln('РЕКОМЕНДАЦИЯ')
      ..writeln(improvementAdvice())
      ..writeln()
      ..writeln('AI-ИНТЕРПРЕТАЦИЯ')
      ..writeln(
        aiExplanation.trim().isEmpty
            ? 'AI-разбор для этого прохождения недоступен.'
            : aiExplanation.trim(),
      )
      ..writeln()
      ..writeln('========================================')
      ..writeln(
        'Числовая оценка сформирована локальным TACTIX Score Engine. '
        'AI используется только для интерпретации результата.',
      )
      ..writeln(
        'Материал предназначен для учебной симуляции.',
      );

    return buffer.toString();
  }

  Future<void> _showAarReport(
    BuildContext context,
  ) async {
    final report = _buildAarReport();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 820,
              maxHeight: 720,
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.description_outlined,
                        color: TactixTheme.gold,
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'TACTIX • AAR REPORT',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight:
                                FontWeight.w900,
                            letterSpacing: .8,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Закрыть',
                        onPressed: () =>
                            Navigator.pop(
                          dialogContext,
                        ),
                        icon: const Icon(
                          Icons.close,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Отчёт сформирован локально и готов для копирования.',
                    style: TextStyle(
                      color: TactixTheme.textMuted,
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: Container(
                      padding:
                          const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: Colors.black
                            .withValues(alpha: .16),
                        borderRadius:
                            BorderRadius.circular(12),
                        border: Border.all(
                          color: TactixTheme.line,
                        ),
                      ),
                      child:
                          SingleChildScrollView(
                        child: SelectableText(
                          report,
                          style:
                              const TextStyle(
                            height: 1.55,
                            fontSize: 11,
                            fontFamily:
                                'monospace',
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(
                          text: report,
                        ),
                      );

                      if (!context.mounted) {
                        return;
                      }

                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'AAR-отчёт скопирован в буфер обмена.',
                          ),
                        ),
                      );
                    },
                    icon: const Icon(
                      Icons.copy_all_outlined,
                    ),
                    label: const Padding(
                      padding:
                          EdgeInsets.symmetric(
                        vertical: 13,
                      ),
                      child: Text(
                        'СКОПИРОВАТЬ ОТЧЁТ',
                        style: TextStyle(
                          fontWeight:
                              FontWeight.w800,
                        ),
                      ),
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

  Widget _sectionTitle(
    String text, {
    IconData? icon,
  }) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(
            icon,
            size: 17,
            color: TactixTheme.gold,
          ),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ],
    );
  }

  Widget _metricBar(
    String label,
    int value,
  ) {
    final color = _scoreColor(value);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                '$value',
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: (value / 100).clamp(0.0, 1.0),
              minHeight: 7,
              backgroundColor: Colors.white10,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _deltaChip(
    String label,
    int value,
  ) {
    final positive = value > 0;
    final negative = value < 0;
    final color = positive
        ? const Color(0xFF4EE39A)
        : negative
            ? const Color(0xFFFF9F43)
            : Colors.white54;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: color.withValues(alpha: .25),
        ),
      ),
      child: Text(
        '$label ${_deltaText(value)}',
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _decisionCard(DecisionRecord item) {
    final color = _scoreColor(item.score);
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .025),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: TactixTheme.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(
                color: color.withValues(alpha: .30),
              ),
            ),
            child: Text(
              '${item.turn}',
              style: TextStyle(
                color: color,
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
                  'ХОД ${item.turn} • ВАРИАНТ ${item.decision}',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .7,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  decisionLabel(item.decision),
                  style: const TextStyle(
                    color: TactixTheme.textMuted,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    _deltaChip('R', item.delta['resources'] ?? 0),
                    _deltaChip('S', item.delta['stability'] ?? 0),
                    _deltaChip('P', item.delta['progress'] ?? 0),
                    _deltaChip('U', item.delta['uncertainty'] ?? 0),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${item.score}',
                style: TextStyle(
                  color: color,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                item.level.isEmpty
                    ? '/ 100'
                    : item.level.toUpperCase(),
                style: const TextStyle(
                  color: TactixTheme.textMuted,
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final adaptation =
        (100 - state.uncertainty).clamp(0, 100);
    final scoreColor = _scoreColor(score);
    final strongest = _strongestCriterion;
    final weakest = _weakestCriterion;
    final best = _bestDecision;
    final weakDecision = _weakestDecision;

    return Container(
      decoration: BoxDecoration(
        color: TactixTheme.panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: TactixTheme.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  scoreColor.withValues(alpha: .13),
                  TactixTheme.panel2,
                  TactixTheme.panel,
                ],
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(18),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: TactixTheme.gold.withValues(alpha: .10),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: TactixTheme.gold.withValues(alpha: .30),
                        ),
                      ),
                      child: const Text(
                        'AFTER ACTION REVIEW',
                        style: TextStyle(
                          color: TactixTheme.gold,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                    const Spacer(),
                    const Text(
                      'LOCAL SCORE • AI EXPLANATION',
                      style: TextStyle(
                        color: TactixTheme.textMuted,
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                        letterSpacing: .7,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  scenarioTitle.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .7,
                  ),
                ),
                if (goal.trim().isNotEmpty) ...[
                  const SizedBox(height: 7),
                  Text(
                    goal,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: TactixTheme.textMuted,
                      fontSize: 11,
                      height: 1.4,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                const Text(
                  'TACTIX SCORE',
                  style: TextStyle(
                    color: TactixTheme.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.8,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '$score',
                  style: TextStyle(
                    color: scoreColor,
                    fontSize: 58,
                    height: 1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _level(score),
                  style: TextStyle(
                    color: scoreColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.3,
                  ),
                ),
                const SizedBox(height: 13),
                Text(
                  finalVerdict(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _deltaChip('ХОДОВ', history.length),
                    _deltaChip('ВРЕМЯ', durationSeconds),
                    _deltaChip('ПРОГРЕСС', state.progress),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Продолжительность: ${_duration()}',
                  style: const TextStyle(
                    color: TactixTheme.textMuted,
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _sectionTitle(
                  'СТРУКТУРА TACTIX SCORE',
                  icon: Icons.radar_rounded,
                ),
                const SizedBox(height: 15),
                ..._criteria.entries.map(
                  (entry) => _metricBar(
                    entry.key,
                    entry.value,
                  ),
                ),
                const SizedBox(height: 8),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final two = constraints.maxWidth >= 620;
                    final width = two
                        ? (constraints.maxWidth - 10) / 2
                        : constraints.maxWidth;

                    Widget insightCard({
                      required String title,
                      required String value,
                      required IconData icon,
                      required Color color,
                    }) {
                      return SizedBox(
                        width: width,
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: .055),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: color.withValues(alpha: .22),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(icon, color: color, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      style: const TextStyle(
                                        color: TactixTheme.textMuted,
                                        fontSize: 8,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: .9,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      value,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        height: 1.35,
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

                    return Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        insightCard(
                          title: 'СИЛЬНАЯ СТОРОНА',
                          value: strongest == null
                              ? 'Нет данных'
                              : '${strongest.key} • ${strongest.value}/100',
                          icon: Icons.trending_up_rounded,
                          color: const Color(0xFF4EE39A),
                        ),
                        insightCard(
                          title: 'ЗОНА РАЗВИТИЯ',
                          value: weakest == null
                              ? 'Нет данных'
                              : '${weakest.key} • ${weakest.value}/100',
                          icon: Icons.track_changes_rounded,
                          color: const Color(0xFFFF9F43),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 22),
                _sectionTitle(
                  'СУММАРНЫЕ ИЗМЕНЕНИЯ СОСТОЯНИЯ',
                  icon: Icons.swap_vert_circle_outlined,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _deltaChip(
                      'РЕСУРСЫ',
                      _aggregateDelta('resources'),
                    ),
                    _deltaChip(
                      'УСТОЙЧИВОСТЬ',
                      _aggregateDelta('stability'),
                    ),
                    _deltaChip(
                      'ПРОГРЕСС',
                      _aggregateDelta('progress'),
                    ),
                    _deltaChip(
                      'НЕОПРЕД.',
                      _aggregateDelta('uncertainty'),
                    ),
                    _deltaChip(
                      'ВРЕМЯ',
                      _aggregateDelta('time'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _sectionTitle(
                  'ФИНАЛЬНОЕ СОСТОЯНИЕ',
                  icon: Icons.dashboard_customize_outlined,
                ),
                const SizedBox(height: 12),
                ScoreRow(
                  title: 'Ресурсы',
                  value: state.resources,
                ),
                ScoreRow(
                  title: 'Стабильность',
                  value: state.stability,
                ),
                ScoreRow(
                  title: 'Прогресс',
                  value: state.progress,
                ),
                ScoreRow(
                  title: 'Адаптация',
                  value: adaptation,
                ),
                const SizedBox(height: 22),
                _sectionTitle(
                  'ТРАЕКТОРИЯ РЕШЕНИЙ',
                  icon: Icons.account_tree_outlined,
                ),
                const SizedBox(height: 12),
                ...history.map(_decisionCard),
                if (best != null || weakDecision != null) ...[
                  const SizedBox(height: 4),
                  InfoRow(
                    icon: Icons.star_outline,
                    title: 'Лучший ход',
                    value: best == null
                        ? 'Нет данных'
                        : 'Ход ${best.turn}: ${best.decision} — ${best.score}/100',
                  ),
                  InfoRow(
                    icon: Icons.flag_outlined,
                    title: 'Самый слабый ход',
                    value: weakDecision == null
                        ? 'Нет данных'
                        : 'Ход ${weakDecision.turn}: ${weakDecision.decision} — ${weakDecision.score}/100',
                  ),
                ],
                const SizedBox(height: 22),
                _sectionTitle(
                  'ПОЧЕМУ ТАКОЙ БАЛЛ',
                  icon: Icons.psychology_alt_outlined,
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: TactixTheme.cyan.withValues(alpha: .045),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: TactixTheme.cyan.withValues(alpha: .20),
                    ),
                  ),
                  child: SelectableText(
                    aiExplanation.trim().isEmpty
                        ? 'TACTIX Score рассчитан локально по пяти критериям. AI-разбор для этого прохождения недоступен.'
                        : aiExplanation,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      height: 1.55,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                _sectionTitle(
                  'РЕКОМЕНДАЦИЯ',
                  icon: Icons.lightbulb_outline_rounded,
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .025),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: TactixTheme.line),
                  ),
                  child: Text(
                    improvementAdvice(),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    const Icon(
                      Icons.verified_outlined,
                      color: TactixTheme.gold,
                      size: 17,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Числовая оценка сформирована локальным TACTIX Score Engine. AI используется только для интерпретации результата.',
                        style: TextStyle(
                          color: TactixTheme.textMuted,
                          fontSize: 9,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final compact =
                        constraints.maxWidth < 560;

                    final reportButton =
                        FilledButton.icon(
                      onPressed: () =>
                          _showAarReport(
                        context,
                      ),
                      icon: const Icon(
                        Icons.description_outlined,
                      ),
                      label: const Padding(
                        padding:
                            EdgeInsets.symmetric(
                          vertical: 14,
                        ),
                        child: Text(
                          'СФОРМИРОВАТЬ ОТЧЁТ',
                          style: TextStyle(
                            fontWeight:
                                FontWeight.w800,
                          ),
                        ),
                      ),
                    );

                    final restartButton =
                        OutlinedButton.icon(
                      onPressed: onRestart,
                      icon: const Icon(
                        Icons.restart_alt,
                      ),
                      label: const Padding(
                        padding:
                            EdgeInsets.symmetric(
                          vertical: 14,
                        ),
                        child: Text(
                          'ПРОЙТИ ЗАНОВО',
                          style: TextStyle(
                            fontWeight:
                                FontWeight.w800,
                          ),
                        ),
                      ),
                    );

                    if (compact) {
                      return Column(
                        crossAxisAlignment:
                            CrossAxisAlignment
                                .stretch,
                        children: [
                          reportButton,
                          const SizedBox(
                            height: 9,
                          ),
                          restartButton,
                        ],
                      );
                    }

                    return Row(
                      children: [
                        Expanded(
                          child:
                              reportButton,
                        ),
                        const SizedBox(
                          width: 10,
                        ),
                        Expanded(
                          child:
                              restartButton,
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =====================================================
// STAT CARD
// =====================================================

// =====================================================
// SECTION TITLE
// =====================================================

// =====================================================
// TEXT FIELD
// =====================================================

// =====================================================
// METRIC CARD
// =====================================================

// =====================================================
// INFO ROW
// =====================================================

// =====================================================
// DECISION BUTTON
// =====================================================

// =====================================================
// SCORE ROW
// =====================================================

// =====================================================
// TRAINING UI HELPERS
// =====================================================

class _StatusPill
    extends StatelessWidget {
  final String label;
  final IconData icon;

  final bool preserveDemo;

  const _StatusPill({
    this.preserveDemo = false,
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final primary =
        Theme.of(context)
            .colorScheme
            .primary;

    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 7,
      ),
      decoration:
          BoxDecoration(
        borderRadius:
            BorderRadius.circular(
          99,
        ),
        color:
            primary.withValues(
          alpha: .12,
        ),
        border:
            Border.all(
          color:
              primary.withValues(
            alpha: .35,
          ),
        ),
      ),
      child: Row(
        mainAxisSize:
            MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 13,
            color: primary,
          ),
          const SizedBox(
            width: 5,
          ),
          Text(
            label,
            style:
                TextStyle(
              fontSize: preserveDemo ? 10 : 12,
              fontWeight:
                  FontWeight.w900,
              color: primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _TrainingMetricCard
    extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final double progress;
  final bool inverted;
  final bool preserveDemo;

  const _TrainingMetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.progress,
    this.inverted = false,
    this.preserveDemo = false,
  });

  @override
  Widget build(BuildContext context) {
    final primary =
        Theme.of(context)
            .colorScheme
            .primary;

    final width =
        (MediaQuery.sizeOf(context).width -
                37) /
            2;

    final safeWidth =
        width < 140 ? 140.0 : width;

    final safeProgress =
        progress.clamp(0.0, 1.0);

    return SizedBox(
      width: preserveDemo ? safeWidth : (MediaQuery.sizeOf(context).width >= 900 ? 210 : (MediaQuery.sizeOf(context).width - 2 * TactixResponsive.horizontalPadding(context) - 9) / 2),
      child: Container(
        padding:
            EdgeInsets.all(preserveDemo ? 13 : 10),
        decoration:
            BoxDecoration(
          color:
              Colors.white.withValues(
            alpha: .035,
          ),
          borderRadius:
              BorderRadius.circular(
            16,
          ),
          border:
              Border.all(
            color: Colors.white10,
          ),
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color:
                      Colors.white70,
                ),
                const SizedBox(
                  width: 9,
                ),
                Expanded(
                  child: Text(
                    title,
                    maxLines: preserveDemo ? 1 : null,
                    overflow:
                        TextOverflow.ellipsis,
                    style:
                        TextStyle(
                      fontSize: preserveDemo ? 10.5 : 12,
                      color:
                          preserveDemo ? Colors.white54 : TactixTheme.textMuted,
                      fontWeight:
                          FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  value,
                  style:
                      TextStyle(
                    fontSize: 15,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(
              height: 10,
            ),
            ClipRRect(
              borderRadius:
                  BorderRadius.circular(
                99,
              ),
              child:
                  LinearProgressIndicator(
                minHeight: preserveDemo ? 5 : 3,
                value: safeProgress,
                backgroundColor:
                    Colors.white10,
                valueColor:
                    AlwaysStoppedAnimation<
                        Color>(
                  inverted &&
                          safeProgress >
                              .60
                      ? Colors
                          .orangeAccent
                      : primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniLabel
    extends StatelessWidget {
  final String text;

  final bool preserveDemo;

  const _MiniLabel({
    this.preserveDemo = false,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: preserveDemo ? 10 : 12,
        fontWeight:
            FontWeight.w900,
        color: Colors.white54,
        letterSpacing: .9,
      ),
    );
  }
}

class _SignalBlock
    extends StatelessWidget {
  final String title;
  final IconData icon;
  final String text;

  final bool preserveDemo;

  const _SignalBlock({
    this.preserveDemo = false,
    required this.title,
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.all(12),
      decoration:
          BoxDecoration(
        borderRadius:
            BorderRadius.circular(
          14,
        ),
        color:
            Colors.white.withValues(
          alpha: .035,
        ),
        border:
            Border.all(
          color: Colors.white10,
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 18,
          ),
          const SizedBox(
            width: 9,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style:
                      TextStyle(
                    fontSize: preserveDemo ? 10 : 12,
                    fontWeight:
                        FontWeight.w900,
                    color:
                        Colors.white54,
                    letterSpacing: .8,
                  ),
                ),
                const SizedBox(
                  height: 4,
                ),
                Text(
                  text,
                  style:
                      TextStyle(
                    height: 1.45,
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

class _HistoryRow
    extends StatelessWidget {
  final DecisionRecord item;
  final bool preserveDemo;

  const _HistoryRow({
    required this.item,
    this.preserveDemo = false,
  });

  @override
  Widget build(BuildContext context) {
    final primary =
        preserveDemo
            ? Theme.of(context).colorScheme.primary
            : TactixTheme.textMuted;

    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 11,
        vertical: 10,
      ),
      decoration:
          BoxDecoration(
        color:
            Colors.white.withValues(
          alpha: .025,
        ),
        borderRadius:
            BorderRadius.circular(
          12,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment:
                Alignment.center,
            decoration:
                BoxDecoration(
              borderRadius:
                  BorderRadius.circular(
                10,
              ),
              color:
                  primary.withValues(
                alpha: .13,
              ),
            ),
            child: Text(
              item.turn.toString(),
              style:
                  TextStyle(
                fontWeight:
                    preserveDemo ? FontWeight.w900 : FontWeight.w600,
                color: primary,
              ),
            ),
          ),
          const SizedBox(
            width: 10,
          ),
          Expanded(
            child: Text(
              'Решение ${item.decision}',
              style:
                  TextStyle(
                fontWeight:
                    preserveDemo ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          Text(
            '${item.score}/100',
            style:
                TextStyle(
              fontWeight:
                  preserveDemo ? FontWeight.w900 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

