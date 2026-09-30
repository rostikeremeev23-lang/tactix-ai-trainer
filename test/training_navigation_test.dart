import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ai_trainer_mobile/app/theme.dart';
import 'package:ai_trainer_mobile/app/user_session_scope.dart';
import 'package:ai_trainer_mobile/models/app_user.dart';
import 'package:ai_trainer_mobile/services/user_session_controller.dart';
import 'package:ai_trainer_mobile/screens/training/training_hub_screen.dart';
import 'package:ai_trainer_mobile/screens/strategy/strategy_screen.dart';
import 'package:ai_trainer_mobile/features/strategy/studio/presentation/city_library.dart';

class LocalSession extends UserSessionController {
  @override
  AppUser get currentUser => AppUser(
    id: 'training-nav',
    callsign: 'TEST',
    fullName: 'Test',
    role: UserRole.trainee,
    createdAt: DateTime(2026),
  );
}

void main() {
  for (final size in [
    const Size(390, 844),
    const Size(1024, 768),
    const Size(1440, 900),
  ]) {
    testWidgets('Training opens existing Simulation Lab and returns at $size', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final session = LocalSession();
      addTearDown(session.dispose);
      await tester.pumpWidget(
        UserSessionScope(
          controller: session,
          child: MaterialApp(
            theme: TactixTheme.dark,
            home: const TrainingHubScreen(),
          ),
        ),
      );
      expect(find.text('ЦЕНТР МОДЕЛИРОВАНИЯ'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('ЦЕНТР МОДЕЛИРОВАНИЯ'));
      await tester.pumpAndSettle();
      expect(find.byType(SimulationLabScreen), findsOneWidget);
      expect(find.byType(CityLibrary), findsOneWidget);
      expect(tester.takeException(), isNull);
      Navigator.of(tester.element(find.byType(CityLibrary))).pop();
      await tester.pumpAndSettle();
      expect(find.byType(TrainingHubScreen), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  }
  test('Legacy Strategy entry preserves user and launch options', () {
    const old = TactixStrategyScreen(
      userId: 'existing',
      startInLibrary: false,
      startInPlatform: true,
    );
    expect(old, isA<SimulationLabScreen>());
    expect(old.userId, 'existing');
    expect(old.startInLibrary, isFalse);
    expect(old.startInPlatform, isTrue);
  });
}
