import 'package:flutter/foundation.dart';
import 'package:kasby/core/models/investment_plan_model.dart';
import 'package:kasby/core/utils/safe_getx.dart';

class UserInvestmentModel {
  final String id;
  final String userId;
  final String planId;
  final String? transactionId;
  final double amount;
  final double profitPercentage;
  final double expectedProfit;
  final double? actualProfit;
  final String status; // active, completed, cancelled, matured
  final DateTime? startDate;
  final DateTime? endDate;
  final DateTime? maturedAt;
  final DateTime? lastPayoutAt;
  final DateTime? nextPayoutAt;
  final bool autoRestartEnabled;
  final String? approvedBy;
  final DateTime? createdAt;
  final InvestmentPlanModel? investment;

  const UserInvestmentModel({
    required this.id,
    required this.userId,
    required this.planId,
    this.transactionId,
    required this.amount,
    required this.profitPercentage,
    this.expectedProfit = 0.0,
    this.actualProfit,
    this.status = 'active',
    this.startDate,
    this.endDate,
    this.maturedAt,
    this.lastPayoutAt,
    this.nextPayoutAt,
    this.autoRestartEnabled = false,
    this.approvedBy,
    this.createdAt,
    this.investment,
  });

  /// Whether this investment's daily cycle is waiting to be manually started.
  /// Applies to:
  /// 1. Brand new non-subscribed investment (status == 'not_active')
  /// 2. Post-payout waiting investment (status == 'not_active' or unstarted cycle)
  bool get isCycleWaiting {
    if (status == 'matured' || status == 'completed' || status == 'cancelled') {
      return false;
    }
    if (status == 'not_active') {
      return true;
    }
    if (status == 'active' && !autoRestartEnabled) {
      return nextPayoutAt == null || !nextPayoutAt!.isAfter(DateTime.now());
    }
    return false;
  }

  /// Whether the investment currently has an active running cycle.
  bool get isCycleActive =>
      status == 'active' &&
      nextPayoutAt != null &&
      nextPayoutAt!.isAfter(DateTime.now());

  /// Effective next profit distribution timestamp for active investments.
  /// Subscribed (auto-restart) investments roll over; non-subscribed investments
  /// stop when due, signaling cycle completion.
  DateTime? get effectiveNextPayout {
    if (status != 'active') return null;
    if (nextPayoutAt == null) return null;
    final now = DateTime.now();
    // Non-subscribed investments do not auto-roll when payout is reached
    if (!autoRestartEnabled && !nextPayoutAt!.isAfter(now)) {
      return nextPayoutAt;
    }
    DateTime base = nextPayoutAt ?? startDate ?? createdAt ?? now;
    if (!base.isAfter(now)) {
      final diffSeconds = now.difference(base).inSeconds;
      final cycles = (diffSeconds / 86400).floor() + 1;
      base = base.add(Duration(seconds: cycles * 86400));
    }
    return base;
  }

  /// Remaining days until maturity. Returns null if no end date.
  int? get remainingDays {
    if (endDate == null) return null;
    final diff = endDate!.difference(DateTime.now()).inDays;
    return diff > 0 ? diff : 0;
  }

  /// Daily profit calculated for this investment instance.
  double get dailyProfit {
    final duration = investment?.durationDays ?? 30;
    if (duration <= 0) return 0.0;
    return (amount * profitPercentage / 100) / duration;
  }

  /// Estimated monthly profit (30-day cycle) calculated from daily profit.
  double get monthlyProfit => dailyProfit * 30;

  /// Effective start date of the investment cycle.
  /// Falls back to [createdAt] if [startDate] is null.
  DateTime? get effectiveStartDate => startDate ?? createdAt;

  /// Effective end date of the investment cycle.
  /// Uses [endDate] if provided, or calculates from [effectiveStartDate] + plan [durationDays].
  DateTime? get effectiveEndDate {
    if (endDate != null) return endDate;
    final start = effectiveStartDate;
    final duration = investment?.durationDays;
    if (start != null && duration != null && duration > 0) {
      return start.add(Duration(days: duration));
    }
    return null;
  }

  /// Total duration of the investment cycle in days.
  /// Determined from the actual date span (endDate - startDate),
  /// or from the plan's durationDays, safely falling back to 30 days.
  int get totalDurationDays {
    final start = effectiveStartDate;
    final end = effectiveEndDate;
    if (start != null && end != null) {
      final s = DateTime(start.year, start.month, start.day);
      final e = DateTime(end.year, end.month, end.day);
      final diff = e.difference(s).inDays;
      if (diff > 0) return diff;
    }
    if ((investment?.durationDays ?? 0) > 0) {
      return investment!.durationDays!;
    }
    return 30;
  }

  /// Elapsed days since the investment cycle started.
  /// Clamped between 0 and [totalDurationDays].
  int getElapsedDays([DateTime? asOf]) {
    final start = effectiveStartDate;
    if (start == null) return 0;
    final target = asOf ?? DateTime.now();
    final today = DateTime(target.year, target.month, target.day);
    final startDay = DateTime(start.year, start.month, start.day);

    if (today.isBefore(startDay)) return 0;

    final diff = today.difference(startDay).inDays;
    return diff.clamp(0, totalDurationDays);
  }

  /// Elapsed days as of current time.
  int get elapsedDays => getElapsedDays();

  /// Remaining days until the investment cycle completes.
  /// Clamped between 0 and [totalDurationDays].
  int getCycleRemainingDays([DateTime? asOf]) {
    final total = totalDurationDays;
    final elapsed = getElapsedDays(asOf);
    final remaining = total - elapsed;
    return remaining.clamp(0, total);
  }

