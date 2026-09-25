import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../domain/scenario.dart';
import '../domain/engine.dart';
import '../domain/decisions.dart';
import 'terrain_view.dart';

class ExerciseContextPanel extends StatelessWidget {
  final StudioScenario scenario;
  final ExerciseFrame? frame;
  final MapObject? selected;
  final bool editing, replay;
  final VoidCallback onMove, onFocus, onDelete;
  final ValueChanged<MapObject> onEdit;
  final ValueChanged<int> onDecision;
  const ExerciseContextPanel({
    super.key,
    required this.scenario,
    required this.frame,
    required this.selected,
    required this.editing,
    required this.replay,
    required this.onMove,
    required this.onFocus,
    required this.onDelete,
    required this.onEdit,
    required this.onDecision,
  });
  @override
  Widget build(BuildContext context) {
    final object = selected;
    final pending = frame?.pending;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          replay
              ? 'ЗАПИСЬ ПРОХОЖДЕНИЯ'
              : editing
              ? 'ПОДГОТОВКА'
              : 'ОБСТАНОВКА',
          style: const TextStyle(
            color: TactixTheme.cyan,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 12),
        if (frame != null) ...[
          _metric('Ресурсы', frame!.resources, TactixTheme.gold),
          _metric('Безопасность', frame!.safety, Colors.greenAccent),
          _metric('Согласованность', frame!.cohesion, TactixTheme.cyan),
          Text(
            frame!.condition,
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
        if (pending != null) ...[
          const Divider(height: 28),
          Text(
            injectLabels[pending.kind.index],
            style: const TextStyle(
              color: TactixTheme.gold,
              fontSize: 19,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(injectBrief(pending.kind)),
          const SizedBox(height: 12),
          if (replay)
            const Text(
              'Просмотр сохранённой вводной. Решения здесь не изменяются.',
            )
          else
            ...choicesFor(pending.kind).asMap().entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FilledButton.tonal(
                      key: ValueKey('decision-${entry.key}'),
                      onPressed: frame!.resources < entry.value.cost
                          ? null
                          : () => onDecision(entry.key),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          entry.value.title,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      entry.value.consequence,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                    if (frame!.resources < entry.value.cost)
                      const Text(
                        'Недостаточно ресурсов',
                        style: TextStyle(
                          color: Colors.orangeAccent,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
        const Divider(height: 28),
        if (object == null) ...[
          const Icon(
            Icons.touch_app_outlined,
            size: 32,
            color: TactixTheme.textMuted,
          ),
          const SizedBox(height: 12),
          Text(
            editing
                ? 'Откройте конструктор, добавьте объекты из библиотеки или выберите объект на карте.'
                : 'Выберите группу или транспорт, чтобы задать прямой учебный маршрут.',
            style: const TextStyle(color: Colors.white70, height: 1.5),
          ),
        ] else ...[
          Row(
            children: [
              Icon(objectIcon(object.kind), color: objectColor(object.kind)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  object.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${object.id} · ${objectLabels[object.kind.index]}',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 12),
          _metric('Готовность', object.readiness, objectColor(object.kind)),
          Text(
            'X ${(object.position.x * 100).round()} / Y ${(object.position.y * 100).round()} · условная сетка',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onFocus,
            icon: const Icon(Icons.center_focus_strong),
            label: const Text('Центрировать'),
          ),
          if (!replay &&
              (editing || (object.mobile && frame!.tick < scenario.duration)))
            OutlinedButton.icon(
              key: const ValueKey('move-object'),
              onPressed: pending == null ? onMove : null,
              icon: const Icon(Icons.route),
              label: Text(editing ? 'Переместить на карте' : 'Задать маршрут'),
            ),
          if (editing) ...[
            OutlinedButton.icon(
              onPressed: () async {
                final result = await editMapObject(context, object);
                if (result != null) onEdit(result);
              },
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Свойства объекта'),
            ),
            TextButton.icon(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Удалить объект'),
            ),
          ],
        ],
        const Divider(height: 28),
        if (frame == null) ...[
          const Text('БРИФИНГ', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Text(
            scenario.briefing,
            style: const TextStyle(height: 1.5, color: Colors.white70),
          ),
          const SizedBox(height: 12),
          const Text(
            'Учебная модель: без расчёта вооружений, столкновений и проходимости. Маршруты прямые.',
            style: TextStyle(fontSize: 12, color: Colors.white54),
          ),
        ] else ...[
          const Text(
            'ЖУРНАЛ СОБЫТИЙ',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          ...frame!.log.reversed.map(
            (line) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                line,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _metric(String label, int value, Color color) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: const TextStyle(fontSize: 12))),
            Text(
              '$value',
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 5),
        LinearProgressIndicator(
          value: value / 100,
          color: color,
          minHeight: 3,
          backgroundColor: Colors.white10,
          borderRadius: BorderRadius.circular(4),
        ),
      ],
    ),
  );
}

Future<MapObject?> editMapObject(BuildContext context, MapObject object) async {
  final name = TextEditingController(text: object.name);
  var readiness = object.readiness;
  final result = await showDialog<MapObject>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, update) => AlertDialog(
        title: const Text('Свойства объекта'),
        content: SizedBox(
          width: 350,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                maxLength: 60,
                decoration: const InputDecoration(labelText: 'Название'),
              ),
              Text('Условная готовность: $readiness'),
              Slider(
                value: readiness.toDouble(),
                divisions: 20,
                min: 0,
                max: 100,
                onChanged: (v) => update(() => readiness = v.round()),
              ),
              const Text(
                'Готовность определяет игровой темп движения, не боевую эффективность.',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              if (name.text.trim().isNotEmpty) {
                Navigator.pop(
                  context,
                  object.copyWith(name: name.text.trim(), readiness: readiness),
                );
              }
            },
            child: const Text('Применить'),
          ),
        ],
      ),
    ),
  );
  await Future<void>.delayed(const Duration(milliseconds: 300));
  name.dispose();
  return result;
}
