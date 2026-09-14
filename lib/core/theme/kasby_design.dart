import 'package:flutter/material.dart';

/// Kasby Design Language — unified design tokens.
///
/// Centralizes the spacing (8pt grid), radius, and motion scales referenced in
/// the product audit so screens stop using interchangeable magic numbers
/// (16/20/24) and bespoke radii (20/24/28).
class KasbySpacing {
  KasbySpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  static const double huge = 40;
  static const double giant = 48;
}

/// Radius scale: 8 (chips) · 12 (inputs) · 16 (cards) · 24 (hero) · 28 (sheets).
class KasbyRadius {
  KasbyRadius._();

  static const double chip = 8;
  static const double input = 12;
  static const double card = 16;
  static const double hero = 24;
  static const double sheet = 28;

  static BorderRadius get chipR => BorderRadius.circular(chip);
  static BorderRadius get inputR => BorderRadius.circular(input);
  static BorderRadius get cardR => BorderRadius.circular(card);
  static BorderRadius get heroR => BorderRadius.circular(hero);
  static BorderRadius get sheetR =>
      const BorderRadius.vertical(top: Radius.circular(sheet));
}

/// Motion helpers that respect the OS "reduce motion" accessibility setting.
///
/// Usage: wrap animation durations with [KasbyMotion.duration] and gate optional
/// decorative animations with [KasbyMotion.enabled].
class KasbyMotion {
  KasbyMotion._();

  /// Returns true when the user has NOT requested reduced motion at the OS level.
  static bool enabled(BuildContext context) {
    final mq = MediaQuery.maybeOf(context);
    return !(mq?.disableAnimations ?? false);
  }

  /// Returns [base] when animations are enabled, otherwise [Duration.zero].
  static Duration duration(BuildContext context, Duration base) =>
      enabled(context) ? base : Duration.zero;

  static const Duration fast = Duration(milliseconds: 200);
  static const Duration normal = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 600);
}

/// Screen-level layout tokens — Material 3 spacing on an 8pt grid.
class KasbyLayout {
  KasbyLayout._();

  /// Standard horizontal screen padding (phones).
  static const double screenPaddingH = KasbySpacing.lg;

  /// Compact vertical gap between list items.
  static const double listItemGap = KasbySpacing.sm;

  /// Standard list outer padding.
  static EdgeInsets listPadding(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final hPad = w >= 600 ? KasbySpacing.xxl : KasbySpacing.lg;
    return EdgeInsets.fromLTRB(hPad, KasbySpacing.md, hPad, KasbySpacing.lg);
  }

  /// Responsive grid column count (2 on phone, 3 on tablet).
  static int gridColumns(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= 900 ? 3 : 2;

  /// Responsive stats grid aspect ratio.
  static double statsAspectRatio(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    if (w >= 900) return 1.9;
    if (w >= 600) return 1.75;
    return 1.55;
  }
}

/// Standardized fintech shadows that avoid harsh or muddy black blurs on light surfaces.
class KasbyShadow {
  KasbyShadow._();

  /// Very subtle ambient elevation for cards and lists.
  static List<BoxShadow> subtle(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return [
      BoxShadow(
        color: isDark
            ? Colors.black.withValues(alpha: 0.25)
            : const Color(0x0A0F172A),
        blurRadius: 10,
        offset: const Offset(0, 2),
      ),
    ];
  }

  /// Standard card elevation with soft ambient depth.
  static List<BoxShadow> card(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return [
      BoxShadow(
        color: isDark
            ? Colors.black.withValues(alpha: 0.35)
            : const Color(0x0C0F172A),
        blurRadius: 16,
        offset: const Offset(0, 4),
      ),
    ];
  }

  /// Prominent elevation for floating sheets, bottom bars, and dialogs.
  static List<BoxShadow> elevated(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return [
      BoxShadow(
        color: isDark
            ? Colors.black.withValues(alpha: 0.5)
            : const Color(0x120F172A),
        blurRadius: 24,
        offset: const Offset(0, 6),
      ),
    ];
  }
}
