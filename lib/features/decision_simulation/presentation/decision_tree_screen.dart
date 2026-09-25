import 'package:flutter/material.dart';

import '../domain/decision_engine.dart';
import '../domain/models.dart';
import 'story_visuals.dart';

class DecisionTreeScreen extends StatelessWidget {
  final DecisionEngine engine;
  final RunState run;
  const DecisionTreeScreen({
    super.key,
    required this.engine,
    required this.run,
  });
  @override
  Widget build(BuildContext context) {
    var replay = engine.start(runId: run.runId, seed: run.seed);
    final beforeScenes = <String, RunState>{};
    for (final command in run.commands) {
      beforeScenes[command.scene] = replay;
      replay = engine.apply(replay, command.action, note: command.note);
    }
    final scenario = engine.scenario;
    return Scaffold(
      backgroundColor: storyBackground,
      appBar: AppBar(
        title: const Text('Дерево решений'),
        backgroundColor: storyBackground,
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Перемещайте и масштабируйте схему. Нажмите на решение: '
              'увидите цену, причину и альтернативный непосредственный результат. '
              'Полный другой финал исследуется новым прохождением.',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          Expanded(
            child: InteractiveViewer(
              constrained: false,
              minScale: .35,
              maxScale: 1.7,
              boundaryMargin: const EdgeInsets.all(100),
              child: SizedBox(
                width: 820,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      for (final scene in scenario.scenes) ...[
                        Text(
                          scene.title,
                          style: TextStyle(
                            fontSize: 19,
                            color: beforeScenes.containsKey(scene.id)
                                ? storyCyan
                                : Colors.white38,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final action in scene.actions.where(
                              (a) => !a.inquiry,
                            ))
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.all(6),
                                  child: _node(
                                    context,
                                    scene,
                                    action,
                                    beforeScenes[scene.id],
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const Padding(
                          padding: EdgeInsets.all(12),
                          child: Icon(
                            Icons.arrow_downward,
                            color: Colors.white30,
                          ),
                        ),
                      ],
                      for (final ending in scenario.endings)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: StoryPanel(
                            child: ListTile(
                              leading: Icon(
                                run.ending == ending.id
                                    ? Icons.check_circle
                                    : Icons.radio_button_unchecked,
                                color: run.ending == ending.id
                                    ? storyCyan
                                    : Colors.white38,
                              ),
                              title: Text(
                                ending.title,
                                style: const TextStyle(color: Colors.white),
                              ),
                              subtitle: Text(
                                run.ending == ending.id
                                    ? 'Ваш финал'
                                    : 'Альтернативный финал',
                                style: const TextStyle(color: Colors.white60),
                              ),
                              onTap: () => showStoryText(
                                context,
                                ending.title,
                                ending.text,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _node(
    BuildContext context,
    StoryScene scene,
    StoryAction action,
    RunState? before,
  ) {
    final selected = run.commands.any(
      (c) => c.scene == scene.id && c.action == action.id,
    );
    final available = before != null && engine.available(before, action);
    return Material(
      color: selected ? const Color(0xFF1B4954) : const Color(0xFF182331),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          final events = run.events
              .where(
                (e) =>
                    e.cause == '${scene.id}/${action.id}' && e.kind != 'cost',
              )
              .map((e) => e.text)
              .join('\n\n');
          var alternative = '';
          if (!selected && available) {
            final next = engine.apply(before, action.id);
            alternative =
                '\n\nНепосредственный результат из вашего состояния:\n'
                '${next.events.skip(before.events.length).map((e) => e.text).join('\n')}'
                '\n\nЭто один альтернативный шаг, а не предсказание всего финала.';
          }
          showStoryText(
            context,
            action.title,
            '${action.tradeoff}\n\nЦена: ${action.minutes} мин., ${action.supplies} резерв.'
            '\n\n${selected
                ? 'Выбрано вами.'
                : available
                ? 'Было доступно.'
                : 'Не исследовано или недоступно в вашем состоянии.'}'
            '${events.isEmpty ? '' : '\n\n$events'}$alternative',
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                selected ? Icons.check_circle : Icons.alt_route,
                color: selected ? storyCyan : Colors.white38,
              ),
              const SizedBox(height: 10),
              Text(
                action.title,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                selected ? 'ПРОЙДЕНО' : 'АЛЬТЕРНАТИВА',
                style: TextStyle(
                  color: selected ? storyCyan : Colors.white54,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
