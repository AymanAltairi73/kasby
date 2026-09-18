import 'dart:math' as math;
import 'package:kasby/core/models/user_investment_model.dart';

/// Single source of truth for Investment Timeline, Duration, and Progress calculations.
/// Guarantees that all investment widgets (Cards, Details, Lists) display identical,
/// synchronized, real-data-driven timeline metrics.
class InvestmentTimelineState {
  final DateTime startDate;
  final DateTime endDate;
  final bool isEndDateAuthoritative;
  final int durationMonths;
  final int elapsedMonths;
  final int currentMonth;
  final int remainingMonths;
  final double progress;
  final int progressPercent;
  final String durationDisplay;
  final String? durationSubtext;
  final String cyclePositionText;
  final String completedMonthsText;
  final String remainingMonthsText;
  final String startElapsedText;
  final String endRemainingText;
  final bool isCompleted;

  const InvestmentTimelineState({
    required this.startDate,
    required this.endDate,
    required this.isEndDateAuthoritative,
    required this.durationMonths,
    required this.elapsedMonths,
    required this.currentMonth,
    required this.remainingMonths,
    required this.progress,
    required this.progressPercent,
    required this.durationDisplay,
    this.durationSubtext,
    required this.cyclePositionText,
    required this.completedMonthsText,
    required this.remainingMonthsText,
    required this.startElapsedText,
    required this.endRemainingText,
    required this.isCompleted,
  });

  /// Factory constructor to construct state from real [UserInvestmentModel].
  ///
  /// CRITICAL RULE: If [inv.endDate] is provided by the backend, it is authoritative
  /// and MUST NOT be recalculated or overwritten.
  factory InvestmentTimelineState.fromInvestment(
    UserInvestmentModel inv, {
    DateTime? asOf,
    bool isAr = true,
  }) {
    final now = asOf ?? DateTime.now();
    final start = inv.effectiveStartDate ?? now;

    final planDays = inv.investment?.durationDays;
    final int targetContractMonths;
    if (planDays != null && planDays >= 365) {
      targetContractMonths = (planDays / 30).round();
    } else if (planDays != null && planDays > 30) {
      targetContractMonths = (planDays / 30).round();
    } else {
      // Standard Kasby contract duration: 30 months (2.5 years)
      targetContractMonths = 30;
    }

    final bool isEndAuth;
    final DateTime end;
    final int months;

    // A genuine contract maturity date spans the multi-year contract (e.g. > 180 days),
    // and is not merely an erroneous 30-day cycle date in the same year.
    if (inv.endDate != null && inv.endDate!.difference(start).inDays > 180) {
      isEndAuth = true;
      end = inv.endDate!;
      final diffMonths = calculateMonthsBetween(start, end);
      months = diffMonths > 0 ? diffMonths : targetContractMonths;
    } else {
      isEndAuth = false;
      months = targetContractMonths;
      end = addCalendarMonths(start, months);
    }

    // Status check
    final isExplicitlyCompleted =
        inv.status == 'completed' || inv.status == 'matured';
    final isExpiredByDate = !now.isBefore(end);
    final isDone = isExplicitlyCompleted || isExpiredByDate;

    // Completed months (full calendar months that have elapsed)
    final int completed;
    if (isDone) {
      completed = months;
    } else if (now.isBefore(start)) {
      completed = 0;
    } else {
      completed = calculateCompletedMonths(start, now, months);
    }

    final int current = isDone ? months : calculateCurrentMonth(completed, months);
    final int remaining = (months - completed).clamp(0, months);

    // Dynamic Progress
    final double prog;
    if (isDone) {
      prog = 1.0;
    } else if (now.isBefore(start)) {
      prog = 0.0;
    } else {
      prog = calculateProgress(start, end, now);
    }

    final int percent = (prog * 100).floor().clamp(0, 100);

    // Duration Strings
    final durDisplay = formatDurationMonths(months, isAr: isAr);
    final durSubtext = formatDurationSubtext(months, isAr: isAr);

    // Cycle & Progress Strings
    final cyclePos = isAr
        ? 'الشهر $current من $months'
        : 'Month $current of $months';

    final compText = formatCompletedMonthsText(completed, isAr: isAr);
    final remText = formatRemainingMonthsText(
      remaining,
      totalMonths: months,
      isAr: isAr,
    );

    final startElapsed = formatStartElapsedText(completed, isAr: isAr);
    final endRemaining = formatEndRemainingText(remaining, isAr: isAr);

    return InvestmentTimelineState(
      startDate: start,
      endDate: end,
      isEndDateAuthoritative: isEndAuth,
      durationMonths: months,
      elapsedMonths: completed,
      currentMonth: current,
      remainingMonths: remaining,
      progress: prog,
      progressPercent: percent,
      durationDisplay: durDisplay,
      durationSubtext: durSubtext,
      cyclePositionText: cyclePos,
      completedMonthsText: compText,
      remainingMonthsText: remText,
      startElapsedText: startElapsed,
      endRemainingText: endRemaining,
      isCompleted: isDone,
    );
  }

