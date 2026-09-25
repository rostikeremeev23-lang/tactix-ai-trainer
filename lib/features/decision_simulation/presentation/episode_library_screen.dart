import 'package:flutter/material.dart';

import '../data/storm_scenario.dart';
import '../data/run_repository.dart';
import '../domain/decision_engine.dart';
import '../domain/models.dart';
import '../domain/scenario_validator.dart';
import 'episode_screen.dart';
import 'cinematic_art.dart';
import 'story_visuals.dart';

class EpisodeLibraryScreen extends StatefulWidget {
  final String userId;
  const EpisodeLibraryScreen({super.key, required this.userId});
  @override
  State<EpisodeLibraryScreen> createState() => _EpisodeLibraryScreenState();
}

class _EpisodeLibraryScreenState extends State<EpisodeLibraryScreen> {
  late final scenario = stormScenario();
  late final engine = DecisionEngine(scenario);
  late final repository = RunRepository(widget.userId, engine);
  RunState? saved;
  bool loading = true;
  String? error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final errors = validateScenario(scenario);
      if (errors.isNotEmpty) throw StateError(errors.join('\n'));
      final run = await repository.load();
      if (!mounted) return;
      setState(() {
        saved = run;
        error = repository.recoveryMessage;
        loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          loading = false;
          error = '$e';
        });
      }
    }
  }

  Future<void> _start() async {
    if (loading) return;
    if (saved != null && !saved!.completed) {
      final replace = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Начать заново?'),
          content: const Text(
            'Текущее незавершённое прохождение будет заменено новым.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Начать'),
            ),
          ],
        ),
      );
      if (replace != true || !mounted) return;
    }
    setState(() => loading = true);
    try {
      final run = engine.start(
        runId: DateTime.now().microsecondsSinceEpoch.toString(),
      );
      await repository.save(run);
      if (!mounted) return;
      setState(() {
        saved = run;
        loading = false;
        error = null;
      });
      await _open(run);
    } catch (e) {
      if (mounted) {
        setState(() {
          loading = false;
          error = '$e';
        });
      }
    }
  }

  Future<void> _open(RunState run) async {
    if (loading) return;
    setState(() => loading = true);
    final again = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => EpisodeScreen(
          engine: engine,
          repository: repository,
          initialState: run,
        ),
      ),
    );
    if (!mounted) return;
    await _load();
    if (again == true && mounted) await _start();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: storyBackground,
    appBar: AppBar(
      title: const Text('Интерактивные истории'),
      backgroundColor: storyBackground,
    ),
    body: StoryBackdrop(
      child: SizedBox.expand(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 28),
                  const Text(
                    'TACTIX / DECISION SIMULATOR',
                    style: TextStyle(
                      color: storyCyan,
                      letterSpacing: 2,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Решение остаётся.\nПоследствия продолжаются.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      height: 1.2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 32),
                  StoryPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox(
                            height: 200,
                            width: double.infinity,
                            child: SceneIllustration(
                              direction: SceneDirection.forScene('s1'),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          scenario.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          '12 сцен  •  4 финала  •  ориентир 15–20 минут  •  офлайн',
                          style: TextStyle(color: storyGold),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          scenario.intro,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            height: 1.65,
                          ),
                        ),
                        const SizedBox(height: 24),
                        if (loading)
                          const LinearProgressIndicator()
                        else
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              FilledButton.icon(
                                key: const Key('new-episode'),
                                onPressed: _start,
                                icon: const Icon(Icons.play_arrow),
                                label: Text(
                                  saved == null
                                      ? 'Начать историю'
                                      : 'Новое прохождение',
                                ),
                              ),
                              if (saved != null)
                                OutlinedButton.icon(
                                  key: const Key('resume-episode'),
                                  onPressed: () => _open(saved!),
                                  icon: const Icon(Icons.history),
                                  label: Text(
                                    saved!.completed
                                        ? 'Открыть итог и дерево'
                                        : 'Продолжить • сцена ${saved!.step + 1}',
                                  ),
                                ),
                            ],
                          ),
                        if (error != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: Text(
                              error!,
                              style: const TextStyle(color: storyGold),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Вымышленное гражданское упражнение. Чтение не расходует '
                    'игровое время. Решения и запросы сведений имеют указанную цену. '
                    'Состояние сохраняется после каждого действия.',
                    style: TextStyle(color: Colors.white70, height: 1.5),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
