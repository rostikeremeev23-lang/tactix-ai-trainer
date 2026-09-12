import 'package:flutter/material.dart';

import '../../models/training_result.dart';
import '../../services/result_storage_service.dart';
import '../../widgets/common_widgets.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({
    super.key,
  });

  @override
  State<StatisticsScreen> createState() =>
      _StatisticsScreenState();
}

class _StatisticsScreenState
    extends State<StatisticsScreen> {
  List<TrainingResult> results = [];

  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadResults();
  }

  Future<void> loadResults() async {
    final loaded =
        await ResultStorageService
            .load();

    if (!mounted) return;

    setState(() {
      results = loaded;
      loading = false;
    });
  }

  int averageScore() {
    if (results.isEmpty) {
      return 0;
    }

    final total =
        results.fold<int>(
      0,
      (sum, result) =>
          sum + result.score,
    );

    return (total /
            results.length)
        .round();
  }

  int bestScore() {
    if (results.isEmpty) {
      return 0;
    }

    return results
        .map(
          (item) => item.score,
        )
        .reduce(_maxInt);
  }

  int totalDecisions() {
    return results.fold<int>(
      0,
      (sum, item) =>
          sum + item.decisions,
    );
  }

  int averageField(
    int Function(TrainingResult)
        getter,
  ) {
    if (results.isEmpty) {
      return 0;
    }

    final total =
        results.fold<int>(
      0,
      (sum, result) =>
          sum + getter(result),
    );

    return (total /
            results.length)
        .round()
        .clamp(0, 100);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            const Text('Статистика'),
        actions: [
          if (results.isNotEmpty)
            IconButton(
              tooltip:
                  'Очистить всю историю',
              onPressed:
                  clearHistory,
              icon:
                  const Icon(
                Icons.delete_sweep,
              ),
            ),
        ],
      ),
      body: loading
          ? const Center(
              child:
                  CircularProgressIndicator(),
            )
          : results.isEmpty
              ? const Center(
                  child: Padding(
                    padding:
                        EdgeInsets.all(30),
                    child: Text(
                      'Статистика появится после завершения первой тренировки.',
                      textAlign:
                          TextAlign.center,
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh:
                      loadResults,
                  child:
                      ListView(
                    padding:
                        const EdgeInsets.all(
                      18,
                    ),
                    children: [
                      const SectionTitle(
                        text:
                            'МОЙ ПРОГРЕСС',
                      ),
                      const SizedBox(
                        height: 12,
                      ),
                      Row(
                        children: [
                          Expanded(
                            child:
                                StatCard(
                              title:
                                  'Тренировок',
                              value:
                                  results.length
                                      .toString(),
                              icon:
                                  Icons
                                      .fitness_center,
                            ),
                          ),
                          const SizedBox(
                            width: 10,
                          ),
                          Expanded(
                            child:
                                StatCard(
                              title:
                                  'Средний',
                              value:
                                  averageScore()
                                      .toString(),
                              icon:
                                  Icons
                                      .analytics,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(
                        height: 10,
                      ),
                      Row(
                        children: [
                          Expanded(
                            child:
                                StatCard(
                              title:
                                  'Лучший',
                              value:
                                  bestScore()
                                      .toString(),
                              icon:
                                  Icons
                                      .emoji_events,
                            ),
                          ),
                          const SizedBox(
                            width: 10,
                          ),
                          Expanded(
                            child:
                                StatCard(
                              title:
                                  'Решений',
                              value:
                                  totalDecisions()
                                      .toString(),
                              icon:
                                  Icons
                                      .alt_route,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(
                        height: 25,
                      ),
                      const SectionTitle(
                        text:
                            'СРЕДНИЕ ПОКАЗАТЕЛИ',
                      ),
                      const SizedBox(
                        height: 12,
                      ),
                      ScoreRow(
                        title:
                            'Цель',
                        value:
                            averageField(
                          (item) =>
                              item.goalScore,
                        ),
                      ),
                      ScoreRow(
                        title:
                            'Ресурсы',
                        value:
                            averageField(
                          (item) =>
                              item.resourceScore,
                        ),
                      ),
                      ScoreRow(
                        title:
                            'Устойчивость',
                        value:
                            averageField(
                          (item) =>
                              item.stabilityScore,
                        ),
                      ),
                      ScoreRow(
                        title:
                            'Неопределённость',
                        value:
                            averageField(
                          (item) =>
                              item.uncertaintyScore,
                        ),
                      ),
                      ScoreRow(
                        title:
                            'Время',
                        value:
                            averageField(
                          (item) =>
                              item.timeScore,
                        ),
                      ),
                      const SizedBox(
                        height: 25,
                      ),
                      const SectionTitle(
                        text:
                            'ИСТОРИЯ',
                      ),
                      const SizedBox(
                        height: 10,
                      ),
                      ...results
                          .take(20)
                          .map(
                        (result) =>
                            Card(
                          margin:
                              const EdgeInsets
                                  .only(
                            bottom: 10,
                          ),
                          child:
                              ListTile(
                            leading:
                                CircleAvatar(
                              child:
                                  Text(
                                result
                                    .score
                                    .toString(),
                              ),
                            ),
                            title:
                                Text(
                              result
                                  .scenarioTitle,
                              maxLines:
                                  1,
                              overflow:
                                  TextOverflow
                                      .ellipsis,
                            ),
                            subtitle:
                                Text(
                              '${result.decisions} решений • '
                              '${formatDuration(
                                result.durationSeconds,
                              )}',
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(
                        height: 18,
                      ),
                      OutlinedButton.icon(
                        onPressed:
                            clearHistory,
                        icon:
                            const Icon(
                          Icons.delete_forever_outlined,
                        ),
                        label:
                            const Padding(
                          padding:
                              EdgeInsets.symmetric(
                            vertical: 13,
                          ),
                          child:
                              Text(
                            'ОЧИСТИТЬ ВСЮ ИСТОРИЮ',
                            style:
                                TextStyle(
                              fontWeight:
                                  FontWeight.w800,
                              letterSpacing:
                                  .4,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(
                        height: 10,
                      ),
                    ],
                  ),
                ),
    );
  }

  String formatDuration(
    int seconds,
  ) {
    final minutes =
        seconds ~/ 60;

    final rest =
        seconds % 60;

    return '$minutesм '
        '${rest.toString().padLeft(2, '0')}с';
  }

  Future<void> clearHistory() async {
    final answer =
        await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) {
        return AlertDialog(
          title:
              const Text(
            'Очистить всю историю?',
          ),
          content:
              const Text(
            'Будут удалены все результаты прохождений, TACTIX Score и история тренировок. Сохранённые сценарии останутся.',
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(
                dialogContext,
                false,
              ),
              child:
                  const Text('ОТМЕНА'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(
                dialogContext,
                true,
              ),
              child:
                  const Text('УДАЛИТЬ ВСЁ'),
            ),
          ],
        );
      },
    );

    if (answer == true) {
      await ResultStorageService.clear();
      await loadResults();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'История прохождений полностью очищена.',
          ),
        ),
      );
    }
  }
}

int _maxInt(
  int a,
  int b,
) {
  return a > b ? a : b;
}

