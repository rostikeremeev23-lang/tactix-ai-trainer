import 'package:flutter/widgets.dart';

import '../services/user_session_controller.dart';

class UserSessionScope
    extends InheritedNotifier<
        UserSessionController> {
  const UserSessionScope({
    super.key,
    required UserSessionController controller,
    required super.child,
  }) : super(
          notifier: controller,
        );

  static UserSessionController of(
    BuildContext context,
  ) {
    final scope = context.dependOnInheritedWidgetOfExactType<
        UserSessionScope>();

    assert(
      scope != null,
      'UserSessionScope was not found in the widget tree.',
    );

    return scope!.notifier!;
  }

  static UserSessionController read(
    BuildContext context,
  ) {
    final element =
        context.getElementForInheritedWidgetOfExactType<
            UserSessionScope>();

    final scope =
        element?.widget as UserSessionScope?;

    assert(
      scope != null,
      'UserSessionScope was not found in the widget tree.',
    );

    return scope!.notifier!;
  }
}

