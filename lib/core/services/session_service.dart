import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kasby/core/services/security_activity_service.dart';
import 'package:kasby/core/services/supabase_service.dart';
import 'package:kasby/core/utils/safe_getx.dart';
import 'package:kasby/features/auth/presentation/controllers/auth_controller.dart';
import 'package:kasby/routes/app_routes.dart';
import 'package:local_auth/local_auth.dart';

/// Single authoritative service for session security, inactivity tracking,
/// background timeouts, and screen lock in the Kasby application.
class SessionService extends GetxService with WidgetsBindingObserver {
  static SessionService get to => Get.find();

  final LocalAuthentication _auth = LocalAuthentication();

  // Timeouts
  static const int lockTimeout = 5; // 5 minutes
  static const Duration screenLockTimeout = Duration(minutes: lockTimeout);

  static const int logoutTimeout = 30; // 30 minutes
  static const Duration backgroundLogoutTimeout = Duration(minutes: logoutTimeout);

  // Background and inactivity state
  DateTime? _backgroundAt;
  DateTime _lastInteractionTime = DateTime.now();

  Timer? _inactivityTimer;
  Timer? _logoutTimer;

  bool _isLocked = false;
  bool get isLocked => _isLocked;

  bool _isBiometricPromptActive = false;
  bool get isBiometricPromptActive => _isBiometricPromptActive;

  DateTime? _lastBiometricPromptEndedAt;
  DateTime? get lastBiometricPromptEndedAt => _lastBiometricPromptEndedAt;

  bool get isBiometricJustFinished {
    if (_isBiometricPromptActive) return true;
    if (_lastBiometricPromptEndedAt == null) return false;
    return DateTime.now().difference(_lastBiometricPromptEndedAt!) < const Duration(seconds: 3);
  }

  void notifyBiometricPromptStarted() {
    _isBiometricPromptActive = true;
  }

