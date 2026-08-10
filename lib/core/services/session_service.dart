import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kasby/core/services/security_activity_service.dart';
import 'package:kasby/core/utils/safe_getx.dart';
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
    SafeGetx.debugTrace(
      className: 'SessionService',
      method: 'onInit',
      feature: 'Core',
      status: 'INFO',
    );
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void onClose() {
    SafeGetx.debugTrace(
      className: 'SessionService',
      method: 'onClose',
      feature: 'Core',
      status: 'INFO',
    );
    WidgetsBinding.instance.removeObserver(this);
    _logoutTimer?.cancel();
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!AuthController.to.isLoggedIn) return;

    if (state == AppLifecycleState.paused) {
      SafeGetx.debugTrace(
        className: 'SessionService',
        method: 'didChangeAppLifecycleState',
        feature: 'Core',
        status: 'INFO',
        params: {'state': 'paused'},
      );
      _backgroundTime = DateTime.now();
      _startLogoutTimer();
    } else if (state == AppLifecycleState.resumed) {
      SafeGetx.debugTrace(
        className: 'SessionService',
        method: 'didChangeAppLifecycleState',
        feature: 'Core',
        status: 'INFO',
        params: {'state': 'resumed'},
      );
      _handleAppResume();
    }
  }

  void _startLogoutTimer() {
    _logoutTimer?.cancel();
    _logoutTimer = Timer(const Duration(minutes: logoutTimeout), () {
      if (_backgroundTime != null) {
        SafeGetx.debugTrace(
          className: 'SessionService',
          method: '_startLogoutTimer',
          feature: 'Core',
          status: 'WARN',
          message: 'Auto logout triggered',
        );
        unawaited(
          SecurityActivityService.to.logEvent(
            SecurityEventType.sessionExpiration,
          ),
        );
        AuthController.to.logout();
      }
    });
  }

  void _handleAppResume() {
    _logoutTimer?.cancel();
    if (_backgroundTime == null) return;

    final duration = DateTime.now().difference(_backgroundTime!);

    if (duration.inMinutes >= logoutTimeout) {
      SafeGetx.debugTrace(
        className: 'SessionService',
        method: '_handleAppResume',
        feature: 'Core',
        status: 'WARN',
        message: 'Logout timeout exceeded',
      );
      unawaited(
        SecurityActivityService.to.logEvent(
          SecurityEventType.sessionExpiration,
        ),
      );
      AuthController.to.logout();
    } else if (duration.inMinutes >= lockTimeout) {
      SafeGetx.debugTrace(
        className: 'SessionService',
        method: '_handleAppResume',
        feature: 'Core',
        status: 'INFO',
        message: 'Showing lock screen',
      );
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
      final bool isDeviceSupported = await _auth.isDeviceSupported();

      if (!canAuthenticateWithBiometrics && !isDeviceSupported) {
        return true;
      }

      return await _auth.authenticate(
        localizedReason: 'authenticate_to_continue'.tr,
        persistAcrossBackgrounding: true,
        biometricOnly: canAuthenticateWithBiometrics,
      );
    } catch (e, stack) {
      SafeGetx.debugTrace(
        className: 'SessionService',
        method: 'authenticate',
        feature: 'Core',
        status: 'ERROR',
        error: e,
        stackTrace: stack,
      );
      return false;
    }
  }
}
