import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ai_trainer_mobile/app/theme.dart';
import 'package:ai_trainer_mobile/features/thread/thread_store.dart';
import 'package:ai_trainer_mobile/features/thread/thread_screen.dart';

void main() {
  for (final size in [
    const Size(390, 844),
    const Size(1024, 768),
    const Size(1440, 900),
  ]) {
    testWidgets('Thread Case creation and evidence at $size', (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = ThreadStore('demo');
      await store.restore(autoSync: false);
      addTearDown(store.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: TactixTheme.dark,
          home: ThreadScreen(store: store),
        ),
      );
      expect(find.text('ЦИФРОВОЙ КОНТУР'), findsOneWidget);
      await tester.tap(find.text('Создать дело'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), 'Fictional gap');
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'Observed during exercise',
      );
      await tester.tap(find.text('Сохранить'));
      await tester.pumpAndSettle();
      expect(store.cases, hasLength(1));
      expect(find.text('Добавить подтверждение'), findsOneWidget);
      // On compact phones the Case detail is scrollable and the action can be
      // below the initial viewport. Scroll it into view before tapping.
      await tester.ensureVisible(find.text('Добавить подтверждение'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Добавить подтверждение'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), 'Result note');
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'Completed practice',
      );
      await tester.tap(find.text('Сохранить'));
      await tester.pumpAndSettle();
      expect(store.cases.single['evidence'], hasLength(1));
      expect(store.cases.single['verification_state'], 'UNVERIFIED');
      expect(find.text('Проверить и закрыть'), findsNothing);
      expect(store.pending, hasLength(2));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('Digital Thread graph renders linked cached Cases', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1024, 768);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = ThreadStore('demo');
    await store.restore(autoSync: false);
    addTearDown(store.dispose);
    final a = await store.create('Origin Case', 'First');
    final b = await store.create('Related Case', 'Second');
    await store.createRelation(
      a,
      fromType: 'CASE',
      fromId: a,
      toType: 'CASE',
      toId: b,
      relationshipType: 'RELATED_TO',
    );
    await tester.pumpWidget(
      MaterialApp(theme: TactixTheme.dark, home: ThreadScreen(store: store)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Связи'));
    await tester.pumpAndSettle();
    expect(find.text('ЦИФРОВОЙ КОНТУР'), findsWidgets);
    expect(find.text('Origin Case'), findsOneWidget);
    expect(find.text('Related Case'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

}