  void notifyBiometricPromptEnded() {
    _isBiometricPromptActive = false;
    _lastBiometricPromptEndedAt = DateTime.now();
  }

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
    if (SupabaseService.isLoggedIn) {
      recordUserInteraction();
    }
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
    _inactivityTimer?.cancel();
    _logoutTimer?.cancel();
    super.onClose();
  }

  // ─── Lifecycle Handling ───

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!SupabaseService.isLoggedIn) return;

    SafeGetx.debugTrace(
      className: 'SessionService',
      method: 'didChangeAppLifecycleState',
      feature: 'Core',
      status: 'INFO',
      params: {'state': state.name},
    );

    if (state == AppLifecycleState.paused) {
      _backgroundAt ??= DateTime.now();
      _inactivityTimer?.cancel();
      _startLogoutTimer();
    } else if (state == AppLifecycleState.inactive) {
      // Transitioning away or momentary system dialog/screenshot
      _backgroundAt ??= DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      _handleAppResume();
    }
  }

  void _startLogoutTimer() {
    _logoutTimer?.cancel();
    _logoutTimer = Timer(backgroundLogoutTimeout, () {
      if (_backgroundAt != null && SupabaseService.isLoggedIn) {
        SafeGetx.debugTrace(
          className: 'SessionService',
          method: '_startLogoutTimer',
          feature: 'Core',
          status: 'WARN',
          message: 'Auto logout triggered after $logoutTimeout minutes in background',
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
    final backgroundTime = _backgroundAt;
    _backgroundAt = null;

    if (!SupabaseService.isLoggedIn) return;

    // Ignore resume triggered by native biometric dialog dismissal
    if (isBiometricJustFinished || _isBiometricPromptActive) {
      recordUserInteraction();
      return;
    }

    if (backgroundTime != null) {
      final elapsed = DateTime.now().difference(backgroundTime);

      SafeGetx.debugTrace(
        className: 'SessionService',
        method: '_handleAppResume',
        feature: 'Core',
        status: 'INFO',
        params: {'elapsedSeconds': elapsed.inSeconds},
      );

      // 1. Check for 30-minute background auto-logout
      if (elapsed >= backgroundLogoutTimeout) {
        SafeGetx.debugTrace(
          className: 'SessionService',
          method: '_handleAppResume',
          feature: 'Core',
          status: 'WARN',
          message: 'Logout timeout exceeded ($logoutTimeout min)',
        );
        unawaited(
          SecurityActivityService.to.logEvent(
            SecurityEventType.sessionExpiration,
          ),
        );
        AuthController.to.logout();
        return;
      }

      // 2. Check for 5-minute background screen lock
      if (elapsed >= screenLockTimeout) {
        SafeGetx.debugTrace(
          className: 'SessionService',
          method: '_handleAppResume',
          feature: 'Core',
          status: 'INFO',
          message: 'Background timeout exceeded ($screenLockTimeout). Showing lock screen.',
        );
        _showLockScreen();
        return;
      }
    }

    // Returned before 5 minutes (or momentary inactive, e.g. screenshot taken):
    // Cancel pending lock, keep state, resume 5-minute inactivity tracking.
    recordUserInteraction();
  }

  // ─── Inactivity Tracking ───

  /// Called on genuine user interactions (taps, drags, navigation).
  /// Resets the 5-minute inactivity timer.
  void recordUserInteraction() {
    if (!SupabaseService.isLoggedIn || _isLocked) return;

    final now = DateTime.now();
    final timeSinceLast = now.difference(_lastInteractionTime);
    _lastInteractionTime = now;

    // Throttle timer recreation to once every 2 seconds during continuous scrolling/gestures
    if (_inactivityTimer != null &&
        _inactivityTimer!.isActive &&
        timeSinceLast < const Duration(seconds: 2)) {
      return;
    }

    _resetInactivityTimer();
  }

  void _resetInactivityTimer() {
    _inactivityTimer?.cancel();
    if (!SupabaseService.isLoggedIn || _isLocked) return;

    _inactivityTimer = Timer(screenLockTimeout, _handleInactivityTimeout);
  }

  void _handleInactivityTimeout() {
    if (!SupabaseService.isLoggedIn || _isLocked) return;
    if (Get.currentRoute == Routes.lockScreen) return;

    // Verify genuine wall-clock elapsed time
    final elapsed = DateTime.now().difference(_lastInteractionTime);
    if (elapsed < screenLockTimeout) {
      final remaining = screenLockTimeout - elapsed;
      _inactivityTimer?.cancel();
      _inactivityTimer = Timer(remaining, _handleInactivityTimeout);
      return;
    }

    SafeGetx.debugTrace(
      className: 'SessionService',
      method: '_handleInactivityTimeout',
      feature: 'Core',
      status: 'WARN',
      message: 'Inactivity timeout reached ($screenLockTimeout). Showing lock screen.',
    );

    _showLockScreen();
  }

  // ─── Lock & Unlock ───

  Future<void> _showLockScreen() async {
    if (!SupabaseService.isLoggedIn) return;
    if (_isLocked) return;
    if (Get.currentRoute == Routes.lockScreen) return;

    // Do not lock while biometric prompt is actively displayed
    if (isBiometricJustFinished || _isBiometricPromptActive) return;

    _isLocked = true;
    _inactivityTimer?.cancel();

    Get.toNamed(Routes.lockScreen);
  }

  void unlock() {
    _isLocked = false;
    _backgroundAt = null;
    _lastInteractionTime = DateTime.now();
    _resetInactivityTimer();
  }

  void onUserLogin() {
    _isLocked = false;
    _backgroundAt = null;
    _lastInteractionTime = DateTime.now();
    _resetInactivityTimer();
  }

  void onUserLogout() {
    _isLocked = false;
    _backgroundAt = null;
    _inactivityTimer?.cancel();
    _logoutTimer?.cancel();
  }

  // ─── Biometric Authentication ───

  Future<bool> authenticate() async {
    notifyBiometricPromptStarted();
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
    } finally {
      notifyBiometricPromptEnded();
    }
  }
}
