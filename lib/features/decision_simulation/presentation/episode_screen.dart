import 'package:flutter/material.dart';

import '../application/simulation_controller.dart';
import '../application/simulation_ai_adapter.dart';
import '../data/run_repository.dart';
import '../domain/assessment.dart';
import '../domain/decision_engine.dart';
import '../domain/models.dart';
import 'decision_tree_screen.dart';
import 'cinematic_art.dart';
import 'cinematic_widgets.dart';
import 'story_visuals.dart';

class EpisodeScreen extends StatefulWidget {
  final DecisionEngine engine;
  final RunRepository repository;
  final RunState initialState;
  const EpisodeScreen({
    super.key,
    required this.engine,
    required this.repository,
    required this.initialState,
  });
  @override
  State<EpisodeScreen> createState() => _EpisodeScreenState();
}

class _EpisodeScreenState extends State<EpisodeScreen> {
  late final controller = SimulationController(
    widget.engine,
    widget.repository,
    widget.initialState,
  );
  late final ai = SimulationAiAdapter(widget.engine);
  final note = TextEditingController();
  final scroll = ScrollController();
  bool aiBusy = false;
  String? proposal;
  @override
  void dispose() {
    controller.dispose();
    note.dispose();
    scroll.dispose();
    super.dispose();
  }

