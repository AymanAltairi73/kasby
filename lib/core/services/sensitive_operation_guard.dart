import 'package:get/get.dart';
import 'package:kasby/core/services/auth_security_service.dart';
import 'package:kasby/core/services/snack_service.dart';
import 'package:kasby/core/utils/safe_getx.dart';
import 'package:kasby/routes/app_routes.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Account-level step-up OTP (email/phone change, password change).
///
/// **Not used for wallet transfers, withdrawals, or QR payments.**
/// Financial operations use [TransactionAuthService] (biometric + transaction PIN).
class SensitiveOperationGuard {
  SensitiveOperationGuard._();

  static const stepUpVerifiedKey = 'step_up_verified_at';

  static void _log(
    String method,
    String message, {
    String status = 'INFO',
    Map<String, Object?>? params,
    Object? error,
  }) {
    SafeGetx.debugTrace(
      className: 'SensitiveOperationGuard',
      method: method,
      feature: 'Authentication',
      status: status,
      message: message,
      params: params,
      error: error,
    );
  }

  /// Returns the user's verified phone for step-up OTP, or null if unavailable.
  static String? get stepUpPhone => AuthSecurityService.getUserPhone();

  /// Whether a recent step-up OTP verification is still valid (5 minutes).
  static bool get hasRecentStepUp {
    if (!Get.isRegistered<SensitiveOperationGuardService>()) return false;
    final verifiedAt = Get.find<SensitiveOperationGuardService>().verifiedAt;
    if (verifiedAt == null) return false;
    return DateTime.now().difference(verifiedAt) < const Duration(minutes: 5);
  }

  /// Marks step-up as verified (called after successful OTP).
  static void markStepUpVerified() {
    if (Get.isRegistered<SensitiveOperationGuardService>()) {
      Get.find<SensitiveOperationGuardService>().verifiedAt = DateTime.now();
    }
  }

  /// Clears cached step-up state (e.g. on logout).
  static void clearStepUp() {
    if (Get.isRegistered<SensitiveOperationGuardService>()) {
      final svc = Get.find<SensitiveOperationGuardService>();
      svc.verifiedAt = null;
      svc.nativeStepUpOtp = false;
    }
  }

  /// Requires Supabase phone OTP verification before proceeding.
  ///
  /// Returns `true` when the user completed step-up verification.
  static Future<bool> requirePhoneOtp({
    required String purpose,
    bool force = false,
  }) async {
    if (!force && hasRecentStepUp) {
      _log('requirePhoneOtp', 'Recent step-up still valid', params: {
        'purpose': purpose,
      });
      return true;
    }

    final phone = stepUpPhone;
    if (phone == null || phone.isEmpty) {
      _log(
        'requirePhoneOtp',
        'No verified phone on account',
        status: 'ERROR',
        params: {'purpose': purpose},
      );
      AppSnack.error('error'.tr, 'phone_verification_required'.tr);
      return false;
    }

    try {
      await AuthSecurityService.requestStepUpOtp();
      _log('requirePhoneOtp', 'Step-up OTP sent', params: {
        'purpose': purpose,
        'phone': phone,
      });
    } catch (e) {
      _log(
        'requirePhoneOtp',
        'Failed to send step-up OTP',
        status: 'ERROR',
        params: {'purpose': purpose},
        error: e,
      );
      AppSnack.error(
        'error'.tr,
        AuthSecurityService.translateOtpError(e),
      );
      return false;
    }

    final verified = await Get.toNamed<bool>(
      Routes.otp,
      arguments: {
        'identifier': phone,
        'isPhone': true,
        'isFreeOtp': false,
        'type': OtpType.sms,
        'purpose': purpose,
        'isStepUp': true,
        'otpLength': AuthSecurityService.phoneOtpLength,
      },
    );

    if (verified == true) {
      markStepUpVerified();
      _log('requirePhoneOtp', 'Step-up OTP verified', params: {
        'purpose': purpose,
      });
      return true;
    }

    _log('requirePhoneOtp', 'Step-up OTP not completed', status: 'WARN', params: {
      'purpose': purpose,
    });
    return false;
  }
}

/// GetX service backing [SensitiveOperationGuard.hasRecentStepUp].
class SensitiveOperationGuardService extends GetxService {
  DateTime? verifiedAt;

  /// True when step-up OTP was sent via Supabase Auth (edge function unavailable).
  bool nativeStepUpOtp = false;
}
