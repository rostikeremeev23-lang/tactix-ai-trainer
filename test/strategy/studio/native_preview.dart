// Native rendering harness only. Production entry remains lib/main.dart and
// continues to enforce its existing authentication/session gate.
import 'package:flutter/material.dart';
import 'package:ai_trainer_mobile/app/theme.dart';
import 'package:ai_trainer_mobile/screens/strategy/strategy_screen.dart';

void main() => runApp(
  MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: TactixTheme.dark,
    home: const TactixStrategyScreen(userId: 'strategy-native-visual-check'),
  ),
);
