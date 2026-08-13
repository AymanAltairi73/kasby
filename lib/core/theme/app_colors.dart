import 'package:flutter/material.dart';
import 'package:kasby/core/controllers/theme_controller.dart';

class AppColors {
  // Theme-aware dynamic getters
  static Color get darkGold => _isDark ? goldDark : goldLight;
  static Color get softGreen => _isDark ? successDark : successLight;
  static Color get error => _isDark ? errorDark : errorLight;
  static Color get background => _isDark ? backgroundDark : backgroundLight;
  static Color get surface => _isDark ? surfaceDark : surfaceLight;
  static Color get onSurface => _isDark ? onSurfaceDark : onSurfaceLight;
  static Color get textBody => _isDark ? textBodyDark : textBodyLight;
  static Color get textSecondary =>
      _isDark ? textSecondaryDark : textSecondaryLight;
  static Color get primary => _isDark ? primaryDark : primaryLight;

  static bool get _isDark => ThemeController.to.isDark.value;

  // Dark Mode Colors (Current/Original Branding)
  static const Color backgroundDark = Color(0xFF0E0E11);
  static const Color surfaceDark = Color(0xFF1A1A1F);
  static const Color onSurfaceDark = Colors.white;
  static const Color primaryDark = Color(
    0xFFC9A24D,
  ); // Gold is primary in Dark Mode
  static const Color successDark = Color(0xFF4CAF50);
  static const Color errorDark = Color(0xFFCF6679);
  static const Color textBodyDark = Color(0xFFE0E0E0);
  static const Color textSecondaryDark = Color(0xFFA0A0A0);
  static const Color goldDark = Color(0xFFC9A24D);
  static const Color primaryGold = Color(0xFFC9A24D);
  static const Color darkBackground = Color(0xFF0E0E11);
  static const Color darkNavy = Color(0xFF0E0E11);

  // Light Mode Colors (Kasby Professional Luxury Fintech Palette)
  static const Color backgroundLight = Color(0xFFF8FAFC);     // Slate 50 canvas
  static const Color surfaceLight = Color(0xFFFFFFFF);        // Crisp white card surface
  static const Color surfaceVariantLight = Color(0xFFF1F5F9); // Slate 100 secondary surface
  static const Color primaryLight = Color(0xFFC9A24D);        // Gold brand accent
  static const Color primaryPressedLight = Color(0xFFB58F3B); // Pressed gold
  static const Color successLight = Color(0xFF059669);        // Emerald 600 profit green
  static const Color successBgLight = Color(0xFFECFDF5);      // Emerald 50
  static const Color errorLight = Color(0xFFDC2626);          // Red 600
  static const Color errorBgLight = Color(0xFFFEF2F2);        // Red 50
  static const Color warningLight = Color(0xFFD97706);        // Amber 600
  static const Color warningBgLight = Color(0xFFFFFBEB);      // Amber 50
  static const Color infoLight = Color(0xFF2563EB);           // Blue 600
  static const Color infoBgLight = Color(0xFFEFF6FF);         // Blue 50
  static const Color goldLight = Color(0xFFC9A24D);           // Kasby Gold
  static const Color onSurfaceLight = Color(0xFF0F172A);      // Slate 900 - Sharp title text
  static const Color textBodyLight = Color(0xFF1E293B);       // Slate 800 - Crisp body text
  static const Color textSecondaryLight = Color(0xFF475569);  // Slate 600 - High contrast secondary text
  static const Color textMutedLight = Color(0xFF94A3B8);      // Slate 400 - Hint/disabled text
  static const Color borderLight = Color(0xFFE2E8F0);         // Slate 200 - Clean card borders
  static const Color borderStrongLight = Color(0xFFCBD5E1);   // Slate 300 - Input borders
  static const Color iconLight = Color(0xFF334155);           // Slate 700 - Deep slate icons

  static const LinearGradient goldGradient = LinearGradient(
    colors: [Color(0xFFC9A24D), Color(0xFFE5C173)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkGradient = LinearGradient(
    colors: [backgroundDark, Color(0xFF1C1C22)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient lightGradient = LinearGradient(
    colors: [backgroundLight, Color(0xFFF1F5F9)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
