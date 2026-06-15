import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:kasby/core/services/auth_security_service.dart';

void main() {
  setUpAll(() {
    Get.testMode = true;
    Get.addTranslations({
      'en_US': {
        'invalid_otp': 'Invalid verification code.',
        'otp_expired': 'Verification code expired.',
        'auth_link_invalid': 'The link is invalid or has expired.',
        'auth_error_rate_limit': 'Too many attempts.',
      },
    });
    Get.updateLocale(const Locale('en', 'US'));
  });

  group('AuthSecurityService.translateOtpError', () {
    test('maps expired token errors to otp_expired', () {
      expect(
        AuthSecurityService.translateOtpError(
          'Token has expired or is invalid',
        ),
        'Verification code expired.',
      );
    });

    test('maps invalid otp errors to invalid_otp', () {
      expect(
        AuthSecurityService.translateOtpError('Invalid OTP'),
        'Invalid verification code.',
      );
    });

    test('maps link-style otp errors to otp messages not auth_link_invalid', () {
      expect(
        AuthSecurityService.translateOtpError(
          'Email link is invalid or has expired',
        ),
        'Verification code expired.',
      );
    });
  });

  group('AuthSecurityService.translateAuthError', () {
    test('does not map otp errors to auth_link_invalid', () {
      expect(
        AuthSecurityService.translateAuthError(
          'Token has expired or is invalid',
        ),
        isNot('The link is invalid or has expired.'),
      );
    });

    test('maps link callback errors to auth_link_invalid', () {
      expect(
        AuthSecurityService.translateAuthError('Invalid callback link'),
        'The link is invalid or has expired.',
      );
    });

    test('maps smtp delivery failures to auth_error_email_delivery', () {
      Get.addTranslations({
        'en_US': {
          'auth_error_email_delivery': 'Unable to send email right now.',
        },
      });
      expect(
        AuthSecurityService.translateAuthError(
          '535 5.7.8 Username and Password not accepted',
        ),
        'Unable to send email right now.',
      );
    });

    test('parses GoTrue JSON error bodies', () {
      expect(
        AuthSecurityService.normalizeAuthErrorMessage(
          '{"code":"unexpected_failure","message":"Error sending recovery email"}',
        ),
        'Error sending recovery email',
      );
      expect(
        AuthSecurityService.translateAuthError(
          '{"code":"unexpected_failure","message":"Error sending recovery email"}',
        ),
        isNot('The link is invalid or has expired.'),
      );
    });
  });
}
