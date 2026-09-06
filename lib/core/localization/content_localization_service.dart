import 'dart:convert';

import 'package:get/get.dart';
import 'package:kasby/core/localization/kasby_l10n.dart';
import 'package:kasby/core/localization/localization_logger.dart';
import 'package:kasby/core/models/notification_model.dart';
import 'package:kasby/core/models/transaction_model.dart';

/// Resolves user-visible database values into localized strings without schema changes.
///
/// Backend may store either:
/// - A localization key (e.g. `deposit_success_title`, `enum_txn_deposit`)
/// - A JSON payload: `{"key":"transfer_received_msg","params":{"amount":"$50","sender":"Ali"}}`
/// - Legacy plain text (displayed as-is)
class ContentLocalizationService {
  ContentLocalizationService._();

  static final RegExp _keyPattern = RegExp(r'^[a-z][a-z0-9_]{2,}$');

  static const Set<String> _knownPrefixes = {
    'enum_',
    'notif_',
    'txn_',
    'deposit_',
    'withdraw_',
    'withdrawal_',
    'transfer_',
    'investment_',
    'marketplace_',
    'kyc_',
    'security_',
    'auth_',
    'otp_',
    'checkin_',
    'referral_',
    'loan_',
    'reward_',
    'spin_',
    'wheel_',
    'qr_',
    'stage_',
    'filter_',
    'status_',
    'tour_',
    'reason_',
    'error_',
  };

  static final RegExp _profitMsgRegex = RegExp(
    r'^تم إضافة ربح بقيمة\s*(\$?[\d\.]+)\s*من استثمار\s*\((.+?)\)\s*بنجاح\.?$',
  );
  static final RegExp _dailyProfitsWalletRegex = RegExp(
    r'^تمت إضافة أرباح بقيمة\s*(\$?[\d\.]+)\s*إلى محفظتك\.?$',
  );
  static final RegExp _loanRequestedRegex = RegExp(
    r'^تم استلام طلب السلفة بقيمة\s*(.+?)\s*وهو قيد المراجعة حالياً\.?$',
  );
  static final RegExp _loanRepaymentSuccessRegex = RegExp(
    r'^تم خصم\s*(.+?)\s*لسداد السلفة\.\s*المبلغ المتبقي:\s*(.+)$',
  );
  static final RegExp _friendRequestRegex = RegExp(
    r'^أرسل لك\s*(.+?)\s*طلب صداقة\.?$',
  );
  static final RegExp _balanceAdjustmentRegex = RegExp(
    r'^قام النظام بتعديل رصيد محفظتك بمقدار\s*(.+?)\.\s*راجع المعاملات للتفاصيل\.?$',
  );
  static final RegExp _adminDepositPendingRegex = RegExp(
    r'^قام\s*(.+?)\s*بتقديم طلب إيداع بمبلغ\s*(.+)$',
  );
  static final RegExp _adminWithdrawalPendingRegex = RegExp(
    r'^قام\s*(.+?)\s*بتقديم طلب سحب بمبلغ\s*(.+)$',
  );
  static final RegExp _kspRedeemNotifRegex = RegExp(
    r'^تم تحويل\s*(\d+)\s*نقطة وإيداع\s*(.+?)\s*في رصيدك النقدي\.?$',
  );
  static final RegExp _investMaturedNotifRegex = RegExp(
    r'^اكتمل استثمارك في\s*(.+?)\s*وتمت استعادة رأس المال بقيمة\s*(.+?)\.?$',
  );
  static final RegExp _txnProfitDailyRegex = RegExp(
    r'^ربح يومي من\s*(.+)$',
  );
  static final RegExp _txnProfitDailyAltRegex = RegExp(
    r'^أرباح يومية —\s*(.+)$',
  );
  static final RegExp _txnInvestPlanPrefixedRegex = RegExp(
    r'^استثمار في باقة\s*(.+)$',
  );
  static final RegExp _txnInvestPlanRegex = RegExp(
    r'^استثمار في\s*(.+)$',
  );
  static final RegExp _txnLoanDisburseRegex = RegExp(
    r'^صرف سلفة مالية -\s*(\d+)\s*أشهر$',
  );
  static final RegExp _txnDepositAgentRegex = RegExp(
    r'^إيداع عبر الوكيل:\s*(.+)$',
  );
  static final RegExp _txnWithdrawalAgentRegex = RegExp(
    r'^سحب عبر الوكيل:\s*(.+)$',
  );
  static final RegExp _txnTransferToRegex = RegExp(
    r'^تحويل إلى\s*(.+)$',
  );
  static final RegExp _txnTransferFromRegex = RegExp(
    r'^تحويل من\s*(.+)$',
  );
  static final RegExp _txnRewardReferralRegex = RegExp(
    r'^عمولة إحالة من استثمار\s*(.+)$',
  );
  static final RegExp _txnRewardDepositFeeRegex = RegExp(
    r'^عمولة إيداع —\s*(.+)$',
  );
  static final RegExp _txnRewardWithdrawalFeeRegex = RegExp(
    r'^عمولة سحب —\s*(.+)$',
  );
  static final RegExp _txnKspRedeemRegex = RegExp(
    r'^استبدال\s*(\d+)\s*نقطة KSP بالرصيد النقدي\s*\((.+?)\)$',
  );
  static final RegExp _txnMarketplaceRegex = RegExp(
    r'^شراء من متجر كسب:\s*(.+)$',
  );
  static final RegExp _investAmountRegex = RegExp(
    r'^(.+?)\s+استثمر\s+([\d\.]+)\s+USD$',
  );
  static final RegExp _matureLegacyRegex = RegExp(
    r'^استثمار\s+(.+?)\s+بقيمة\s+([\d\.]+)\s+اكتمل\.$',
  );

