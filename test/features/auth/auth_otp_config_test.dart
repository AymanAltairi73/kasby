import 'package:flutter_test/flutter_test.dart';
import 'package:kasby/features/auth/domain/auth_otp_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('AuthOtpConfig', () {
    test('email change defaults to 8 digits', () {
      expect(AuthOtpConfig.lengthForPurpose('email_change'), 8);
      expect(AuthOtpConfig.lengthForOtpType(OtpType.emailChange), 8);
    });

    test('signup and recovery default to 6 digits', () {
      expect(AuthOtpConfig.lengthForPurpose('signup'), 6);
      expect(AuthOtpConfig.lengthForOtpType(OtpType.signup), 6);
      expect(AuthOtpConfig.lengthForOtpType(OtpType.recovery), 6);
    });

    test('normalize strips non-digits', () {
      expect(AuthOtpConfig.normalize('12-34 56'), '123456');
    });

    test('isComplete validates exact length', () {
      expect(AuthOtpConfig.isComplete('12345678', 8), isTrue);
      expect(AuthOtpConfig.isComplete('1234567', 8), isFalse);
      expect(AuthOtpConfig.isComplete('123456789', 8), isFalse);
    });
  });
}
