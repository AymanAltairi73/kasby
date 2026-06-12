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
  });
}
