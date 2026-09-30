import 'package:ai_trainer_mobile/screens/about/system_readiness_screen.dart';
import 'package:ai_trainer_mobile/services/system_readiness_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('readiness response is parsed without exposing implementation details', () {
    final snapshot = SystemReadinessSnapshot.fromJson({
      'status': 'ready',
      'checked_at': '2026-09-30T10:00:00Z',
      'release': 'rc1',
      'environment': 'production',
      'components': {
        'database': 'available',
        'authentication': 'configured',
        'ai': 'configured',
      },
      'capabilities': {
        'digital_thread': true,
        'pulse': true,
      },
    });

    expect(snapshot.ready, isTrue);
    expect(snapshot.release, 'rc1');
    expect(snapshot.components['database'], 'available');
    expect(snapshot.capabilities['pulse'], isTrue);
  });

  testWidgets('system readiness screen explains release state in Russian', (tester) async {
    final snapshot = SystemReadinessSnapshot(
      ready: true,
      checkedAt: DateTime.utc(2026, 9, 30, 10),
      release: 'phase-i-test',
      environment: 'production',
      components: const {
        'database': 'available',
        'authentication': 'configured',
        'ai': 'optional_offline',
      },
      capabilities: const {
        'digital_thread': true,
        'training': true,
        'simulation_lab': true,
        'ask_tactix': true,
        'branches': true,
        'pulse': true,
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: SystemReadinessScreen(loader: () async => snapshot),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ГОТОВНОСТЬ СИСТЕМЫ'), findsOneWidget);
    expect(find.text('Система готова'), findsOneWidget);
    expect(find.text('База данных'), findsOneWidget);
    expect(find.text('Аутентификация'), findsOneWidget);
    expect(find.text('phase-i-test'), findsOneWidget);
  });
}
