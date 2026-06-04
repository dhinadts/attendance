import 'package:flutter/material.dart';

/// Simple responsive helpers used across the app.
class Responsive {
  // Breakpoints
  static const double mobileMaxWidth = 600;
  static const double tabletMaxWidth = 1200;

  static double width(BuildContext context) => MediaQuery.sizeOf(context).width;
  static double height(BuildContext context) => MediaQuery.sizeOf(context).height;

  static bool isMobile(BuildContext context) => width(context) < mobileMaxWidth;
  static bool isTablet(BuildContext context) => width(context) >= mobileMaxWidth && width(context) < tabletMaxWidth;
  static bool isDesktop(BuildContext context) => width(context) >= tabletMaxWidth;

  /// Variant used by admin shell where a slightly smaller desktop threshold is desired.
  static bool isLargeDesktop(BuildContext context) => width(context) >= 1000;
}