  static final Map<String, String> _exactDynamicMap = {
    // Notification Titles
    'أرباحك اليومية وصلت ✅': 'notif_daily_profits_title',
    'أرباح يومية 📈': 'notif_daily_profits_title',
    'أرباح استثمار جديدة 💰': 'notif_new_investment_profit_title',
    'طلب إيداع جديد بانتظار المراجعة 📥': 'notif_admin_deposit_pending_title',
    'طلب سحب جديد بانتظار المراجعة 📤': 'notif_admin_withdrawal_pending_title',
    '💰 مبروك!': 'notif_loan_approved_title',
    'طلب سلفة قيد المراجعة 📝': 'notif_loan_requested_title',
    'طلب سلفة جديد': 'notif_loan_requested_title',
    'سداد السلفة بنجاح': 'notif_loan_repayment_success_title',
    '✅ تم توثيق الحساب': 'notif_kyc_verified_title',
    'طلب توثيق جديد 📋': 'notif_admin_kyc_pending_title',
    'طلب توثيق جديد بانتظار مراجعة الإدارة.': 'notif_admin_kyc_pending_msg',
    'طلب صداقة جديد': 'notif_friend_request_title',
    '⚖️ تعديل الرصيد': 'notif_balance_adjustment_title',
    '⚠️ تنبيه حساب': 'notif_account_blocked_title',
    '✅ تم تنشيط الحساب': 'notif_account_unblocked_title',
    'تم تجميد الحساب ⛔': 'notif_account_frozen_title',
    'تم حذف الحساب': 'notif_account_deleted_title',
    '🏗️ صيانة مجدولة': 'notif_maintenance_title',
    'تم استبدال نقاط KSP بنجاح': 'notif_ksp_redeem_success_title',
    'استحقاق الاستثمار 🎉': 'notif_investment_matured_title',
    'تم إنشاء الاستثمار 🚀': 'investment_created_title',
    'استثمارك نضج! 🎉': 'investment_matured_title',
    '📈 استثمار جديد بانتظار المراجعة': 'admin_investment_pending_title',
    'عمولة إحالة 💰': 'referral_commission_simple',
    'أرباح جديدة': 'new_profits',
    'إيداع ناجح': 'deposit_successful',
    'سحب ناجح': 'withdrawal_successful',
    'تم توثيق الحساب بنجاح': 'account_verified_success',
    'جائزة عجلة الحظ': 'spin_wheel_reward',

    // Notification Messages
    'تم إيقاف حسابك مؤقتاً. يرجى التواصل مع الدعم.': 'notif_account_blocked_msg',
    'تمت إعادة تنشيط حسابك! يمكنك الآن تسجيل الدخول واستخدام التطبيق.':
        'notif_account_unblocked_msg',
    'تم تجميد حسابك. يرجى مراجعة خدمة العملاء.': 'notif_account_frozen_msg',
    'تم حذف حسابك من قبل الإدارة. اتصل بالدعم إذا كنت تعتقد أن هذا خطأ.':
        'notif_account_deleted_msg',
    'النظام يخضع للصيانة لتقديم أفضل خدمة. سنعود قريباً.':
        'notif_maintenance_msg',
    'تمت الموافقة على طلب السلفة الخاص بك. تم إضافة المبلغ إلى محفظتك.':
        'notif_loan_approved_msg',
    'تم توثيق حسابك بنجاح! يمكنك الآن الاستفادة من جميع الميزات.':
        'notif_kyc_verified_msg',
    'تم إيداع أرباحك اليومية بنجاح': 'daily_profits_deposited_msg',
    'طلب سحب قيد المعالجة': 'withdrawal_request_processing',
    'طلب السحب الخاص بك قيد الدراسة والمراجعة وسيتم التحويل قريبا':
        'withdrawal_request_review_msg',
    'استثمارك نضج — تم إرجاع رأس المال':
        'investment_matured_principal_returned',

    // Transactions
    'أرباح شهرية': 'txn_profit_monthly',
    'استثمار في العقارات': 'txn_invest_real_estate_legacy',
    'استحقاق الاستثمار - استعادة رأس المال': 'txn_investment_return',
    'إضافة رصيد من الإدارة': 'txn_admin_credit',
    'خصم رصيد من الإدارة': 'txn_admin_debit',
    'سداد السلفة كاملة': 'txn_loan_repayment_full',
    'سداد جزئي للسلفة': 'txn_loan_repayment_partial',
    'إيداع تجريبي مبدئي': 'txn_deposit_initial_test',
    'إيداع عبر وكيل': 'txn_deposit_agent_generic',
    'طلب سحب عبر وكيل': 'txn_withdrawal_request_agent',
    'طلب سحب': 'txn_withdrawal_request',
    'تحويل رصيد': 'txn_transfer_out_generic',
    'تحويل من مستخدم': 'txn_transfer_in_generic',
    'تحويل مستلم من صديق': 'txn_transfer_in_friend',
    'رسوم اشتراك VIP': 'txn_fee_vip_subscription',

    // Admin Reasons
    'البيانات غير مطابقة للمستندات المرفقة': 'reason_kyc_mismatch',
    'صورة الوثيقة غير واضحة أو غير مقروءة': 'reason_kyc_unclear_doc',
    'سجل الأرباح غير كافٍ للحصول على السلفة':
        'reason_loan_insufficient_earnings',
    'الحساب غير مؤهل للحصول على سلفة حالياً': 'reason_loan_ineligible',
    'مخالفة شروط وسياسات استخدام المنصة':
        'reason_account_policy_violation',
  };

