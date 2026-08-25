import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kasby/core/services/biometric_login_service.dart';
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
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
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

    // Route to lockScreen immediately on resume
    Get.toNamed(Routes.lockScreen);
  }
}
