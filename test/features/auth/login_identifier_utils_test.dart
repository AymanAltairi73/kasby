import 'package:flutter_test/flutter_test.dart';
import 'package:kasby/features/auth/domain/utils/login_identifier_utils.dart';

void main() {
  group('LoginIdentifierUtils', () {
    test('isEmail detects valid emails', () {
      expect(LoginIdentifierUtils.isEmail('user@example.com'), isTrue);
      expect(LoginIdentifierUtils.isEmail('+966501234567'), isFalse);
    });

    test('isPhone detects phone-like input', () {
      expect(LoginIdentifierUtils.isPhone('+966501234567'), isTrue);
      expect(LoginIdentifierUtils.isPhone('501234567'), isTrue);
      expect(LoginIdentifierUtils.isPhone('user@example.com'), isFalse);
    });

    test('normalizePhoneForAuth strips formatting', () {
      expect(
        LoginIdentifierUtils.normalizePhoneForAuth('+966 50 123 4567'),
        '966501234567',
      );
    });

    test('toE164 adds plus prefix', () {
      expect(LoginIdentifierUtils.toE164('966501234567'), '+966501234567');
    });
  });
}
