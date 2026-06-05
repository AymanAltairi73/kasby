import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:get/get.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// Unified OTP Service for phone & email verification.
///
/// Supports:
///   - Phone OTP via FCM local notification
///   - Email OTP via Resend
///   - Password reset via custom OTP
///
/// Security:
///   - SHA-256 hashed storage (server-side)
///   - 5-minute expiration
///   - Max 5 verification attempts
///   - Rate limited: 5 requests per 15 minutes
///   - One-time use
class OTPService extends GetxService {
  static OTPService get to => Get.find();

  final _supabase = Supabase.instance.client;

  /// Send OTP to a phone number (via FCM notification) or email (via Resend).
  ///
  /// [target] — Phone number (e.g. "+967123456789") or email address.
  /// [targetType] — 'phone' or 'email'.
  /// [fcmToken] — Required for phone OTP delivery.
  /// [purpose] — 'verification', 'password_reset', 'email_change', or 'phone_change'.
  Future<bool> sendOtp({
    required String target,
    required String targetType,
    String? fcmToken,
    String purpose = 'verification',
  }) async {
    try {
      debugPrint('[OTP] Sending $targetType OTP to: $target for $purpose');

      // Use the HARDENED endpoint
      final response = await _rawInvoke(
        'send-otp-hardened',
        body: {
          'target': target,
          'target_type': targetType,
          if (fcmToken != null) 'device_fcm_token': fcmToken,
          'purpose': purpose,
        },
      );

      final rawBody = response.body;
      final data = jsonDecode(rawBody);
      
      if (response.statusCode != 200) {
        final error = data['error'] ?? 'Failed to send OTP';
        final code = data['code'] ?? '';
        debugPrint('[OTP] Send failed: $error ($code)');
        throw Exception(error);
      }

      debugPrint('[OTP] Sent successfully. Expires in ${data['expires_in_seconds']}s');
      return data['success'] as bool? ?? false;
    } catch (e) {
      debugPrint('[OTP] Send error: $e');
      rethrow;
    }
  }

  /// Verify an OTP code entered by the user.
  Future<Map<String, dynamic>> verifyOtp({
    required String target,
    required String targetType,
    required String otpCode,
  }) async {
    try {
      debugPrint('[OTP] Verifying $targetType OTP for: $target');

      final response = await _rawInvoke(
        'verify-otp',
        body: {
          'target': target,
          'target_type': targetType,
          'otp_code': otpCode,
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode != 200) {
        final error = data['error'] ?? 'Invalid OTP';
        final code = data['code'] ?? '';
        final remaining = data['remaining_attempts'];
        debugPrint('[OTP] Verify failed: $error ($code), remaining: $remaining');
        throw OTPVerificationException(
          message: error,
          code: code,
          remainingAttempts: remaining,
        );
      }

      debugPrint('[OTP] Verification successful');
      return Map<String, dynamic>.from(data);
    } catch (e) {
      debugPrint('[OTP] Verify error: $e');
      rethrow;
    }
  }

  /// Secure password reset flow using custom OTP.
  ///
  /// Calls the dedicated Edge Function that verifies OTP AND updates password atomically.
  Future<void> resetPasswordSecure({
    required String target,
    required String otpCode,
    required String newPassword,
  }) async {
    try {
      debugPrint('[OTP] Securely resetting password for: $target');

      final response = await _rawInvoke(
        'reset-password-secure',
        body: {
          'target': target,
          'otp_code': otpCode,
          'new_password': newPassword,
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode != 200) {
        final error = data['error'] ?? 'Failed to reset password';
        debugPrint('[OTP] Password reset failed: $error');
        throw Exception(error);
      }

      debugPrint('[OTP] Password reset successful');
    } catch (e) {
      debugPrint('[OTP] Password reset error: $e');
      rethrow;
    }
  }

  /// Radical Fix: Private method to invoke Edge Functions via raw HTTP 
  /// to bypass SDK-level JWT injection that causes 401s.
  Future<http.Response> _rawInvoke(String functionName, {required Map<String, dynamic> body}) async {
    final supabaseUrl = dotenv.env['SUPABASE_URL']!;
    final anonKey = dotenv.env['SUPABASE_ANON_KEY']!;
    
    final url = Uri.parse('$supabaseUrl/functions/v1/$functionName');
    
    // For authenticated operations, we might want to pass the session token
    final session = _supabase.auth.currentSession;
    final token = session?.accessToken;
    
    debugPrint('[OTP] _rawInvoke: $functionName | session: ${session != null} | token: ${token != null ? "present (${token.length})" : "null"}');
    
    return await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'apikey': anonKey,
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    );
  }

  /// Legacy: Admin password reset flow (kept for backward compatibility but calls new secure method if possible).
  @Deprecated('Use resetPasswordSecure() instead')
  Future<void> resetPasswordWithOtp(
    String target,
    String otpCode,
    String newPassword,
  ) async {
    return resetPasswordSecure(
      target: target,
      otpCode: otpCode,
      newPassword: newPassword,
    );
  }

  // ─── LEGACY COMPATIBILITY ────────────────────────────────

  /// Legacy: Send phone OTP (wraps new unified method).
  @Deprecated('Use sendOtp(target:, targetType: "phone") instead')
  Future<void> sendOtpLegacy(String phoneNumber, String fcmToken) async {
    await sendOtp(
      target: phoneNumber,
      targetType: 'phone',
      fcmToken: fcmToken,
      purpose: 'verification',
    );
  }

  /// Legacy: Verify phone OTP (wraps new unified method).
  @Deprecated('Use verifyOtp(target:, targetType: "phone") instead')
  Future<void> verifyOtpLegacy(String phoneNumber, String otpCode) async {
    await verifyOtp(
      target: phoneNumber,
      targetType: 'phone',
      otpCode: otpCode,
    );
  }

  /// Legacy: Admin reset password.
  @Deprecated('Use resetPasswordWithOtp() instead')
  Future<void> resetPasswordAdmin(
    String phoneNumber,
    String otpCode,
    String newPassword,
  ) async {
    return resetPasswordWithOtp(phoneNumber, otpCode, newPassword);
  }
}

/// Custom exception for OTP verification failures.
///
/// Provides structured error info for the UI:
///   - [code]: 'INVALID_CODE', 'EXPIRED', 'MAX_ATTEMPTS', 'NOT_FOUND'
///   - [remainingAttempts]: how many tries are left
class OTPVerificationException implements Exception {
  final String message;
  final String code;
  final int? remainingAttempts;

  OTPVerificationException({
    required this.message,
    this.code = '',
    this.remainingAttempts,
  });

  @override
  String toString() => message;
}
