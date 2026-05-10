import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kasby/core/services/fcm_service.dart';
import 'package:kasby/core/services/supabase_service.dart';
import 'package:kasby/core/services/snack_service.dart';
import 'package:kasby/features/auth/domain/services/otp_service.dart';
import 'package:kasby/features/home/presentation/controllers/home_controller.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileUpdateController extends GetxController {
  static ProfileUpdateController get to => Get.find();

  final RxBool isLoading = false.obs;
  final RxInt resendTimer = 0.obs;
  Timer? _timer;

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
        _log('Cannot verify password: no email found on current user', isError: true);
        AppSnack.error('error'.tr, 'unknown_error'.tr);
        return false;
      }

      // Reauthenticate using Supabase Auth
      await SupabaseService.auth.signInWithPassword(
        email: currentEmail,
        password: password.trim(),
      );

      isPasswordVerified.value = true;
      _log('Password verified successfully for profile update');
      AppSnack.success('success'.tr, 'password_verified'.tr);
      return true;
    } on AuthException catch (e) {
      _log('Password verification failed: ${e.message}', isError: true);
      AppSnack.error('error'.tr, 'incorrect_password'.tr);
      return false;
    } catch (e) {
      _log('Password verification error: $e', isError: true);
      AppSnack.error('error'.tr, 'unknown_error'.tr);
      return false;
    } finally {
      isVerifyingPassword.value = false;
    }
  }

  // ─── OTP FLOW ───────────────────────────────────────────

  /// Sends OTP for either email or phone change.
  /// Requires password verification first.
  Future<String?> sendUpdateOtp({
    required String target,
    required String type, // 'email_change' or 'phone_change'
  }) async {
    // Guard: password must be verified first
    if (!isPasswordVerified.value) {
      AppSnack.warning('error'.tr, 'password_required_first'.tr);
      return null;
    }

    if (resendTimer.value > 0 || isLoading.value) return null;

    isLoading.value = true;
    
    // Ensure session is fresh for sensitive operation
    await SupabaseService.hardRefreshSession();
    try {
      final targetType = type == 'email_change' ? 'email' : 'phone';
      final fcmToken = Get.find<FCMService>().fcmToken.value;
      
      if (fcmToken.isEmpty) {
        AppSnack.error('error'.tr, 'enable_notifications_error'.tr);
        return null;
      }

      final String? otp = await OTPService.to.sendOtp(
        target: target,
        targetType: targetType,
        purpose: type,
        fcmToken: fcmToken, 
      );

      _startResendTimer();
      
      // Deliver OTP via premium notification-style snackbar
      if (otp != null) {
        AppSnack.otp(otp);
      } else {
        AppSnack.success(
          'success'.tr,
          'otp_sent_notification'.tr,
        );
      }
      
      return otp;
    } catch (e) {
      _log('Error sending update OTP for $type to $target: $e', isError: true);
      String msg = e.toString().replaceAll('Exception:', '').trim();
      if (e.toString().contains('RATE_LIMIT')) msg = 'rate_limit_exceeded_friend'.tr;
      AppSnack.error('error'.tr, msg);
      return null;
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
        // 1. Refresh Profile
        await HomeController.to.fetchProfile();
        
        // 2. If email changed, refresh session to update JWT
        if (type == 'email_change') {
          await SupabaseService.client.auth.refreshSession();
        }

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
          _log('Failed to decode error response: ${response.body}', isError: true);
        }

        AppSnack.error('error'.tr, userMsg);
        return false;
      }
    } catch (e) {
      _log('Error in verifyAndUpdate: $e', isError: true);
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

  void _log(String message, {bool isError = false}) {
    debugPrint('[PROFILE_UPDATE_CONTROLLER] ${isError ? "❌" : "ℹ️"} $message');
  }

  @override
  void onClose() {
    _timer?.cancel();
    super.onClose();
  }
}
