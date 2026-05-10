import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kasby/features/auth/presentation/controllers/auth_controller.dart';
import 'package:kasby/routes/app_routes.dart';
import 'package:local_auth/local_auth.dart';

class SessionService extends GetxService with WidgetsBindingObserver {
  static SessionService get to => Get.find();

  final LocalAuthentication _auth = LocalAuthentication();
  DateTime? _backgroundTime;
  Timer? _logoutTimer;

  // Timeouts in minutes
  static const int lockTimeout = 5;
  static const int logoutTimeout = 30;

  bool _isLocked = false;
  bool get isLocked => _isLocked;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    _logoutTimer?.cancel();
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!AuthController.to.isLoggedIn) return;

    if (state == AppLifecycleState.paused) {
      _backgroundTime = DateTime.now();
      _startLogoutTimer();
    } else if (state == AppLifecycleState.resumed) {
      _handleAppResume();
    }
  }

  void _startLogoutTimer() {
    _logoutTimer?.cancel();
    _logoutTimer = Timer(const Duration(minutes: logoutTimeout), () {
      if (_backgroundTime != null) {
        AuthController.to.logout();
      }
    });
  }

  void _handleAppResume() {
    _logoutTimer?.cancel();
    if (_backgroundTime == null) return;

    final duration = DateTime.now().difference(_backgroundTime!);
    
    if (duration.inMinutes >= logoutTimeout) {
      AuthController.to.logout();
    } else if (duration.inMinutes >= lockTimeout) {
      _showLockScreen();
    }

    _backgroundTime = null;
  }

  Future<void> _showLockScreen() async {
    if (_isLocked) return;
    _isLocked = true;
    
    // We use Get.toNamed to show a lock screen that can't be dismissed easily
    Get.toNamed(Routes.lockScreen);
  }

  void unlock() {
    _isLocked = false;
  }

  Future<bool> authenticate() async {
    try {
      final bool canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
      if (!canAuthenticateWithBiometrics) return true; // Fallback if no biometrics

      return await _auth.authenticate(
        localizedReason: 'authenticate_to_continue'.tr,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
    } catch (e) {
      debugPrint('Auth error: $e');
      return false;
    }
  }
}
