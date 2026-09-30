import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_trainer_mobile/features/strategy/studio/data/pdf_report_service.dart';
import 'package:ai_trainer_mobile/features/strategy/studio/domain/engine.dart';
import 'package:ai_trainer_mobile/features/strategy/studio/domain/scenario.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('generates a Cyrillic PDF offline from scenario data', () async {
    final engine = ExerciseEngine(StudioScenario.demo());
    engine.advance();

    final bytes = await PdfReportService().createExerciseReport(engine);

    expect(utf8.decode(bytes.take(4).toList()), '%PDF');
    expect(bytes.length, greaterThan(10000));
    expect(await rootBundle.load('assets/fonts/NotoSans-Variable.ttf'), isNotNull);
  });
}
