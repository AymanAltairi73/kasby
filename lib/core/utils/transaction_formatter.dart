import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kasby/core/theme/app_colors.dart';

/// Centralized Single Source of Truth for formatting all transaction amounts,
/// types, colors, and icons across the entire Kasby application.
///
/// Rules strictly enforced:
/// 1. Transaction currency MUST always be the actual currency of the transaction.
/// 2. KSP is NEVER formatted as USD or with '$'.
/// 3. KSP is NEVER converted to fiat during formatting.
/// 4. Never infer transaction currency from the user's selected wallet currency.
/// 5. Bi-directional Unicode mark (\u200E) is used to ensure +/- signs stay on the
///    correct side in both Arabic (RTL) and English (LTR) layouts.
class TransactionFormatter {
  TransactionFormatter._();

  /// Formats any financial or reward amount with its real currency and correct sign.
  ///
  /// Examples:
  /// - KSP credit: `+50 KSP`
  /// - KSP debit: `-100 KSP`
  /// - USD credit: `+$50.00`
  /// - USD debit: `-$100.00`
  /// - SAR credit: `+187.50 SAR`
  /// - EUR debit: `-50.00 EUR`
  static String formatAmount({
    required double amount,
    required String currency,
    bool? isDebit,
    bool showSign = true,
  }) {
    final cleanCurrency = currency.trim().toUpperCase();
    final signStr = showSign && isDebit != null ? (isDebit ? '-' : '+') : '';

    if (cleanCurrency == 'KSP') {
      final kspInt = amount.round();
      final formatted = _formatInteger(kspInt);
      // \u200E ensures the sign and digits remain in LTR order even in RTL layouts
      return '\u200E$signStr$formatted KSP';
    }

    // Fiat currencies
    final formattedNum = _formatDecimal(amount, decimalPlaces: 2);

    if (cleanCurrency == 'USD') {
      return '\u200E$signStr\$$formattedNum';
    }

    if (cleanCurrency.isEmpty) {
      return '\u200E$signStr$formattedNum';
    }

    return '\u200E$signStr$formattedNum $cleanCurrency';
  }

  /// Formats amount without any leading +/- sign.
  static String formatAmountWithoutSign({
    required double amount,
    required String currency,
  }) {
    return formatAmount(
      amount: amount,
      currency: currency,
      showSign: false,
    );
  }

  /// Helper to format integer with thousand separators.
  static String _formatInteger(int value) {
    final formatter = NumberFormat.decimalPattern('en_US');
    return formatter.format(value);
  }

  /// Helper to format decimal with fixed decimal places and thousand separators.
  static String _formatDecimal(double value, {int decimalPlaces = 2}) {
    final formatter = NumberFormat.decimalPattern('en_US');
    formatter.minimumFractionDigits = decimalPlaces;
    formatter.maximumFractionDigits = decimalPlaces;
    return formatter.format(value);
  }

  /// Centralized visual color for each transaction type.
  static Color getTypeColor(String type) {
    switch (type) {
      case 'deposit':
      case 'transfer_in':
      case 'investment_return':
      case 'admin_credit':
      case 'ksp_redemption':
        return AppColors.softGreen;

      case 'withdrawal':
      case 'transfer_out':
      case 'admin_debit':
      case 'spin_purchase':
        return AppColors.error;

      case 'investment':
        return const Color(0xFF2196F3);

      case 'profit':
      case 'investment_profit':
        return AppColors.darkGold;

      case 'reward':
      case 'daily_check_in':
      case 'daily_checkin':
      case 'spin_reward':
      case 'referral_reward':
      case 'referral_commission':
        return const Color(0xFFE91E63);

      case 'fee':
      case 'agent_commission':
        return Colors.orange;

      case 'loan_disbursement':
        return const Color(0xFF9C27B0);

      case 'loan_repayment':
        return Colors.teal;

      case 'adjustment':
        return Colors.blueGrey;

      case 'marketplace_purchase':
        return Colors.deepOrange;

      case 'qr_payment':
        return const Color(0xFF00BCD4);

      default:
        return AppColors.textSecondary;
    }
  }

  /// Centralized icon for each transaction type.
  static IconData getTypeIcon(String type) {
    switch (type) {
      case 'deposit':
        return Icons.arrow_downward_rounded;

      case 'withdrawal':
        return Icons.arrow_upward_rounded;

      case 'transfer_in':
        return Icons.call_received_rounded;

      case 'transfer_out':
        return Icons.call_made_rounded;

      case 'investment':
        return Icons.trending_up_rounded;

      case 'investment_return':
        return Icons.assignment_return_rounded;

      case 'profit':
      case 'investment_profit':
        return Icons.auto_awesome_rounded;

      case 'reward':
        return Icons.card_giftcard_rounded;

      case 'daily_check_in':
      case 'daily_checkin':
        return Icons.event_available_rounded;

      case 'spin_purchase':
        return Icons.stars_rounded;

      case 'spin_reward':
        return Icons.casino_rounded;

      case 'referral_reward':
      case 'referral_commission':
        return Icons.people_alt_rounded;

      case 'agent_commission':
        return Icons.support_agent_rounded;

      case 'fee':
        return Icons.receipt_long_rounded;

      case 'loan_disbursement':
        return Icons.handshake_rounded;

      case 'loan_repayment':
        return Icons.payments_rounded;

      case 'adjustment':
        return Icons.tune_rounded;

      case 'admin_credit':
        return Icons.add_card_rounded;

      case 'admin_debit':
        return Icons.credit_card_off_rounded;

      case 'marketplace_purchase':
        return Icons.shopping_bag_rounded;

      case 'ksp_redemption':
        return Icons.currency_exchange_rounded;

      case 'qr_payment':
        return Icons.qr_code_scanner_rounded;

      default:
        return Icons.receipt_rounded;
    }
  }

  /// Centralized visual color for each transaction status.
  static Color getStatusColor(String status) {
    switch (status) {
      case 'completed':
      case 'approved':
        return AppColors.softGreen;

      case 'pending':
        return AppColors.darkGold;

      case 'processing':
        return const Color(0xFF2196F3);

      case 'rejected':
      case 'failed':
      case 'cancelled':
        return AppColors.error;

      default:
        return AppColors.textSecondary;
    }
  }

  /// Centralized icon for each transaction status.
  static IconData getStatusIcon(String status) {
    switch (status) {
      case 'completed':
      case 'approved':
        return Icons.check_circle_rounded;

      case 'pending':
        return Icons.hourglass_empty_rounded;

      case 'processing':
        return Icons.sync_rounded;

      case 'rejected':
      case 'failed':
      case 'cancelled':
        return Icons.cancel_rounded;

      default:
        return Icons.info_outline_rounded;
    }
  }
}
