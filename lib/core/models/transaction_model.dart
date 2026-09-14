import 'package:flutter/material.dart';
import 'package:kasby/core/localization/content_localization_service.dart';
import 'package:kasby/core/utils/safe_getx.dart';
import 'package:kasby/core/utils/transaction_formatter.dart';

class TransactionModel {
  final String id;
  final String? idempotencyKey;
  final String userId;
  final String walletId;
  final String
  type; // deposit, withdrawal, transfer_in, transfer_out, investment, investment_return, loan_disbursement, loan_repayment, reward, adjustment, profit, fee, daily_check_in, spin_purchase, spin_reward, referral_reward, referral_commission, agent_commission, ksp_redemption, marketplace_purchase, qr_payment
  final double amount;
  final double fee;
  final double? netAmount; // generated column: amount - fee
  final String currency;
  final String
  status; // pending, processing, completed, approved, rejected, cancelled, failed
  final double? runningBalance;
  final String? counterpartUserId;
  final String? referenceId;
  final String? reason;
  final String? description;
  final String? proofUrl;
  final String? processedBy;
  final DateTime? processedAt;
  final String? rejectionReason;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const TransactionModel({
    required this.id,
    this.idempotencyKey,
    required this.userId,
    required this.walletId,
    required this.type,
    required this.amount,
    this.fee = 0.0,
    this.netAmount,
    this.currency = 'USD',
    this.status = 'pending',
    this.runningBalance,
    this.counterpartUserId,
    this.referenceId,
    this.reason,
    this.description,
    this.proofUrl,
    this.processedBy,
    this.processedAt,
    this.rejectionReason,
    this.createdAt,
    this.updatedAt,
  });

  /// Whether this is a credit (money in) transaction.
  bool get isCredit => [
    'deposit',
    'transfer_in',
    'investment_return',
    'loan_disbursement',
    'reward',
    'profit',
    'investment_profit',
    'admin_credit',
    'daily_check_in',
    'daily_checkin',
    'spin_reward',
    'referral_reward',
    'referral_commission',
    'agent_commission',
    'ksp_redemption',
  ].contains(type);

  /// Whether this is a debit (money out) transaction.
  bool get isDebit => !isCredit;

  /// Formatted amount with real currency and sign (+/-)
  String get formattedAmount => TransactionFormatter.formatAmount(
    amount: amount,
    currency: currency,
    isDebit: isDebit,
  );

  /// Formatted amount without sign (+/-)
  String get formattedAmountWithoutSign => TransactionFormatter.formatAmountWithoutSign(
    amount: amount,
    currency: currency,
  );

  /// Formatted fee with real currency
  String get formattedFee => TransactionFormatter.formatAmount(
    amount: fee,
    currency: currency,
    showSign: false,
  );

  /// Formatted net amount with real currency and sign
  String get formattedNetAmount => TransactionFormatter.formatAmount(
    amount: netAmount ?? (amount - fee),
    currency: currency,
    isDebit: isDebit,
  );

  Color get typeColor => TransactionFormatter.getTypeColor(type);
  IconData get typeIcon => TransactionFormatter.getTypeIcon(type);
  Color get statusColor => TransactionFormatter.getStatusColor(status);
  IconData get statusIcon => TransactionFormatter.getStatusIcon(status);

  String get localizedTypeLabel => ContentLocalizationService.transactionTypeLabel(type);
  String get localizedStatusLabel => ContentLocalizationService.transactionStatusLabel(status);
  String get localizedDescription => ContentLocalizationService.translate(description);

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    try {
      return TransactionModel(
        id: json['id'] as String,
        idempotencyKey: json['idempotency_key'] as String?,
        userId: json['user_id'] as String,
        walletId: json['wallet_id'] as String,
        type: json['type'] as String,
        amount: (json['amount'] as num).toDouble(),
        fee: (json['fee'] as num?)?.toDouble() ?? 0.0,
        netAmount: (json['net_amount'] as num?)?.toDouble(),
        currency: (json['currency'] as String?)?.isNotEmpty == true
            ? json['currency'] as String
            : (json['wallet_id'] == 'points_wallet' || json['points'] != null ? 'KSP' : 'USD'),
        status: json['status'] as String? ?? 'pending',
        runningBalance: (json['running_balance'] as num?)?.toDouble(),
        counterpartUserId: json['counterpart_user_id'] as String?,
        referenceId: json['reference_id'] as String?,
        reason: json['reason'] as String?,
        description: json['description'] as String?,
        proofUrl: json['proof_url'] as String?,
        processedBy: json['processed_by'] as String?,
        processedAt: json['processed_at'] != null
            ? DateTime.parse(json['processed_at'])
            : null,
        rejectionReason: json['rejection_reason'] as String?,
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'])
            : null,
        updatedAt: json['updated_at'] != null
            ? DateTime.parse(json['updated_at'])
            : null,
      );
    } catch (e, stack) {
      SafeGetx.debugTrace(
        className: 'TransactionModel',
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
      'idempotency_key': idempotencyKey,
      'user_id': userId,
      'wallet_id': walletId,
      'type': type,
      'amount': amount,
      'fee': fee,
      'currency': currency,
      'status': status,
      'running_balance': runningBalance,
      'counterpart_user_id': counterpartUserId,
      'reference_id': referenceId,
      'reason': reason,
      'description': description,
      'proof_url': proofUrl,
    };
  }

  TransactionModel copyWith({
    String? id,
    String? idempotencyKey,
    String? userId,
    String? walletId,
    String? type,
    double? amount,
    double? fee,
    double? netAmount,
    String? currency,
    String? status,
    double? runningBalance,
    String? counterpartUserId,
    String? referenceId,
    String? reason,
    String? description,
    String? proofUrl,
    String? processedBy,
    DateTime? processedAt,
    String? rejectionReason,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
      userId: userId ?? this.userId,
      walletId: walletId ?? this.walletId,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      fee: fee ?? this.fee,
      netAmount: netAmount ?? this.netAmount,
      currency: currency ?? this.currency,
      status: status ?? this.status,
      runningBalance: runningBalance ?? this.runningBalance,
      counterpartUserId: counterpartUserId ?? this.counterpartUserId,
      referenceId: referenceId ?? this.referenceId,
      reason: reason ?? this.reason,
      description: description ?? this.description,
      proofUrl: proofUrl ?? this.proofUrl,
      processedBy: processedBy ?? this.processedBy,
      processedAt: processedAt ?? this.processedAt,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
