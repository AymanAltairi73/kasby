import 'package:flutter_test/flutter_test.dart';
import 'package:kasby/features/auth/domain/auth_otp_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('AuthOtpConfig phone OTP', () {
    test('normalizes non-digit characters from pasted codes', () {
      expect(AuthOtpConfig.normalize('12-34 56'), '123456');
    });

    test('isComplete returns true only at expected SMS length', () {
      expect(AuthOtpConfig.isComplete('123456', 6), isTrue);
      expect(AuthOtpConfig.isComplete('12345', 6), isFalse);
      expect(AuthOtpConfig.isComplete('1234567', 6), isFalse);
    });

    test('lengthForOtpType returns 6 for sms and phoneChange', () {
      expect(AuthOtpConfig.lengthForOtpType(OtpType.sms), 6);
      expect(AuthOtpConfig.lengthForOtpType(OtpType.phoneChange), 6);
    });
  });
}
