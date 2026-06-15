import 'package:flutter_test/flutter_test.dart';
import 'package:kasby/core/models/profile_model.dart';

void main() {
  group('ProfileModel', () {
    group('fromJson', () {
      test('parses complete JSON correctly', () {
        final json = {
          'id': 'user-123',
          'full_name': 'Test User',
          'email': 'test@example.com',
          'phone': '+967123456789',
          'avatar_url': 'https://example.com/avatar.png',
          'status': 'active',
          'account_tier': 'verified',
          'kyc_status': 'verified',
          'role': 'user',
          'referral_code': 'K0001',
          'referred_by_id': 'referrer-456',
          'country_code': 'YE',
          'province': 'Sana\'a',
          'city': 'Sana\'a',
          'country': 'Yemen',
          'address': '123 Main St',
          'whatsapp': '+967123456789',
          'telegram': '@testuser',
          'last_login_at': '2026-06-09T12:00:00Z',
          'last_login_ip': '192.168.1.1',
          'created_at': '2026-01-01T00:00:00Z',
          'updated_at': '2026-06-09T12:00:00Z',
        };

        final profile = ProfileModel.fromJson(json);

        expect(profile.id, 'user-123');
        expect(profile.fullName, 'Test User');
        expect(profile.email, 'test@example.com');
        expect(profile.phone, '+967123456789');
        expect(profile.status, 'active');
        expect(profile.accountTier, 'verified');
        expect(profile.kycStatus, 'verified');
        expect(profile.role, 'user');
        expect(profile.referralCode, 'K0001');
        expect(profile.referredBy, 'referrer-456');
        expect(profile.country, 'Yemen');
        expect(profile.lastLoginAt, isNotNull);
        expect(profile.createdAt, isNotNull);
      });

      test('handles null email for phone-only accounts', () {
        final json = {
          'id': 'user-789',
          'full_name': 'Phone User',
          'email': null,
          'phone': '+967111111111',
          'role': 'user',
        };

        final profile = ProfileModel.fromJson(json);

        expect(profile.email, isNull);
        expect(profile.phone, '+967111111111');
        expect(profile.fullName, 'Phone User');
      });

      test('handles missing optional fields with defaults', () {
        final json = {
          'id': 'user-minimal',
          'full_name': null,
        };

        final profile = ProfileModel.fromJson(json);

        expect(profile.id, 'user-minimal');
        expect(profile.fullName, '');
        expect(profile.email, isNull);
        expect(profile.phone, isNull);
        expect(profile.status, 'active');
        expect(profile.accountTier, 'free');
        expect(profile.kycStatus, 'unverified');
        expect(profile.role, 'user');
        expect(profile.address, '');
        expect(profile.whatsapp, '');
        expect(profile.telegram, '');
      });

      test('reads referred_by_id column correctly', () {
        final json = {
          'id': 'user-ref',
          'referred_by_id': 'referrer-abc',
          'role': 'user',
        };

        final profile = ProfileModel.fromJson(json);
        expect(profile.referredBy, 'referrer-abc');
      });
    });

    group('toJson', () {
      test('serializes correctly with referred_by_id key', () {
        final profile = ProfileModel(
          id: 'user-123',
          fullName: 'Test',
          email: 'test@test.com',
          role: 'user',
          referredBy: 'ref-456',
        );

        final json = profile.toJson();

        expect(json['id'], 'user-123');
        expect(json['full_name'], 'Test');
        expect(json['email'], 'test@test.com');
        expect(json['referred_by_id'], 'ref-456');
        expect(json.containsKey('referred_by'), isFalse);
      });

      test('serializes null email correctly', () {
        final profile = ProfileModel(
          id: 'user-phone',
          fullName: 'Phone User',
          role: 'user',
        );

        final json = profile.toJson();
        expect(json['email'], isNull);
      });
    });

    group('copyWith', () {
      test('creates copy with updated fields', () {
        final original = ProfileModel(
          id: 'user-1',
          fullName: 'Original',
          email: 'original@test.com',
          role: 'user',
          kycStatus: 'unverified',
        );

        final updated = original.copyWith(
          fullName: 'Updated',
          kycStatus: 'verified',
        );

        expect(updated.fullName, 'Updated');
        expect(updated.kycStatus, 'verified');
        expect(updated.id, 'user-1');
        expect(updated.email, 'original@test.com');
        expect(updated.role, 'user');
      });
    });

    group('roundtrip', () {
      test('fromJson -> toJson preserves data', () {
        final json = {
          'id': 'roundtrip-user',
          'full_name': 'Roundtrip Test',
          'email': 'rt@test.com',
          'phone': '+967999888777',
          'status': 'active',
          'account_tier': 'vip',
          'kyc_status': 'verified',
          'role': 'agent',
          'referral_code': 'XYZ',
          'referred_by_id': 'ref-parent',
          'address': '456 Side St',
          'whatsapp': '+967999888777',
          'telegram': '@rt_user',
        };

        final profile = ProfileModel.fromJson(json);
        final output = profile.toJson();

        expect(output['id'], json['id']);
        expect(output['full_name'], json['full_name']);
        expect(output['email'], json['email']);
        expect(output['referred_by_id'], json['referred_by_id']);
        expect(output['role'], json['role']);
      });
    });
  });
}
