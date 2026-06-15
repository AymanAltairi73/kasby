import 'dart:async';
import 'package:get/get.dart';
import 'package:kasby/core/services/fcm_service.dart';
import 'package:kasby/core/services/supabase_service.dart';
import 'package:kasby/core/services/snack_service.dart';
import 'package:kasby/features/auth/domain/services/otp_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
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

  /// Sends OTP for either email or phone change.
  /// Requires password verification first.
  Future<bool> sendUpdateOtp({
    required String target,
    required String type, // 'email_change' or 'phone_change'
  }) async {
    // Guard: password must be verified first
    if (!isPasswordVerified.value) {
      AppSnack.warning('error'.tr, 'password_required_first'.tr);
      return false;
    }

    if (resendTimer.value > 0 || isLoading.value) return false;

    isLoading.value = true;
    
    // Ensure session is fresh for sensitive operation
    await SupabaseService.hardRefreshSession();
    try {
      final targetType = type == 'email_change' ? 'email' : 'phone';
      final isEmailChange = type == 'email_change';
      String? fcmToken;

      if (!isEmailChange) {
        fcmToken = Get.find<FCMService>().fcmToken.value;
        if (fcmToken.isEmpty) {
          AppSnack.error('error'.tr, 'enable_notifications_error'.tr);
          return false;
        }
      }

      final bool success = await OTPService.to.sendOtp(
        target: target,
        targetType: targetType,
        purpose: type,
        fcmToken: isEmailChange ? null : fcmToken,
      );

      _startResendTimer();
      
      if (success) {
        AppSnack.success(
          'success'.tr,
          isEmailChange ? 'otp_sent_email'.tr : 'otp_sent_notification'.tr,
        );
      }
      
      return success;
    } catch (e) {
      _log('Error sending update OTP', method: 'sendUpdateOtp', isError: true, error: e, params: {'type': type});
      String msg = e.toString().replaceAll('Exception:', '').trim();
      if (e.toString().contains('RATE_LIMIT')) msg = 'rate_limit_exceeded_friend'.tr;
      AppSnack.error('error'.tr, msg);
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// Requests email change via Supabase Auth (confirmation email sent).
  Future<bool> requestEmailChange(String newEmail) async {
    if (!isPasswordVerified.value) {
      AppSnack.warning('error'.tr, 'password_required_first'.tr);
      return false;
    }

    isLoading.value = true;
    try {
      await SupabaseService.hardRefreshSession();
      await AuthSecurityService.requestEmailChange(newEmail);
      AppSnack.success('success'.tr, 'email_change_confirmation_sent'.tr);
      return true;
    } on AuthException catch (e) {
      _log('Email change request failed', method: 'requestEmailChange', isError: true, error: e.message);
      AppSnack.error('error'.tr, AuthSecurityService.translateAuthError(e));
      return false;
    } catch (e) {
      _log('Email change request error', method: 'requestEmailChange', isError: true, error: e);
      AppSnack.error('error'.tr, 'unknown_error'.tr);
      return false;
    } finally {
      isLoading.value = false;
    }
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

  /// Verifies OTP and performs the atomic update via Edge Function.
  Future<bool> verifyAndUpdate({
    required String type,
    required String newValue,
    required String otpCode,
  }) async {
    isLoading.value = true;
    try {
      final response = await _invokeSecureUpdate({
        'type': type,
        'new_value': newValue,
        'otp_code': otpCode,
      });

      if (response.statusCode == 200) {
        await AuthSecurityService.refreshUserProfileState();
        AppSnack.success('success'.tr, 'profile_updated_success'.tr);
        return true;
      } else {
        String userMsg = 'unknown_error'.tr;
        try {
          final data = jsonDecode(response.body);
          final error = data['error'] ?? userMsg;
          final code = data['code'] ?? '';
          
          userMsg = error;
          if (code == 'INVALID_CODE') userMsg = 'invalid_otp'.tr;
          if (code == 'INVALID_OTP') userMsg = 'otp_expired'.tr;
          if (code == 'MAX_ATTEMPTS') userMsg = 'max_attempts_reached'.tr;
          if (code == 'DUPLICATE_VALUE') {
            userMsg = type == 'email_change' ? 'email_already_exists'.tr : 'phone_already_exists'.tr;
          }
        } catch (e) {
          _log('Failed to decode error response', method: 'verifyAndUpdate', isError: true);
        }

        AppSnack.error('error'.tr, userMsg);
        return false;
      }
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

  Future<http.Response> _invokeSecureUpdate(Map<String, dynamic> body) async {
    final supabaseUrl = dotenv.env['SUPABASE_URL']!;
    final anonKey = dotenv.env['SUPABASE_ANON_KEY']!;
    final session = SupabaseService.client.auth.currentSession;
    
    final url = Uri.parse('$supabaseUrl/functions/v1/secure-profile-update');
    
    return await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'apikey': anonKey,
        'Authorization': 'Bearer ${session?.accessToken ?? anonKey}',
      },
      body: jsonEncode(body),
    );
  }

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
