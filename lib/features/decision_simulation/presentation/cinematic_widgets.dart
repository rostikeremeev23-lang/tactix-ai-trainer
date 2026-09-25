import 'package:flutter/material.dart';

import '../domain/models.dart';
import 'cinematic_art.dart';
import 'story_visuals.dart';

const cinematicMetricLabels = {
  'time': 'Время',
  'supplies': 'Резерв',
  'safety': 'Безопасность',
  'coordination': 'Координация',
  'trust': 'Доверие',
  'evidence': 'Сведения',
  'fatigue': 'Нагрузка',
};

class CinematicEntrance extends StatelessWidget {
  final Widget child;
  const CinematicEntrance({super.key, required this.child});

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 480),
    curve: Curves.easeOutCubic,
    child: child,
    builder: (context, value, child) => Opacity(
      opacity: value,
      child: Transform.translate(
        offset: Offset(0, 12 * (1 - value)),
        child: child,
      ),
    ),
  );
}

class CinematicStage extends StatelessWidget {
  final StoryScene scene;
  const CinematicStage({super.key, required this.scene});

  @override
  Widget build(BuildContext context) {
    final direction = SceneDirection.forScene(scene.id);
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 700;
        final textScale = MediaQuery.textScalerOf(context).scale(16) / 16;
        return ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: SizedBox(
            height: (compact ? 228 : 254) + (textScale - 1).clamp(0, 2) * 100,
            child: Stack(
              fit: StackFit.expand,
              children: [
                SceneIllustration(
                  key: ValueKey('art-${scene.id}'),
                  direction: direction,
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF09151D).withValues(alpha: .97),
                        const Color(0xFF09151D)
                            .withValues(alpha: compact ? .70 : .25),
                        const Color(0xFF09151D).withValues(alpha: .05),
                      ],
                      stops: const [0, .57, 1],
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(compact ? 24 : 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        direction.caption,
                        style: TextStyle(
                          color: direction.accent,
                          fontSize: 11,
                          letterSpacing: 2.4,
                        ),
                      ),
                      const Spacer(),
                      Container(width: 38, height: 2, color: direction.accent),
                      const SizedBox(height: 16),
                      Text(
                        scene.title,
                        style: TextStyle(
                          color: const Color(0xFFF3EDE1),
                          fontSize: compact ? 28 : 38,
                          height: 1.16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -.7,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        scene.location,
                        style: const TextStyle(
                          color: Color(0xFFB4C5CB),
                          fontSize: 13,
                          letterSpacing: .5,
                        ),
                      ),
                    ],
                  ),
                ),
                IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.white.withValues(alpha: .10),
                      ),
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class CinematicStatus extends StatelessWidget {
  final RunState state;
  final bool busy;
  const CinematicStatus({super.key, required this.state, required this.busy});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Wrap(
        spacing: 18,
        runSpacing: 10,
        children: [
          _item(Icons.schedule_outlined, '${state.minutes} мин.', storyGold),
          _item(
            Icons.inventory_2_outlined,
            'Резерв ${state.values['supplies']}',
            storyGold,
          ),
          _item(
            Icons.shield_outlined,
            'Безопасность ${state.values['safety']}',
            storyCyan,
          ),
          _item(
            Icons.people_outline,
            'Доверие ${state.values['trust']}',
            storyCyan,
          ),
          _item(
            Icons.hub_outlined,
            'Координация ${state.values['coordination']}',
            storyCyan,
          ),
        ],
      ),
      const SizedBox(height: 16),
      LinearProgressIndicator(
        value: state.step / 12,
        minHeight: 2,
        color: storyGold,
        backgroundColor: Colors.white10,
        semanticsLabel: 'Прогресс истории: ${state.step} из 12 решений',
      ),
      const SizedBox(height: 10),
      Text(
        busy
            ? 'Сохранение решения…'
            : 'Сохранено на устройстве • сцена ${state.step + 1} из 12',
        style: const TextStyle(color: Color(0xFF9DB0BB), fontSize: 11),
      ),
    ],
  );

  Widget _item(IconData icon, String label, Color color) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 16, color: color),
      const SizedBox(width: 7),
      Text(
        label,
        style: const TextStyle(color: Color(0xFFD6E0E3), fontSize: 12),
      ),
    ],
  );
}

