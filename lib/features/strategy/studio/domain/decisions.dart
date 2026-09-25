import 'scenario.dart';

class ExerciseChoice {
  final String title, consequence;
  final int cost, safety, cohesion, delay, laterSafety, laterCohesion;
  const ExerciseChoice(
    this.title,
    this.consequence, {
    this.cost = 0,
    this.safety = 0,
    this.cohesion = 0,
    this.delay = 0,
    this.laterSafety = 0,
    this.laterCohesion = 0,
  });
}

List<ExerciseChoice> choicesFor(InjectKind kind) => switch (kind) {
  InjectKind.road => const [
    ExerciseChoice(
      'Организовать учебный обход',
      'Ресурсы −12; движение ×0,45 на 6 тактов. Через 3 такта согласованность +5.',
      cost: 12,
      delay: 6,
      laterCohesion: 5,
    ),
    ExerciseChoice(
      'Продолжить по условному маршруту',
      'Без расхода ресурсов и задержки. Через 3 такта безопасность −20.',
      laterSafety: -20,
    ),
  ],
  InjectKind.communications => const [
    ExerciseChoice(
      'Включить резервный канал',
      'Ресурсы −10; согласованность +5. Движение без задержки.',
      cost: 10,
      cohesion: 5,
    ),
    ExerciseChoice(
      'Действовать автономно',
      'Согласованность −10 сейчас и ещё −10 через 3 такта.',
      cohesion: -10,
      laterCohesion: -10,
    ),
  ],
  InjectKind.weather => const [
    ExerciseChoice(
      'Снизить темп',
      'Движение ×0,45 на 8 тактов. Безопасность +5. Ресурсы сохраняются.',
      delay: 8,
      safety: 5,
    ),
    ExerciseChoice(
      'Сохранить темп',
      'Ресурсы −5. Через 3 такта безопасность −15.',
      cost: 5,
      laterSafety: -15,
    ),
  ],
};

String injectBrief(InjectKind kind) => switch (kind) {
  InjectKind.road => 'Учебный диспетчер сообщил о перекрытии дороги у моста. Выберите способ продолжения занятия.',
  InjectKind.communications => 'Основной игровой канал связи недоступен. Решите, как сохранить согласованность групп.',
  InjectKind.weather => 'В долине ухудшилась видимость. Балансируйте темп и условный показатель безопасности.',
};
