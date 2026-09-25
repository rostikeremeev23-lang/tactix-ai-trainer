import '../../../../models/ai_chat_message.dart';
import '../../../../services/ai_service.dart';
import '../domain/engine.dart';

/// Read-only boundary: only verified events and engine-calculated metrics leave.
/// The returned text is never parsed back into simulation state or scores.
class StrategyAIReviewAdapter {
  Map<String, dynamic> payload(ExerciseEngine engine) => {
    'exercise': engine.scenario.name,
    'fictional_training_only': true,
    'score': engine.score,
    'completed': engine.completed,
    'metrics': {
      'resources': engine.current.resources,
      'safety': engine.current.safety,
      'cohesion': engine.current.cohesion,
      'reached': engine.current.reached.length,
    },
    'confirmed_events': engine.current.log.take(100).toList(),
    'score_rule': engine.objectiveRule,
  };
  Future<String> review(ExerciseEngine engine) async {
    if (!engine.completed) throw StateError('Сначала завершите занятие');
    await AIService.loadConfig();
    if (AIService.mode == AIMode.offline || !await AIService.refreshStatus()) {
      return 'AI недоступен. Автономный отчёт движка:\n\n${engine.report}';
    }
    try {
      return await AIService.chat(
        message:
            'Разбери только подтверждённые события учебного сценария из context. '
            'Не добавляй события, не меняй оценку. Объясни причинно-следственные связи '
            'и предложи вопросы для обсуждения инструктором. Не давай советов по реальным операциям. '
            'Если данных недостаточно, укажи это.',
        contextType: AIChatContextType.debrief,
        context: payload(engine),
      );
    } catch (_) {
      return 'AI недоступен. Автономный отчёт движка:\n\n${engine.report}';
    }
  }
}
