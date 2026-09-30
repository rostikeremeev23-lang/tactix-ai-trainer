import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_trainer_mobile/widgets/strategy_spotlight.dart';

void main() {
  testWidgets('Strategy spotlight shows real counts and opens its destination',
      (tester) async {
    var opened = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: StrategySpotlight(
        sessionCount: 3,
        activeAssignments: 2,
        onLaunch: () => opened = true,
      )),
    ));
    expect(find.text('Сессий: 3'), findsOneWidget);
    expect(find.text('Заданий: 2'), findsOneWidget);
    await tester.tap(find.text('Открыть симулятор'));
    expect(opened, isTrue);
  });
}
