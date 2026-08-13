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
      primaryColor: AppColors.goldLight,
      scaffoldBackgroundColor: AppColors.backgroundLight,
      colorScheme: ColorScheme.light(
        primary: AppColors.goldLight,
        onPrimary: Colors.black,
        primaryContainer: AppColors.goldLight.withValues(alpha: 0.15),
        onPrimaryContainer: AppColors.onSurfaceLight,
        secondary: AppColors.textBodyLight,
        onSecondary: Colors.white,
        surface: AppColors.surfaceLight,
        onSurface: AppColors.onSurfaceLight,
        surfaceContainerHighest: AppColors.surfaceVariantLight,
        onSurfaceVariant: AppColors.textSecondaryLight,
        error: AppColors.errorLight,
        onError: Colors.white,
        outline: AppColors.borderLight,
        outlineVariant: AppColors.borderStrongLight,
      ),
      textTheme: const TextTheme(
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
        headlineLarge: TextStyle(
          fontFamily: 'IBMPlexSansArabic',
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: AppColors.onSurfaceLight,
        ),
        headlineMedium: TextStyle(
          fontFamily: 'IBMPlexSansArabic',
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.onSurfaceLight,
        ),
        headlineSmall: TextStyle(
          fontFamily: 'IBMPlexSansArabic',
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.onSurfaceLight,
        ),
        titleLarge: TextStyle(
          fontFamily: 'IBMPlexSansArabic',
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.onSurfaceLight,
        ),
        titleMedium: TextStyle(
          fontFamily: 'IBMPlexSansArabic',
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.onSurfaceLight,
        ),
        titleSmall: TextStyle(
          fontFamily: 'IBMPlexSansArabic',
          fontSize: 14,
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
          color: AppColors.onSurfaceLight,
        ),
        labelMedium: TextStyle(
          fontFamily: 'IBMPlexSansArabic',
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondaryLight,
        ),
        labelSmall: TextStyle(
          fontFamily: 'IBMPlexSansArabic',
          fontSize: 10,
          color: AppColors.textSecondaryLight,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surfaceLight,
        elevation: 0,
        shadowColor: const Color(0x0F0F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.borderLight, width: 1),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.borderLight,
        thickness: 1,
        space: 1,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.backgroundLight,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: AppColors.onSurfaceLight),
        actionsIconTheme: IconThemeData(color: AppColors.onSurfaceLight),
        titleTextStyle: TextStyle(
          fontFamily: 'IBMPlexSansArabic',
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppColors.onSurfaceLight,
        ),
      ),
      iconTheme: const IconThemeData(color: AppColors.iconLight, size: 24),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceLight,
        hintStyle: const TextStyle(
          fontFamily: 'IBMPlexSansArabic',
          color: AppColors.textMutedLight,
          fontSize: 14,
        ),
        labelStyle: const TextStyle(
          fontFamily: 'IBMPlexSansArabic',
          color: AppColors.textSecondaryLight,
          fontSize: 14,
        ),
        prefixIconColor: AppColors.textSecondaryLight,
        suffixIconColor: AppColors.textSecondaryLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.borderStrongLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.borderStrongLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.goldLight, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.errorLight),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.errorLight, width: 1.5),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surfaceLight,
        elevation: 8,
        selectedItemColor: AppColors.goldLight,
        unselectedItemColor: AppColors.textSecondaryLight,
        selectedLabelStyle: TextStyle(
          fontFamily: 'IBMPlexSansArabic',
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
        unselectedLabelStyle: TextStyle(
          fontFamily: 'IBMPlexSansArabic',
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surfaceLight,
        surfaceTintColor: Colors.transparent,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.borderLight),
        ),
        titleTextStyle: const TextStyle(
          fontFamily: 'IBMPlexSansArabic',
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppColors.onSurfaceLight,
        ),
        contentTextStyle: const TextStyle(
          fontFamily: 'IBMPlexSansArabic',
          fontSize: 14,
          color: AppColors.textBodyLight,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surfaceLight,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: AppColors.onSurfaceLight,
        contentTextStyle: TextStyle(
          fontFamily: 'IBMPlexSansArabic',
          color: Colors.white,
          fontSize: 14,
        ),
        behavior: SnackBarBehavior.floating,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceVariantLight,
        disabledColor: AppColors.borderLight,
        selectedColor: AppColors.goldLight.withValues(alpha: 0.18),
        secondarySelectedColor: AppColors.goldLight,
        labelStyle: const TextStyle(
          fontFamily: 'IBMPlexSansArabic',
          color: AppColors.onSurfaceLight,
          fontSize: 12,
        ),
        secondaryLabelStyle: const TextStyle(
          fontFamily: 'IBMPlexSansArabic',
          color: AppColors.onSurfaceLight,
          fontSize: 12,
        ),
        side: const BorderSide(color: AppColors.borderLight),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      tabBarTheme: const TabBarThemeData(
        indicatorColor: AppColors.goldLight,
        labelColor: AppColors.goldLight,
        unselectedLabelColor: AppColors.textSecondaryLight,
        labelStyle: TextStyle(
          fontFamily: 'IBMPlexSansArabic',
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
        unselectedLabelStyle: TextStyle(
          fontFamily: 'IBMPlexSansArabic',
          fontSize: 14,
          fontWeight: FontWeight.normal,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.goldLight
              : const Color(0xFF94A3B8),
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.goldLight.withValues(alpha: 0.3)
              : AppColors.borderLight,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.goldLight
              : Colors.transparent,
        ),
        checkColor: WidgetStateProperty.all(Colors.black),
        side: const BorderSide(color: AppColors.textSecondaryLight),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.goldLight
              : AppColors.textSecondaryLight,
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.goldLight,
        circularTrackColor: AppColors.borderLight,
        linearTrackColor: AppColors.borderLight,
      ),
    );
  }
}
