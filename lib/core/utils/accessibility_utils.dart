import 'package:flutter/material.dart';

/// Accessibility helpers for production-grade a11y compliance.
class AccessibilityUtils {
  AccessibilityUtils._();

  /// Minimum touch target per Material / WCAG (48 logical pixels).
  static const double minTouchTarget = 48;

  /// Clamps text scaling to avoid layout breakage while supporting large text.
  static MediaQueryData clampTextScale(
    BuildContext context, {
    double min = 0.85,
    double max = 1.4,
  }) {
    final mq = MediaQuery.of(context);
    final clamped = mq.textScaler.clamp(
      minScaleFactor: min,
      maxScaleFactor: max,
    );
    return mq.copyWith(textScaler: clamped);
  }

  static Widget wrapMinTouchTarget({required Widget child}) {
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minWidth: minTouchTarget,
        minHeight: minTouchTarget,
      ),
      child: Center(child: child),
    );
  }
}
