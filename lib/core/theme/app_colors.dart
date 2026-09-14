import 'package:flutter/material.dart';
import 'package:kasby/core/controllers/theme_controller.dart';

class AppColors {
  // Theme-aware dynamic getters
  static Color get darkGold => _isDark ? goldDark : goldLight;
  static Color get softGreen => _isDark ? successDark : successLight;
  static Color get error => _isDark ? errorDark : errorLight;
  static Color get background => _isDark ? backgroundDark : backgroundLight;
  static Color get surface => _isDark ? surfaceDark : surfaceLight;
  static Color get surfaceSecondary =>
      _isDark ? const Color(0xFF22222A) : surfaceVariantLight;
  static Color get surfaceElevated =>
      _isDark ? const Color(0xFF25252E) : surfaceLight;
  static Color get onSurface => _isDark ? onSurfaceDark : onSurfaceLight;
  static Color get textBody => _isDark ? textBodyDark : textBodyLight;
  static Color get textSecondary =>
      _isDark ? textSecondaryDark : textSecondaryLight;
  static Color get textMuted =>
      _isDark ? const Color(0xFF71717A) : textMutedLight;
  static Color get border =>
      _isDark ? Colors.white.withValues(alpha: 0.08) : borderLight;
  static Color get borderStrong =>
      _isDark ? Colors.white.withValues(alpha: 0.16) : borderStrongLight;
  static Color get primary => _isDark ? primaryDark : primaryLight;

  // Emotional soft backgrounds
  static Color get successSoftBg =>
      _isDark ? const Color(0xFF102818) : successBgLight;
  static Color get errorSoftBg =>
      _isDark ? const Color(0xFF2E1518) : errorBgLight;
  static Color get warningSoftBg =>
      _isDark ? const Color(0xFF2A1F0D) : warningBgLight;
  static Color get infoSoftBg =>
      _isDark ? const Color(0xFF122035) : infoBgLight;
  static Color get goldSoftBg =>
      _isDark ? const Color(0xFF2A2312) : const Color(0xFFFDF8EE);