class CinematicDialogue extends StatelessWidget {
  final StoryScene scene;
  final StoryCharacter character;
  final List<SceneVariant> variants;
  final Widget tools;
  const CinematicDialogue({
    super.key,
    required this.scene,
    required this.character,
    required this.variants,
    required this.tools,
  });

  @override
  Widget build(BuildContext context) => StoryPanel(
    padding: const EdgeInsets.all(24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CharacterPortrait(characterId: character.id, size: 64),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'НА СВЯЗИ',
                    style: TextStyle(
                      color: storyCyan,
                      fontSize: 10,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    character.name,
                    style: const TextStyle(
                      color: Color(0xFFF0E6D9),
                      fontSize: 19,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    character.role,
                    style: const TextStyle(
                      color: Color(0xFF9AAEBB),
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Divider(height: 1, color: Colors.white10),
        ),
        AnimatedNarration(
          key: ValueKey('dialogue-${scene.id}'),
          text: scene.text,
        ),
        for (final variant in variants)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text(
              variant.text,
              style: const TextStyle(
                color: storyCyan,
                height: 1.6,
                fontSize: 15,
              ),
            ),
          ),
        const SizedBox(height: 18),
        tools,
      ],
    ),
  );
}

/// Full narration is always exposed to accessibility, with no layout movement.
/// Completing or skipping the reveal never dispatches an engine command.
class AnimatedNarration extends StatefulWidget {
  final String text;
  const AnimatedNarration({super.key, required this.text});
  @override
  State<AnimatedNarration> createState() => _AnimatedNarrationState();
}

