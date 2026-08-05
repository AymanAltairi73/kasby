import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/core/utils/safe_getx.dart';
import 'package:audioplayers/audioplayers.dart';

/// Unified, premium notification service for all user-facing alerts.
/// Provides consistent glassmorphic styling, haptic feedback, and clear messaging.
class AppSnack {
  AppSnack._();

  /// ✅ Success notification — green accent, checkmark icon, light haptic.
  static void success(String title, String message, {TextButton? mainButton}) {
    SafeGetx.debugTrace(
      className: 'AppSnack',
      method: 'success',
      feature: 'Core',
      status: 'INFO',
      params: {'title': title},
    );
    HapticFeedback.mediumImpact();
    _show(
      title: title,
      message: message,
      icon: Icons.check_circle_rounded,
      accentColor: AppColors.softGreen,
      mainButton: mainButton,
    );
  }

  /// ❌ Error notification — red accent, alert icon, heavy haptic.
  static void error(String title, String message, {TextButton? mainButton}) {
    SafeGetx.debugTrace(
      className: 'AppSnack',
      method: 'error',
      feature: 'Core',
      status: 'INFO',
      params: {'title': title},
    );
    HapticFeedback.heavyImpact();
    _show(
      title: title,
      message: message,
      icon: Icons.error_rounded,
      accentColor: AppColors.error,
      mainButton: mainButton,
    );
  }

  /// ⚠️ Warning notification — gold accent, warning icon, medium haptic.
  static void warning(String title, String message, {TextButton? mainButton}) {
    SafeGetx.debugTrace(
      className: 'AppSnack',
      method: 'warning',
      feature: 'Core',
      status: 'INFO',
      params: {'title': title},
    );
    HapticFeedback.mediumImpact();
    _show(
      title: title,
      message: message,
      icon: Icons.warning_amber_rounded,
      accentColor: AppColors.darkGold,
      mainButton: mainButton,
    );
  }

  /// ℹ️ Info notification — blue accent, info icon, light haptic.
  static void info(String title, String message, {TextButton? mainButton}) {
    SafeGetx.debugTrace(
      className: 'AppSnack',
      method: 'info',
      feature: 'Core',
      status: 'INFO',
      params: {'title': title},
    );
    HapticFeedback.lightImpact();
    _show(
      title: title,
      message: message,
      icon: Icons.info_rounded,
      accentColor: Colors.blueAccent,
      mainButton: mainButton,
    );
  }

  /// 🔐 OTP notification — premium notification-style snackbar for verification codes.
  /// Mimics a system notification with shield icon, prominent code display, and elevated shadow.
  static void otp(String code) {
    SafeGetx.debugTrace(
      className: 'AppSnack',
      method: 'otp',
      feature: 'Core',
      status: 'INFO',
      message: 'OTP snackbar displayed',
    );
    HapticFeedback.mediumImpact();
    // Play notification sound
    final player = AudioPlayer();
    player.play(AssetSource('sounds/notification.mp3')).then((_) {
      player.onPlayerComplete.listen((_) => player.dispose());
    });
    final isDark = Get.isDarkMode;
    final accentColor = AppColors.darkGold;

    Get.snackbar(
      '',
      '',
      titleText: Row(
        children: [
          // Shield icon with gradient-like glow
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  accentColor.withValues(alpha: 0.25),
                  accentColor.withValues(alpha: 0.10),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.verified_user_rounded,
              color: accentColor,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'otp_notification_title'.tr,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    color: isDark ? Colors.white : Colors.black87,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'otp_notification_body'.tr,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      messageText: Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: accentColor.withValues(alpha: isDark ? 0.12 : 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: accentColor.withValues(alpha: 0.25),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline_rounded, color: accentColor, size: 18),
            const SizedBox(width: 12),
            Text(
              code,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: 8,
                color: accentColor,
              ),
            ),
          ],
        ),
      ),
      snackPosition: SnackPosition.TOP,
      backgroundColor: isDark
          ? const Color(0xFF12121A).withValues(alpha: 0.97)
          : Colors.white.withValues(alpha: 0.97),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      borderRadius: 20,
      borderColor: accentColor.withValues(alpha: 0.15),
      borderWidth: 1,
      duration: const Duration(seconds: 6),
      animationDuration: const Duration(milliseconds: 500),
      isDismissible: true,
      dismissDirection: DismissDirection.horizontal,
      forwardAnimationCurve: Curves.easeOutCubic,
      reverseAnimationCurve: Curves.easeInCubic,
      boxShadows: [
        BoxShadow(
          color: accentColor.withValues(alpha: 0.12),
          blurRadius: 25,
          spreadRadius: 2,
          offset: const Offset(0, 8),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.15),
          blurRadius: 15,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  static void _show({
    required String title,
    required String message,
    required IconData icon,
    required Color accentColor,
    TextButton? mainButton,
  }) {
    final isDark = Get.isDarkMode;

    Get.snackbar(
      '',
      '',
      titleText: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: accentColor, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ),
        ],
      ),
      messageText: Padding(
        padding: const EdgeInsets.only(right: 34),
        child: Text(
          message,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.white70 : Colors.black54,
            height: 1.4,
          ),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      snackPosition: SnackPosition.TOP,
      backgroundColor: isDark
          ? const Color(0xFF1A1A2E).withValues(alpha: 0.95)
          : Colors.white.withValues(alpha: 0.95),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      borderRadius: 16,
      borderColor: accentColor.withValues(alpha: 0.2),
      borderWidth: 1,
      duration: const Duration(seconds: 4),
      animationDuration: const Duration(milliseconds: 400),
      isDismissible: true,
      forwardAnimationCurve: Curves.easeOutCubic,
      reverseAnimationCurve: Curves.easeInCubic,
      boxShadows: [
        BoxShadow(
          color: accentColor.withValues(alpha: 0.08),
          blurRadius: 15,
          offset: const Offset(0, 6),
        ),
      ],
      mainButton: mainButton,
    );
  }
}
