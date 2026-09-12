import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:kasby/core/controllers/theme_controller.dart';

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
    final code = Get.locale?.languageCode;
    if (code != null) return code == 'en';
    if (Get.isRegistered<ThemeController>()) {
      return ThemeController.to.isEnglish;
    }
    return false;
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

  /// Large hero / Display title: 28 (ar) / 24.0 (en)
  static double displayTitle([BuildContext? context]) => sp(ar: 28.0, en: 24.0, context: context);

  /// Button label size: 16 (ar) / 13.5 (en)
  static double button([BuildContext? context]) => sp(ar: 16.0, en: 13.5, context: context);

  /// Hero / Plan card title: 20 (ar) / 17.5 (en)
  static double cardTitle([BuildContext? context]) => sp(ar: 20.0, en: 17.5, context: context);

  /// Section header: 18 (ar) / 15.5 (en)
  static double sectionHeader([BuildContext? context]) => sp(ar: 18.0, en: 15.5, context: context);

  /// Standard card item title / ListTile title: 15 (ar) / 13.5 (en)
  static double itemTitle([BuildContext? context]) => sp(ar: 15.0, en: 13.5, context: context);

  /// Standard body text / Form input: 14 (ar) / 12.5 (en)
  static double body([BuildContext? context]) => sp(ar: 14.0, en: 12.5, context: context);

  /// Secondary body / Subtitle: 13 (ar) / 11.5 (en)
  static double bodySecondary([BuildContext? context]) => sp(ar: 13.0, en: 11.5, context: context);

  /// Caption / Timestamp: 12 (ar) / 10.5 (en)
  static double caption([BuildContext? context]) => sp(ar: 12.0, en: 10.5, context: context);

  /// Small badge / Tag: 10 (ar) / 8.5 (en)
  static double badge([BuildContext? context]) => sp(ar: 10.0, en: 8.5, context: context);

  /// Micro / Status indicator text: 9 (ar) / 8.0 (en)
  static double micro([BuildContext? context]) => sp(ar: 9.0, en: 8.0, context: context);
}