class _AnimatedNarrationState extends State<AnimatedNarration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context)) {
      _controller.value = 1;
    } else if (!_started) {
      _controller.forward();
    }
    _started = true;
  }

  @override
  void didUpdateWidget(AnimatedNarration oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      if (MediaQuery.disableAnimationsOf(context) ||
          MediaQuery.accessibleNavigationOf(context)) {
        _controller.value = 1;
      } else {
        _controller.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      color: Color(0xFFD5DEE2),
      fontSize: 16,
      height: 1.75,
    );
    final characters = widget.text.characters;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final complete = _controller.value == 1;
        final visible = complete
            ? widget.text
            : characters
                  .take((characters.length * _controller.value).floor())
                  .toString();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              label: widget.text,
              child: ExcludeSemantics(
                child: Stack(
                  children: [
                    Opacity(opacity: 0, child: Text(widget.text, style: style)),
                    Text(
                      visible,
                      key: const Key('narration-visible'),
                      style: style,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 48,
              child: Align(
                alignment: Alignment.centerLeft,
                child: complete
                    ? const Text(
                        'Чтение не расходует игровое время',
                        style: TextStyle(
                          color: Color(0xFF94A9B5),
                          fontSize: 11,
                        ),
                      )
                    : TextButton.icon(
                        key: const Key('finish-dialogue'),
                        onPressed: () => _controller.value = 1,
                        icon: const Icon(Icons.fast_forward_outlined, size: 16),
                        label: const Text('Показать полностью'),
                        style: TextButton.styleFrom(foregroundColor: storyCyan),
                      ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class CinematicReports extends StatelessWidget {
  final List<RunEvent> events;
  final DecisionScenario scenario;
  const CinematicReports({
    super.key,
    required this.events,
    required this.scenario,
  });

  @override
  Widget build(BuildContext context) {
    final reports = events
        .where((e) => e.kind != 'cost' && e.kind != 'rationale')
        .toList();
    final delta = <String, int>{};
    for (final event in events) {
      for (final entry in event.delta.entries) {
        delta.update(
          entry.key,
          (value) => value + entry.value,
          ifAbsent: () => entry.value,
        );
      }
    }
    return CinematicEntrance(
      child: Container(
        key: const Key('consequence-feed'),
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF203232), Color(0xFF14232A)],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: storyCyan.withValues(alpha: .25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.graphic_eq, color: storyCyan, size: 17),
                SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'ПОСЛЕДНЕЕ ДОНЕСЕНИЕ',
                    style: TextStyle(
                      color: storyCyan,
                      fontSize: 10,
                      letterSpacing: 1.8,
                    ),
                  ),
                ),
              ],
            ),
            for (final report in reports) ...[
              const SizedBox(height: 10),
              if (report.kind == 'consequence' || report.kind == 'averted')
                Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Text(
                    '${report.kind == 'averted' ? 'Последствие предотвращено' : 'Отложенное последствие'} • ${_cause(report.cause)}',
                    style: const TextStyle(color: storyGold, fontSize: 12),
                  ),
                ),
              Text(
                report.text,
                style: const TextStyle(
                  color: Color(0xFFE1E8E6),
                  fontSize: 14,
                  height: 1.55,
                ),
              ),
            ],
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final entry in delta.entries.where((e) => e.value != 0))
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: .18),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      '${cinematicMetricLabels[entry.key] ?? entry.key} ${entry.value > 0 ? '+' : ''}${entry.value}',
                      style: TextStyle(
                        color: entry.key == 'time' || entry.key == 'supplies'
                            ? storyGold
                            : storyCyan,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _cause(String cause) {
    final parts = cause.split('/');
    if (parts.length != 2) return 'Событие обстановки';
    return scenario
        .scene(parts.first)
        .actions
        .firstWhere((action) => action.id == parts.last)
        .title;
  }
}

class CinematicChoice extends StatefulWidget {
  final StoryAction action;
  final int number;
  final bool available, used, busy, proposed;
  final VoidCallback onChoose;
  const CinematicChoice({
    super.key,
    required this.action,
    required this.number,
    required this.available,
    required this.used,
    required this.busy,
    required this.proposed,
    required this.onChoose,
  });
  @override
  State<CinematicChoice> createState() => _CinematicChoiceState();
}

class _CinematicChoiceState extends State<CinematicChoice> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) {
    final action = widget.action;
    final accent = action.inquiry ? storyCyan : storyGold;
    final enabled = widget.available && !widget.busy;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 160),
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _hovered && enabled
              ? const Color(0xFF253239)
              : const Color(0xFF17242D),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: _hovered && enabled ? accent : accent.withValues(alpha: .2),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  action.inquiry ? Icons.radio_outlined : Icons.alt_route,
                  color: accent,
                  size: 17,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    action.inquiry
                        ? 'УТОЧНЕНИЕ'
                        : 'ВАРИАНТ ${widget.number.toString().padLeft(2, '0')}',
                    style: TextStyle(
                      color: accent,
                      fontSize: 10,
                      letterSpacing: 1.8,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (widget.proposed)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  'AI предлагает эту основу. Выбор остаётся за вами.',
                  style: TextStyle(color: storyGold),
                ),
              ),
            Text(
              action.title,
              style: TextStyle(
                color: widget.available
                    ? const Color(0xFFF3EDE1)
                    : Colors.white54,
                fontSize: action.inquiry ? 16 : 18,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 9),
            Text(
              action.tradeoff,
              style: const TextStyle(
                color: Color(0xFFAEBEC8),
                fontSize: 13,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 15),
            Wrap(
              spacing: 14,
              runSpacing: 6,
              children: [
                Text(
                  '${action.minutes} мин.',
                  style: TextStyle(color: accent, fontSize: 12),
                ),
                Text(
                  'Резерв: ${action.supplies}',
                  style: const TextStyle(
                    color: Color(0xFFADBEC6),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: Key('action-${action.id}'),
                onPressed: enabled ? widget.onChoose : null,
                icon: Icon(
                  widget.used
                      ? Icons.done
                      : action.inquiry
                      ? Icons.graphic_eq
                      : Icons.arrow_forward,
                  size: 17,
                ),
                label: Text(
                  widget.used
                      ? 'Запрос выполнен'
                      : !widget.available
                      ? 'Недоступно при текущих условиях'
                      : action.inquiry
                      ? 'Уточнить по связи'
                      : 'Выбрать',
                ),
                style: FilledButton.styleFrom(
                  foregroundColor: action.inquiry
                      ? storyCyan
                      : const Color(0xFF192126),
                  backgroundColor: action.inquiry
                      ? const Color(0xFF213B43)
                      : storyGold,
                  minimumSize: const Size(48, 48),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
