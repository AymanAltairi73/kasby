import 'package:flutter_test/flutter_test.dart';
import 'package:kasby/core/models/investment_plan_model.dart';
import 'package:kasby/core/models/user_investment_model.dart';
import 'package:kasby/core/localization/kasby_translations.dart';

void main() {
  group('UserInvestmentModel Cycle Progress Calculations', () {
    const plan30Days = InvestmentPlanModel(
      id: 'plan_30',
      nameAr: 'خطة 30 يوم',
      profitPercentage: 10.0,
      durationDays: 30,
      minAmount: 100,
    );

    const plan90Days = InvestmentPlanModel(
      id: 'plan_90',
      nameAr: 'خطة 90 يوم',
      profitPercentage: 25.0,
      durationDays: 90,
      minAmount: 500,
    );

    test('1. Day 0 (Investment just started today)', () {
      final start = DateTime(2026, 9, 1);
      final end = DateTime(2026, 10, 1); // 30 days
      final inv = UserInvestmentModel(
        id: 'inv_1',
        userId: 'u1',
        planId: 'plan_30',
        amount: 1000,
        profitPercentage: 10,
        startDate: start,
        endDate: end,
        investment: plan30Days,
      );

      final asOf = DateTime(2026, 9, 1, 10, 0);
      expect(inv.totalDurationDays, 30);
      expect(inv.getElapsedDays(asOf), 0);
      expect(inv.getCycleRemainingDays(asOf), 30);
      expect(inv.getCycleProgress(asOf), 0.0);
    });

    test('2. Day 1 (1 day elapsed)', () {
      final start = DateTime(2026, 9, 1);
      final end = DateTime(2026, 10, 1);
      final inv = UserInvestmentModel(
        id: 'inv_2',
        userId: 'u1',
        planId: 'plan_30',
        amount: 1000,
        profitPercentage: 10,
        startDate: start,
        endDate: end,
        investment: plan30Days,
      );

      final asOf = DateTime(2026, 9, 2);
      expect(inv.getElapsedDays(asOf), 1);
      expect(inv.getCycleRemainingDays(asOf), 29);
      expect(inv.getCycleProgress(asOf), closeTo(1 / 30, 0.001));
    });

    test('3. Middle of cycle (Day 12 of 30 -> 40% progress, 18 days left)', () {
      final start = DateTime(2026, 9, 1);
      final end = DateTime(2026, 10, 1);
      final inv = UserInvestmentModel(
        id: 'inv_3',
        userId: 'u1',
        planId: 'plan_30',
        amount: 1000,
        profitPercentage: 10,
        startDate: start,
        endDate: end,
        investment: plan30Days,
      );

      final asOf = DateTime(2026, 9, 13);
      expect(inv.totalDurationDays, 30);
      expect(inv.getElapsedDays(asOf), 12);
      expect(inv.getCycleRemainingDays(asOf), 18);
      expect(inv.getCycleProgress(asOf), 0.40);
    });

    test('4. Last day of cycle (Day 30 of 30)', () {
      final start = DateTime(2026, 9, 1);
      final end = DateTime(2026, 10, 1);
      final inv = UserInvestmentModel(
        id: 'inv_4',
        userId: 'u1',
        planId: 'plan_30',
        amount: 1000,
        profitPercentage: 10,
        startDate: start,
        endDate: end,
        investment: plan30Days,
      );

      final asOf = DateTime(2026, 10, 1);
      expect(inv.getElapsedDays(asOf), 30);
      expect(inv.getCycleRemainingDays(asOf), 0);
      expect(inv.getCycleProgress(asOf), 1.0);
    });

    test('5. Completed cycle (Beyond end date)', () {
      final start = DateTime(2026, 9, 1);
      final end = DateTime(2026, 10, 1);
      final inv = UserInvestmentModel(
        id: 'inv_5',
        userId: 'u1',
        planId: 'plan_30',
        amount: 1000,
        profitPercentage: 10,
        startDate: start,
        endDate: end,
        investment: plan30Days,
      );

      final asOf = DateTime(2026, 10, 15);
      expect(inv.getElapsedDays(asOf), 30);
      expect(inv.getCycleRemainingDays(asOf), 0);
      expect(inv.getCycleProgress(asOf), 1.0);
    });

    test('6. Future start date (Not started yet)', () {
      final start = DateTime(2026, 9, 20);
      final end = DateTime(2026, 10, 20);
      final inv = UserInvestmentModel(
        id: 'inv_6',
        userId: 'u1',
        planId: 'plan_30',
        amount: 1000,
        profitPercentage: 10,
        startDate: start,
        endDate: end,
        investment: plan30Days,
      );

      final asOf = DateTime(2026, 9, 15);
      expect(inv.getElapsedDays(asOf), 0);
      expect(inv.getCycleRemainingDays(asOf), 30);
      expect(inv.getCycleProgress(asOf), 0.0);
    });

    test('7. Missing end date: calculates from start + durationDays', () {
      final start = DateTime(2026, 9, 1);
      final inv = UserInvestmentModel(
        id: 'inv_7',
        userId: 'u1',
        planId: 'plan_90',
        amount: 1000,
        profitPercentage: 25,
        startDate: start,
        endDate: null,
        investment: plan90Days,
      );

      expect(inv.totalDurationDays, 90);
      expect(inv.effectiveEndDate, DateTime(2026, 9, 1).add(const Duration(days: 90)));

      final asOf = DateTime(2026, 9, 1).add(const Duration(days: 45));
      expect(inv.getElapsedDays(asOf), 45);
      expect(inv.getCycleRemainingDays(asOf), 45);
      expect(inv.getCycleProgress(asOf), 0.5);
    });

    test('8. Completely missing dates: graceful fallback without crash', () {
      const inv = UserInvestmentModel(
        id: 'inv_8',
        userId: 'u1',
        planId: 'plan_unknown',
        amount: 1000,
        profitPercentage: 10,
        startDate: null,
        endDate: null,
        createdAt: null,
        investment: null,
      );

      expect(inv.totalDurationDays, 30);
      expect(inv.elapsedDays, 0);
      expect(inv.cycleRemainingDays, 30);
      expect(inv.cycleProgress, 0.0);
    });
  });

  group('Localization Keys Verification', () {
    final translations = KasbyTranslations();
    final enKeys = translations.keys['en_US']!;
    final arKeys = translations.keys['ar_SA']!;

    test('Cycle progress keys exist in both English and Arabic', () {
      const requiredKeys = [
        'cycle_progress',
        'days_completed',
        'days_remaining',
        'days_left',
        'day_x_of_y',
        'started',
        'ends',
        'cycle_not_started',
        'cycle_completed',
      ];

      for (final key in requiredKeys) {
        expect(enKeys.containsKey(key), isTrue, reason: 'en_US missing key: $key');
        expect(arKeys.containsKey(key), isTrue, reason: 'ar_SA missing key: $key');
        expect(enKeys[key]!.isNotEmpty, isTrue);
        expect(arKeys[key]!.isNotEmpty, isTrue);
      }
    });
  });
}