  // ─── Chat Semantic Tokens ───
  /// Chat canvas background — subtle tinted surface
  static Color get chatBackground =>
      _isDark ? backgroundDark : const Color(0xFFF0F2F5);
  /// Received message bubble — soft neutral
  static Color get chatReceivedBubble =>
      _isDark ? surfaceDark : const Color(0xFFFFFFFF);
  /// Received bubble border
  static Color get chatReceivedBorder =>
      _isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFE2E8F0);
  /// Chat input area surface
  static Color get chatInputSurface =>
      _isDark ? surfaceDark : const Color(0xFFFFFFFF);
  /// Chat input field background
  static Color get chatInputField =>
      _isDark ? backgroundDark : const Color(0xFFF1F4F8);
  /// Chat input field border
  static Color get chatInputBorder =>
      _isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFE2E8F0);
  /// Chat input top divider
  static Color get chatInputDivider =>
      _isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFE2E8F0);
  /// Chat text on received bubble
  static Color get chatReceivedText =>
      _isDark ? const Color(0xFFE0E0E0) : const Color(0xFF1E293B);
  /// Chat secondary text (timestamps, edited labels) on received side
  static Color get chatReceivedMuted =>
      _isDark ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF94A3B8);
  /// Chat date separator text
  static Color get chatDateText =>
      _isDark ? Colors.white.withValues(alpha: 0.3) : const Color(0xFF94A3B8);
  /// Chat date separator divider
  static Color get chatDateDivider =>
      _isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFE2E8F0);
  /// Chat deleted message text/icon
  static Color get chatDeletedText =>
      _isDark ? Colors.white.withValues(alpha: 0.3) : const Color(0xFFCBD5E1);
  /// Chat deleted message surface
  static Color get chatDeletedBg =>
      _isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF8FAFC);
  /// Chat deleted message border
  static Color get chatDeletedBorder =>
      _isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFE2E8F0);
  /// Bottom sheet handle
  static Color get sheetHandle =>
      _isDark ? const Color(0x3DFFFFFF) : const Color(0xFFCBD5E1);
  /// Bottom sheet divider
  static Color get sheetDivider =>
      _isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFE2E8F0);
  /// Bottom sheet option text/icon
  static Color get sheetOptionColor =>
      _isDark ? Colors.white : const Color(0xFF1E293B);
  /// Reaction container surface
  static Color get chatReactionBg =>
      _isDark ? surfaceDark : const Color(0xFFF1F4F8);
  /// Reaction container border
  static Color get chatReactionBorder =>
      _isDark ? const Color(0x1AFFFFFF) : const Color(0xFFE2E8F0);
  /// User bubble timestamp color (on gold gradient)
  static Color get chatUserTimestamp =>
      _isDark ? Colors.black.withValues(alpha: 0.6) : Colors.black.withValues(alpha: 0.55);
  /// User bubble edited label color (on gold gradient)
  static Color get chatUserEditedLabel =>
      _isDark ? Colors.black.withValues(alpha: 0.5) : Colors.black.withValues(alpha: 0.45);
  /// Welcome/connecting overlay text
  static Color get chatWelcomeText =>
      _isDark ? Colors.white.withValues(alpha: 0.9) : const Color(0xFF1E293B);
  /// Placeholder shimmer in chat image loading
  static Color get chatImagePlaceholder =>
      _isDark ? const Color(0x1AFFFFFF) : const Color(0xFFEDF2F7);

  // Theme-aware shadows
  static Color get shadowColor =>
      _isDark ? Colors.black.withValues(alpha: 0.4) : const Color(0x0A0F172A);

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
  // Calmed canvas: subtle warm-cool slate off-white, preventing glare
  static const Color backgroundLight = Color(0xFFF6F8FA);
  static const Color surfaceLight = Color(0xFFFFFFFF);        // Crisp white card surface
  static const Color surfaceVariantLight = Color(0xFFF1F4F8); // Gentle neutral secondary
  static const Color surfaceSecondaryLight = Color(0xFFEDF2F7); // Slate 100 muted secondary
  static const Color primaryLight = Color(0xFFC9A24D);        // Refined Kasby gold
  static const Color primaryPressedLight = Color(0xFFB58F3B); // Pressed gold
  static const Color successLight = Color(0xFF107C41);        // Deep, calm emerald
  static const Color successBgLight = Color(0xFFF0FDF4);      // Mint 50
  static const Color errorLight = Color(0xFFC53030);          // Muted informative crimson
  static const Color errorBgLight = Color(0xFFFEF2F2);        // Red 50
  static const Color warningLight = Color(0xFFD97706);        // Warm honey amber
  static const Color warningBgLight = Color(0xFFFFFBEB);      // Amber 50
  static const Color infoLight = Color(0xFF2563EB);           // Restrained blue
  static const Color infoBgLight = Color(0xFFEFF6FF);         // Blue 50
  static const Color goldLight = Color(0xFFC9A24D);           // Kasby Gold
  static const Color champagneGoldLight = Color(0xFFE5C173);  // Champagne accent
  static const Color onSurfaceLight = Color(0xFF0F172A);      // Slate 900 - Sharp title text
  static const Color textBodyLight = Color(0xFF1E293B);       // Slate 800 - Crisp body text
  static const Color textSecondaryLight = Color(0xFF475569);  // Slate 600 - High contrast
  static const Color textMutedLight = Color(0xFF94A3B8);      // Slate 400 - Hint/disabled text
  static const Color borderLight = Color(0xFFE2E8F0);         // Slate 200 - Clean card borders
  static const Color borderStrongLight = Color(0xFFCBD5E1);   // Slate 300 - Input borders
  static const Color iconLight = Color(0xFF334155);           // Slate 700 - Deep slate icons

  // Luxury Card Tokens
  static const Color obsidianCardDark = Color(0xFF141418);
  static const Color obsidianCardLight = Color(0xFF18181F);

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
