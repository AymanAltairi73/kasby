import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:kasby/core/services/email_delivery_logger.dart';
import 'package:kasby/features/auth/domain/auth_otp_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';

/// Unified Twilio Verify OTP platform (phone + email).
///
/// All verification flows route through Supabase Edge Functions:
///   - send-phone-otp / verify-phone-otp
///   - send-email-otp / verify-email-otp
class OTPService extends GetxService {
  static OTPService get to => Get.find();

  final _supabase = Supabase.instance.client;

  Future<void> sendPhoneOtp({
    required String phone,
    required String purpose,
    Map<String, dynamic>? provision,
  }) async {
    await _send(
      function: 'send-phone-otp',
      flow: purpose.toUpperCase(),
      body: {
        'phone': _normalizePhone(phone),
        'purpose': purpose,
        if (provision != null) ...provision,
      },
      phone: phone,
    );
  }

  Future<void> sendEmailOtp({
    required String email,
    required String purpose,
    Map<String, dynamic>? provision,
  }) async {
    await _send(
      function: 'send-email-otp',
      flow: purpose.toUpperCase(),
      body: {
        'email': email.trim().toLowerCase(),
        'purpose': purpose,
        if (provision != null) ...provision,
      },
      email: email,
    );
  }

  Future<void> _send({
    required String function,
    required String flow,
    required Map<String, dynamic> body,
    String? email,
    String? phone,
  }) async {
    EmailDeliveryLogger.logRequest(
      flow: flow,
      source: function,
      email: email,
      phone: phone,
    );

    try {
      final response = await _invoke(function, body: body);
      final data = _decode(response.body);

      if (response.statusCode != 200 || data['success'] != true) {
        final error = data['error']?.toString() ?? 'otp_resend_failed'.tr;
        final code = data['code']?.toString() ?? '';
        EmailDeliveryLogger.logFailure(
          flow: flow,
          source: function,
          error: error,
          httpStatus: response.statusCode,
          email: email,
          phone: phone,
          extra: {'code': code},
        );
        throw OTPDispatchException(message: error, code: code);
      }

      EmailDeliveryLogger.logSuccess(
        flow: flow,
        source: function,
        httpStatus: response.statusCode,
        delivery: data['delivery']?.toString(),
      );
    } catch (e, stack) {
      if (e is! OTPDispatchException) {
        EmailDeliveryLogger.logFailure(
          flow: flow,
          source: function,
          error: e,
          stackTrace: stack,
          email: email,
          phone: phone,
        );
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> verifyPhoneOtp({
    required String phone,
    required String code,
    required String purpose,
    String? newValue,
    String? newPassword,
  }) async {
    return _verify(
      function: 'verify-phone-otp',
      flow: purpose.toUpperCase(),
      body: {
        'phone': _normalizePhone(phone),
        'code': AuthOtpConfig.normalize(code),
        'purpose': purpose,
        if (newValue != null) 'new_value': newValue,
        if (newPassword != null) 'new_password': newPassword,
      },
      phone: phone,
    );
  }

  Future<Map<String, dynamic>> verifyEmailOtp({
    required String email,
    required String code,
    required String purpose,
    String? newValue,
    String? newPassword,
  }) async {
    return _verify(
      function: 'verify-email-otp',
      flow: purpose.toUpperCase(),
      body: {
        'email': email.trim().toLowerCase(),
        'code': AuthOtpConfig.normalize(code),
        'purpose': purpose,
        if (newValue != null) 'new_value': newValue,
        if (newPassword != null) 'new_password': newPassword,
      },
      email: email,
    );
  }

  Future<Map<String, dynamic>> _verify({
    required String function,
    required String flow,
    required Map<String, dynamic> body,
    String? email,
    String? phone,
  }) async {
    final response = await _invoke(function, body: body);
    final data = _decode(response.body);

    if (response.statusCode != 200 || data['success'] != true) {
      final error = data['error']?.toString() ?? 'invalid_otp'.tr;
      final code = data['code']?.toString() ?? '';
      throw OTPVerificationException(
        message: error,
        code: code,
        remainingAttempts: data['remaining_attempts'] as int?,
      );
    }

    if (kDebugMode) {
      debugPrint('[OTP] Verified via $function ($flow)');
    }
    return Map<String, dynamic>.from(data);
  }

  Future<void> resetPasswordSecure({
    required String target,
    required String otpCode,
    required String newPassword,
    required bool isPhone,
  }) async {
    if (isPhone) {
      await verifyPhoneOtp(
        phone: target,
        code: otpCode,
        purpose: 'password_reset',
        newPassword: newPassword,
      );
    } else {
      await verifyEmailOtp(
        email: target,
        code: otpCode,
        purpose: 'password_reset',
        newPassword: newPassword,
      );
    }
  }

  Future<http.Response> _invoke(
    String functionName, {
    required Map<String, dynamic> body,
  }) async {
    final supabaseUrl = dotenv.env['SUPABASE_URL']!;
    final anonKey = dotenv.env['SUPABASE_ANON_KEY']!;
    final url = Uri.parse('$supabaseUrl/functions/v1/$functionName');
    final session = _supabase.auth.currentSession;

    return http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'apikey': anonKey,
        if (session?.accessToken != null)
          'Authorization': 'Bearer ${session!.accessToken}',
      },
      body: jsonEncode(body),
    );
  }

  Map<String, dynamic> _decode(String body) {
    final data = jsonDecode(body);
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return {};
  }

  String _normalizePhone(String phone) {
    var value = phone.trim().replaceAll(RegExp(r'[\s\-()]'), '');
    if (!value.startsWith('+')) value = '+$value';
    return value;
  }
}

class OTPDispatchException implements Exception {
  final String message;
  final String code;
  OTPDispatchException({required this.message, this.code = ''});
  @override
  String toString() => message;
}

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
