import 'package:kasby/core/utils/safe_getx.dart';

class DashboardModel {
  final String userId;
  final String fullName;
  final String accountTier;
  final String kycStatus;
  final double availableBalance;
  final double profitBalance;
  final double investedBalance;
  final double pendingBalance;
  final bool isFrozen;
  final String? frozenReason;
  final String currency;
  final int pointBalance;
  final int activeInvestments;
  final int activeLoans;
  final double dailyProfit;
  final double profitPercentage;

  DashboardModel({
    required this.userId,
    required this.fullName,
    required this.accountTier,
    required this.kycStatus,
    required this.availableBalance,
    required this.profitBalance,
    required this.investedBalance,
    required this.pendingBalance,
    required this.isFrozen,
    this.frozenReason,
    required this.currency,
    required this.pointBalance,
    required this.activeInvestments,
    required this.activeLoans,
    required this.dailyProfit,
    required this.profitPercentage,
  });

  factory DashboardModel.fromJson(Map<String, dynamic> json) {
    try {
      return DashboardModel(
      userId: json['user_id'] as String,
      fullName: json['full_name'] as String? ?? '',
      accountTier: json['account_tier'] as String? ?? 'free',
      kycStatus: json['kyc_status'] as String? ?? 'unverified',
      availableBalance: (json['available_balance'] as num?)?.toDouble() ?? 0.0,
      profitBalance: (json['profit_balance'] as num?)?.toDouble() ?? 0.0,
      investedBalance: (json['invested_balance'] as num?)?.toDouble() ?? 0.0,
      pendingBalance: (json['pending_balance'] as num?)?.toDouble() ?? 0.0,
      isFrozen: json['is_frozen'] as bool? ?? false,
      frozenReason: json['frozen_reason'] as String?,
      currency: json['currency'] as String? ?? 'USD',
      pointBalance: (json['point_balance'] as num?)?.toInt() ?? 0,
      activeInvestments: (json['active_investments'] as num?)?.toInt() ?? 0,
      activeLoans: (json['active_loans'] as num?)?.toInt() ?? 0,
      dailyProfit: (json['daily_profit'] as num?)?.toDouble() ?? 0.0,
      profitPercentage: (json['profit_percentage'] as num?)?.toDouble() ?? 0.0,
      );
    } catch (e, stack) {
      SafeGetx.debugTrace(
        className: 'DashboardModel',
        method: 'fromJson',
        feature: 'Core',
        status: 'ERROR',
        params: {'userId': json['user_id']?.toString()},
        error: e,
        stackTrace: stack,
      );
      rethrow;
    }
  }
}
