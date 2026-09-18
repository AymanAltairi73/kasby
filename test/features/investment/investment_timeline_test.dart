import 'package:flutter_test/flutter_test.dart';
import 'package:kasby/core/models/investment_plan_model.dart';
import 'package:kasby/core/models/user_investment_model.dart';

void main() {
  group('Investment Timeline & Calendar Month Arithmetic', () {
    test('Test A — 30 Month Investment: 17 Sep 2026 + 30 months -> 17 Mar 2029', () {
      final start = DateTime(2026, 9, 17, 10, 0, 0);
      final end = InvestmentTimelineState.addCalendarMonths(start, 30);

      expect(end.year, 2029);
      expect(end.month, 3);
      expect(end.day, 17);
      expect(end.hour, 10);
      expect(end.minute, 0);

      // Verify months between
      final months = InvestmentTimelineState.calculateMonthsBetween(start, end);
      expect(months, 30);
    });

    test('Boundary Cases — Month-end dates & Leap Years', () {
      // 31 January 2026 + 1 month -> 28 February 2026 (non-leap year)
      final jan31 = DateTime(2026, 1, 31);
      final feb28 = InvestmentTimelineState.addCalendarMonths(jan31, 1);
      expect(feb28.year, 2026);
      expect(feb28.month, 2);
      expect(feb28.day, 28);

      // 29 February 2024 + 1 month -> 29 March 2024 (leap year)
      final feb29Leap = DateTime(2024, 2, 29);
      final mar29 = InvestmentTimelineState.addCalendarMonths(feb29Leap, 1);
      expect(mar29.year, 2024);
      expect(mar29.month, 3);
      expect(mar29.day, 29);

      // 30 November 2025 + 3 months -> 28 February 2026
      final nov30 = DateTime(2025, 11, 30);
      final feb28After3Mo = InvestmentTimelineState.addCalendarMonths(nov30, 3);
      expect(feb28After3Mo.year, 2026);
      expect(feb28After3Mo.month, 2);
      expect(feb28After3Mo.day, 28);
    });

    test('Test B — Progress at Start (17 September 2026)', () {
      final start = DateTime(2026, 9, 17, 12, 0, 0);
      final end = InvestmentTimelineState.addCalendarMonths(start, 30);

      final completed = InvestmentTimelineState.calculateCompletedMonths(start, start, 30);
      expect(completed, 0, reason: 'Completed months at start must be 0');

      final current = InvestmentTimelineState.calculateCurrentMonth(completed, 30);
      expect(current, 1, reason: 'Current month at start must be 1');

      final progress = InvestmentTimelineState.calculateProgress(start, end, start);
      expect(progress, 0.0, reason: 'Progress at start must be 0.0');

      // 3 days later (20 September 2026)
      final day3 = DateTime(2026, 9, 20, 12, 0, 0);
      final completedDay3 = InvestmentTimelineState.calculateCompletedMonths(start, day3, 30);
      expect(completedDay3, 0, reason: 'Partial elapsed time must remain 0 completed months');

      final currentDay3 = InvestmentTimelineState.calculateCurrentMonth(completedDay3, 30);
      expect(currentDay3, 1, reason: 'Current month must remain 1');

      final progressDay3 = InvestmentTimelineState.calculateProgress(start, end, day3);
      expect(progressDay3 > 0.0 && progressDay3 < 0.01, true);
    });

    test('Test C — Progress at 1 Month (17 October 2026)', () {
      final start = DateTime(2026, 9, 17, 12, 0, 0);
      final end = InvestmentTimelineState.addCalendarMonths(start, 30);
      final oneMonth = DateTime(2026, 10, 17, 12, 0, 0);

      final completed = InvestmentTimelineState.calculateCompletedMonths(start, oneMonth, 30);
      expect(completed, 1, reason: 'Exactly 1 full month has elapsed');

      final current = InvestmentTimelineState.calculateCurrentMonth(completed, 30);
      expect(current, 2, reason: 'Current month is now Month 2 of 30');

      final progress = InvestmentTimelineState.calculateProgress(start, end, oneMonth);
      // ~30 days out of 912 days is approx 0.03289 (near 1/30)
      expect((progress - (1.0 / 30.0)).abs() < 0.01, true);
    });

    test('Test D — Financial Validation (\$7,500 at 10%)', () {
      const amount = 7500.0;
      const profitPercentage = 10.0;

      const userInv = UserInvestmentModel(
        id: 'test-inv',
        userId: 'test-user',
        planId: 'test-plan',
        amount: amount,
        profitPercentage: profitPercentage,
        investment: InvestmentPlanModel(
          id: 'test-plan',
          nameAr: 'خطة استثمار',
          profitPercentage: profitPercentage,
          durationDays: 30,
          minAmount: 1000,
        ),
      );

      expect(userInv.monthlyProfit, 750.0);
      expect(userInv.dailyProfit, 25.0);
    });

    test('Test F — Duration Display & Subtext in Arabic and English', () {
      // 30 Months
      expect(InvestmentTimelineState.formatDurationMonths(30, isAr: true), '30 شهرًا');
      expect(InvestmentTimelineState.formatDurationSubtext(30, isAr: true), '(سنتين ونصف)');
      expect(InvestmentTimelineState.formatDurationMonths(30, isAr: false), '30 months');
      expect(InvestmentTimelineState.formatDurationSubtext(30, isAr: false), '(2.5 years)');

      // 12 Months
      expect(InvestmentTimelineState.formatDurationMonths(12, isAr: true), '12 شهرًا');
      expect(InvestmentTimelineState.formatDurationSubtext(12, isAr: true), '(سنة واحدة)');
      expect(InvestmentTimelineState.formatDurationMonths(12, isAr: false), '12 months');
      expect(InvestmentTimelineState.formatDurationSubtext(12, isAr: false), '(1 year)');

      // 24 Months
      expect(InvestmentTimelineState.formatDurationMonths(24, isAr: true), '24 شهرًا');
      expect(InvestmentTimelineState.formatDurationSubtext(24, isAr: true), '(سنتين)');
      expect(InvestmentTimelineState.formatDurationMonths(24, isAr: false), '24 months');
      expect(InvestmentTimelineState.formatDurationSubtext(24, isAr: false), '(2 years)');

      // 36 Months
      expect(InvestmentTimelineState.formatDurationMonths(36, isAr: true), '36 شهرًا');
      expect(InvestmentTimelineState.formatDurationSubtext(36, isAr: true), '(3 سنوات)');
      expect(InvestmentTimelineState.formatDurationMonths(36, isAr: false), '36 months');
      expect(InvestmentTimelineState.formatDurationSubtext(36, isAr: false), '(3 years)');
    });

    test('Authoritative Backend end_date Priority', () {
      final backendEnd = DateTime(2029, 2, 12, 19, 37, 13);
      final backendStart = DateTime(2026, 8, 12, 19, 37, 13);

      final inv = UserInvestmentModel(
        id: 'real-inv-1',
        userId: 'user-1',
        planId: 'plan-1',
        amount: 5000.0,
        profitPercentage: 10.0,
        startDate: backendStart,
        endDate: backendEnd, // Authoritative backend end_date
        investment: const InvestmentPlanModel(
          id: 'plan-1',
          nameAr: 'مركز استثمار العقارات',
          profitPercentage: 10.0,
          durationDays: 30,
          minAmount: 5000,
        ),
      );

      final state = inv.timelineState(asOf: backendStart, isAr: true);
      expect(state.isEndDateAuthoritative, true);
      expect(state.endDate, backendEnd, reason: 'Must NOT overwrite backend end_date');
      expect(state.durationMonths, 30);
      expect(state.durationDisplay, '30 شهرًا');
      expect(state.durationSubtext, '(سنتين ونصف)');
    });

    test('formatRemainingMonthsText formatting', () {
      expect(
        InvestmentTimelineState.formatRemainingMonthsText(29, totalMonths: 30, isAr: true),
        'متبقي 29 شهرا من 30 شهرا',
      );
      expect(
        InvestmentTimelineState.formatRemainingMonthsText(29, isAr: true),
        'متبقي 29 شهرا من 30 شهرا',
      );
      expect(
        InvestmentTimelineState.formatRemainingMonthsText(29, totalMonths: 30, isAr: false),
        '29 of 30 months remaining',
      );
    });

    test('Resolution of same-year 30-day cycle date to full 2.5-year contract', () {
      final start = DateTime(2026, 9, 18, 0, 32, 6);
      final cycleEnd = DateTime(2026, 10, 18, 0, 32, 6); // Erroneous 1-month date in same year

      final inv = UserInvestmentModel(
        id: 'cycle-row-1',
        userId: 'user-1',
        planId: 'plan-1',
        amount: 5000.0,
        profitPercentage: 10.0,
        startDate: start,
        endDate: cycleEnd,
        investment: const InvestmentPlanModel(
          id: 'plan-1',
          nameAr: 'مركز استثمار العقارات',
          profitPercentage: 10.0,
          durationDays: 30, // 30 represents 30 months (2.5 years)
          minAmount: 5000,
        ),
      );

      final state = inv.timelineState(asOf: start, isAr: true);
      expect(state.startDate.year, 2026);
      expect(state.endDate.year, 2029, reason: 'Start and end date must NOT be in the same year');
      expect(state.durationMonths, 30);
      expect(state.durationDisplay, '30 شهرًا');
      expect(state.durationSubtext, '(سنتين ونصف)');
      expect(state.remainingMonthsText, 'متبقي 30 شهرا من 30 شهرا');
    });

    test('Cycle completed state handling', () {
      final inv = UserInvestmentModel(
        id: 'matured-inv',
        userId: 'user-1',
        planId: 'plan-1',
        amount: 5000.0,
        profitPercentage: 10.0,
        status: 'completed',
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2028, 7, 1),
      );

      final state = inv.timelineState();
      expect(state.isCompleted, true);
      expect(state.progress, 1.0);
      expect(state.progressPercent, 100);
      expect(state.elapsedMonths, state.durationMonths);
      expect(state.currentMonth, state.durationMonths);
      expect(state.remainingMonths, 0);
    });
  });
}
