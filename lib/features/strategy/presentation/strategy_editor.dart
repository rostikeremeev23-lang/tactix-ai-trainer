import 'package:flutter/material.dart';

import '../domain/strategy_session.dart';
import '../domain/strategy_state.dart';

class StrategyEditor extends StatelessWidget {
  final StrategySession session;
  final VoidCallback onChanged;
  const StrategyEditor({
    super.key,
    required this.session,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'РЕДАКТОР УЧЕБНОЙ ОБСТАНОВКИ',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      const Text(
        'Задайте начальные сектора, состояние групп и запас ресурсов.',
      ),
      Text('Ресурсы: ${session.current.resources}%'),
      Slider(
        value: session.current.resources.toDouble(),
        min: 10,
        max: 100,
        divisions: 9,
        label: '${session.current.resources}%',
        onChanged: (value) {
          session.configure(resources: value.round());
          onChanged();
        },
      ),
      ...session.current.units.map(
        (unit) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${unit.name} • ${unit.type}'),
              DropdownButton<int>(
                key: ValueKey('sector-${unit.id}'),
                value: unit.sector,
                isExpanded: true,
                items: List.generate(
                  strategySectorNames.length,
                  (i) => DropdownMenuItem(
                    value: i,
                    child: Text(strategySectorNames[i]),
                  ),
                ),
                onChanged: (value) {
                  if (value == null) return;
                  session.configure(unitId: unit.id, sector: value);
                  onChanged();
                },
              ),
              Row(
                children: [
                  Text('Состояние: ${unit.strength}%'),
                  Expanded(
                    child: Slider(
                      value: unit.strength.toDouble(),
                      min: 0,
                      max: 100,
                      divisions: 20,
                      label: '${unit.strength}%',
                      onChanged: (value) {
                        session.configure(
                          unitId: unit.id,
                          strength: value.round(),
                        );
                        onChanged();
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ],
  );
}
