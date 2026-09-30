import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../domain/city_scenarios.dart';
import '../domain/scenario.dart';
import 'city_map.dart';

class CityLibrary extends StatefulWidget {
  final String currentName;
  final VoidCallback onResume, onArchive;
  final Future<void> Function(StudioScenario) onOpen;
  const CityLibrary({
    super.key,
    required this.currentName,
    required this.onResume,
    required this.onArchive,
    required this.onOpen,
  });
  @override
  State<CityLibrary> createState() => _CityLibraryState();
}

class _CityLibraryState extends State<CityLibrary> {
  int _difficulty = 1;
  int _seed = 42;
  bool _busy = false;
  Future<void> _brief(int index) async {
    final scenario = CityScenarios.create(
      index,
      difficulty: _difficulty,
      seed: _seed,
    );
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(scenario.name),
        content: SizedBox(
          width: 540,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(scenario.briefing, style: const TextStyle(height: 1.6)),
                const SizedBox(height: 20),
                Text(
                  '${scenario.duration} тактов · ${scenario.resources} ресурсов · seed ${scenario.seed}',
                ),
                const SizedBox(height: 12),
                const Text(
                  'Планирование: выберите жетон и переместите его к цели. Удержание позволяет перетаскивать. '
                  'Запустите игру; во время паузы можно задавать прямые маршруты. '
                  'При вводной выберите решение, затем продолжите воспроизведение.',
                ),
                const SizedBox(height: 12),
                const Text(
                  'Синтетическая карта, придуманные объекты и условные жетоны. '
                  'Прямые маршруты не учитывают мосты и дороги. Это образовательная игра.',
                  style: TextStyle(color: TactixTheme.textMuted),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Назад'),
          ),
          FilledButton(
            key: const Key('prepare-city'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('К планированию'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.onOpen(scenario);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < 700;
      return ListView(
        padding: EdgeInsets.all(compact ? 20 : 36),
        children: [
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: TactixTheme.panel,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: TactixTheme.line),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: Opacity(
                    opacity: .46,
                    child: CustomPaint(
                      painter: const CityMapPainter(labels: false),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          TactixTheme.bg,
                          TactixTheme.bg.withValues(alpha: .4),
                        ],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(compact ? 24 : 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'TRAINING / SIMULATION LAB',
                        style: TextStyle(
                          color: TactixTheme.gold,
                          letterSpacing: 3,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 22),
                      Text(
                        'Каждое решение.\nНовый исход.',
                        style: TextStyle(
                          fontSize: compact ? 34 : 52,
                          height: 1.12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -1.5,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const SizedBox(
                        width: 460,
                        child: Text(
                          'Город — система взаимосвязей. Распределяйте ресурсы, '
                          'проверяйте предположения и учитесь на последствиях.',
                          style: TextStyle(
                            color: Color(0xFFB5C3CB),
                            height: 1.6,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          FilledButton.icon(
                            key: const Key('resume-studio'),
                            onPressed: widget.onResume,
                            icon: const Icon(Icons.play_arrow),
                            label: const Text('Продолжить занятие'),
                          ),
                          OutlinedButton.icon(
                            onPressed: widget.onArchive,
                            icon: const Icon(Icons.history),
                            label: const Text('Мои планы и результаты'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        widget.currentName,
                        style: const TextStyle(color: TactixTheme.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          Text(
            'Лаборатория решений',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text(
            'Три вымышленных сценария · автономная игра · воспроизводимые результаты',
            style: TextStyle(color: TactixTheme.textMuted),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 24,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: compact ? constraints.maxWidth - 40 : 380,
                child: DropdownButton<int>(
                  isExpanded: true,
                  value: _difficulty,
                  items: const [
                    DropdownMenuItem(
                      value: 0,
                      child: Text('Ознакомление · 80 тактов / 100 ресурсов'),
                    ),
                    DropdownMenuItem(
                      value: 1,
                      child: Text('Стандарт · 60 тактов / 75 ресурсов'),
                    ),
                    DropdownMenuItem(
                      value: 2,
                      child: Text('Вызов · 40 тактов / 45 ресурсов'),
                    ),
                  ],
                  onChanged: _busy
                      ? null
                      : (v) => setState(() => _difficulty = v!),
                ),
              ),
              SizedBox(
                width: 200,
                child: TextFormField(
                  initialValue: '42',
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Seed событий (0–999999)',
                  ),
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  validator: (v) =>
                      int.tryParse(v ?? '') == null ||
                          int.parse(v!) < 0 ||
                          int.parse(v) > 999999
                      ? 'Целое число 0–999999'
                      : null,
                  onChanged: (v) =>
                      setState(() => _seed = int.tryParse(v) ?? -1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              for (var i = 0; i < 3; i++)
                SizedBox(
                  width: compact
                      ? constraints.maxWidth - 40
                      : (constraints.maxWidth - 104) / 3,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                [
                                  Icons.shield_outlined,
                                  Icons.hub_outlined,
                                  Icons.explore_outlined,
                                ][i],
                                color: TactixTheme.gold,
                                size: 32,
                              ),
                              const Spacer(),
                              Text(
                                '0${i + 1}',
                                style: const TextStyle(
                                  color: TactixTheme.textMuted,
                                  letterSpacing: 2,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 28),
                          Text(
                            CityScenarios.titles[i],
                            style: const TextStyle(
                              fontSize: 23,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            CityScenarios.subtitles[i],
                            style: const TextStyle(
                              color: TactixTheme.textMuted,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            i == 2
                                ? '3 цели / 5 вводных'
                                : '2 цели / 3 вводные',
                            style: const TextStyle(color: TactixTheme.cyan),
                          ),
                          const SizedBox(height: 16),
                          TextButton.icon(
                            key: Key('city-scenario-$i'),
                            onPressed: _busy || _seed < 0 || _seed > 999999
                                ? null
                                : () => _brief(i),
                            icon: const Icon(Icons.arrow_forward),
                            label: const Text('Открыть брифинг'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'ASTRA — вымышленный город с архитектурным вдохновением от Астаны. '
            'Геометрия, секторы, мосты и сценарии полностью синтетические.',
            style: TextStyle(color: TactixTheme.textMuted, height: 1.5),
          ),
        ],
      );
    },
  );
}
