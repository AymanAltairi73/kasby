import 'package:get/get.dart';
import 'package:kasby/features/auth/domain/repositories/authentication_repository.dart';
import 'package:kasby/features/auth/domain/services/email_otp_service.dart';
import 'package:kasby/features/auth/domain/services/phone_otp_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Backward-compatible facade — delegates to Supabase Auth OTP services only.
class OTPService extends GetxService {
  static OTPService get to => Get.find();

  AuthenticationRepository get _repo => AuthenticationRepository.to;
  EmailOtpService get _email => EmailOtpService.to;
  PhoneOtpService get _phone => PhoneOtpService.to;

  Future<void> sendPhoneOtp({
    required String phone,
    required String purpose,
    Map<String, dynamic>? provision,
  }) async {
    switch (purpose) {
      case 'password_reset':
        await _repo.sendPasswordResetPhone(phone);
        break;
      case 'phone_change':
        await _repo.initiatePhoneChange(phone);
        break;
      case 'verification':
      case 'phone_confirm':
      case 'signup':
        await _repo.sendPhoneVerificationOtp(phone);
        break;
      case 'sensitive_action':
        await _repo.sendStepUpOtp(phone);
        break;
      default:
        await _phone.sendOtp(
          phone: phone,
          shouldCreateUser: false,
          data: provision?['provision_metadata'] as Map<String, dynamic>?,
        );
    }
  }

  Future<void> sendEmailOtp({
    required String email,
    required String purpose,
    Map<String, dynamic>? provision,
  }) async {
    switch (purpose) {
      case 'password_reset':
      case 'recovery':
        await _repo.sendPasswordResetEmail(email);
        break;
      case 'email_change':
        await _repo.initiateEmailChange(email);
        break;
      case 'signup':
      case 'verification':
        await _repo.sendSignupEmailOtp(email);
        break;
      default:
        await _email.sendSignupVerification(email);
    }
  }

  Future<Map<String, dynamic>> verifyPhoneOtp({
    required String phone,
    required String code,
    required String purpose,
    String? newValue,
    String? newPassword,
  }) async {
    OtpType type;
    switch (purpose) {
      case 'password_reset':
        type = OtpType.recovery;
        break;
      case 'phone_change':
        type = OtpType.phoneChange;
        break;
      default:
        type = OtpType.sms;
    }

    await _repo.verifyPhoneOtp(phone: phone, code: code, type: type);

    if (newPassword != null && newPassword.isNotEmpty) {
      await _repo.completePasswordReset(newPassword);
    }

    return {'success': true};
  }

  Future<Map<String, dynamic>> verifyEmailOtp({
    required String email,
    required String code,
    required String purpose,
    String? newValue,
    String? newPassword,
  }) async {
    OtpType type;
    switch (purpose) {
      case 'password_reset':
      case 'recovery':
        type = OtpType.recovery;
        break;
      case 'email_change':
        type = OtpType.emailChange;
        break;
      default:
        type = OtpType.signup;
    }

    if (type == OtpType.emailChange) {
      await _repo.confirmEmailChange(newEmail: email, code: code);
    } else if (type == OtpType.recovery) {
      await _repo.verifyPasswordResetEmailOtp(email: email, code: code);
      if (newPassword != null && newPassword.isNotEmpty) {
        await _repo.completePasswordReset(newPassword);
      }
    } else {
      await _repo.verifySignupEmailOtp(email: email, code: code);
    }

    return {'success': true};
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