  static String _localizePlanName(String planName) {
    if (Get.locale?.languageCode == 'ar') return planName;
    final clean = planName.trim();
    switch (clean) {
      case 'مركز استثمار الذهب':
        return 'Gold Investment Center';
      case 'مركز استثمار الفضة':
        return 'Silver Investment Center';
      case 'مركز استثمار العقارات':
        return 'Real Estate Investment Center';
      case 'مركز استثمار التكنولوجيا':
        return 'Technology Investment Center';
      default:
        return clean;
    }
  }

  /// Whether [value] looks like a localization key rather than free-form user text.
  static bool isLocalizationKey(String? value) {
    if (value == null) return false;
    final trimmed = value.trim();
    if (trimmed.isEmpty || trimmed.contains(' ')) return false;
    if (!_keyPattern.hasMatch(trimmed)) return false;
    if (_containsNonAsciiLetter(trimmed)) return false;
    if (KasbyL10n.hasKey(trimmed)) return true;
    return _knownPrefixes.any(trimmed.startsWith);
  }

  static bool _containsNonAsciiLetter(String value) {
    for (final codeUnit in value.codeUnits) {
      if (codeUnit > 127) return true;
    }
    return false;
  }

  /// Resolve any dynamic string — keys, JSON payloads, or passthrough text.
  static String resolve(
    String? value, {
    Map<String, String>? params,
    String? context,
  }) {
    if (value == null) return '';
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '';

    final parsed = _tryParsePayload(trimmed);
    if (parsed != null) {
      return _resolveKey(
        parsed.key,
        params: parsed.params ?? params,
        context: context,
      );
    }

    if (!isLocalizationKey(trimmed)) {
      return _resolveDynamicPatterns(trimmed);
    }

    return _resolveKey(trimmed, params: params, context: context);
  }

