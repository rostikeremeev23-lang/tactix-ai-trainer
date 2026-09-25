import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../domain/scenario.dart';

class ExerciseTimeline extends StatelessWidget {
  final int tick, duration, speed, index, count;
  final bool running, editing, completed, replay, awaitingDecision;
  final List<ScenarioInject> injects;
  final VoidCallback onPlay, onStep, onReset, onReplay, onReport;
  final ValueChanged<int> onSpeed, onSeek;
  const ExerciseTimeline({
    super.key,
    required this.tick,
    required this.duration,
    required this.speed,
    required this.index,
    required this.count,
    required this.running,
    required this.editing,
    required this.completed,
    required this.replay,
    required this.awaitingDecision,
    required this.injects,
    required this.onPlay,
    required this.onStep,
    required this.onReset,
    required this.onReplay,
    required this.onReport,
    required this.onSpeed,
    required this.onSeek,
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    color: TactixTheme.panel,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilledButton.icon(
              key: const ValueKey('play-exercise'),
              onPressed: !replay && (awaitingDecision || completed)
                  ? null
                  : onPlay,
              icon: Icon(running ? Icons.pause : Icons.play_arrow),
              label: Text(
                running
                    ? 'Пауза'
                    : editing
                    ? 'Запустить'
                    : replay
                    ? 'Воспроизвести'
                    : 'Продолжить',
              ),
            ),
            IconButton(
              key: const ValueKey('step-exercise'),
              tooltip: 'Один такт',
              onPressed:
                  editing ||
                      running ||
                      (!replay && (completed || awaitingDecision))
                  ? null
                  : onStep,
              icon: const Icon(Icons.skip_next),
            ),
            DropdownButton<int>(
              value: speed,
              underline: const SizedBox.shrink(),
              items: [1, 2, 4]
                  .map((v) => DropdownMenuItem(value: v, child: Text('$v×')))
                  .toList(),
              onChanged: (v) => onSpeed(v!),
            ),
            Text(
              'T+${tick.toString().padLeft(3, '0')} / $duration',
              style: const TextStyle(
                fontFeatures: [FontFeature.tabularFigures()],
                color: TactixTheme.cyan,
              ),
            ),
            if (awaitingDecision && !replay)
              const Text(
                'Ожидается решение',
                style: TextStyle(color: TactixTheme.gold),
              ),
            if (!editing)
              IconButton(
                tooltip: 'Повторить с подготовки',
                onPressed: onReset,
                icon: const Icon(Icons.restart_alt),
              ),
            if (!editing)
              TextButton.icon(
                onPressed: onReplay,
                icon: const Icon(Icons.history),
                label: Text(replay ? 'К текущему состоянию' : 'Запись'),
              ),
            if (completed)
              TextButton.icon(
                onPressed: onReport,
                icon: const Icon(Icons.assessment_outlined),
                label: const Text('Отчёт'),
              ),
          ],
        ),
        if (replay && count > 1)
          Slider(
            key: const ValueKey('replay-slider'),
            value: index.toDouble(),
            min: 0,
            max: (count - 1).toDouble(),
            divisions: count - 1,
            onChanged: (v) => onSeek(v.round()),
          )
        else
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 4),
            child: SizedBox(
              height: 16,
              child: LayoutBuilder(
                builder: (context, constraints) => Stack(
                  children: [
                    Positioned(
                      top: 6,
                      left: 0,
                      right: 0,
                      child: LinearProgressIndicator(
                        value: tick / duration,
                        color: TactixTheme.cyan,
                        backgroundColor: Colors.white10,
                      ),
                    ),
                    ...injects.map(
                      (e) => Positioned(
                        left: (constraints.maxWidth - 12) * e.tick / duration,
                        child: Tooltip(
                          message: 'T+${e.tick}: ${injectLabels[e.kind.index]}',
                          child: Icon(
                            Icons.diamond,
                            size: 12,
                            color: e.tick <= tick
                                ? TactixTheme.cyan
                                : TactixTheme.gold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    ),
  );
}