  /// Remaining days as of current time.
  int get cycleRemainingDays => getCycleRemainingDays();

  /// Current cycle progress as a fraction between 0.0 and 1.0.
  double getCycleProgress([DateTime? asOf]) {
    final total = totalDurationDays;
    if (total <= 0) return 0.0;
    final progress = getElapsedDays(asOf) / total;
    return progress.clamp(0.0, 1.0);
  }

  /// Current cycle progress as of current time.
  double get cycleProgress => getCycleProgress();


  factory UserInvestmentModel.fromJson(Map<String, dynamic> json) {
    try {
      final model = UserInvestmentModel(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        planId: json['plan_id'] as String,
        transactionId: json['transaction_id'] as String?,
        amount: (json['amount'] as num).toDouble(),
        profitPercentage: (json['profit_percentage'] as num).toDouble(),
        expectedProfit: (json['expected_profit'] as num?)?.toDouble() ?? 0.0,
        actualProfit: (json['actual_profit'] as num?)?.toDouble(),
        status: json['status'] as String? ?? 'active',
        startDate: json['start_date'] != null
            ? DateTime.parse(json['start_date'])
            : null,
        endDate: json['end_date'] != null
            ? DateTime.parse(json['end_date'])
            : null,
        maturedAt: json['matured_at'] != null
            ? DateTime.parse(json['matured_at'])
            : null,
        lastPayoutAt: json['last_payout_at'] != null
            ? DateTime.parse(json['last_payout_at'])
            : null,
        nextPayoutAt: json['next_payout_at'] != null
            ? DateTime.parse(json['next_payout_at'])
            : null,
        autoRestartEnabled: json['auto_restart_enabled'] as bool? ?? false,
        approvedBy: json['approved_by'] as String?,
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'])
            : null,
        investment: json['investment'] != null
            ? InvestmentPlanModel.fromJson(json['investment'])
            : null,
      );

      debugPrint(
        '[PROFIT_COUNTDOWN] Investment loaded -> investment_id: ${model.id} | status: ${model.status} | auto_restart_enabled: ${model.autoRestartEnabled} | next_payout_at: ${model.nextPayoutAt} | last_payout_at: ${model.lastPayoutAt} | isCycleWaiting: ${model.isCycleWaiting} | effectiveNextPayout: ${model.effectiveNextPayout}',
      );

      model._logStateVerification();

      return model;
    } catch (e, stack) {
      SafeGetx.debugTrace(
        className: 'UserInvestmentModel',
        method: 'fromJson',
        feature: 'Core',
        status: 'ERROR',
        params: {'id': json['id']?.toString()},
        error: e,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  void _logStateVerification() {
    if (!autoRestartEnabled) {
      debugPrint(
        '[PROFIT_NON_SUBSCRIBED] subscription_active: false | auto_restart_enabled: false | next_payout_at: $nextPayoutAt | isCycleWaiting: $isCycleWaiting',
      );
      if (isCycleWaiting) {
        debugPrint(
          '[PROFIT_NON_SUBSCRIBED] countdown_state: cycle_completed | show_cycle_completed_message: true | show_start_next_cycle_button: true | show_next_profit: false',
        );
      }
    } else {
      debugPrint(
        '[PROFIT_SUBSCRIBED] subscription_active: true | auto_restart_enabled: true | next_payout_at: $nextPayoutAt',
      );
      if (isCycleWaiting) {
        debugPrint(
          '[PROFIT_ERROR] INVALID SUBSCRIBED STATE -> Subscribed investment cannot be in cycleWaiting state! investment_id: $id',
        );
      } else {
        debugPrint(
          '[PROFIT_SUBSCRIBED] countdown_state: active | show_cycle_completed_message: false | show_start_next_cycle_button: false',
        );
      }
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'plan_id': planId,
      'transaction_id': transactionId,
      'amount': amount,
      'profit_percentage': profitPercentage,
      'expected_profit': expectedProfit,
      'actual_profit': actualProfit,
      'status': status,
      'start_date': startDate?.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'last_payout_at': lastPayoutAt?.toIso8601String(),
      'next_payout_at': nextPayoutAt?.toIso8601String(),
      'auto_restart_enabled': autoRestartEnabled,
    };
  }

  UserInvestmentModel copyWith({
    String? id,
    String? userId,
    String? planId,
    String? transactionId,
    double? amount,
    double? profitPercentage,
    double? expectedProfit,
    double? actualProfit,
    String? status,
    DateTime? startDate,
    DateTime? endDate,
    DateTime? maturedAt,
    DateTime? lastPayoutAt,
    DateTime? nextPayoutAt,
    bool? autoRestartEnabled,
    String? approvedBy,
    DateTime? createdAt,
    InvestmentPlanModel? investment,
  }) {
    return UserInvestmentModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      planId: planId ?? this.planId,
      transactionId: transactionId ?? this.transactionId,
      amount: amount ?? this.amount,
      profitPercentage: profitPercentage ?? this.profitPercentage,
      expectedProfit: expectedProfit ?? this.expectedProfit,
      actualProfit: actualProfit ?? this.actualProfit,
      status: status ?? this.status,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      maturedAt: maturedAt ?? this.maturedAt,
      lastPayoutAt: lastPayoutAt ?? this.lastPayoutAt,
      nextPayoutAt: nextPayoutAt ?? this.nextPayoutAt,
      autoRestartEnabled: autoRestartEnabled ?? this.autoRestartEnabled,
      approvedBy: approvedBy ?? this.approvedBy,
      createdAt: createdAt ?? this.createdAt,
      investment: investment ?? this.investment,
    );
  }
}
