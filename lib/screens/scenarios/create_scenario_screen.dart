import 'package:flutter/material.dart';

import '../../app/responsive.dart';
import '../../models/scenario.dart';
import '../../services/storage_service.dart';
import '../../widgets/common_widgets.dart';

class CreateScenarioScreen
    extends StatefulWidget {
  const CreateScenarioScreen({
    super.key,
  });

  @override
  State<CreateScenarioScreen> createState() =>
      _CreateScenarioScreenState();
}

class _CreateScenarioScreenState
    extends State<CreateScenarioScreen> {
  final titleController =
      TextEditingController();

  final descriptionController =
      TextEditingController();

  final timeController =
      TextEditingController();

  final resourcesController =
      TextEditingController();

  final conditionsController =
      TextEditingController();

  final optionAController =
      TextEditingController();

  final optionBController =
      TextEditingController();

  final optionCController =
      TextEditingController();

  bool saving = false;

  Future<void> saveScenario() async {
    final scenario =
        TrainingScenario(
      title:
          titleController.text.trim(),
      description:
          descriptionController.text
              .trim(),
      time:
          timeController.text.trim(),
      resources:
          resourcesController.text
              .trim(),
      conditions:
          conditionsController.text
              .trim(),
      optionA:
          optionAController.text.trim(),
      optionB:
          optionBController.text.trim(),
      optionC:
          optionCController.text.trim(),
    );

    if (scenario.title.isEmpty ||
        scenario.description.isEmpty ||
        scenario.optionA.isEmpty ||
        scenario.optionB.isEmpty ||
        scenario.optionC.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Заполните основные поля.',
          ),
        ),
      );
      return;
    }

    setState(() {
      saving = true;
    });

    try {
      await ScenarioStorage.save(
        scenario,
      );

      if (!mounted) return;

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        saving = false;
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content:
              Text('Ошибка: $e'),
        ),
      );
    }
  }

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    timeController.dispose();
    resourcesController.dispose();
    conditionsController.dispose();
    optionAController.dispose();
    optionBController.dispose();
    optionCController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            const Text('Создать сценарий'),
      ),
      body: SafeArea(
        child:
            SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            TactixResponsive.horizontalPadding(context),
            18,
            TactixResponsive.horizontalPadding(context),
            28,
          ),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.stretch,
            children: [
              const SectionTitle(
                text:
                    'ОСНОВНЫЕ ДАННЫЕ',
              ),
              const SizedBox(height: 15),
              AppTextField(
                controller:
                    titleController,
                label:
                    'Название',
              ),
              AppTextField(
                controller:
                    descriptionController,
                label:
                    'Описание',
                maxLines: 6,
              ),
              Row(
                children: [
                  Expanded(
                    child:
                        AppTextField(
                      controller:
                          timeController,
                      label:
                          'Время',
                      hint:
                          '45',
                    ),
                  ),
                  const SizedBox(
                    width: 10,
                  ),
                  Expanded(
                    child:
                        AppTextField(
                      controller:
                          resourcesController,
                      label:
                          'Ресурсы',
                      hint:
                          '80',
                    ),
                  ),
                ],
              ),
              AppTextField(
                controller:
                    conditionsController,
                label:
                    'Условия',
                maxLines: 3,
              ),
              const SizedBox(height: 10),
              const SectionTitle(
                text:
                    'ВАРИАНТЫ',
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller:
                    optionAController,
                label:
                    'Вариант A',
                maxLines: 4,
              ),
              AppTextField(
                controller:
                    optionBController,
                label:
                    'Вариант B',
                maxLines: 4,
              ),
              AppTextField(
                controller:
                    optionCController,
                label:
                    'Вариант C',
                maxLines: 4,
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed:
                    saving
                        ? null
                        : saveScenario,
                icon: saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child:
                            CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(
                        Icons.save,
                      ),
                label:
                    const Padding(
                  padding:
                      EdgeInsets.symmetric(
                    vertical: 15,
                  ),
                  child:
                      Text('СОХРАНИТЬ'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

