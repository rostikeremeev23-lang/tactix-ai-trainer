import 'package:flutter/material.dart';

import '../screens/auth/auth_screen.dart';
import '../services/ai_service.dart';
import 'theme.dart';
import 'user_session_scope.dart';

class SessionGate extends StatelessWidget {
  final Widget authenticatedChild;

  const SessionGate({super.key, required this.authenticatedChild});

  @override
  Widget build(BuildContext context) {
    final session = UserSessionScope.of(context);
    AIService.setAccessToken(session.accessToken);

    if (session.loading) return const _SessionLoadingScreen();
    if (!session.isAuthenticated) return const AuthScreen();

    return Stack(
      children: [
        Positioned.fill(child: authenticatedChild),
        if (session.isOffline)
          Positioned(
            left: 12,
            right: 12,
            top: 8,
            child: SafeArea(
              bottom: false,
              child: Align(
                alignment: Alignment.topCenter,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: TactixTheme.panel2,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: TactixTheme.line),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    child: Text(
                      'OFFLINE MODE - Cached server profile',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: TactixTheme.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _SessionLoadingScreen extends StatelessWidget {
  const _SessionLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: TactixTheme.bg,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.shield_outlined, color: TactixTheme.gold, size: 44),
            SizedBox(height: 18),
            CircularProgressIndicator(color: TactixTheme.gold),
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
              'RESTORING SESSION',
              style: TextStyle(
                color: TactixTheme.textMuted,
                fontSize: 11,
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
