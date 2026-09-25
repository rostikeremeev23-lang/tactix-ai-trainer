import 'dart:convert';

import '../../../models/ai_chat_message.dart';
import '../../../services/ai_service.dart';
import '../domain/assessment.dart';
import '../domain/decision_engine.dart';
import '../domain/models.dart';

/// AI never receives a mutable state or a reference to the controller.
class SimulationAiAdapter {
  final DecisionEngine engine;
  const SimulationAiAdapter(this.engine);
  Map<String, dynamic> context(RunState state) => {
    'scenario': engine.scenario.title,
    'scene': engine.scenario.scene(state.sceneId).title,
    'facts': engine.scenario.scene(state.sceneId).text,
    'recent_events': state.events
        .where((e) => e.kind != 'cost')
        .toList()
        .reversed
        .take(5)
        .map((e) => e.text)
        .toList()
        .reversed
        .toList(),
    'rule':
        'Только вымышленное упражнение. Не придумывай новые факты, '
        'события, доступность ресурсов и баллы. При отсутствии данных скажи об этом.',
  };
  Future<String> discuss(RunState state, String question) => AIService.chat(
    message: question,
    contextType: AIChatContextType.coach,
    context: context(state),
  );

  Future<String> debrief(RunState state) => AIService.chat(
    message:
        'Объясни компромиссы и предложи два вопроса для самостоятельного '
        'разбора по переданным фактам. Не вычисляй баллы и не добавляй события.',
    contextType: AIChatContextType.debrief,
    context: {
      ...context(state),
      'score': Assessment.fromRun(state).total,
      'components': Assessment.fromRun(state).components,
      'ending': state.ending,
      'decisions': state.commands
          .where((c) => c.action != 'ask')
          .map((c) => '${c.scene}/${c.action}')
          .toList(),
    },
  );

  static String? validateProposal(String raw, Set<String> allowed) {
    try {
      final clean = raw
          .trim()
          .replaceFirst(RegExp(r'^\x60\x60\x60(?:json)?\s*'), '')
          .replaceFirst(RegExp(r'\s*\x60\x60\x60$'), '');
      final decoded = jsonDecode(clean);
      if (decoded is! Map || decoded['actionId'] is! String) return null;
      return allowed.contains(decoded['actionId'])
          ? decoded['actionId'] as String
          : null;
    } catch (_) {
      return null;
    }
  }

  Future<String?> interpret(RunState state, String text) async {
    final actions = engine.scenario
        .scene(state.sceneId)
        .actions
        .where((a) => !a.inquiry && engine.available(state, a))
        .toList();
    final answer = await AIService.chat(
      message:
          'Сопоставь замысел с одним разрешённым действием. '
          'Верни JSON {"actionId":"идентификатор"}; при неоднозначности {"actionId":null}. '
          'Это только предложение, не исполнение. Замысел: $text',
      contextType: AIChatContextType.coach,
      context: {
        ...context(state),
        'allowed_actions': actions
            .map((a) => {'id': a.id, 'title': a.title})
            .toList(),
      },
    );
    return validateProposal(answer, actions.map((a) => a.id).toSet());
  }
}
