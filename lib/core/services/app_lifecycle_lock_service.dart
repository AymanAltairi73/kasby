import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kasby/core/services/biometric_login_service.dart';
import 'package:kasby/core/services/session_service.dart';
import 'package:kasby/core/services/supabase_service.dart';
import 'package:kasby/routes/app_routes.dart';

/// Monitors AppLifecycleState to lock the app with biometric authentication
/// when returning from background if enabled in Security Center.
class AppLifecycleLockService extends GetxService with WidgetsBindingObserver {
  static AppLifecycleLockService get to => Get.find();

  DateTime? _pausedAt;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _pausedAt ??= DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      _handleAppResume();
      _pausedAt = null;
    }
  }

  void _handleAppResume() {
    if (!SupabaseService.isLoggedIn) return;

    final biometricEnabled = Get.isRegistered<BiometricLoginService>() &&
        BiometricLoginService.to.isEnabled.value;

    if (!biometricEnabled) return;

    if (Get.currentRoute == Routes.lockScreen) return;

    // Ignore resume triggered by native biometric authentication dialog dismissal
    if (Get.isRegistered<SessionService>() &&
        SessionService.to.isBiometricJustFinished) {
      return;
    }

    // Ignore momentary background pauses (e.g. system popups/overlays under 2 seconds)
    if (_pausedAt != null &&
        DateTime.now().difference(_pausedAt!) < const Duration(seconds: 2)) {
      return;
    }

    // Route to lockScreen immediately on resume
    Get.toNamed(Routes.lockScreen);
  }
}
