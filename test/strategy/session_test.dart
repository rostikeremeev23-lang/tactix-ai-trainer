import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ai_trainer_mobile/features/strategy/domain/strategy_session.dart';
import 'package:ai_trainer_mobile/features/strategy/domain/strategy_report.dart';
import 'package:ai_trainer_mobile/features/strategy/data/strategy_repository.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('editor is locked after start; snapshots remain immutable', () {
    final session = StrategySession();
    session.configure(unitId: 'alpha', sector: 3, strength: 50, resources: 10);
    final initial = session.current;
    session.start();
    expect(() => session.configure(resources: 100), throwsStateError);
    expect(session.move('alpha', 3), isFalse);
    expect(session.move('missing', 0), isFalse);
    expect(session.move('alpha', -1), isFalse);
    expect(session.move('alpha', 4), isTrue);
    expect(initial.resources, 10);
    expect(initial.units.first.sector, 3);
    expect(session.current.resources, 8);
    expect(() => session.history.clear(), throwsUnsupportedError);
    expect(() => session.current.units.clear(), throwsUnsupportedError);
    expect(() => session.current.log.clear(), throwsUnsupportedError);
  });

  test('resource exhaustion prevents moves and all eight turns resolve', () {
    final session = StrategySession()
      ..configure(resources: 2)
      ..start();
    expect(session.move('armor', 0), isFalse);
    expect(session.move('alpha', 3), isTrue);
    expect(session.move('alpha', 0), isFalse);
    for (var i = 0; i < 7; i++) {
      session.nextTurn();
    }
    expect(session.current.turn, 8);
    expect(session.current.completed, isFalse);
    final before = session.current;
    session.nextTurn();
    expect(session.current.completed, isTrue);
    expect(session.current.time, lessThan(before.time));
    final count = session.history.length;
    session.nextTurn();
    expect(session.move('bravo', 3), isFalse);
    expect(session.history.length, count);
    final report = StrategyReport(session.current);
    expect(report.total, inInclusiveRange(0, 100));
    expect(report.held, 3);
    expect(report.text, contains(session.current.log.last));
  });

  test(
    'save restores editor, run and final report without sharing profiles',
    () async {
      final repository = StrategyRepository('one');
      final session = StrategySession()..configure(unitId: 'bravo', sector: 3);
      await repository.save(session);
      expect((await repository.load())!.started, isFalse);
      session.start();
      session.move('alpha', 4);
      session.nextTurn();
      await repository.save(session);
      final restored = (await repository.load())!;
      expect(restored.toJson(), session.toJson());
      expect(await StrategyRepository('two').load(), isNull);
      for (var i = 0; i < 7; i++) {
        restored.nextTurn();
      }
      await repository.save(restored);
      final completed = (await repository.load())!;
      expect(completed.current.completed, isTrue);
      expect(
        StrategyReport(completed.current).text,
        StrategyReport(restored.current).text,
      );
    },
  );

  test('corrupt latest copy falls back, then a new save repairs it', () async {
    final repository = StrategyRepository('recovery');
    final session = StrategySession()..start();
    await repository.save(session);
    session.nextTurn();
    await repository.save(session);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('${repository.key}.0', '{bad json');
    expect((await repository.load())!.current.turn, 1);
    expect(repository.recoveryMessage, isNotNull);
    await repository.save(session);
    expect((await repository.load())!.current.turn, 2);
    await prefs.setString('${repository.key}.0', '{}');
    await prefs.setString('${repository.key}.1', '{}');
    await expectLater(repository.load(), throwsFormatException);
  });

  test('unknown versions and invalid states cannot be restored', () {
    final data = jsonDecode(
      jsonEncode(StrategySession().toJson()),
    ) as Map<String, dynamic>;
    data['version'] = 2;
    expect(() => StrategySession.fromJson(data), throwsFormatException);
    data['version'] = 1;
    data['history'][0]['units'][0]['sector'] = 99;
    expect(() => StrategySession.fromJson(data), throwsFormatException);
  });
}