  static String _resolveDynamicPatterns(String trimmed) {
    // 1. Direct Map Lookup (O(1))
    final mappedKey = _exactDynamicMap[trimmed];
    if (mappedKey != null) {
      return _resolveKey(mappedKey);
    }

    final lowercase = trimmed.toLowerCase();
    if (lowercase == 'daily profit distribution' ||
        lowercase == 'توزيع الأرباح اليومية') {
      return _resolveKey('daily_profit_distribution');
    }
    if (lowercase == 'investment matured — principal returned' ||
        lowercase == 'investment matured - principal returned') {
      return _resolveKey('investment_matured_principal_returned');
    }

    // 2. Notification Message Patterns with Parameters
    final profitMatch = _profitMsgRegex.firstMatch(trimmed);
    if (profitMatch != null) {
      final amount = profitMatch.group(1)?.trim() ?? '';
      final plan = _localizePlanName(profitMatch.group(2)?.trim() ?? '');
      return _resolveKey(
        'notif_new_investment_profit_msg',
        params: {'amount': amount.startsWith('\$') ? amount : '\$$amount', 'plan': plan},
      );
    }

    final dailyWalletMatch = _dailyProfitsWalletRegex.firstMatch(trimmed);
    if (dailyWalletMatch != null) {
      final amount = dailyWalletMatch.group(1)?.trim() ?? '';
      return _resolveKey(
        'notif_daily_profits_wallet_msg',
        params: {'amount': amount.startsWith('\$') ? amount : '\$$amount'},
      );
    }

    final loanReqMatch = _loanRequestedRegex.firstMatch(trimmed);
    if (loanReqMatch != null) {
      return _resolveKey(
        'notif_loan_requested_msg',
        params: {'amount': loanReqMatch.group(1)?.trim() ?? ''},
      );
    }

    final loanRepayMatch = _loanRepaymentSuccessRegex.firstMatch(trimmed);
    if (loanRepayMatch != null) {
      return _resolveKey(
        'notif_loan_repayment_success_msg',
        params: {
          'paid': loanRepayMatch.group(1)?.trim() ?? '',
          'remaining': loanRepayMatch.group(2)?.trim() ?? '',
        },
      );
    }

    final friendMatch = _friendRequestRegex.firstMatch(trimmed);
    if (friendMatch != null) {
      return _resolveKey(
        'notif_friend_request_msg',
        params: {'user': friendMatch.group(1)?.trim() ?? ''},
      );
    }

    final balanceAdjMatch = _balanceAdjustmentRegex.firstMatch(trimmed);
    if (balanceAdjMatch != null) {
      return _resolveKey(
        'notif_balance_adjustment_msg',
        params: {'amount': balanceAdjMatch.group(1)?.trim() ?? ''},
      );
    }

    final adminDepMatch = _adminDepositPendingRegex.firstMatch(trimmed);
    if (adminDepMatch != null) {
      return _resolveKey(
        'notif_admin_deposit_pending_msg',
        params: {
          'user': adminDepMatch.group(1)?.trim() ?? '',
          'amount': adminDepMatch.group(2)?.trim() ?? '',
        },
      );
    }

    final adminWithMatch = _adminWithdrawalPendingRegex.firstMatch(trimmed);
    if (adminWithMatch != null) {
      return _resolveKey(
        'notif_admin_withdrawal_pending_msg',
        params: {
          'user': adminWithMatch.group(1)?.trim() ?? '',
          'amount': adminWithMatch.group(2)?.trim() ?? '',
        },
      );
    }

    final kspNotifMatch = _kspRedeemNotifRegex.firstMatch(trimmed);
    if (kspNotifMatch != null) {
      return _resolveKey(
        'notif_ksp_redeem_success_msg',
        params: {
          'points': kspNotifMatch.group(1)?.trim() ?? '',
          'amount': kspNotifMatch.group(2)?.trim() ?? '',
        },
      );
    }

    final matureNotifMatch = _investMaturedNotifRegex.firstMatch(trimmed);
    if (matureNotifMatch != null) {
      final plan = _localizePlanName(matureNotifMatch.group(1)?.trim() ?? '');
      final amount = matureNotifMatch.group(2)?.trim() ?? '';
      return _resolveKey(
        'notif_investment_matured_msg',
        params: {'plan': plan, 'amount': amount},
      );
    }

    // 3. Transaction Description Patterns with Parameters
    final txnProfitDailyMatch = _txnProfitDailyRegex.firstMatch(trimmed);
    if (txnProfitDailyMatch != null) {
      final plan = _localizePlanName(txnProfitDailyMatch.group(1)?.trim() ?? '');
      return _resolveKey(
        'txn_profit_daily_from_plan',
        params: {'plan': plan},
      );
    }

    final txnProfitAltMatch = _txnProfitDailyAltRegex.firstMatch(trimmed);
    if (txnProfitAltMatch != null) {
      final plan = _localizePlanName(txnProfitAltMatch.group(1)?.trim() ?? '');
      return _resolveKey(
        'txn_profit_daily_plan_alt',
        params: {'plan': plan},
      );
    }

    final txnInvestPrefixedMatch = _txnInvestPlanPrefixedRegex.firstMatch(trimmed);
    if (txnInvestPrefixedMatch != null) {
      final plan = _localizePlanName(txnInvestPrefixedMatch.group(1)?.trim() ?? '');
      return _resolveKey(
        'txn_invest_in_plan_prefixed',
        params: {'plan': plan},
      );
    }

    final txnInvestMatch = _txnInvestPlanRegex.firstMatch(trimmed);
    if (txnInvestMatch != null) {
      final plan = _localizePlanName(txnInvestMatch.group(1)?.trim() ?? '');
      return _resolveKey(
        'txn_invest_in_plan',
        params: {'plan': plan},
      );
    }

    final txnLoanDisburseMatch = _txnLoanDisburseRegex.firstMatch(trimmed);
    if (txnLoanDisburseMatch != null) {
      return _resolveKey(
        'txn_loan_disbursement_months',
        params: {'months': txnLoanDisburseMatch.group(1)?.trim() ?? ''},
      );
    }

    final txnDepositAgentMatch = _txnDepositAgentRegex.firstMatch(trimmed);
    if (txnDepositAgentMatch != null) {
      return _resolveKey(
        'txn_deposit_agent',
        params: {'agent': txnDepositAgentMatch.group(1)?.trim() ?? ''},
      );
    }

    final txnWithdrawalAgentMatch = _txnWithdrawalAgentRegex.firstMatch(trimmed);
    if (txnWithdrawalAgentMatch != null) {
      return _resolveKey(
        'txn_withdrawal_agent',
        params: {'agent': txnWithdrawalAgentMatch.group(1)?.trim() ?? ''},
      );
    }

    final txnTransferToMatch = _txnTransferToRegex.firstMatch(trimmed);
    if (txnTransferToMatch != null) {
      return _resolveKey(
        'txn_transfer_to_user',
        params: {'user': txnTransferToMatch.group(1)?.trim() ?? ''},
      );
    }

    final txnTransferFromMatch = _txnTransferFromRegex.firstMatch(trimmed);
    if (txnTransferFromMatch != null) {
      return _resolveKey(
        'txn_transfer_from_user',
        params: {'user': txnTransferFromMatch.group(1)?.trim() ?? ''},
      );
    }

    final txnRewardReferralMatch = _txnRewardReferralRegex.firstMatch(trimmed);
    if (txnRewardReferralMatch != null) {
      return _resolveKey(
        'txn_reward_referral_invest',
        params: {'user': txnRewardReferralMatch.group(1)?.trim() ?? ''},
      );
    }

    final txnRewardDepositMatch = _txnRewardDepositFeeRegex.firstMatch(trimmed);
    if (txnRewardDepositMatch != null) {
      return _resolveKey(
        'txn_reward_deposit_fee',
        params: {'amount': txnRewardDepositMatch.group(1)?.trim() ?? ''},
      );
    }

    final txnRewardWithdrawalMatch = _txnRewardWithdrawalFeeRegex.firstMatch(trimmed);
    if (txnRewardWithdrawalMatch != null) {
      return _resolveKey(
        'txn_reward_withdrawal_fee',
        params: {'amount': txnRewardWithdrawalMatch.group(1)?.trim() ?? ''},
      );
    }

    final txnKspRedeemMatch = _txnKspRedeemRegex.firstMatch(trimmed);
    if (txnKspRedeemMatch != null) {
      return _resolveKey(
        'txn_ksp_redemption',
        params: {
          'points': txnKspRedeemMatch.group(1)?.trim() ?? '',
          'amount': txnKspRedeemMatch.group(2)?.trim() ?? '',
        },
      );
    }

    final txnMarketplaceMatch = _txnMarketplaceRegex.firstMatch(trimmed);
    if (txnMarketplaceMatch != null) {
      return _resolveKey(
        'txn_marketplace_purchase',
        params: {'product': txnMarketplaceMatch.group(1)?.trim() ?? ''},
      );
    }

    // 4. Legacy patterns
    if (trimmed.startsWith('عمولة إحالة من استثمار ')) {
      final name = trimmed.substring('عمولة إحالة من استثمار '.length).trim();
      return _resolveKey(
        'referral_commission_from_investment',
        params: {'name': name},
      );
    }
    if (trimmed.startsWith('Referral commission from investment of ')) {
      final name = trimmed
          .substring('Referral commission from investment of '.length)
          .trim();
      return _resolveKey(
        'referral_commission_from_investment',
        params: {'name': name},
      );
    }

    final investMatchAr = _investAmountRegex.firstMatch(trimmed);
    if (investMatchAr != null) {
      final name = investMatchAr.group(1)?.trim();
      final amount = investMatchAr.group(2)?.trim();
      return _resolveKey(
        'user_invested_amount',
        params: {'name': name ?? '', 'amount': amount ?? ''},
      );
    }

    final matureMatchAr = _matureLegacyRegex.firstMatch(trimmed);
    if (matureMatchAr != null) {
      final name = matureMatchAr.group(1)?.trim();
      final amount = matureMatchAr.group(2)?.trim();
      return _resolveKey(
        'user_investment_matured_msg',
        params: {'name': name ?? '', 'amount': amount ?? ''},
      );
    }

    return trimmed;
  }

