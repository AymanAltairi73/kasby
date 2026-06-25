import 'dart:async';
import 'package:get/get.dart';
import 'package:kasby/core/services/supabase_service.dart';
import 'package:kasby/core/services/snack_service.dart';
import 'package:kasby/features/auth/domain/services/otp_service.dart';
import 'package:kasby/core/services/auth_security_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kasby/core/utils/safe_getx.dart';

class ProfileUpdateController extends GetxController {
  static ProfileUpdateController get to => Get.find();

  final RxBool isLoading = false.obs;
  final RxInt resendTimer = 0.obs;
  Timer? _timer;

  @override
  void onInit() {
    SafeGetx.debugTrace(
      className: 'ProfileUpdateController',
      method: 'onInit',
      feature: 'Profile',
      status: 'INFO',
    );
    super.onInit();
  }

  // ─── PASSWORD VERIFICATION STATE ─────────────────────────
  final RxBool isPasswordVerified = false.obs;
  final RxBool isVerifyingPassword = false.obs;

  // ─── PASSWORD VERIFICATION ───────────────────────────────

  /// Reauthenticates the user with their current password.
  /// Returns true if the password is correct, false otherwise.
  Future<bool> verifyPassword(String password) async {
    if (password.trim().isEmpty) {
      AppSnack.error('error'.tr, 'enter_current_password_to_verify'.tr);
      return false;
    }

    isVerifyingPassword.value = true;
    try {
      // Get current user email for reauthentication
      final currentEmail = SupabaseService.currentUser?.email;
      if (currentEmail == null || currentEmail.isEmpty) {
        _log('Cannot verify password: no email on current user', method: 'verifyPassword', isError: true);
        AppSnack.error('error'.tr, 'unknown_error'.tr);
        return false;
      }

      await AuthSecurityService.reauthenticateWithPassword(password.trim());

      isPasswordVerified.value = true;
      _log('Password verified successfully', method: 'verifyPassword');
      AppSnack.success('success'.tr, 'password_verified'.tr);
      return true;
    } on AuthException catch (e) {
      _log('Password verification failed', method: 'verifyPassword', isError: true, error: e.message);
      AppSnack.error('error'.tr, 'incorrect_password'.tr);
      return false;
    } catch (e) {
      _log('Password verification error', method: 'verifyPassword', isError: true, error: e);
      AppSnack.error('error'.tr, 'unknown_error'.tr);
      return false;
    } finally {
      isVerifyingPassword.value = false;
    }
  }

  // ─── OTP FLOW ───────────────────────────────────────────

  /// Sends OTP for either email or phone change via Resend / FCM.
  /// Requires password verification first.
  Future<bool> sendUpdateOtp({
    required String target,
    required String type, // 'email_change' or 'phone_change'
  }) async {
    if (!isPasswordVerified.value) {
      AppSnack.warning('error'.tr, 'password_required_first'.tr);
      return false;
    }

    if (resendTimer.value > 0 || isLoading.value) return false;

    isLoading.value = true;

    await SupabaseService.hardRefreshSession();
    try {
      final isEmailChange = type == 'email_change';
      final normalizedTarget = isEmailChange
          ? target.trim().toLowerCase()
          : target.trim();

      if (isEmailChange) {
        await AuthSecurityService.sendProfileChangeOtp(
          target: normalizedTarget,
          targetType: 'email',
          purpose: type,
        );
        _startResendTimer();
        AppSnack.success('success'.tr, 'otp_sent_email'.tr);
        return true;
      }

      await AuthSecurityService.sendProfileChangeOtp(
        target: normalizedTarget,
        targetType: 'phone',
        purpose: type,
      );
      _startResendTimer();
      AppSnack.success('success'.tr, 'otp_sent_sms'.tr);
      return true;
    } catch (e) {
      _log('Error sending update OTP', method: 'sendUpdateOtp', isError: true, error: e, params: {'type': type});
      String msg = e.toString().replaceAll('Exception:', '').trim();
      if (e is AuthException) {
        msg = AuthSecurityService.translateOtpError(e);
      } else if (e is Exception && msg.isNotEmpty) {
        msg = msg;
      } else {
        msg = 'otp_resend_failed'.tr;
      }
      if (e.toString().contains('RATE_LIMIT')) msg = 'rate_limit_exceeded_friend'.tr;
      AppSnack.error('error'.tr, msg);
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// Requests email change OTP (Resend) — kept for resend actions.
  Future<bool> requestEmailChange(String newEmail) async {
    return sendUpdateOtp(target: newEmail, type: 'email_change');
  }

  /// Checks whether a pending email change has been confirmed.
  Future<bool> checkEmailChangeComplete(String targetEmail) async {
    isLoading.value = true;
    try {
      final complete =
          await AuthSecurityService.isPendingEmailChangeComplete(targetEmail);
      if (complete) {
        await AuthSecurityService.refreshUserProfileState();
        AppSnack.success('success'.tr, 'email_changed_success'.tr);
      }
      return complete;
    } catch (e) {
      _log('Email change status check failed', method: 'checkEmailChangeComplete', isError: true, error: e);
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// Verifies OTP and applies profile update via Twilio Verify platform.
  Future<bool> verifyAndUpdate({
    required String type,
    required String newValue,
    required String otpCode,
  }) async {
    isLoading.value = true;
    try {
      if (type == 'email_change') {
        await OTPService.to.verifyEmailOtp(
          email: newValue.trim().toLowerCase(),
          code: otpCode,
          purpose: 'email_change',
          newValue: newValue.trim().toLowerCase(),
        );
      } else {
        await OTPService.to.verifyPhoneOtp(
          phone: newValue.trim(),
          code: otpCode,
          purpose: 'phone_change',
          newValue: newValue.trim(),
        );
      }
      await AuthSecurityService.refreshUserProfileState();
      AppSnack.success('success'.tr, 'profile_updated_success'.tr);
      return true;
    } on OTPVerificationException catch (e) {
      AppSnack.error('error'.tr, AuthSecurityService.translateOtpError(e));
      return false;
    } catch (e) {
      _log('Error in verifyAndUpdate', method: 'verifyAndUpdate', isError: true, error: e);
      AppSnack.error('error'.tr, 'unknown_error'.tr);
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  // ─── FLOW MANAGEMENT ─────────────────────────────────────

  /// Resets the entire update flow state for reuse.
  void resetFlow() {
    isPasswordVerified.value = false;
    isVerifyingPassword.value = false;
    resendTimer.value = 0;
    _timer?.cancel();
  }

  // ─── HELPERS ──────────────────────────────────────────

  void _startResendTimer() {
    resendTimer.value = 60;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (resendTimer.value > 0) {
        resendTimer.value--;
      } else {
        _timer?.cancel();
      }
    });
  }

  void _log(String message, {String method = 'event', bool isError = false, Object? error, StackTrace? stack, Map<String, Object?>? params}) {
    SafeGetx.debugTrace(
      className: 'ProfileUpdateController',
      method: method,
      feature: 'Profile',
      status: isError ? 'ERROR' : 'INFO',
      message: message,
      params: params,
      error: error,
      stackTrace: stack,
    );
  }

  @override
  void onClose() {
    SafeGetx.debugTrace(
      className: 'ProfileUpdateController',
      method: 'onClose',
      feature: 'Profile',
      status: 'INFO',
    );
    _timer?.cancel();
    super.onClose();
  }
}
