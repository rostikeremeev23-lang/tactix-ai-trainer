import 'package:flutter/material.dart';

import '../../app/responsive.dart';
import '../../models/scenario.dart';
import '../../services/storage_service.dart';
import 'create_scenario_screen.dart';

class MyScenariosScreen
    extends StatefulWidget {
  final Widget Function() aiScreenBuilder;
  final Widget Function(TrainingScenario scenario) runScreenBuilder;

  const MyScenariosScreen({
    super.key,
    required this.aiScreenBuilder,
    required this.runScreenBuilder,
  });

  @override
  State<MyScenariosScreen> createState() =>
      _MyScenariosScreenState();
}

class _MyScenariosScreenState
    extends State<MyScenariosScreen> {
  List<TrainingScenario> scenarios = [];

  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadScenarios();
  }

  Future<void> loadScenarios() async {
    try {
      final result =
          await ScenarioStorage.load();

      if (!mounted) return;

      setState(() {
        scenarios = result;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        loading = false;
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content:
              Text('Ошибка загрузки: $e'),
        ),
      );
    }
  }

  Future<void> openAI() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            widget.aiScreenBuilder(),
      ),
    );

    loadScenarios();
  }

  Future<void> openManual() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            const CreateScenarioScreen(),
      ),
    );

    loadScenarios();
  }

  Future<void> removeScenario(
    int index,
  ) async {
    await ScenarioStorage.delete(
      index,
    );

    await loadScenarios();
  }

  Future<void> confirmDelete(
    int index,
  ) async {
    final scenario =
        scenarios[index];

    final answer =
        await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Удалить сценарий?',
          ),
          content: Text(
            'Удалить «${scenario.title}»?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child:
                  const Text('ОТМЕНА'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              child:
                  const Text('УДАЛИТЬ'),
            ),
          ],
        );
      },
    );

    if (answer == true) {
      await removeScenario(index);
    }
  }

  Future<void> clearAllScenarios() async {
    // Удаляем с конца, чтобы индексы не смещались.
    for (int index = scenarios.length - 1; index >= 0; index--) {
      await ScenarioStorage.delete(index);
    }

    await loadScenarios();
  }

  Future<void> confirmClearAll() async {
    if (scenarios.isEmpty) return;

    final answer = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Очистить сценарии?',
          ),
          content: Text(
            'Будут удалены все сохранённые пользовательские сценарии (${scenarios.length}). '
            'История результатов тренировок не удаляется.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child: const Text('ОТМЕНА'),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              icon: const Icon(
                Icons.delete_sweep_outlined,
              ),
              label: const Text(
                'ОЧИСТИТЬ',
              ),
            ),
          ],
        );
      },
    );

    if (answer == true) {
      await clearAllScenarios();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Сохранённые сценарии очищены. История результатов сохранена.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            const Text('Мои сценарии'),
        actions: [
          if (scenarios.isNotEmpty)
            IconButton(
              tooltip: 'Очистить все сценарии',
              onPressed: confirmClearAll,
              icon: const Icon(
                Icons.delete_sweep_outlined,
              ),
            ),
          IconButton(
            tooltip: 'Создать с AI',
            onPressed: openAI,
            icon:
                const Icon(
              Icons.auto_awesome,
            ),
          ),
          IconButton(
            tooltip: 'Создать вручную',
            onPressed: openManual,
            icon:
                const Icon(Icons.add),
          ),
        ],
      ),
      body: loading
          ? const Center(
              child:
                  CircularProgressIndicator(),
            )
          : scenarios.isEmpty
              ? _buildEmpty()
              : ListView.builder(
                  padding: EdgeInsets.fromLTRB(
                    TactixResponsive.horizontalPadding(context),
                    14,
                    TactixResponsive.horizontalPadding(context),
                    24,
                  ),
                  itemCount:
                      scenarios.length,
                  itemBuilder:
                      (context, index) {
                    final scenario =
                        scenarios[index];

                    return Card(
                      margin:
                          const EdgeInsets
                              .only(
                        bottom: 12,
                      ),
                      child:
                          ListTile(
                        leading:
                            const CircleAvatar(
                          child: Icon(
                            Icons
                                .description,
                          ),
                        ),
                        title:
                            Text(
                          scenario.title,
                          style:
                              const TextStyle(
                            fontWeight:
                                FontWeight
                                    .bold,
                          ),
                        ),
                        subtitle:
                            Text(
                          scenario
                              .description,
                          maxLines: 2,
                          overflow:
                              TextOverflow
                                  .ellipsis,
                        ),
                        trailing:
                            PopupMenuButton<
                                String>(
                          onSelected:
                              (value) {
                            if (value ==
                                'delete') {
                              confirmDelete(
                                index,
                              );
                            }
                          },
                          itemBuilder:
                              (_) => const [
                            PopupMenuItem(
                              value:
                                  'delete',
                              child:
                                  Text(
                                'Удалить',
                              ),
                            ),
                          ],
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  widget.runScreenBuilder(
                                scenario,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            const Icon(
              Icons
                  .description_outlined,
              size: 70,
              color:
                  Colors.white54,
            ),
            const SizedBox(
              height: 18,
            ),
            const Text(
              'Сценариев пока нет',
              style:
                  TextStyle(
                fontSize: 22,
                fontWeight:
                    FontWeight.bold,
              ),
            ),
            const SizedBox(
              height: 10,
            ),
            const Text(
              'Создайте свой первый сценарий вручную или с AI.',
              textAlign:
                  TextAlign.center,
              style:
                  TextStyle(
                color:
                    Colors.white60,
              ),
            ),
            const SizedBox(
              height: 20,
            ),
            ElevatedButton.icon(
              onPressed:
                  openAI,
              icon:
                  const Icon(
                Icons.auto_awesome,
              ),
              label:
                  const Text(
                'СОЗДАТЬ С AI',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