  Future<void> _act(StoryAction action) async {
    if (controller.busy) return;
    if (!action.inquiry) {
      final approved = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF17242D),
          scrollable: true,
          icon: const Icon(Icons.alt_route, color: storyGold),
          title: Text(action.title),
          content: Text(
            '${action.tradeoff}\n\nВремя: ${action.minutes} мин. '
            'Резерв: ${action.supplies}.\n\nПосле подтверждения решение будет сохранено.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Вернуться'),
            ),
            FilledButton(
              key: const Key('confirm-decision'),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Принять решение'),
            ),
          ],
        ),
      );
      if (approved != true || !mounted) return;
    }
    final success = await controller.act(
      action.id,
      note: action.inquiry ? '' : note.text,
    );
    if (!mounted) return;
    if (success) {
      note.clear();
      setState(() => proposal = null);
      // Wait for the new scene/report to establish its scroll dimensions.
      // Otherwise layout can cancel the animation while shrinking the content.
      await WidgetsBinding.instance.endOfFrame;
      if (mounted && scroll.hasClients) {
        await scroll.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    }
  }

  Future<void> _askAi() async {
    var draft = '';
    final question = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Вопрос AI-инструктору'),
        content: SizedBox(
          width: 480,
          child: TextField(
            onChanged: (value) => draft = value,
            maxLength: 600,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'Уточните смысл уже известных сведений.',
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, draft.trim()),
            child: const Text('Спросить'),
          ),
        ],
      ),
    );
    if (question == null || question.isEmpty || !mounted) return;
    await _aiText(
      () => ai.discuss(controller.state, question),
      'Комментарий AI',
    );
  }

  Future<void> _aiText(Future<String> Function() request, String title) async {
    if (aiBusy) return;
    final revision = controller.state.revision;
    setState(() => aiBusy = true);
    try {
      final text = await request();
      if (!mounted || controller.state.revision != revision) return;
      await showStoryText(
        context,
        title,
        'Дополнительный комментарий. Подтверждённые факты, результаты и баллы '
        'смотрите в журнале движка.\n\n$text',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'AI недоступен. Сценарий и локальный разбор работают офлайн. $e',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => aiBusy = false);
    }
  }

  Future<void> _interpret() async {
    if (note.text.trim().isEmpty || aiBusy) return;
    final revision = controller.state.revision;
    setState(() => aiBusy = true);
    try {
      final id = await ai.interpret(controller.state, note.text.trim());
      if (!mounted || revision != controller.state.revision) return;
      setState(() => proposal = id);
      if (id == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Нет однозначного соответствия. Выберите исполнимую основу самостоятельно.',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'AI недоступен. Выберите основу решения ниже; обоснование сохранится.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => aiBusy = false);
    }
  }

  void _documents(RunState state) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: storyBackground,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .7,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                'Документы смены',
                style: TextStyle(color: storyCyan, fontSize: 24),
              ),
              const SizedBox(height: 16),
              for (final doc in widget.engine.scenario.documents.where(
                (d) => state.knownDocuments.contains(d.id),
              ))
                ListTile(
                  leading: const Icon(
                    Icons.description_outlined,
                    color: storyCyan,
                  ),
                  title: Text(
                    doc.title,
                    style: const TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    doc.source,
                    style: const TextStyle(color: Colors.white60),
                  ),
                  onTap: () => showStoryText(
                    sheetContext,
                    doc.title,
                    'Источник: ${doc.source}\nДостоверность: ${doc.reliability}\n\n${doc.text}',
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _characters() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: storyBackground,
    builder: (context) => SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .8,
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Команда',
                style: TextStyle(color: storyCyan, fontSize: 24),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  for (final character in widget.engine.scenario.characters)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: StoryPanel(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CharacterPortrait(
                              characterId: character.id,
                              size: 60,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    character.name,
                                    style: const TextStyle(
                                      color: storyGold,
                                      fontSize: 18,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    character.role,
                                    style: const TextStyle(
                                      color: storyCyan,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    character.position,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      height: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Закрыть'),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  String _eventText(RunEvent event) {
    const labels = {
      'time': 'Время',
      'supplies': 'Резерв',
      'safety': 'Безопасность',
      'coordination': 'Координация',
      'trust': 'Доверие',
      'evidence': 'Работа со сведениями',
      'fatigue': 'Нагрузка команды',
    };
    final scene = widget.engine.scenario.scene(event.scene);
    final origin = event.cause.split('/');
    final cause = origin.length == 2
        ? widget.engine.scenario
              .scene(origin.first)
              .actions
              .firstWhere((action) => action.id == origin.last)
              .title
        : 'Погодное событие';
    final changes = event.delta.entries
        .map(
          (entry) =>
              '${labels[entry.key] ?? entry.key}: '
              '${entry.value > 0 ? '+' : ''}${entry.value}',
        )
        .join(', ');
    return '#${event.sequence} • ${scene.title}\nПричина: $cause\n'
        '${event.text}${changes.isEmpty ? '' : '\nИзменения: $changes'}';
  }

  void _journal(RunState state) => showStoryText(
    context,
    'Журнал событий',
    state.events.isEmpty
        ? 'Решения ещё не приняты.'
        : state.events.map(_eventText).join('\n\n'),
  );

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final state = controller.state;
      return Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
            primary: storyGold,
            onPrimary: storyBackground,
            secondary: storyCyan,
            surface: storyBackground,
          ),
        ),
        child: PopScope(
          canPop: !controller.busy,
          child: Scaffold(
            backgroundColor: storyBackground,
            appBar: AppBar(
              backgroundColor: storyBackground,
              title: Text(
                state.completed ? 'Итог эпизода' : 'Сигнал после шторма',
              ),
              actions: [
                IconButton(
                  tooltip: 'Документы',
                  onPressed: () => _documents(state),
                  icon: const Icon(Icons.folder_open),
                ),
                IconButton(
                  tooltip: 'Журнал событий',
                  onPressed: () => _journal(state),
                  icon: const Icon(Icons.receipt_long),
                ),
              ],
            ),
            body: StoryBackdrop(
              child: SizedBox.expand(
                child: SingleChildScrollView(
                  controller: scroll,
                  padding: const EdgeInsets.all(20),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1280),
                      child: state.completed ? _report(state) : _episode(state),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );

  Widget _episode(RunState state) {
    final scene = widget.engine.scenario.scene(state.sceneId);
    final character = widget.engine.scenario.characters.firstWhere(
      (character) => character.name == scene.speaker,
    );
    final lastCost = state.events.lastIndexWhere(
      (event) => event.kind == 'cost',
    );
    final recent = lastCost < 0
        ? <RunEvent>[]
        : state.events.skip(lastCost).toList();
    final dialogue = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CinematicDialogue(
          scene: scene,
          character: character,
          variants: scene.variants
              .where((variant) => variant.when.matches(state))
              .toList(),
          tools: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              TextButton.icon(
                onPressed: () => _documents(state),
                icon: const Icon(Icons.description_outlined, size: 18),
                label: const Text('Изучить документы'),
              ),
              TextButton.icon(
                onPressed: _characters,
                icon: const Icon(Icons.people_outline, size: 18),
                label: const Text('Команда'),
              ),
              TextButton.icon(
                onPressed: aiBusy ? null : _askAi,
                icon: const Icon(Icons.auto_awesome_outlined, size: 18),
                label: Text(aiBusy ? 'AI отвечает…' : 'Обсудить с AI'),
              ),
            ],
          ),
        ),
        for (final action in scene.actions.where((action) => action.inquiry))
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: _action(state, action),
          ),
      ],
    );
    final decisions = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ВАШ СЛЕДУЮЩИЙ ШАГ',
          style: TextStyle(color: storyGold, letterSpacing: 2, fontSize: 11),
        ),
        const SizedBox(height: 8),
        const Text(
          'У каждого решения есть цена.',
          style: TextStyle(color: Color(0xFFAFBEC6), fontSize: 13),
        ),
        const SizedBox(height: 18),
        if (scene.id == 's11') ...[
          StoryPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ваше решение своими словами',
                  style: TextStyle(color: storyCyan, fontSize: 20),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: note,
                  maxLines: 4,
                  maxLength: 1200,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: 'Что поручить, кому и почему?',
                    border: OutlineInputBorder(),
                  ),
                ),
                const Text(
                  'Текст сохраняется как обоснование. Выберите исполнимую основу ниже. '
                  'AI может предложить соответствие, но не выполнит решение.',
                  style: TextStyle(color: Colors.white70, height: 1.5),
                ),
                TextButton(
                  onPressed: aiBusy ? null : _interpret,
                  child: const Text('Предложить соответствие через AI'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        for (final action in scene.actions.where((action) => !action.inquiry))
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _action(state, action),
          ),
        const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.bookmark_border, size: 15, color: Color(0xFF8EA5B2)),
            SizedBox(width: 7),
            Expanded(
              child: Text(
                'Решение сохранится после подтверждения.',
                style: TextStyle(
                  color: Color(0xFF8EA5B2),
                  fontSize: 11,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ],
    );
    return CinematicEntrance(
      key: ValueKey('scene-entrance-${scene.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CinematicStatus(state: state, busy: controller.busy),
          if (controller.error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                controller.error!,
                style: const TextStyle(color: storyGold),
              ),
            ),
          const SizedBox(height: 20),
          CinematicStage(scene: scene),
          const SizedBox(height: 22),
          if (recent.isNotEmpty) ...[
            CinematicReports(
              key: ValueKey('reports-${state.revision}'),
              events: recent,
              scenario: widget.engine.scenario,
            ),
            const SizedBox(height: 22),
          ],
          LayoutBuilder(
            builder: (context, constraints) {
              final textScale = MediaQuery.textScalerOf(context).scale(16) / 16;
              if (constraints.maxWidth >= 1000 && textScale <= 1.4) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 6, child: dialogue),
                    const SizedBox(width: 24),
                    Expanded(flex: 5, child: decisions),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [dialogue, const SizedBox(height: 28), decisions],
              );
            },
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _action(RunState state, StoryAction action) {
    final actions = widget.engine.scenario
        .scene(state.sceneId)
        .actions
        .where((item) => !item.inquiry)
        .toList();
    return CinematicChoice(
      action: action,
      number: actions.indexOf(action) + 1,
      available: widget.engine.available(state, action),
      used: state.usedActions.contains('${state.sceneId}/${action.id}'),
      busy: controller.busy,
      proposed: proposal == action.id,
      onChoose: () => _act(action),
    );
  }

  Widget _report(RunState state) {
    final ending = widget.engine.scenario.endings.firstWhere(
      (e) => e.id == state.ending,
    );
    final assessment = Assessment.fromRun(state);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ЭПИЗОД ЗАВЕРШЁН',
          style: TextStyle(color: storyCyan, letterSpacing: 3),
        ),
        const SizedBox(height: 20),
        Text(
          ending.title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 34,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          ending.text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            height: 1.7,
          ),
        ),
        const SizedBox(height: 24),
        StoryPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Результат эпизода: ${assessment.total}/100',
                style: const TextStyle(color: storyGold, fontSize: 25),
              ),
              const SizedBox(height: 20),
              for (final entry in assessment.components.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${entry.key} — ${entry.value}',
                        style: const TextStyle(color: Colors.white),
                      ),
                      const SizedBox(height: 7),
                      LinearProgressIndicator(
                        value: entry.value / 100,
                        color: storyCyan,
                        backgroundColor: Colors.white10,
                      ),
                    ],
                  ),
                ),
              for (final finding in assessment.findings)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    finding,
                    style: const TextStyle(color: Colors.white70, height: 1.6),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton.icon(
              key: const Key('decision-tree'),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      DecisionTreeScreen(engine: widget.engine, run: state),
                ),
              ),
              icon: const Icon(Icons.account_tree_outlined),
              label: const Text('Дерево решений'),
            ),
            OutlinedButton.icon(
              onPressed: () => _journal(state),
              icon: const Icon(Icons.receipt_long),
              label: const Text('Причины и последствия'),
            ),
            OutlinedButton.icon(
              onPressed: aiBusy
                  ? null
                  : () => _aiText(
                      () => ai.debrief(state),
                      'Разбор AI-инструктора',
                    ),
              icon: const Icon(Icons.auto_awesome),
              label: Text(
                aiBusy ? 'AI отвечает…' : 'Дополнить разбор через AI',
              ),
            ),
            FilledButton.icon(
              key: const Key('replay-episode'),
              onPressed: () => Navigator.pop(context, true),
              icon: const Icon(Icons.replay),
              label: const Text('Пройти заново'),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const Text(
          'Вопросы для разбора',
          style: TextStyle(color: storyCyan, fontSize: 22),
        ),
        const SizedBox(height: 12),
        const Text(
          'Какими сведениями вы располагали в момент выбора?\n'
          'Какие обязательства появились раньше, чем стали заметны последствия?\n'
          'Какой другой способ действий вы проверите в следующем прохождении?',
          style: TextStyle(color: Colors.white70, height: 1.8, fontSize: 16),
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}
