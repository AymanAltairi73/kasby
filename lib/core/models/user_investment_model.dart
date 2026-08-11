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
  /// A cycle is only considered "waiting" after at least one payout has occurred
  /// (lastPayoutAt != null). A brand-new investment with nextPayoutAt == null
  /// and lastPayoutAt == null is still awaiting its first cron distribution
  /// and should NOT show "cycle completed".
  bool get isCycleWaiting =>
      status == 'active' &&
      !autoRestartEnabled &&
      lastPayoutAt != null &&
      (nextPayoutAt == null || !nextPayoutAt!.isAfter(DateTime.now()));

  /// Effective next profit distribution timestamp for active investments.
  /// Subscribed (auto-restart) investments roll over; non-subscribed investments
  /// stop when due, signaling cycle completion.
  DateTime? get effectiveNextPayout {
    if (status != 'active') return nextPayoutAt;
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