  static String resolveEnum(String prefix, String? enumValue) {
    if (enumValue == null || enumValue.isEmpty) return '';
    final key = 'enum_$prefix$enumValue';
    if (isLocalizationKey(key) || KasbyL10n.hasKey(key)) {
      return _resolveKey(key, context: 'enum');
    }
    return enumValue;
  }

  static String transactionTypeLabel(String type) => resolveEnum('txn_', type);

  static String transactionStatusLabel(String status) =>
      resolveEnum('status_', status);

  static String transactionDescription(TransactionModel tx) {
    if (tx.description != null && tx.description!.trim().isNotEmpty) {
      return resolve(tx.description, context: 'transaction');
    }
    return transactionTypeLabel(tx.type);
  }

  static String notificationTitle(NotificationModel notification) {
    if (notification.titleKey != null && notification.titleKey!.isNotEmpty) {
      final params = notification.parameters
          ?.map((k, v) => MapEntry(k, v?.toString() ?? ''));
      return tr(notification.titleKey!, params: params);
    }
    return resolve(notification.title, context: 'notification_title');
  }

  static String notificationMessage(NotificationModel notification) {
    if (notification.messageKey != null && notification.messageKey!.isNotEmpty) {
      final params = notification.parameters
          ?.map((k, v) => MapEntry(k, v?.toString() ?? ''));
      return tr(notification.messageKey!, params: params);
    }
    return resolve(notification.message, context: 'notification_message');
  }

