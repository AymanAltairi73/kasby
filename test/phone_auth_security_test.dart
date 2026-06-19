import 'package:flutter_test/flutter_test.dart';
import 'package:kasby/core/services/auth_security_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('AuthSecurityService OTP error translation', () {
    test('translateOtpError handles expired token message', () {
      final result = AuthSecurityService.translateOtpError(
        const AuthException('Token has expired'),
      );
      expect(result, isNotEmpty);
    });

    test('translateOtpError handles invalid OTP message', () {
      final result = AuthSecurityService.translateOtpError(
        const AuthException('Invalid verification code'),
      );
      expect(result, isNotEmpty);
    });

    test('translateOtpError handles rate limit message', () {
      final result = AuthSecurityService.translateOtpError(
        const AuthException('rate limit exceeded'),
      );
      expect(result, isNotEmpty);
    });
  });
}
