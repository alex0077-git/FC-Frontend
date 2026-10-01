import 'package:flutter/material.dart';

class Responsive {
  const Responsive._();

  static const mobileMaxWidth = 600.0;
  static const desktopMinWidth = 1024.0;

  static double widthOf(BuildContext context) {
    return MediaQuery.sizeOf(context).width;
  }

  static bool isMobile(BuildContext context) {
    return widthOf(context) < mobileMaxWidth;
  }

  static bool isTablet(BuildContext context) {
    final width = widthOf(context);
    return width >= mobileMaxWidth && width < desktopMinWidth;
  }

  static bool isDesktop(BuildContext context) {
    return widthOf(context) >= desktopMinWidth;
  }

  /// A phone in landscape is wider than 600, but the short side is still small.
  static bool isPhone(BuildContext context) {
    return MediaQuery.sizeOf(context).shortestSide < mobileMaxWidth;
  }

  /// Map screens drop the desktop side column on a phone.
  static bool useCompactMapLayout(BuildContext context) {
    return isMobile(context) || isPhone(context);
  }

  static double sidePanelWidth(
    BuildContext context, {
    required double desktopWidth,
  }) {
    if (isDesktop(context)) {
      return desktopWidth;
    }
    return (widthOf(context) * 0.36).clamp(260.0, desktopWidth);
  }

  static double dialogWidth(BuildContext context, double preferred) {
    final inner = widthOf(context) - 128;
    if (inner <= 0 || inner >= preferred) {
      return preferred;
    }
    return inner;
  }
}
