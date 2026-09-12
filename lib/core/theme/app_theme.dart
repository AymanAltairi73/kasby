import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'kasby_typography.dart';

class AppTheme {
  static ThemeData get darkTheme =>
      getDarkTheme(isEnglish: KasbyTypography.isEnglish());
  static ThemeData get lightTheme =>
      getLightTheme(isEnglish: KasbyTypography.isEnglish());

  static ThemeData getDarkTheme({required bool isEnglish}) {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: AppColors.primaryDark,
      scaffoldBackgroundColor: AppColors.backgroundDark,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primaryDark,
        surface: AppColors.surfaceDark,
        onSurface: AppColors.onSurfaceDark,
        error: AppColors.errorDark,
      ),
      textTheme: _buildTextTheme(isDark: true, isEnglish: isEnglish),
      cardTheme: CardThemeData(
        color: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 0,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: KasbyTypography.fontFamily,
          fontSize: isEnglish ? 16.5 : 18,
          fontWeight: FontWeight.bold,
          color: AppColors.onSurfaceDark,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceDark,
        hintStyle: TextStyle(
          fontFamily: KasbyTypography.fontFamily,
          color: AppColors.textSecondaryDark.withValues(alpha: 0.6),
          fontSize: isEnglish ? 12.5 : 14,
        ),
        labelStyle: TextStyle(
          fontFamily: KasbyTypography.fontFamily,
          color: AppColors.textSecondaryDark,
          fontSize: isEnglish ? 12.5 : 14,
        ),
        prefixIconColor: AppColors.textSecondaryDark,
        suffixIconColor: AppColors.textSecondaryDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.goldDark, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.errorDark),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.errorDark, width: 1.5),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.surfaceDark,
        elevation: 8,
        selectedItemColor: AppColors.goldDark,
        unselectedItemColor: AppColors.textSecondaryDark,
        selectedLabelStyle: TextStyle(
          fontFamily: KasbyTypography.fontFamily,
          fontSize: isEnglish ? 10 : 11,
          fontWeight: FontWeight.bold,
        ),
        unselectedLabelStyle: TextStyle(
          fontFamily: KasbyTypography.fontFamily,
          fontSize: isEnglish ? 10 : 11,
          fontWeight: FontWeight.w500,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surfaceDark,
        surfaceTintColor: Colors.transparent,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        titleTextStyle: TextStyle(
          fontFamily: KasbyTypography.fontFamily,
          fontSize: isEnglish ? 16 : 18,
          fontWeight: FontWeight.bold,
          color: AppColors.onSurfaceDark,
        ),
        contentTextStyle: TextStyle(
          fontFamily: KasbyTypography.fontFamily,
          fontSize: isEnglish ? 12.5 : 14,
          color: AppColors.textBodyDark,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surfaceDark,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surfaceDark,
        contentTextStyle: TextStyle(
          fontFamily: KasbyTypography.fontFamily,
          color: Colors.white,
          fontSize: isEnglish ? 13 : 14,
        ),
        behavior: SnackBarBehavior.floating,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white.withValues(alpha: 0.05),
        disabledColor: Colors.white.withValues(alpha: 0.02),
        selectedColor: AppColors.goldDark.withValues(alpha: 0.18),
        secondarySelectedColor: AppColors.goldDark,
        labelStyle: TextStyle(
          fontFamily: KasbyTypography.fontFamily,
          color: AppColors.onSurfaceDark,
          fontSize: isEnglish ? 11 : 12,
        ),
        secondaryLabelStyle: TextStyle(
          fontFamily: KasbyTypography.fontFamily,
          color: AppColors.onSurfaceDark,
          fontSize: isEnglish ? 11 : 12,
        ),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      tabBarTheme: TabBarThemeData(
        indicatorColor: AppColors.goldDark,
        labelColor: AppColors.goldDark,
        unselectedLabelColor: AppColors.textSecondaryDark,
        labelStyle: TextStyle(
          fontFamily: KasbyTypography.fontFamily,
          fontSize: isEnglish ? 13 : 14,
          fontWeight: FontWeight.bold,
        ),
        unselectedLabelStyle: TextStyle(
          fontFamily: KasbyTypography.fontFamily,
          fontSize: isEnglish ? 13 : 14,
          fontWeight: FontWeight.normal,
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.goldDark,
        circularTrackColor: Colors.white10,
        linearTrackColor: Colors.white10,
      ),
    );
  }

  static ThemeData getLightTheme({required bool isEnglish}) {
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
      textTheme: _buildTextTheme(isDark: false, isEnglish: isEnglish),
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
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.backgroundLight,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppColors.onSurfaceLight),
        actionsIconTheme: const IconThemeData(color: AppColors.onSurfaceLight),
        titleTextStyle: TextStyle(
          fontFamily: KasbyTypography.fontFamily,
          fontSize: isEnglish ? 16.5 : 18,
          fontWeight: FontWeight.bold,
          color: AppColors.onSurfaceLight,
        ),
      ),
      iconTheme: const IconThemeData(color: AppColors.iconLight, size: 24),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceLight,
        hintStyle: TextStyle(
          fontFamily: KasbyTypography.fontFamily,
          color: AppColors.textMutedLight,
          fontSize: isEnglish ? 12.5 : 14,
        ),
        labelStyle: TextStyle(
          fontFamily: KasbyTypography.fontFamily,
          color: AppColors.textSecondaryLight,
          fontSize: isEnglish ? 12.5 : 14,
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
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.surfaceLight,
        elevation: 8,
        selectedItemColor: AppColors.goldLight,
        unselectedItemColor: AppColors.textSecondaryLight,
        selectedLabelStyle: TextStyle(
          fontFamily: KasbyTypography.fontFamily,
          fontSize: isEnglish ? 10 : 11,
          fontWeight: FontWeight.bold,
        ),
        unselectedLabelStyle: TextStyle(
          fontFamily: KasbyTypography.fontFamily,
          fontSize: isEnglish ? 10 : 11,
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
        titleTextStyle: TextStyle(
          fontFamily: KasbyTypography.fontFamily,
          fontSize: isEnglish ? 16 : 18,
          fontWeight: FontWeight.bold,
          color: AppColors.onSurfaceLight,
        ),
        contentTextStyle: TextStyle(
          fontFamily: KasbyTypography.fontFamily,
          fontSize: isEnglish ? 12.5 : 14,
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
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.onSurfaceLight,
        contentTextStyle: TextStyle(
          fontFamily: KasbyTypography.fontFamily,
          color: Colors.white,
          fontSize: isEnglish ? 13 : 14,
        ),
        behavior: SnackBarBehavior.floating,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceVariantLight,
        disabledColor: AppColors.borderLight,
        selectedColor: AppColors.goldLight.withValues(alpha: 0.18),
        secondarySelectedColor: AppColors.goldLight,
        labelStyle: TextStyle(
          fontFamily: KasbyTypography.fontFamily,
          color: AppColors.onSurfaceLight,
          fontSize: isEnglish ? 11 : 12,
        ),
        secondaryLabelStyle: TextStyle(
          fontFamily: KasbyTypography.fontFamily,
          color: AppColors.onSurfaceLight,
          fontSize: isEnglish ? 11 : 12,
        ),
        side: const BorderSide(color: AppColors.borderLight),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      tabBarTheme: TabBarThemeData(
        indicatorColor: AppColors.goldLight,
        labelColor: AppColors.goldLight,
        unselectedLabelColor: AppColors.textSecondaryLight,
        labelStyle: TextStyle(
          fontFamily: KasbyTypography.fontFamily,
          fontSize: isEnglish ? 13 : 14,
          fontWeight: FontWeight.bold,
        ),
        unselectedLabelStyle: TextStyle(
          fontFamily: KasbyTypography.fontFamily,
          fontSize: isEnglish ? 13 : 14,
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

  static TextTheme _buildTextTheme({required bool isDark, required bool isEnglish}) {
    final primaryTextColor = isDark ? AppColors.onSurfaceDark : AppColors.onSurfaceLight;
    final secondaryTextColor = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final bodyTextColor = isDark ? AppColors.textBodyDark : AppColors.textBodyLight;

    return TextTheme(
      displayLarge: TextStyle(
        fontFamily: KasbyTypography.fontFamily,
        fontSize: isEnglish ? 26 : 32,
        fontWeight: FontWeight.bold,
        color: primaryTextColor,
      ),
      displayMedium: TextStyle(
        fontFamily: KasbyTypography.fontFamily,
        fontSize: isEnglish ? 22 : 28,
        fontWeight: FontWeight.bold,
        color: primaryTextColor,
      ),
      displaySmall: TextStyle(
        fontFamily: KasbyTypography.fontFamily,
        fontSize: isEnglish ? 20 : 24,
        fontWeight: FontWeight.bold,
        color: primaryTextColor,
      ),
      headlineLarge: TextStyle(
        fontFamily: KasbyTypography.fontFamily,
        fontSize: isEnglish ? 18.5 : 22,
        fontWeight: FontWeight.bold,
        color: primaryTextColor,
      ),
      headlineMedium: TextStyle(
        fontFamily: KasbyTypography.fontFamily,
        fontSize: isEnglish ? 17 : 20,
        fontWeight: FontWeight.bold,
        color: primaryTextColor,
      ),
      headlineSmall: TextStyle(
        fontFamily: KasbyTypography.fontFamily,
        fontSize: isEnglish ? 15.5 : 18,
        fontWeight: FontWeight.w600,
        color: primaryTextColor,
      ),
      titleLarge: TextStyle(
        fontFamily: KasbyTypography.fontFamily,
        fontSize: isEnglish ? 17 : 20,
        fontWeight: FontWeight.bold,
        color: primaryTextColor,
      ),
      titleMedium: TextStyle(
        fontFamily: KasbyTypography.fontFamily,
        fontSize: isEnglish ? 14 : 16,
        fontWeight: FontWeight.w600,
        color: primaryTextColor,
      ),
      titleSmall: TextStyle(
        fontFamily: KasbyTypography.fontFamily,
        fontSize: isEnglish ? 12.5 : 14,
        fontWeight: FontWeight.w600,
        color: secondaryTextColor,
      ),
      bodyLarge: TextStyle(
        fontFamily: KasbyTypography.fontFamily,
        fontSize: isEnglish ? 13.5 : 16,
        fontWeight: FontWeight.normal,
        color: bodyTextColor,
      ),
      bodyMedium: TextStyle(
        fontFamily: KasbyTypography.fontFamily,
        fontSize: isEnglish ? 12.5 : 14,
        fontWeight: FontWeight.normal,
        color: bodyTextColor,
      ),
      bodySmall: TextStyle(
        fontFamily: KasbyTypography.fontFamily,
        fontSize: isEnglish ? 11 : 12,
        fontWeight: FontWeight.normal,
        color: secondaryTextColor,
      ),
      labelLarge: TextStyle(
        fontFamily: KasbyTypography.fontFamily,
        fontSize: isEnglish ? 13 : 14,
        fontWeight: FontWeight.w600,
        color: primaryTextColor,
        letterSpacing: isEnglish ? 0.2 : 0,
      ),
      labelMedium: TextStyle(
        fontFamily: KasbyTypography.fontFamily,
        fontSize: isEnglish ? 11 : 12,
        fontWeight: FontWeight.w500,
        color: secondaryTextColor,
      ),
      labelSmall: TextStyle(
        fontFamily: KasbyTypography.fontFamily,
        fontSize: isEnglish ? 9.5 : 11,
        fontWeight: FontWeight.w500,
        color: secondaryTextColor,
      ),
    );
  }
}

