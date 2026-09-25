import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../domain/scenario.dart';
import 'terrain_view.dart';

class ScenarioEditor extends StatelessWidget {
  final StudioScenario scenario;
  final ValueChanged<StudioScenario> onChanged;
  final ValueChanged<ObjectKind> onAdd;
  final ValueChanged<String> onSelect;
  const ScenarioEditor({
    super.key,
    required this.scenario,
    required this.onChanged,
    required this.onAdd,
    required this.onSelect,
  });
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      Row(
        children: [
          const Expanded(
            child: Text(
              'КОНСТРУКТОР',
              style: TextStyle(
                color: TactixTheme.gold,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.4,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Закрыть конструктор',
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      const SizedBox(height: 16),
      Text(scenario.name, style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      Text(
        exerciseLabels[scenario.kind.index],
        style: const TextStyle(color: TactixTheme.cyan),
      ),
      const SizedBox(height: 8),
      const Text(
        'Долина Северная • вымышленная территория',
        style: TextStyle(color: Colors.white54, fontSize: 12),
      ),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: () async {
          final result = await editScenario(context, scenario);
          if (result != null) onChanged(result);
        },
        icon: const Icon(Icons.tune),
        label: const Text('Параметры занятия'),
      ),
      const Divider(height: 32),
      const Text(
        'БИБЛИОТЕКА ОБЪЕКТОВ',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 8),
      const Text(
        'Выберите тип, затем коснитесь места на карте.',
        style: TextStyle(color: Colors.white54, fontSize: 12),
      ),
      ...ObjectKind.values.map(
        (kind) => ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(objectIcon(kind), color: objectColor(kind)),
          title: Text(objectLabels[kind.index]),
          trailing: const Icon(Icons.add, size: 18),
          onTap: () => onAdd(kind),
        ),
      ),
      const Divider(height: 24),
      Text(
        'ОБЪЕКТЫ / ${scenario.objects.length} из 30',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      ...scenario.objects.map(
        (o) => ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            objectIcon(o.kind),
            size: 20,
            color: objectColor(o.kind),
          ),
          title: Text(o.name),
          subtitle: Text(o.id),
          onTap: () => onSelect(o.id),
        ),
      ),
      const Divider(height: 24),
      const Text(
        'ПОСЛЕДОВАТЕЛЬНОСТЬ ВВОДНЫХ',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      ...([...scenario.injects]..sort((a, b) => a.tick.compareTo(b.tick))).map(
        (e) => ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(injectLabels[e.kind.index]),
          subtitle: Text('T+${e.tick} • обязательная пауза'),
          onTap: () async {
            final edited = await editInject(context, e, scenario.duration);
            if (edited != null) {
              onChanged(
                scenario.copyWith(
                  injects: scenario.injects
                      .map((i) => i.id == e.id ? edited : i)
                      .toList(),
                ),
              );
            }
          },
          trailing: IconButton(
            tooltip: 'Удалить вводную',
            icon: const Icon(Icons.close),
            onPressed: () => onChanged(
              scenario.copyWith(
                injects: scenario.injects.where((i) => i.id != e.id).toList(),
              ),
            ),
          ),
        ),
      ),
      OutlinedButton.icon(
        onPressed: scenario.injects.length >= 8
            ? null
            : () async {
                var id = 1;
                while (scenario.injects.any((e) => e.id == 'evt-$id')) {
                  id++;
                }
                final e = await editInject(
                  context,
                  ScenarioInject('evt-$id', InjectKind.road, 10),
                  scenario.duration,
                );
                if (e != null) {
                  onChanged(
                    scenario.copyWith(injects: [...scenario.injects, e]),
                  );
                }
              },
        icon: const Icon(Icons.add),
        label: const Text('Добавить вводную'),
      ),
      const SizedBox(height: 20),
    ],
  );
}

Future<StudioScenario?> editScenario(
  BuildContext context,
  StudioScenario scenario,
) async {
  final name = TextEditingController(text: scenario.name);
  final briefing = TextEditingController(text: scenario.briefing);
  var kind = scenario.kind;
  var resources = scenario.resources;
  var duration = scenario.duration;
  final result = await showDialog<StudioScenario>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, update) => AlertDialog(
        title: const Text('Параметры учебного сценария'),
        content: SizedBox(
          width: 450,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  maxLength: 100,
                  decoration: const InputDecoration(labelText: 'Название'),
                ),
                TextField(
                  controller: briefing,
                  minLines: 3,
                  maxLines: 5,
                  maxLength: 2000,
                  decoration: const InputDecoration(
                    labelText: 'Исходная обстановка и цели',
                  ),
                ),
                DropdownButtonFormField<ExerciseKind>(
                  initialValue: kind,
                  isExpanded: true,
                  items: ExerciseKind.values
                      .map(
                        (k) => DropdownMenuItem(
                          value: k,
                          child: Text(exerciseLabels[k.index]),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => kind = v!,
                ),
                const SizedBox(height: 16),
                Text('Начальные ресурсы: $resources'),
                Slider(
                  value: resources.toDouble(),
                  min: 10,
                  max: 100,
                  divisions: 18,
                  onChanged: (v) => update(() => resources = v.round()),
                ),
                Text('Длительность: $duration учебных тактов'),
                Slider(
                  value: duration.toDouble(),
                  min: 40,
                  max: 120,
                  divisions: 8,
                  onChanged: (v) => update(() => duration = v.round()),
                ),
                const Text(
                  'Один такт — условная единица, не реальное время.',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              if (name.text.trim().isEmpty) return;
              Navigator.pop(
                context,
                scenario.copyWith(
                  name: name.text.trim(),
                  briefing: briefing.text,
                  kind: kind,
                  resources: resources,
                  duration: duration,
                  injects: scenario.injects
                      .map(
                        (e) => ScenarioInject(
                          e.id,
                          e.kind,
                          e.tick.clamp(1, duration - 4),
                        ),
                      )
                      .toList(),
                ),
              );
            },
            child: const Text('Применить'),
          ),
        ],
      ),
    ),
  );
  // Controllers are owned by this dialog and no longer used after its exit animation.
  await Future<void>.delayed(const Duration(milliseconds: 300));
  name.dispose();
  briefing.dispose();
  return result;
}

Future<ScenarioInject?> editInject(
  BuildContext context,
  ScenarioInject inject,
  int duration,
) => showDialog<ScenarioInject>(
  context: context,
  builder: (context) {
    var kind = inject.kind;
    var tick = inject.tick;
    return StatefulBuilder(
      builder: (context, update) => AlertDialog(
        title: const Text('Учебная вводная'),
        content: SizedBox(
          width: 350,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<InjectKind>(
                initialValue: kind,
                isExpanded: true,
                items: InjectKind.values
                    .map(
                      (k) => DropdownMenuItem(
                        value: k,
                        child: Text(injectLabels[k.index]),
                      ),
                    )
                    .toList(),
                onChanged: (v) => kind = v!,
              ),
              const SizedBox(height: 20),
              Text('Время появления: T+$tick'),
              Slider(
                value: tick.toDouble(),
                min: 1,
                max: (duration - 4).toDouble(),
                divisions: duration - 5,
                onChanged: (v) => update(() => tick = v.round()),
              ),
              const Text(
                'Правила и последствия фиксированы. Время и порядок задаёт инструктор.',
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
            onPressed: () =>
                Navigator.pop(context, ScenarioInject(inject.id, kind, tick)),
            child: const Text('Применить'),
          ),
        ],
      ),
    );
  },
);
