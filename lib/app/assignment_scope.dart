import 'package:flutter/widgets.dart';

import '../services/assignment_controller.dart';

class AssignmentScope
    extends InheritedNotifier<
        AssignmentController> {
  const AssignmentScope({
    super.key,
    required AssignmentController controller,
    required super.child,
  }) : super(
          notifier: controller,
        );

  static AssignmentController of(
    BuildContext context,
  ) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<
            AssignmentScope>();

    assert(
      scope != null,
      'AssignmentScope was not found in the widget tree.',
    );

    return scope!.notifier!;
  }

  static AssignmentController read(
    BuildContext context,
  ) {
    final element = context
        .getElementForInheritedWidgetOfExactType<
            AssignmentScope>();

    final scope =
        element?.widget as AssignmentScope?;

    assert(
      scope != null,
      'AssignmentScope was not found in the widget tree.',
    );

    return scope!.notifier!;
  }
}

