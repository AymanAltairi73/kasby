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
  };

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
    final lowercase = trimmed.toLowerCase();

    // Exact matches
    if (trimmed == 'تم إنشاء الاستثمار 🚀') {
      return _resolveKey('investment_created_title');
    }
    if (trimmed == 'استثمارك نضج! 🎉') {
      return _resolveKey('investment_matured_title');
    }
    if (trimmed == '📈 استثمار جديد بانتظار المراجعة') {
      return _resolveKey('admin_investment_pending_title');
    }
    if (trimmed == 'عمولة إحالة 💰') {
      return _resolveKey('referral_commission_simple');
    }
    if (lowercase == 'daily profit distribution') {
      return _resolveKey('daily_profit_distribution');
    }
    if (lowercase == 'investment matured — principal returned' ||
        lowercase == 'investment matured - principal returned') {
      return _resolveKey('investment_matured_principal_returned');
    }

    // Pattern matches
    // 1. Referral commission: "عمولة إحالة من استثمار [Name]"
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

    // 2. Investment notification message: "[Name] استثمر [Amount] USD"
    final investMatchAr = RegExp(
      r'^(.+?)\s+استثمر\s+([\d\.]+)\s+USD$',
    ).firstMatch(trimmed);
    if (investMatchAr != null) {
      final name = investMatchAr.group(1)?.trim();
      final amount = investMatchAr.group(2)?.trim();
      return _resolveKey(
        'user_invested_amount',
        params: {'name': name ?? '', 'amount': amount ?? ''},
      );
    }

    // 3. Investment matured notification message: "استثمار [Name] بقيمة [Amount] اكتمل."
    final matureMatchAr = RegExp(
      r'^استثمار\s+(.+?)\s+بقيمة\s+([\d\.]+)\s+اكتمل\.$',
    ).firstMatch(trimmed);
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

  static String notificationTitle(NotificationModel notification) =>
      resolve(notification.title, context: 'notification_title');

  static String notificationMessage(NotificationModel notification) =>
      resolve(notification.message, context: 'notification_message');

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
