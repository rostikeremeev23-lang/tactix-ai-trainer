import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ai_trainer_mobile/app/app.dart';

void main() {
  testWidgets(
    'TACTIX app starts',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        const TactixApp(
          home: SizedBox.shrink(),
        ),
      );

      expect(
        find.byType(MaterialApp),
        findsOneWidget,
      );
    },
  );
}
