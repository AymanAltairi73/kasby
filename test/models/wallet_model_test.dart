import 'package:flutter_test/flutter_test.dart';
import 'package:kasby/core/models/wallet_model.dart';

void main() {
  group('WalletModel', () {
    group('fromJson', () {
      test('parses complete JSON correctly', () {
        final json = {
          'id': 'wallet-123',
          'user_id': 'user-456',
          'available_balance': 1000.50,
          'profit_balance': 250.75,
          'invested_balance': 5000.00,
          'pending_balance': 100.00,
          'currency': 'USD',
          'is_frozen': false,
          'created_at': '2026-01-01T00:00:00Z',
          'updated_at': '2026-06-09T12:00:00Z',
        };

        final wallet = WalletModel.fromJson(json);

        expect(wallet.id, 'wallet-123');
        expect(wallet.userId, 'user-456');
        expect(wallet.availableBalance, 1000.50);
        expect(wallet.profitBalance, 250.75);
        expect(wallet.investedBalance, 5000.00);
        expect(wallet.pendingBalance, 100.00);
        expect(wallet.currency, 'USD');
        expect(wallet.isFrozen, false);
      });

      test('handles null balance values with zero defaults', () {
        final json = {'id': 'wallet-empty', 'user_id': 'user-new'};

        final wallet = WalletModel.fromJson(json);

        expect(wallet.availableBalance, 0.0);
        expect(wallet.profitBalance, 0.0);
        expect(wallet.investedBalance, 0.0);
        expect(wallet.pendingBalance, 0.0);
        expect(wallet.isFrozen, false);
      });

      test('handles frozen wallet', () {
        final json = {
          'id': 'wallet-frozen',
          'user_id': 'user-bad',
          'is_frozen': true,
          'frozen_reason': 'Suspicious activity',
          'frozen_at': '2026-06-01T00:00:00Z',
          'frozen_by': 'admin-1',
        };

        final wallet = WalletModel.fromJson(json);

        expect(wallet.isFrozen, true);
        expect(wallet.frozenReason, 'Suspicious activity');
        expect(wallet.frozenAt, isNotNull);
        expect(wallet.frozenBy, 'admin-1');
      });

      test('handles integer balance values (num casting)', () {
        final json = {
          'id': 'wallet-int',
          'user_id': 'user-int',
          'available_balance': 1000,
          'profit_balance': 0,
          'invested_balance': 5000,
        };

        final wallet = WalletModel.fromJson(json);

        expect(wallet.availableBalance, 1000.0);
        expect(wallet.profitBalance, 0.0);
        expect(wallet.investedBalance, 5000.0);
      });
    });

    group('totalBalance', () {
      test('calculates total across all balance types', () {
        final wallet = WalletModel(
          id: 'w1',
          userId: 'u1',
          availableBalance: 100.0,
          profitBalance: 50.0,
          investedBalance: 200.0,
          pendingBalance: 25.0,
        );

        expect(wallet.totalBalance, 375.0);
      });

      test('returns zero for empty wallet', () {
        final wallet = WalletModel(id: 'w2', userId: 'u2');
        expect(wallet.totalBalance, 0.0);
      });
    });

    group('toJson', () {
      test('serializes frozen wallet correctly', () {
        final wallet = WalletModel(
          id: 'w-frozen',
          userId: 'u-frozen',
          isFrozen: true,
          frozenReason: 'Test freeze',
          availableBalance: 500.0,
        );

        final json = wallet.toJson();

        expect(json['is_frozen'], true);
        expect(json['frozen_reason'], 'Test freeze');
        expect(json['available_balance'], 500.0);
      });
    });

    group('copyWith', () {
      test('updates balance while preserving other fields', () {
        final original = WalletModel(
          id: 'w1',
          userId: 'u1',
          availableBalance: 100.0,
          currency: 'USD',
        );

        final updated = original.copyWith(availableBalance: 200.0);

        expect(updated.availableBalance, 200.0);
        expect(updated.id, 'w1');
        expect(updated.userId, 'u1');
        expect(updated.currency, 'USD');
      });

      test('can freeze wallet via copyWith', () {
        final wallet = WalletModel(id: 'w1', userId: 'u1');
        final frozen = wallet.copyWith(isFrozen: true, frozenReason: 'Fraud');

        expect(frozen.isFrozen, true);
        expect(frozen.frozenReason, 'Fraud');
      });
    });
  });
}
