import 'package:flutter/material.dart';

import '../screens/auth/user_setup_screen.dart';
import 'theme.dart';
import 'user_session_scope.dart';

class SessionGate extends StatelessWidget {
  final Widget authenticatedChild;

  const SessionGate({
    super.key,
    required this.authenticatedChild,
  });

  @override
  Widget build(BuildContext context) {
    final session =
        UserSessionScope.of(context);

    if (session.loading) {
      return const _SessionLoadingScreen();
    }

    if (!session.isAuthenticated) {
      return const UserSetupScreen();
    }

    return authenticatedChild;
  }
}

class _SessionLoadingScreen
    extends StatelessWidget {
  const _SessionLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: TactixTheme.bg,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.shield_outlined,
              color: TactixTheme.gold,
              size: 44,
            ),
            SizedBox(height: 18),
            CircularProgressIndicator(
              color: TactixTheme.gold,
            ),
            SizedBox(height: 14),
            Text(
              'TACTIX',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
            SizedBox(height: 5),
            Text(
              'ЗАГРУЗКА ПРОФИЛЯ',
              style: TextStyle(
                color: TactixTheme.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

