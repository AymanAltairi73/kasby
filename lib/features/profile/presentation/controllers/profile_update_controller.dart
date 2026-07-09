import 'dart:async';
import 'package:get/get.dart';
import 'package:kasby/core/services/snack_service.dart';
import 'package:kasby/core/services/supabase_service.dart';
import 'package:kasby/core/services/authentication_logger.dart';
import 'package:kasby/features/auth/domain/auth_otp_config.dart';
import 'package:kasby/features/auth/domain/repositories/authentication_repository.dart';
import 'package:kasby/features/auth/domain/services/phone_otp_service.dart';
import 'package:kasby/core/services/auth_security_service.dart';
import 'package:kasby/core/utils/input_validators.dart';
import 'package:kasby/core/utils/safe_getx.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileUpdateController extends GetxController {
  static ProfileUpdateController get to => Get.find();

  AuthenticationRepository get _authRepo => AuthenticationRepository.to;
  PhoneOtpService get _phoneOtp => PhoneOtpService.to;

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

  final RxBool isPasswordVerified = false.obs;
  final RxBool isVerifyingPassword = false.obs;

  Future<bool> verifyPassword(String password) async {
    if (password.trim().isEmpty) {
      AppSnack.error('error'.tr, 'enter_current_password_to_verify'.tr);
      return false;
    }

    isVerifyingPassword.value = true;
    final sw = AuthenticationLogger.logStart(
      'password_verification',
      method: 'verifyPassword',
      authMethod: 'email_password',
    );
    try {
      final user = await _authRepo.fetchFreshUser();
      final email = user?.email?.trim();
      if (email == null || email.isEmpty) {
        _log('Cannot verify password: no email on current user',
            method: 'verifyPassword', isError: true);
        AppSnack.error('error'.tr, 'cannot_verify_identity'.tr);
        return false;
      }

      await _authRepo.reauthenticateWithPassword(password.trim());

      isPasswordVerified.value = true;
      AuthenticationLogger.logSuccess(
        'password_verification',
        stopwatch: sw,
        method: 'verifyPassword',
        authMethod: 'email_password',
      );
      _log('Password verified successfully', method: 'verifyPassword');
      AppSnack.success('success'.tr, 'password_verified'.tr);
      return true;
    } on AuthException catch (e) {
      AuthenticationLogger.logFailure(
        'password_verification',
        e,
        stopwatch: sw,
        method: 'verifyPassword',
        authMethod: 'email_password',
      );
      _log('Password verification failed',
          method: 'verifyPassword', isError: true, error: e.message);
      AppSnack.error('error'.tr, 'incorrect_password'.tr);
      return false;
    } catch (e, stack) {
      AuthenticationLogger.logFailure(
        'password_verification',
        e,
        stopwatch: sw,
        method: 'verifyPassword',
        authMethod: 'email_password',
        stackTrace: stack,
      );
      _log('Password verification error',
          method: 'verifyPassword', isError: true, error: e);
      AppSnack.error('error'.tr, 'unexpected_error'.tr);
      return false;
    } finally {
      isVerifyingPassword.value = false;
    }
  }

  Future<bool> sendUpdateOtp({
    required String target,
    required String type,
    String? currentValue,
  }) async {
    if (!isPasswordVerified.value) {
      AppSnack.warning('error'.tr, 'password_required_first'.tr);
      return false;
    }

    if (resendTimer.value > 0 || isLoading.value) return false;

    final isEmailChange = type == 'email_change';
    final normalizedTarget = isEmailChange
        ? target.trim().toLowerCase()
        : _phoneOtp.toE164(target.trim());

    final validationError = _validateChangeTarget(
      type: type,
      newValue: normalizedTarget,
      currentValue: currentValue,
    );
    if (validationError != null) {
      AppSnack.error('error'.tr, validationError);
      return false;
    }

    isLoading.value = true;
    final operation =
        isEmailChange ? 'email_change_request' : 'phone_change_request';
    final sw = AuthenticationLogger.logStart(
      operation,
      method: 'sendUpdateOtp',
      authMethod: isEmailChange ? 'email_otp' : 'phone_otp',
      email: isEmailChange ? normalizedTarget : null,
      phone: isEmailChange ? null : normalizedTarget,
    );

    try {
      if (isEmailChange) {
        final available =
            await AuthSecurityService.isEmailAvailable(normalizedTarget);
        if (!available) {
          AppSnack.error('error'.tr, 'email_already_exists'.tr);
          return false;
        }
        await _authRepo.initiateEmailChange(normalizedTarget);
        _startResendTimer();
        AuthenticationLogger.logSuccess(
          operation,
          stopwatch: sw,
          method: 'sendUpdateOtp',
          authMethod: 'email_otp',
          email: normalizedTarget,
        );
        AppSnack.success('success'.tr, 'otp_sent_email'.tr);
        return true;
      }

      final available =
          await AuthSecurityService.isPhoneAvailable(normalizedTarget);
      if (!available) {
        AppSnack.error('error'.tr, 'phone_already_used'.tr);
        return false;
      }

      await _authRepo.initiatePhoneChange(normalizedTarget);
      _startResendTimer();
      AuthenticationLogger.logSuccess(
        operation,
        stopwatch: sw,
        method: 'sendUpdateOtp',
        authMethod: 'phone_otp',
        phone: normalizedTarget,
      );
      AppSnack.success('success'.tr, 'otp_sent_sms'.tr);
      return true;
    } on AuthException catch (e) {
      AuthenticationLogger.logFailure(
        operation,
        e,
        stopwatch: sw,
        method: 'sendUpdateOtp',
        authMethod: isEmailChange ? 'email_otp' : 'phone_otp',
        email: isEmailChange ? normalizedTarget : null,
        phone: isEmailChange ? null : normalizedTarget,
      );
      AppSnack.error(
        'error'.tr,
        isEmailChange
            ? AuthSecurityService.normalizeOtpDispatchError(e.message)
            : AuthSecurityService.translateOtpError(e),
      );
      return false;
    } catch (e, stack) {
      AuthenticationLogger.logFailure(
        operation,
        e,
        stopwatch: sw,
        method: 'sendUpdateOtp',
        authMethod: isEmailChange ? 'email_otp' : 'phone_otp',
        stackTrace: stack,
      );
      _log('Error sending update OTP',
          method: 'sendUpdateOtp', isError: true, error: e, params: {'type': type});
      AppSnack.error('error'.tr, 'otp_resend_failed'.tr);
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  String? _validateChangeTarget({
    required String type,
    required String newValue,
    String? currentValue,
  }) {
    final isEmailChange = type == 'email_change';
    if (newValue.isEmpty) return 'fill_all_data'.tr;

    if (isEmailChange) {
      if (!InputValidators.isValidEmail(newValue)) return 'invalid_email'.tr;
      final current = currentValue?.trim().toLowerCase() ??
          SupabaseService.currentUser?.email?.trim().toLowerCase();
      if (current != null && current == newValue) {
        return 'email_same_as_current'.tr;
      }
      return null;
    }

    if (!InputValidators.isValidE164Phone(newValue)) {
      return 'invalid_phone'.tr;
    }
    final currentPhone = currentValue?.trim() ??
        AuthSecurityService.getUserPhone()?.trim();
    if (currentPhone != null) {
      final normalizedCurrent = _phoneOtp.toE164(currentPhone);
      if (normalizedCurrent == newValue) {
        return 'phone_same_as_current'.tr;
      }
    }
    return null;
  }

  Future<bool> requestEmailChange(String newEmail) async {
    return sendUpdateOtp(target: newEmail, type: 'email_change');
  }

  Future<bool> checkEmailChangeComplete(String targetEmail) async {
    isLoading.value = true;
    try {
      final complete =
          await _authRepo.isPendingEmailChangeComplete(targetEmail);
      if (complete) {
        await _authRepo.refreshUserProfileState();
        AppSnack.success('success'.tr, 'email_changed_success'.tr);
      }
      return complete;
    } catch (e) {
      _log('Email change status check failed',
          method: 'checkEmailChangeComplete', isError: true, error: e);
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> verifyAndUpdate({
    required String type,
    required String newValue,
    required String otpCode,
  }) async {
    if (!InputValidators.isValidOtp(otpCode)) {
      AppSnack.error('error'.tr, 'invalid_otp'.tr);
      return false;
    }

    isLoading.value = true;
    final operation =
        type == 'email_change' ? 'email_change_confirm' : 'phone_change_confirm';
    final sw = AuthenticationLogger.logStart(
      operation,
      method: 'verifyAndUpdate',
      authMethod: type == 'email_change' ? 'email_otp' : 'phone_otp',
    );
    try {
      if (type == 'email_change') {
        final email = newValue.trim().toLowerCase();
        await _authRepo.confirmEmailChange(
          newEmail: email,
          code: otpCode.trim(),
        );
      } else {
        await _authRepo.confirmPhoneChange(
          newPhone: _phoneOtp.toE164(newValue.trim()),
          code: otpCode.trim(),
        );
      }
      AuthenticationLogger.logSuccess(
        operation,
        stopwatch: sw,
        method: 'verifyAndUpdate',
        authMethod: type == 'email_change' ? 'email_otp' : 'phone_otp',
      );
      AppSnack.success('success'.tr, 'profile_updated_success'.tr);
      return true;
    } on AuthException catch (e) {
      AuthenticationLogger.logFailure(
        operation,
        e,
        stopwatch: sw,
        method: 'verifyAndUpdate',
        authMethod: type == 'email_change' ? 'email_otp' : 'phone_otp',
      );
      AppSnack.error('error'.tr, AuthSecurityService.translateOtpError(e));
      return false;
    } catch (e, stack) {
      AuthenticationLogger.logFailure(
        operation,
        e,
        stopwatch: sw,
        method: 'verifyAndUpdate',
        authMethod: type == 'email_change' ? 'email_otp' : 'phone_otp',
        stackTrace: stack,
      );
      _log('Error in verifyAndUpdate',
          method: 'verifyAndUpdate', isError: true, error: e);
      AppSnack.error('error'.tr, 'unexpected_error'.tr);
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  void resetFlow() {
    isPasswordVerified.value = false;
    isVerifyingPassword.value = false;
    resendTimer.value = 0;
    _timer?.cancel();
  }

  void _startResendTimer() {
    resendTimer.value = AuthOtpConfig.cooldownSeconds;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (resendTimer.value > 0) {
        resendTimer.value--;
      } else {
        _timer?.cancel();
      }
    });
  }

  void _log(String message,
      {String method = 'event',
      bool isError = false,
      Object? error,
      StackTrace? stack,
      Map<String, Object?>? params}) {
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
    _timer?.cancel();
    super.onClose();
  }
}
