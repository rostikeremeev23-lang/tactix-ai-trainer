import 'package:flutter/material.dart';

import '../services/assignment_controller.dart';
import '../services/user_session_controller.dart';
import 'assignment_scope.dart';
import 'session_gate.dart';
import 'theme.dart';
import 'user_session_scope.dart';

class TactixApp extends StatefulWidget {
  final Widget home;

  const TactixApp({
    super.key,
    required this.home,
  });

  @override
  State<TactixApp> createState() =>
      _TactixAppState();
}

class _TactixAppState
    extends State<TactixApp> {
  late final UserSessionController
      _sessionController;

  late final AssignmentController
      _assignmentController;

  String? _loadedAssignmentUserId;

  @override
  void initState() {
    super.initState();

    _sessionController =
        UserSessionController();

    _assignmentController =
        AssignmentController();

    _sessionController.addListener(
      _handleSessionChanged,
    );

    _sessionController.load();
  }

  Future<void> _handleSessionChanged() async {
    final user =
        _sessionController.currentUser;

    if (user == null) {
      _loadedAssignmentUserId = null;
      return;
    }

    if (_loadedAssignmentUserId ==
        user.id) {
      return;
    }

    _loadedAssignmentUserId = user.id;

    await _assignmentController
        .loadForAssignee(
      user.id,
    );
  }

  @override
  void dispose() {
    _sessionController.removeListener(
      _handleSessionChanged,
    );

    _assignmentController.dispose();
    _sessionController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return UserSessionScope(
      controller: _sessionController,
      child: AssignmentScope(
        controller: _assignmentController,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'TACTIX',
          theme: TactixTheme.dark,
          home: SessionGate(
            authenticatedChild: widget.home,
          ),
        ),
      ),
    );
  }
}