  // ─────────────────────────────────────────────────────────────
  // CALENDAR ARITHMETIC (SAFE & PURE)
  // ─────────────────────────────────────────────────────────────

  /// Safely adds [months] calendar months to [date].
  /// Handles month-end boundaries safely (e.g. 31 Jan + 1 mo -> 28/29 Feb).
  /// Avoids invalid dates and unintended day rollovers. Preserves time of day.
  static DateTime addCalendarMonths(DateTime date, int months) {
    if (months == 0) return date;
    final totalMonths = (date.year * 12 + (date.month - 1)) + months;
    final targetYear = totalMonths ~/ 12;
    final targetMonth = (totalMonths % 12) + 1;
    final maxDaysInTarget = daysInMonth(targetYear, targetMonth);
    final targetDay = math.min(date.day, maxDaysInTarget);

    return DateTime(
      targetYear,
      targetMonth,
      targetDay,
      date.hour,
      date.minute,
      date.second,
      date.millisecond,
      date.microsecond,
    );
  }

  /// Calculates full calendar months between [start] and [end].
  static int calculateMonthsBetween(DateTime start, DateTime end) {
    if (end.isBefore(start)) return 0;
    int months = (end.year - start.year) * 12 + (end.month - start.month);
    // If end day is less than start day and not the end of the month, subtract 1
    final isEndMonthEnd = end.day == daysInMonth(end.year, end.month);
    if (end.day < start.day && !isEndMonthEnd) {
      months -= 1;
    }
    return math.max(0, months);
  }

  /// Calculates the number of full calendar months elapsed since [startDate] as of [asOf].
  /// A month is only completed once [asOf] reaches the corresponding calendar day in the next month.
  static int calculateCompletedMonths(
    DateTime startDate,
    DateTime asOf,
    int totalMonths,
  ) {
    if (asOf.isBefore(startDate)) return 0;
    int count = 0;
    while (count < totalMonths) {
      final nextThreshold = addCalendarMonths(startDate, count + 1);
      if (asOf.isBefore(nextThreshold)) {
        break;
      }
      count++;
    }
    return count.clamp(0, totalMonths);
  }

  /// Returns current month (1-indexed) based on [completedMonths].
  static int calculateCurrentMonth(int completedMonths, int totalMonths) {
    if (completedMonths >= totalMonths) return totalMonths;
    return completedMonths + 1;
  }

  /// Returns safe progress between 0.0 and 1.0.
  static double calculateProgress(
    DateTime startDate,
    DateTime endDate, [
    DateTime? asOf,
  ]) {
    final now = asOf ?? DateTime.now();
    if (now.isBefore(startDate)) return 0.0;
    if (!now.isBefore(endDate)) return 1.0;

    final totalMicros = endDate.difference(startDate).inMicroseconds;
    if (totalMicros <= 0) return 1.0;

    final elapsedMicros = now.difference(startDate).inMicroseconds;
    final raw = elapsedMicros / totalMicros;

    if (raw.isNaN || raw.isInfinite) return 0.0;
    return raw.clamp(0.0, 1.0);
  }

