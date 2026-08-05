import 'package:flutter_test/flutter_test.dart';
import 'package:kasby/core/models/transaction_model.dart';

void main() {
  group('TransactionModel', () {
    group('fromJson', () {
      test('parses deposit transaction correctly', () {
        final json = {
          'id': 'txn-001',
          'user_id': 'user-1',
          'wallet_id': 'wallet-1',
          'type': 'deposit',
          'amount': 500.00,
          'fee': 0.0,
          'net_amount': 500.00,
          'currency': 'USD',
          'status': 'pending',
          'description': 'Deposit via agent',
          'created_at': '2026-06-09T12:00:00Z',
        };

        final txn = TransactionModel.fromJson(json);

        expect(txn.id, 'txn-001');
        expect(txn.type, 'deposit');
        expect(txn.amount, 500.00);
        expect(txn.fee, 0.0);
        expect(txn.status, 'pending');
        expect(txn.isCredit, true);
        expect(txn.isDebit, false);
      });

      test('parses withdrawal transaction correctly', () {
        final json = {
          'id': 'txn-002',
          'user_id': 'user-1',
          'wallet_id': 'wallet-1',
          'type': 'withdrawal',
          'amount': 200.00,
          'fee': 5.00,
          'net_amount': 195.00,
          'currency': 'USD',
          'status': 'completed',
          'processed_by': 'admin-1',
          'processed_at': '2026-06-09T13:00:00Z',
        };

        final txn = TransactionModel.fromJson(json);

        expect(txn.type, 'withdrawal');
        expect(txn.fee, 5.00);
        expect(txn.isDebit, true);
        expect(txn.isCredit, false);
        expect(txn.processedBy, 'admin-1');
        expect(txn.processedAt, isNotNull);
      });

      test('handles missing optional fields', () {
        final json = {
          'id': 'txn-minimal',
          'user_id': 'u1',
          'wallet_id': 'w1',
          'type': 'deposit',
          'amount': 100,
        };

        final txn = TransactionModel.fromJson(json);

        expect(txn.fee, 0.0);
        expect(txn.currency, 'USD');
        expect(txn.status, 'pending');
        expect(txn.processedBy, isNull);
        expect(txn.rejectionReason, isNull);
        expect(txn.idempotencyKey, isNull);
      });
    });

    group('isCredit / isDebit', () {
      test('deposit is credit', () {
        final txn = TransactionModel(
          id: 't1',
          userId: 'u1',
          walletId: 'w1',
          type: 'deposit',
          amount: 100,
        );
        expect(txn.isCredit, true);
      });

      test('withdrawal is debit', () {
        final txn = TransactionModel(
          id: 't2',
          userId: 'u1',
          walletId: 'w1',
          type: 'withdrawal',
          amount: 100,
        );
        expect(txn.isDebit, true);
      });

      test('transfer_in is credit', () {
        final txn = TransactionModel(
          id: 't3',
          userId: 'u1',
          walletId: 'w1',
          type: 'transfer_in',
          amount: 50,
        );
        expect(txn.isCredit, true);
      });

      test('transfer_out is debit', () {
        final txn = TransactionModel(
          id: 't4',
          userId: 'u1',
          walletId: 'w1',
          type: 'transfer_out',
          amount: 50,
        );
        expect(txn.isDebit, true);
      });

      test('profit is credit', () {
        final txn = TransactionModel(
          id: 't5',
          userId: 'u1',
          walletId: 'w1',
          type: 'profit',
          amount: 10,
        );
        expect(txn.isCredit, true);
      });

      test('investment is debit', () {
        final txn = TransactionModel(
          id: 't6',
          userId: 'u1',
          walletId: 'w1',
          type: 'investment',
          amount: 1000,
        );
        expect(txn.isDebit, true);
      });

      test('investment_return is credit', () {
        final txn = TransactionModel(
          id: 't7',
          userId: 'u1',
          walletId: 'w1',
          type: 'investment_return',
          amount: 1000,
        );
        expect(txn.isCredit, true);
      });

      test('loan_disbursement is credit', () {
        final txn = TransactionModel(
          id: 't8',
          userId: 'u1',
          walletId: 'w1',
          type: 'loan_disbursement',
          amount: 500,
        );
        expect(txn.isCredit, true);
      });

      test('loan_repayment is debit', () {
        final txn = TransactionModel(
          id: 't9',
          userId: 'u1',
          walletId: 'w1',
          type: 'loan_repayment',
          amount: 100,
        );
        expect(txn.isDebit, true);
      });

      test('reward is credit', () {
        final txn = TransactionModel(
          id: 't10',
          userId: 'u1',
          walletId: 'w1',
          type: 'reward',
          amount: 5,
        );
        expect(txn.isCredit, true);
      });
    });

    group('toJson', () {
      test('excludes id and computed fields from output', () {
        final txn = TransactionModel(
          id: 'txn-out',
          userId: 'u1',
          walletId: 'w1',
          type: 'deposit',
          amount: 100,
          status: 'pending',
        );

        final json = txn.toJson();

        expect(json.containsKey('id'), isFalse);
        expect(json['user_id'], 'u1');
        expect(json['type'], 'deposit');
        expect(json['amount'], 100);
      });
    });

    group('copyWith', () {
      test('updates status while preserving other fields', () {
        final original = TransactionModel(
          id: 'txn-orig',
          userId: 'u1',
          walletId: 'w1',
          type: 'withdrawal',
          amount: 200,
          status: 'pending',
        );

        final completed = original.copyWith(
          status: 'completed',
          processedBy: 'admin-1',
          processedAt: DateTime(2026, 6, 9),
        );

        expect(completed.status, 'completed');
        expect(completed.processedBy, 'admin-1');
        expect(completed.type, 'withdrawal');
        expect(completed.amount, 200);
        expect(completed.id, 'txn-orig');
      });
    });
  });
}
