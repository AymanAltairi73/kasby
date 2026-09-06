import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Centralized typography token system that scales font sizes proportionally
/// between Arabic and English without breaking the visual hierarchy.
///
/// Arabic text requires slightly larger point sizes for its intricate ligatures,
/// whereas English glyphs in `IBMPlexSansArabic` have wider side bearings and
/// longer word lengths, requiring slightly more compact sizes to prevent crowding.
class KasbyTypography {
  KasbyTypography._();

  static const String fontFamily = 'IBMPlexSansArabic';

  /// Whether the active application locale is English.
  static bool isEnglish([BuildContext? context]) {
    if (context != null) {
      final loc = Localizations.maybeLocaleOf(context);
      if (loc != null) return loc.languageCode == 'en';
    }
    return Get.locale?.languageCode == 'en';
  }

  /// Whether the active application locale is Arabic.
  static bool isArabic([BuildContext? context]) => !isEnglish(context);

  /// Returns [en] if current locale is English, otherwise [ar].
  static double sp({required double ar, required double en, BuildContext? context}) {
    return isEnglish(context) ? en : ar;
  }

  /// Returns [en] if English, otherwise [ar] for LetterSpacing.
  static double letterSpacing({required double ar, required double en, BuildContext? context}) {
    return isEnglish(context) ? en : ar;
  }

  // ─── STANDARD COMPONENT SIZES ─────────────────────────────

  /// Button label size: 16 (ar) / 14.5 (en)
  static double button(BuildContext context) => sp(ar: 16.0, en: 14.5, context: context);

  /// Hero / Plan card title: 22 (ar) / 19.0 (en)
  static double cardTitle(BuildContext context) => sp(ar: 22.0, en: 19.0, context: context);

  /// Section header: 18 (ar) / 16.5 (en)
  static double sectionHeader(BuildContext context) => sp(ar: 18.0, en: 16.5, context: context);

  /// Standard body text: 14 (ar) / 13.0 (en)
  static double body(BuildContext context) => sp(ar: 14.0, en: 13.0, context: context);

  /// Secondary body / Subtitle: 13 (ar) / 12.0 (en)
  static double bodySecondary(BuildContext context) => sp(ar: 13.0, en: 12.0, context: context);

  /// Caption / Timestamp: 12 (ar) / 11.0 (en)
  static double caption(BuildContext context) => sp(ar: 12.0, en: 11.0, context: context);

  /// Small badge / Tag: 10 (ar) / 9.5 (en)
  static double badge(BuildContext context) => sp(ar: 10.0, en: 9.5, context: context);
}
