import 'package:flutter/material.dart';

class TactixResponsive {
  TactixResponsive._();

  static const double mobile = 600;
  static const double tablet = 900;
  static const double wide = 1200;

  static bool isMobile(
    BuildContext context,
  ) =>
      MediaQuery.sizeOf(context).width <
      mobile;

  static bool isTablet(
    BuildContext context,
  ) {
    final width =
        MediaQuery.sizeOf(context).width;

    return width >= mobile &&
        width < wide;
  }

  static bool isWide(
    BuildContext context,
  ) =>
      MediaQuery.sizeOf(context).width >=
      wide;

  static double horizontalPadding(
    BuildContext context,
  ) {
    final width =
        MediaQuery.sizeOf(context).width;

    if (width < mobile) return 14;
    if (width < wide) return 24;
    return 32;
  }
}

