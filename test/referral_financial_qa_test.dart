import 'package:flutter_test/flutter_test.dart';
import 'package:kasby/core/services/referral_service.dart';

void main() {
  group('Referral code normalization QA', () {
    test('normalizeCode strips hyphens and uppercases', () {
      expect(ReferralService.normalizeCode('k-561a-9672'), 'K561A9672');
      expect(ReferralService.normalizeCode(' K12345 '), 'K12345');
    });

    test(
      'isValidFormat accepts production hyphenated codes after normalize',
      () {
        expect(ReferralService.isValidFormat('K-561A-9672'), isTrue);
        expect(ReferralService.isValidFormat('K561A9672'), isTrue);
        expect(ReferralService.isValidFormat('K12'), isFalse);
        expect(ReferralService.isValidFormat('ABC'), isFalse);
      },
    );

    test('formatDisplayCode returns normalized display', () {
      expect(ReferralService.formatDisplayCode('K-561A-9672'), 'K561A9672');
      expect(ReferralService.formatDisplayCode(null), '---');
    });
  });
}
