import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:get/get.dart';
import 'package:kasby/core/services/auth_security_service.dart';
import 'package:kasby/core/services/authentication_logger.dart';
import 'package:kasby/core/services/referral_service.dart';
import 'package:kasby/core/services/snack_service.dart';
import 'package:kasby/features/auth/presentation/controllers/auth_controller.dart';
import 'package:kasby/routes/app_routes.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kasby/core/utils/safe_getx.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Handles incoming deep links (referral invites, notification routes).
class DeepLinkService extends GetxService {
  static DeepLinkService get to => Get.find();

  static const String pendingReferralKey = 'pending_referral_code';

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;

  Future<DeepLinkService> init() async {
    final stopwatch = Stopwatch()..start();
    SafeGetx.debugTrace(className: 'DeepLinkService', method: 'init', feature: 'Core', status: 'INFO');
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        await _handleUri(initialUri, isColdStart: true);
      }

      _linkSubscription = _appLinks.uriLinkStream.listen(
        (uri) => _handleUri(uri, isColdStart: false),
        onError: (Object e, stack) => SafeGetx.debugTrace(
          className: 'DeepLinkService',
          method: 'init',
          feature: 'Core',
          status: 'ERROR',
          error: e,
          stackTrace: stack,
        ),
      );
    } catch (e, stack) {
      SafeGetx.debugTrace(
        className: 'DeepLinkService',
        method: 'init',
        feature: 'Core',
        status: 'WARN',
        message: 'Init skipped',
        error: e,
        stackTrace: stack,
      );
    }
    SafeGetx.debugTrace(
      className: 'DeepLinkService',
      method: 'init',
      feature: 'Core',
      status: 'SUCCESS',
      durationMs: stopwatch.elapsedMilliseconds,
    );
    return this;
  }

  Future<void> _handleUri(Uri uri, {required bool isColdStart}) async {
    SafeGetx.debugTrace(
      className: 'DeepLinkService',
      method: '_handleUri',
      feature: 'Core',
      status: 'INFO',
      params: {'path': uri.path, 'coldStart': isColdStart},
    );

    if (AuthSecurityService.isAuthCallbackUri(uri)) {
      final sw = AuthenticationLogger.logStart(
        'email_verification_deep_link',
        method: '_handleUri',
        authMethod: 'email_link',
        params: {'coldStart': isColdStart, 'path': uri.path},
      );
      try {
        await AuthSecurityService.handleAuthCallback(uri);
        await AuthController.to.handleEmailVerificationDeepLink();
        AppSnack.success('success'.tr, 'auth_link_success'.tr);
        AuthenticationLogger.logSuccess(
          'email_verification_deep_link',
          stopwatch: sw,
          method: '_handleUri',
          authMethod: 'email_link',
          params: {'coldStart': isColdStart},
        );
      } on AuthException catch (e) {
        AuthenticationLogger.logFailure(
          'email_verification_deep_link',
          e,
          stopwatch: sw,
          method: '_handleUri',
          authMethod: 'email_link',
          params: {'coldStart': isColdStart},
        );
        final message = AuthSecurityService.translateAuthError(e);
        if (message.toLowerCase().contains('expired') ||
            message.toLowerCase().contains('invalid')) {
          AppSnack.error('error'.tr, 'verification_link_invalid'.tr);
        } else {
          AppSnack.error('error'.tr, message);
        }
      } catch (e, stack) {
        AuthenticationLogger.logFailure(
          'email_verification_deep_link',
          e,
          stopwatch: sw,
          method: '_handleUri',
          authMethod: 'email_link',
          stackTrace: stack,
          params: {'coldStart': isColdStart},
        );
        SafeGetx.debugTrace(
          className: 'DeepLinkService',
          method: '_handleUri',
          feature: 'Core',
          status: 'ERROR',
          message: 'Auth deep link failed',
          error: e,
          stackTrace: stack,
        );
        AppSnack.error('error'.tr, 'auth_link_invalid'.tr);
      }
      return;
    }

    final referralCode = _extractReferralCode(uri);
    if (referralCode != null) {
      await _storePendingReferral(referralCode);
      _applyReferralToRegister(referralCode);

      if (AuthController.to.authStatus.value == AuthStatus.unauthenticated) {
        if (Get.currentRoute != Routes.register) {
          Get.toNamed(Routes.register);
        }
      }
      return;
    }

    final path = uri.path;
    if (path == '/join' || path.endsWith('/join')) {
      final ref = uri.queryParameters['ref'];
      if (ref != null && ref.isNotEmpty) {
        await _storePendingReferral(ref);
        _applyReferralToRegister(ref);
        if (AuthController.to.authStatus.value == AuthStatus.unauthenticated) {
          Get.toNamed(Routes.register);
        }
      }
    }
  }

  String? _extractReferralCode(Uri uri) {
    final ref = uri.queryParameters['ref'];
    if (ref != null && ref.trim().isNotEmpty) {
      return ReferralService.normalizeCode(ref);
    }

    if (uri.pathSegments.length >= 2 && uri.pathSegments[0] == 'join') {
      return ReferralService.normalizeCode(uri.pathSegments[1]);
    }
    return null;
  }

  Future<void> _storePendingReferral(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(pendingReferralKey, code);
  }

  static Future<String?> getPendingReferralCode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(pendingReferralKey);
  }

  static Future<void> clearPendingReferralCode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(pendingReferralKey);
  }

  void _applyReferralToRegister(String code) {
    if (!Get.isRegistered<AuthController>()) return;
    final controller = AuthController.to;
    controller.referralCodeController.text = code;
    controller.checkReferralCode(code);
  }

  @override
  void onClose() {
    SafeGetx.debugTrace(className: 'DeepLinkService', method: 'onClose', feature: 'Core', status: 'INFO');
    _linkSubscription?.cancel();
    super.onClose();
  }
}
