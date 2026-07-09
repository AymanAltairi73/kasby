import 'package:get/get.dart';
import 'package:kasby/core/services/authentication_logger.dart';
import 'package:kasby/core/services/supabase_service.dart';
import 'package:kasby/features/auth/domain/auth_otp_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase Auth email OTP — single source of truth for email verification flows.
class EmailOtpService extends GetxService {
  static EmailOtpService get to => Get.find();

  GoTrueClient get _auth => SupabaseService.auth;

  String _sanitizeEmail(String email) => email.trim().toLowerCase();

  /// Resend signup verification OTP (after [signUp]).
  Future<void> sendSignupVerification(String email) async {
    final sw = AuthenticationLogger.logStart(
      'email_otp_signup',
      method: 'sendSignupVerification',
      authMethod: 'email_otp',
      email: _sanitizeEmail(email),
    );
    try {
      await _auth.resend(
        type: OtpType.signup,
        email: _sanitizeEmail(email),
      );
      AuthenticationLogger.logSuccess(
        'email_otp_signup',
        stopwatch: sw,
        method: 'sendSignupVerification',
        authMethod: 'email_otp',
        email: _sanitizeEmail(email),
      );
    } catch (e, stack) {
      AuthenticationLogger.logFailure(
        'email_otp_signup',
        e,
        stopwatch: sw,
        method: 'sendSignupVerification',
        authMethod: 'email_otp',
        email: _sanitizeEmail(email),
        stackTrace: stack,
      );
      rethrow;
    }
  }

  /// Password reset OTP via Supabase Auth (Gmail SMTP).
  Future<void> sendPasswordReset(String email) async {
    final sanitized = _sanitizeEmail(email);
    final sw = AuthenticationLogger.logStart(
      'password_reset',
      method: 'sendPasswordReset',
      authMethod: 'email_otp',
      email: sanitized,
    );
    try {
      await _auth.resetPasswordForEmail(sanitized);
      AuthenticationLogger.logSuccess(
        'password_reset',
        stopwatch: sw,
        method: 'sendPasswordReset',
        authMethod: 'email_otp',
        email: sanitized,
      );
    } catch (e, stack) {
      AuthenticationLogger.logFailure(
        'password_reset',
        e,
        stopwatch: sw,
        method: 'sendPasswordReset',
        authMethod: 'email_otp',
        email: sanitized,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  /// Initiates email change — Supabase sends OTP to the new address.
  Future<void> sendEmailChange(String newEmail) async {
    final sanitized = _sanitizeEmail(newEmail);
    final sw = AuthenticationLogger.logStart(
      'email_change',
      method: 'sendEmailChange',
      authMethod: 'email_otp',
      email: sanitized,
    );
    try {
      await _auth.updateUser(UserAttributes(email: sanitized));
      AuthenticationLogger.logSuccess(
        'email_change',
        stopwatch: sw,
        method: 'sendEmailChange',
        authMethod: 'email_otp',
        email: sanitized,
      );
    } catch (e, stack) {
      AuthenticationLogger.logFailure(
        'email_change',
        e,
        stopwatch: sw,
        method: 'sendEmailChange',
        authMethod: 'email_otp',
        email: sanitized,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  /// Resend email OTP for a given [OtpType].
  Future<void> resend({
    required String email,
    required OtpType type,
  }) async {
    final sanitized = _sanitizeEmail(email);
    final sw = AuthenticationLogger.logStart(
      'email_otp_resend',
      method: 'resend',
      authMethod: 'email_otp',
      email: sanitized,
      params: {'type': type.name},
    );
    try {
      await _auth.resend(type: type, email: sanitized);
      AuthenticationLogger.logSuccess(
        'email_otp_resend',
        stopwatch: sw,
        method: 'resend',
        authMethod: 'email_otp',
        email: sanitized,
        params: {'type': type.name},
      );
    } catch (e, stack) {
      AuthenticationLogger.logFailure(
        'email_otp_resend',
        e,
        stopwatch: sw,
        method: 'resend',
        authMethod: 'email_otp',
        email: sanitized,
        stackTrace: stack,
        params: {'type': type.name},
      );
      rethrow;
    }
  }

  /// Verify email OTP via Supabase Auth.
  Future<AuthResponse> verify({
    required String email,
    required String token,
    required OtpType type,
  }) async {
    final sanitized = _sanitizeEmail(email);
    final normalized = AuthOtpConfig.normalize(token);
    final expected = AuthOtpConfig.lengthForOtpType(type);
    if (normalized.length != expected) {
      throw AuthException(
        'otp_length_mismatch',
        statusCode: '400',
      );
    }

    final sw = AuthenticationLogger.logStart(
      'email_otp_verify',
      method: 'verify',
      authMethod: 'email_otp',
      email: sanitized,
      params: {'type': type.name},
    );
    try {
      final response = await _auth.verifyOTP(
        type: type,
        email: sanitized,
        token: normalized,
      );
      AuthenticationLogger.logSuccess(
        'email_otp_verify',
        stopwatch: sw,
        method: 'verify',
        authMethod: 'email_otp',
        email: sanitized,
        params: {'type': type.name},
      );
      return response;
    } catch (e, stack) {
      AuthenticationLogger.logFailure(
        'email_otp_verify',
        e,
        stopwatch: sw,
        method: 'verify',
        authMethod: 'email_otp',
        email: sanitized,
        stackTrace: stack,
        params: {'type': type.name},
      );
      rethrow;
    }
  }

  /// Complete password reset after OTP verification.
  Future<void> updatePasswordAfterRecovery(String newPassword) async {
    final sw = AuthenticationLogger.logStart(
      'password_reset_complete',
      method: 'updatePasswordAfterRecovery',
      authMethod: 'email_otp',
    );
    try {
      await _auth.updateUser(UserAttributes(password: newPassword.trim()));
      await SupabaseService.hardRefreshSession();
      AuthenticationLogger.logSuccess(
        'password_reset_complete',
        stopwatch: sw,
        method: 'updatePasswordAfterRecovery',
        authMethod: 'email_otp',
      );
    } catch (e, stack) {
      AuthenticationLogger.logFailure(
        'password_reset_complete',
        e,
        stopwatch: sw,
        method: 'updatePasswordAfterRecovery',
        authMethod: 'email_otp',
        stackTrace: stack,
      );
      rethrow;
    }
  }
}
