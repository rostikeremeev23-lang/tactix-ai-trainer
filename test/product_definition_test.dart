import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_trainer_mobile/app/theme.dart';
import 'package:ai_trainer_mobile/screens/about/product_definition_screen.dart';

void main() {
  testWidgets('Russian product definition explains TACTIX and training simulator', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: TactixTheme.dark,
        home: const ProductDefinitionScreen(),
      ),
    );

    expect(find.text('О СИСТЕМЕ TACTIX'), findsOneWidget);
    expect(find.text('Что мы создаём'), findsOneWidget);
    expect(find.textContaining('военным учебным тренажёром'), findsWidgets);
    expect(find.textContaining('ИИ-сценариями'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Основные модули'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Основные модули'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
