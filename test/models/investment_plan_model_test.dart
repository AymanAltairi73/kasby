import 'package:flutter_test/flutter_test.dart';
import 'package:kasby/core/models/investment_plan_model.dart';

void main() {
  group('InvestmentPlanModel', () {
    group('fromJson', () {
      test('parses complete plan correctly', () {
        final json = {
          'id': 'plan-001',
          'name_ar': 'خطة الذهب',
          'name_en': 'Gold Plan',
          'description_ar': 'خطة استثمارية ممتازة',
          'description_en': 'Excellent investment plan',
          'profit_percentage': 15.0,
          'duration_days': 90,
          'min_amount': 100.0,
          'max_amount': 10000.0,
          'available_amounts': [100, 500, 1000, 5000],
          'risk_level': 'medium',
          'is_active': true,
          'version': 2,
          'created_at': '2026-01-01T00:00:00Z',
        };

        final plan = InvestmentPlanModel.fromJson(json);

        expect(plan.id, 'plan-001');
        expect(plan.nameAr, 'خطة الذهب');
        expect(plan.nameEn, 'Gold Plan');
        expect(plan.profitPercentage, 15.0);
        expect(plan.durationDays, 90);
        expect(plan.minAmount, 100.0);
        expect(plan.maxAmount, 10000.0);
        expect(plan.availableAmounts, [100, 500, 1000, 5000]);
        expect(plan.riskLevel, 'medium');
        expect(plan.isActive, true);
        expect(plan.version, 2);
      });

      test('handles integer profit/amount values', () {
        final json = {
          'id': 'plan-int',
          'name_ar': 'خطة',
          'profit_percentage': 10,
          'min_amount': 50,
          'max_amount': 5000,
        };

        final plan = InvestmentPlanModel.fromJson(json);

        expect(plan.profitPercentage, 10.0);
        expect(plan.minAmount, 50.0);
        expect(plan.maxAmount, 5000.0);
      });

      test('applies defaults for missing optional fields', () {
        final json = {
          'id': 'plan-min',
          'name_ar': 'خطة بسيطة',
          'profit_percentage': 5,
          'min_amount': 100,
        };

        final plan = InvestmentPlanModel.fromJson(json);

        expect(plan.nameEn, isNull);
        expect(plan.descriptionAr, '');
        expect(plan.durationDays, isNull);
        expect(plan.maxAmount, isNull);
        expect(plan.riskLevel, 'medium');
        expect(plan.isActive, true);
        expect(plan.version, 1);
      });
    });

    group('toJson', () {
      test('serializes plan data correctly', () {
        final plan = InvestmentPlanModel(
          id: 'plan-out',
          nameAr: 'خطة البلاتين',
          profitPercentage: 20.0,
          minAmount: 1000.0,
          riskLevel: 'high',
          isActive: true,
        );

        final json = plan.toJson();

        expect(json['name_ar'], 'خطة البلاتين');
        expect(json['profit_percentage'], 20.0);
        expect(json['min_amount'], 1000.0);
        expect(json['risk_level'], 'high');
        expect(json['is_active'], true);
        expect(json.containsKey('id'), isFalse);
      });
    });

    group('copyWith', () {
      test('deactivates plan while preserving other fields', () {
        final plan = InvestmentPlanModel(
          id: 'plan-1',
          nameAr: 'Active Plan',
          profitPercentage: 10.0,
          minAmount: 100.0,
          isActive: true,
        );

        final deactivated = plan.copyWith(isActive: false);

        expect(deactivated.isActive, false);
        expect(deactivated.nameAr, 'Active Plan');
        expect(deactivated.profitPercentage, 10.0);
      });
    });
  });
}
