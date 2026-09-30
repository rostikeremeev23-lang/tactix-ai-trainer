import 'package:flutter/material.dart';

import '../../app/theme.dart';

class ProductDefinitionScreen extends StatelessWidget {
  const ProductDefinitionScreen({super.key});

  static const definition =
      'TACTIX — единая цифровая платформа управления задачами, подготовкой и результатами подразделения со встроенным военным учебным тренажёром, ИИ-сценариями и инструментами анализа результатов.';

  @override
  Widget build(BuildContext context) {
    const modules = <({IconData icon, String title, String detail})>[
      (
        icon: Icons.account_tree_outlined,
        title: 'Цифровой контур',
        detail: 'Связывает задачу, решения, действия, подтверждения, подготовку и итоговый результат.',
      ),
      (
        icon: Icons.fact_check_outlined,
        title: 'Подтверждения',
        detail: 'Разделяет «выполнено» и «проверено» и сохраняет основание для закрытия дела.',
      ),
      (
        icon: Icons.auto_awesome_outlined,
        title: 'Анализ TACTIX',
        detail: 'ИИ анализирует только доступные материалы дела и показывает источники, пробелы и уровень уверенности.',
      ),
      (
        icon: Icons.school_outlined,
        title: 'Подготовка и моделирование',
        detail: 'Военный учебный тренажёр для моделирования вымышленных учебных ситуаций, создания ИИ-сценариев, проведения сессий и разбора результатов.',
      ),
      (
        icon: Icons.fork_right_outlined,
        title: 'Варианты плана',
        detail: 'Позволяет сравнивать альтернативные планы и выявлять конфликты до применения изменений.',
      ),
      (
        icon: Icons.monitor_heart_outlined,
        title: 'Контроль процессов',
        detail: 'Показывает просрочки, ожидание проверки, узкие места и ленту событий без автоматического принятия решений.',
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('О СИСТЕМЕ TACTIX')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const Icon(
                  Icons.hub_outlined,
                  size: 54,
                  color: TactixTheme.cyan,
                ),
                const SizedBox(height: 18),
                Text(
                  'Что мы создаём',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                const Text(
                  definition,
                  textAlign: TextAlign.center,
                  style: TextStyle(height: 1.6, fontSize: 16),
                ),
                const SizedBox(height: 28),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Главная логика',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Источник → задача → решение → исполнение → подтверждение → подготовка / проверка → результат → закрытие',
                          style: TextStyle(
                            color: TactixTheme.gold,
                            fontWeight: FontWeight.w700,
                            height: 1.6,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'TACTIX не принимает решение вместо пользователя. Система собирает контекст, показывает связи, фиксирует ход работы и помогает подтвердить результат.',
                          style: TextStyle(
                            color: TactixTheme.textMuted,
                            height: 1.55,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Основные модули',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 10),
                for (final module in modules)
                  Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 8,
                      ),
                      leading: Icon(module.icon, color: TactixTheme.cyan),
                      title: Text(module.title),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Text(
                          module.detail,
                          style: const TextStyle(height: 1.45),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 18),
                const Text(
                  'Короткое определение для доклада: «TACTIX — цифровая платформа управления подготовкой и задачами подразделения со встроенным военным тренажёром, ИИ-сценариями и контролем подтверждённых результатов».',
                  style: TextStyle(
                    color: TactixTheme.textMuted,
                    height: 1.55,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
