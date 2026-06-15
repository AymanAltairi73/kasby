import 'package:flutter_test/flutter_test.dart';
import 'package:kasby/core/models/loan_model.dart';

void main() {
  group('LoanModel', () {
    group('fromJson', () {
      test('parses complete loan JSON correctly', () {
        final json = {
          'id': 'loan-001',
          'user_id': 'user-1',
          'amount': 1000.00,
          'interest_rate': 5.0,
          'total_due': 1050.00,
          'remaining_amount': 1050.00,
          'paid_amount': 0.0,
          'status': 'pending',
          'repayment_date': '2026-09-09T00:00:00Z',
          'created_at': '2026-06-09T00:00:00Z',
        };

        final loan = LoanModel.fromJson(json);

        expect(loan.id, 'loan-001');
        expect(loan.amount, 1000.00);
        expect(loan.interestRate, 5.0);
        expect(loan.totalDue, 1050.00);
        expect(loan.remainingAmount, 1050.00);
        expect(loan.paidAmount, 0.0);
        expect(loan.status, 'pending');
      });

      test('handles missing optional fields', () {
        final json = {
          'id': 'loan-minimal',
          'user_id': 'u1',
          'amount': 500,
          'repayment_date': '2026-12-31T00:00:00Z',
        };

        final loan = LoanModel.fromJson(json);

        expect(loan.interestRate, 0.0);
        expect(loan.paidAmount, 0.0);
        expect(loan.status, 'pending');
        expect(loan.approvedBy, isNull);
        expect(loan.rejectionReason, isNull);
      });

      test('falls back to total_due or amount for remaining_amount', () {
        final json = {
          'id': 'loan-fb',
          'user_id': 'u1',
          'amount': 1000,
          'total_due': 1050,
          'remaining_amount': null,
          'repayment_date': '2026-12-31T00:00:00Z',
        };

        final loan = LoanModel.fromJson(json);
        expect(loan.remainingAmount, 1050.0);
      });
    });

    group('calculatedRemaining', () {
      test('calculates remaining correctly with partial payment', () {
        final loan = LoanModel(
          id: 'l1',
          userId: 'u1',
          amount: 1000,
          totalDue: 1050,
          paidAmount: 300,
          repaymentDate: DateTime(2026, 12, 31),
        );

        expect(loan.calculatedRemaining, 750.0);
      });

      test('returns zero when fully paid', () {
        final loan = LoanModel(
          id: 'l2',
          userId: 'u1',
          amount: 1000,
          totalDue: 1050,
          paidAmount: 1050,
          repaymentDate: DateTime(2026, 12, 31),
        );

        expect(loan.calculatedRemaining, 0.0);
      });

      test('uses amount when totalDue is null', () {
        final loan = LoanModel(
          id: 'l3',
          userId: 'u1',
          amount: 500,
          paidAmount: 200,
          repaymentDate: DateTime(2026, 12, 31),
        );

        expect(loan.calculatedRemaining, 300.0);
      });
    });

    group('paymentProgress', () {
      test('returns 0 for unpaid loan', () {
        final loan = LoanModel(
          id: 'l1',
          userId: 'u1',
          amount: 1000,
          totalDue: 1050,
          paidAmount: 0,
          repaymentDate: DateTime(2026, 12, 31),
        );

        expect(loan.paymentProgress, 0.0);
      });

      test('returns fraction for partial payment', () {
        final loan = LoanModel(
          id: 'l2',
          userId: 'u1',
          amount: 1000,
          totalDue: 1000,
          paidAmount: 500,
          repaymentDate: DateTime(2026, 12, 31),
        );

        expect(loan.paymentProgress, 0.5);
      });

      test('returns 1.0 for fully paid loan', () {
        final loan = LoanModel(
          id: 'l3',
          userId: 'u1',
          amount: 1000,
          totalDue: 1000,
          paidAmount: 1000,
          repaymentDate: DateTime(2026, 12, 31),
        );

        expect(loan.paymentProgress, 1.0);
      });

      test('clamps to 1.0 for overpaid loan', () {
        final loan = LoanModel(
          id: 'l4',
          userId: 'u1',
          amount: 1000,
          totalDue: 1000,
          paidAmount: 1500,
          repaymentDate: DateTime(2026, 12, 31),
        );

        expect(loan.paymentProgress, 1.0);
      });

      test('returns 0.0 when totalDue is zero', () {
        final loan = LoanModel(
          id: 'l5',
          userId: 'u1',
          amount: 0,
          totalDue: 0,
          paidAmount: 0,
          repaymentDate: DateTime(2026, 12, 31),
        );

        expect(loan.paymentProgress, 0.0);
      });
    });

    group('copyWith', () {
      test('updates status for loan approval', () {
        final pending = LoanModel(
          id: 'l1',
          userId: 'u1',
          amount: 1000,
          status: 'pending',
          repaymentDate: DateTime(2026, 12, 31),
        );

        final approved = pending.copyWith(
          status: 'approved',
          approvedBy: 'admin-1',
          approvedAt: DateTime(2026, 6, 10),
        );

        expect(approved.status, 'approved');
        expect(approved.approvedBy, 'admin-1');
        expect(approved.amount, 1000);
      });
    });
  });
}
