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
  static const Color primaryDark = Color(0xFFC9A24D); // Gold is primary in Dark Mode
  static const Color successDark = Color(0xFF4CAF50);
  static const Color errorDark = Color(0xFFCF6679);
  static const Color textBodyDark = Color(0xFFE0E0E0);
  static const Color textSecondaryDark = Color(0xFFA0A0A0);
  static const Color goldDark = Color(0xFFC9A24D);
  static const Color primaryGold = Color(0xFFC9A24D);
  static const Color darkBackground = Color(0xFF0E0E11);
  static const Color darkNavy = Color(0xFF0E0E11);

  // Light Mode Colors (Professional Requested Palette)
  static const Color backgroundLight = Color(0xFFF1F5F9);
  static const Color surfaceLight = Color(0xFFF8FAFC);
  static const Color primaryLight = Color(0xFF1E3A8A);
  static const Color primaryPressedLight = Color(0xFF1E40AF);
  static const Color successLight = Color(0xFF065F46);
  static const Color errorLight = Color(0xFF991B1B);
  static const Color goldLight = Color(0xFFC5A059);
  static const Color onSurfaceLight = Color(0xFF0F172A); // Almost black
  static const Color textBodyLight = Color(0xFF1E293B);   // Slate 800
  static const Color textSecondaryLight = Color(0xFF475569); // Slate 600
  static const Color borderLight = Color(0xFFCBD5E1);     // Slate 300
  static const Color iconLight = Color(0xFF334155);       // Slate 700

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
    colors: [backgroundLight, Color(0xFFE2E8F0)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