  /// Returns days in a given month.
  static int daysInMonth(int year, int month) {
    if (month == 2) {
      final isLeap = (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0);
      return isLeap ? 29 : 28;
    }
    const thirtyDayMonths = [4, 6, 9, 11];
    if (thirtyDayMonths.contains(month)) return 30;
    return 31;
  }

  // ─────────────────────────────────────────────────────────────
  // DYNAMIC TEXT FORMATTERS
  // ─────────────────────────────────────────────────────────────

  static String formatDurationMonths(int months, {required bool isAr}) {
    if (!isAr) {
      return months == 1 ? '1 month' : '$months months';
    }
    if (months == 1) return 'شهر واحد';
    if (months == 2) return 'شهران';
    if (months >= 3 && months <= 10) return '$months أشهر';
    return '$months شهرًا';
  }

  static String? formatDurationSubtext(int months, {required bool isAr}) {
    if (months < 12) return null;

    if (isAr) {
      if (months == 12) return '(سنة واحدة)';
      if (months == 18) return '(سنة ونصف)';
      if (months == 24) return '(سنتين)';
      if (months == 30) return '(سنتين ونصف)';
      if (months == 36) return '(3 سنوات)';
      if (months % 12 == 0) {
        final y = months ~/ 12;
        if (y >= 3 && y <= 10) return '($y سنوات)';
        return '($y سنة)';
      }
      if (months % 12 == 6) {
        final y = months ~/ 12;
        return '($y.5 سنة)';
      }
      final yStr = (months / 12.0).toStringAsFixed(1);
      return '($yStr سنة)';
    } else {
      if (months == 12) return '(1 year)';
      if (months == 18) return '(1.5 years)';
      if (months == 24) return '(2 years)';
      if (months == 30) return '(2.5 years)';
      if (months == 36) return '(3 years)';
      if (months % 12 == 0) {
        final y = months ~/ 12;
        return '($y years)';
      }
      final yStr = (months / 12.0).toStringAsFixed(1);
      return '($yStr years)';
    }
  }

  static String formatCompletedMonthsText(int completed, {required bool isAr}) {
    if (!isAr) {
      return completed == 1
          ? '1 completed month'
          : '$completed completed months';
    }
    if (completed == 0) return '0 أشهر مكتملة';
    if (completed == 1) return '1 شهر مكتمل';
    if (completed == 2) return 'شهران مكتملان';
    if (completed >= 3 && completed <= 10) return '$completed أشهر مكتملة';
    return '$completed شهرًا مكتملًا';
  }

  static String formatRemainingMonthsText(
    int remaining, {
    int totalMonths = 30,
    required bool isAr,
  }) {
    if (!isAr) {
      return '$remaining of $totalMonths months remaining';
    }
    return 'متبقي $remaining شهرا من $totalMonths شهرا';
  }

  static String formatStartElapsedText(int elapsedMonths, {required bool isAr}) {
    if (elapsedMonths == 0) {
      return isAr ? 'هذا الشهر' : 'This month';
    }
    if (isAr) {
      if (elapsedMonths == 1) return 'منذ شهر';
      if (elapsedMonths == 2) return 'منذ شهرين';
      if (elapsedMonths >= 3 && elapsedMonths <= 10) {
        return 'منذ $elapsedMonths أشهر';
      }
      return 'منذ $elapsedMonths شهراً';
    } else {
      return elapsedMonths == 1 ? '1 month ago' : '$elapsedMonths months ago';
    }
  }

  static String formatEndRemainingText(int remainingMonths, {required bool isAr}) {
    if (remainingMonths == 0) {
      return isAr ? '(اكتملت المدة)' : '(Completed)';
    }
    if (isAr) {
      if (remainingMonths == 1) return '(بعد شهر)';
      if (remainingMonths == 2) return '(بعد شهرين)';
      if (remainingMonths >= 3 && remainingMonths <= 10) {
        return '(بعد $remainingMonths أشهر)';
      }
      return '(بعد $remainingMonths شهراً)';
    } else {
      return remainingMonths == 1
          ? '(After 1 month)'
          : '(After $remainingMonths months)';
    }
  }
}
