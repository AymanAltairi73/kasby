import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: AppColors.primaryDark,
      scaffoldBackgroundColor: AppColors.backgroundDark,
      colorScheme: ColorScheme.dark(
        primary: AppColors.primaryDark,
        surface: AppColors.surfaceDark,
        onSurface: AppColors.onSurfaceDark,
        error: AppColors.errorDark,
      ),
      textTheme: TextTheme(
        displayLarge: TextStyle(
          fontFamily: 'IBMPlexSansArabic',
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: AppColors.onSurfaceDark,
        ),
        displayMedium: TextStyle(
          fontFamily: 'IBMPlexSansArabic',
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: AppColors.onSurfaceDark,
        ),
        displaySmall: TextStyle(
          fontFamily: 'IBMPlexSansArabic',
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: AppColors.onSurfaceDark,
        ),
        headlineMedium: TextStyle(
          fontFamily: 'IBMPlexSansArabic',
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.onSurfaceDark,
        ),
        titleLarge: TextStyle(
          fontFamily: 'IBMPlexSansArabic',
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.onSurfaceDark,
        ),
        bodyLarge: TextStyle(
          fontFamily: 'IBMPlexSansArabic',
          fontSize: 16,
          color: AppColors.textBodyDark,
        ),
        bodyMedium: TextStyle(
          fontFamily: 'IBMPlexSansArabic',
          fontSize: 14,
          color: AppColors.textBodyDark,
        ),
        labelLarge: TextStyle(
          fontFamily: 'IBMPlexSansArabic',
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.goldDark,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 0,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: AppColors.primaryLight,
      scaffoldBackgroundColor: AppColors.backgroundLight,
      colorScheme: ColorScheme.light(
        primary: AppColors.primaryLight,
        onPrimary: Colors.white,
        primaryContainer: AppColors.primaryPressedLight,
        surface: AppColors.surfaceLight,
        onSurface: AppColors.onSurfaceLight,
        error: AppColors.errorLight,
        outline: AppColors.borderLight,
        outlineVariant: AppColors.borderLight.withValues(alpha: 0.5),
      ),
      textTheme: TextTheme(
        displayLarge: TextStyle(
          fontFamily: 'IBMPlexSansArabic',
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: AppColors.onSurfaceLight,
        ),
        displayMedium: TextStyle(
          fontFamily: 'IBMPlexSansArabic',
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: AppColors.onSurfaceLight,
        ),
        displaySmall: TextStyle(
          fontFamily: 'IBMPlexSansArabic',
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: AppColors.onSurfaceLight,
        ),
        headlineMedium: TextStyle(
          fontFamily: 'IBMPlexSansArabic',
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.onSurfaceLight,
        ),
        titleLarge: TextStyle(
          fontFamily: 'IBMPlexSansArabic',
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.onSurfaceLight,
        ),
        bodyLarge: TextStyle(
          fontFamily: 'IBMPlexSansArabic',
          fontSize: 16,
          color: AppColors.textBodyLight,
        ),
        bodyMedium: TextStyle(
          fontFamily: 'IBMPlexSansArabic',
          fontSize: 14,
          color: AppColors.textBodyLight,
        ),
        bodySmall: TextStyle(
          fontFamily: 'IBMPlexSansArabic',
          fontSize: 12,
          color: AppColors.textSecondaryLight,
        ),
        labelLarge: TextStyle(
          fontFamily: 'IBMPlexSansArabic',
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.primaryLight,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surfaceLight,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppColors.borderLight, width: 1),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: AppColors.borderLight,
        thickness: 1,
        space: 1,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.backgroundLight,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: AppColors.onSurfaceLight),
        titleTextStyle: TextStyle(
          fontFamily: 'IBMPlexSansArabic',
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.onSurfaceLight,
        ),
      ),
      iconTheme: IconThemeData(color: AppColors.iconLight, size: 24),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppColors.borderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppColors.borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppColors.primaryLight, width: 2),
        ),
      ),
    );
  }
}
