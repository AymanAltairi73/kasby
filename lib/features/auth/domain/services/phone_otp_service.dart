import 'package:get/get.dart';
import 'package:kasby/core/services/authentication_logger.dart';
import 'package:kasby/core/services/supabase_service.dart';
import 'package:kasby/features/auth/domain/auth_otp_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase Auth phone OTP — single source of truth for SMS verification (Twilio).
class PhoneOtpService extends GetxService {
  static PhoneOtpService get to => Get.find();

  GoTrueClient get _auth => SupabaseService.auth;

  String toE164(String phone) {
    var value = phone.trim().replaceAll(RegExp(r'[\s\-()]'), '');
    if (!value.startsWith('+')) value = '+$value';
    return value;
  }

  /// Send SMS OTP for phone verification or login.
  Future<void> sendOtp({
    required String phone,
    bool shouldCreateUser = false,
    Map<String, dynamic>? data,
  }) async {
    final e164 = toE164(phone);
    final sw = AuthenticationLogger.logStart(
      'phone_otp_send',
      method: 'sendOtp',
      authMethod: 'phone_otp',
      phone: e164,
      params: {'shouldCreateUser': shouldCreateUser},
    );
    try {
      await _auth.signInWithOtp(
        phone: e164,
        shouldCreateUser: shouldCreateUser,
        data: data,
      );
      AuthenticationLogger.logSuccess(
        'phone_otp_send',
        stopwatch: sw,
        method: 'sendOtp',
        authMethod: 'phone_otp',
        phone: e164,
      );
    } catch (e, stack) {
      AuthenticationLogger.logFailure(
        'phone_otp_send',
        e,
        stopwatch: sw,
        method: 'sendOtp',
        authMethod: 'phone_otp',
        phone: e164,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  /// Attach phone to authenticated user and trigger SMS OTP.
  Future<void> sendPhoneVerification(String phone) async {
    final e164 = toE164(phone);
    final sw = AuthenticationLogger.logStart(
      'phone_verification',
      method: 'sendPhoneVerification',
      authMethod: 'phone_otp',
      phone: e164,
    );
    try {
      await _auth.updateUser(UserAttributes(phone: e164));
      AuthenticationLogger.logSuccess(
        'phone_verification',
        stopwatch: sw,
        method: 'sendPhoneVerification',
        authMethod: 'phone_otp',
        phone: e164,
      );
    } catch (e, stack) {
      AuthenticationLogger.logFailure(
        'phone_verification',
        e,
        stopwatch: sw,
        method: 'sendPhoneVerification',
        authMethod: 'phone_otp',
        phone: e164,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  /// Initiate phone number change — Supabase sends OTP to new number.
  Future<void> sendPhoneChange(String newPhone) async {
    final e164 = toE164(newPhone);
    final sw = AuthenticationLogger.logStart(
      'phone_change',
      method: 'sendPhoneChange',
      authMethod: 'phone_otp',
      phone: e164,
    );
    try {
      await _auth.updateUser(UserAttributes(phone: e164));
      AuthenticationLogger.logSuccess(
        'phone_change',
        stopwatch: sw,
        method: 'sendPhoneChange',
        authMethod: 'phone_otp',
        phone: e164,
      );
    } catch (e, stack) {
      AuthenticationLogger.logFailure(
        'phone_change',
        e,
        stopwatch: sw,
        method: 'sendPhoneChange',
        authMethod: 'phone_otp',
        phone: e164,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  /// Resend phone OTP for a given [OtpType].
  Future<void> resend({
    required String phone,
    required OtpType type,
  }) async {
    final e164 = toE164(phone);
    final sw = AuthenticationLogger.logStart(
      'phone_otp_resend',
      method: 'resend',
      authMethod: 'phone_otp',
      phone: e164,
      params: {'type': type.name},
    );
    try {
      await _auth.resend(type: type, phone: e164);
      AuthenticationLogger.logSuccess(
        'phone_otp_resend',
        stopwatch: sw,
        method: 'resend',
        authMethod: 'phone_otp',
        phone: e164,
        params: {'type': type.name},
      );
    } catch (e, stack) {
      AuthenticationLogger.logFailure(
        'phone_otp_resend',
        e,
        stopwatch: sw,
        method: 'resend',
        authMethod: 'phone_otp',
        phone: e164,
        stackTrace: stack,
        params: {'type': type.name},
      );
      rethrow;
    }
  }

  /// Verify phone OTP via Supabase Auth.
  Future<AuthResponse> verify({
    required String phone,
    required String token,
    required OtpType type,
  }) async {
    final e164 = toE164(phone);
    final normalized = AuthOtpConfig.normalize(token);
    final expected = AuthOtpConfig.lengthForOtpType(type);
    if (normalized.length != expected) {
      throw AuthException('otp_length_mismatch', statusCode: '400');
    }

    final sw = AuthenticationLogger.logStart(
      'phone_otp_verify',
      method: 'verify',
      authMethod: 'phone_otp',
      phone: e164,
      params: {'type': type.name},
    );
    try {
      final response = await _auth.verifyOTP(
        type: type,
        phone: e164,
        token: normalized,
      );
      AuthenticationLogger.logSuccess(
        'phone_otp_verify',
        stopwatch: sw,
        method: 'verify',
        authMethod: 'phone_otp',
        phone: e164,
        params: {'type': type.name},
      );
      return response;
    } catch (e, stack) {
      AuthenticationLogger.logFailure(
        'phone_otp_verify',
        e,
        stopwatch: sw,
        method: 'verify',
        authMethod: 'phone_otp',
        phone: e164,
        stackTrace: stack,
        params: {'type': type.name},
      );
      rethrow;
    }
  }

  /// Step-up OTP for sensitive account operations (not financial).
  Future<void> sendStepUpOtp(String phone) async {
    await sendOtp(phone: phone, shouldCreateUser: false);
  }

  Future<void> verifyStepUpOtp({
    required String phone,
    required String token,
  }) async {
    await verify(phone: phone, token: token, type: OtpType.sms);
  }
}
