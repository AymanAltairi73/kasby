import 'package:flutter_test/flutter_test.dart';
import 'package:kasby/core/models/user_investment_model.dart';

void main() {
  group('UserInvestmentModel', () {
    group('fromJson', () {
      test('parses active investment correctly', () {
        final json = {
          'id': 'inv-001',
          'user_id': 'user-1',
          'plan_id': 'plan-gold',
          'amount': 1000.0,
          'profit_percentage': 15.0,
          'expected_profit': 150.0,
          'status': 'active',
          'start_date': '2026-06-01T00:00:00Z',
          'end_date': '2026-09-01T00:00:00Z',
          'created_at': '2026-06-01T00:00:00Z',
        };

        final inv = UserInvestmentModel.fromJson(json);

        expect(inv.id, 'inv-001');
        expect(inv.amount, 1000.0);
        expect(inv.profitPercentage, 15.0);
        expect(inv.expectedProfit, 150.0);
        expect(inv.status, 'active');
        expect(inv.startDate, isNotNull);
        expect(inv.endDate, isNotNull);
      });

      test('handles nested investment plan', () {
        final json = {
          'id': 'inv-002',
          'user_id': 'user-1',
          'plan_id': 'plan-gold',
          'amount': 500.0,
          'profit_percentage': 10.0,
          'investment': {
            'id': 'plan-gold',
            'name_ar': 'خطة الذهب',
            'profit_percentage': 10.0,
            'min_amount': 100.0,
          },
        };

        final inv = UserInvestmentModel.fromJson(json);

        expect(inv.investment, isNotNull);
        expect(inv.investment!.nameAr, 'خطة الذهب');
      });

      test('handles missing optional fields', () {
        final json = {
          'id': 'inv-min',
          'user_id': 'u1',
          'plan_id': 'p1',
          'amount': 100,
          'profit_percentage': 5,
        };

        final inv = UserInvestmentModel.fromJson(json);

        expect(inv.expectedProfit, 0.0);
        expect(inv.actualProfit, isNull);
        expect(inv.status, 'active');
        expect(inv.transactionId, isNull);
        expect(inv.approvedBy, isNull);
        expect(inv.investment, isNull);
      });
    });

    group('remainingDays', () {
      test('returns null when no end date', () {
        final inv = UserInvestmentModel(
          id: 'i1',
          userId: 'u1',
          planId: 'p1',
          amount: 100,
          profitPercentage: 10,
        );

        expect(inv.remainingDays, isNull);
      });

      test('returns 0 for past end date', () {
        final inv = UserInvestmentModel(
          id: 'i2',
          userId: 'u1',
          planId: 'p1',
          amount: 100,
          profitPercentage: 10,
          endDate: DateTime.now().subtract(const Duration(days: 10)),
        );

        expect(inv.remainingDays, 0);
      });

      test('returns positive days for future end date', () {
        final inv = UserInvestmentModel(
          id: 'i3',
          userId: 'u1',
          planId: 'p1',
          amount: 100,
          profitPercentage: 10,
          endDate: DateTime.now().add(const Duration(days: 30)),
        );

        expect(inv.remainingDays, greaterThanOrEqualTo(29));
        expect(inv.remainingDays, lessThanOrEqualTo(30));
      });
    });

    group('toJson', () {
      test('serializes investment data correctly', () {
        final inv = UserInvestmentModel(
          id: 'i1',
          userId: 'u1',
          planId: 'p1',
          amount: 500,
          profitPercentage: 10,
          expectedProfit: 50,
          status: 'active',
        );

        final json = inv.toJson();

        expect(json['user_id'], 'u1');
        expect(json['plan_id'], 'p1');
        expect(json['amount'], 500);
        expect(json['status'], 'active');
        expect(json.containsKey('id'), isFalse);
      });
    });

    group('copyWith', () {
      test('completes investment', () {
        final active = UserInvestmentModel(
          id: 'i1',
          userId: 'u1',
          planId: 'p1',
          amount: 1000,
          profitPercentage: 10,
          status: 'active',
        );

        final completed = active.copyWith(
          status: 'completed',
          actualProfit: 100.0,
          maturedAt: DateTime(2026, 9, 1),
        );

        expect(completed.status, 'completed');
        expect(completed.actualProfit, 100.0);
        expect(completed.amount, 1000);
      });
    });
  });
}
