import 'package:kasby/core/utils/safe_getx.dart';

class RecurringInvestmentModel {
  final String id;
  final String userId;
  final String planId;
  final String? planName;
  final double amount;
  final String frequency; // 'daily', 'weekly', 'monthly', 'custom'
  final int? customDays;
  final String status; // 'active', 'paused', 'cancelled'
  final DateTime? nextExecutionDate;
  final DateTime? lastExecutionDate;
  final int totalExecutions;
  final int successfulExecutions;
  final int failedExecutions;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const RecurringInvestmentModel({
    required this.id,
    required this.userId,
    required this.planId,
    this.planName,
    required this.amount,
    required this.frequency,
    this.customDays,
    this.status = 'active',
    this.nextExecutionDate,
    this.lastExecutionDate,
    this.totalExecutions = 0,
    this.successfulExecutions = 0,
    this.failedExecutions = 0,
    required this.createdAt,
    this.updatedAt,
  });

  factory RecurringInvestmentModel.fromJson(Map<String, dynamic> json) {
    try {
      return RecurringInvestmentModel(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        planId: json['plan_id'] as String,
        planName: json['plan_name'] as String?,
        amount: (json['amount'] as num).toDouble(),
        frequency: json['frequency'] as String? ?? 'monthly',
        customDays: json['custom_days'] as int?,
        status: json['status'] as String? ?? 'active',
        nextExecutionDate: json['next_execution_date'] != null
            ? DateTime.parse(json['next_execution_date'])
            : null,
        lastExecutionDate: json['last_execution_date'] != null
            ? DateTime.parse(json['last_execution_date'])
            : null,
        totalExecutions: json['total_executions'] as int? ?? 0,
        successfulExecutions: json['successful_executions'] as int? ?? 0,
        failedExecutions: json['failed_executions'] as int? ?? 0,
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'])
            : DateTime.now(),
        updatedAt: json['updated_at'] != null
            ? DateTime.parse(json['updated_at'])
            : null,
      );
    } catch (e, stack) {
      SafeGetx.debugTrace(
        className: 'RecurringInvestmentModel',
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

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'plan_id': planId,
      'plan_name': planName,
      'amount': amount,
      'frequency': frequency,
      'custom_days': customDays,
      'status': status,
      'next_execution_date': nextExecutionDate?.toIso8601String(),
      'last_execution_date': lastExecutionDate?.toIso8601String(),
      'total_executions': totalExecutions,
      'successful_executions': successfulExecutions,
      'failed_executions': failedExecutions,
    };
  }

  RecurringInvestmentModel copyWith({
    String? id,
    String? userId,
    String? planId,
    String? planName,
    double? amount,
    String? frequency,
    int? customDays,
    String? status,
    DateTime? nextExecutionDate,
    DateTime? lastExecutionDate,
    int? totalExecutions,
    int? successfulExecutions,
    int? failedExecutions,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RecurringInvestmentModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      planId: planId ?? this.planId,
      planName: planName ?? this.planName,
      amount: amount ?? this.amount,
      frequency: frequency ?? this.frequency,
      customDays: customDays ?? this.customDays,
      status: status ?? this.status,
      nextExecutionDate: nextExecutionDate ?? this.nextExecutionDate,
      lastExecutionDate: lastExecutionDate ?? this.lastExecutionDate,
      totalExecutions: totalExecutions ?? this.totalExecutions,
      successfulExecutions: successfulExecutions ?? this.successfulExecutions,
      failedExecutions: failedExecutions ?? this.failedExecutions,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  String get frequencyLabel {
    switch (frequency) {
      case 'daily':
        return 'daily';
      case 'weekly':
        return 'weekly';
      case 'monthly':
        return 'monthly';
      case 'custom':
        return 'custom_schedule';
      default:
        return frequency;
    }
  }

  bool get isActive => status == 'active';
  bool get isPaused => status == 'paused';
  bool get isCancelled => status == 'cancelled';
}