  /// Convenience wrapper matching GetX `.tr` for UI code.
  static String tr(String key, {Map<String, String>? params}) {
    if (!isLocalizationKey(key)) return key;
    return _resolveKey(key, params: params);
  }

  static String _resolveKey(
    String key, {
    Map<String, String>? params,
    String? context,
  }) {
    try {
      if (Get.locale != null) {
        final translated = params == null || params.isEmpty
            ? key.tr
            : key.trParams(params);
        if (translated != key || KasbyL10n.hasKey(key)) return translated;
      }
    } catch (_) {
      // GetX not ready — fall through to static map lookup.
    }

    final fallback = KasbyL10n.tr(key, params: params);
    if (fallback == key) {
      LocalizationLogger.missingKey(
        key,
        locale: KasbyL10n.currentLocaleTag,
        context: context,
      );
    }
    return fallback;
  }

  static _Payload? _tryParsePayload(String raw) {
    if (!raw.startsWith('{')) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final key = decoded['key']?.toString();
      if (key == null || key.isEmpty) return null;
      final paramsRaw = decoded['params'];
      Map<String, String>? params;
      if (paramsRaw is Map) {
        params = paramsRaw.map(
          (k, v) => MapEntry(k.toString(), v?.toString() ?? ''),
        );
      }
      return _Payload(key: key, params: params);
    } catch (_) {
      LocalizationLogger.invalidKey(raw, reason: 'invalid_json_payload');
      return null;
    }
  }
}

class _Payload {
  final String key;
  final Map<String, String>? params;

  const _Payload({required this.key, this.params});
}
