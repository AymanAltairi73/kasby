import 'package:kasby/core/services/supabase_service.dart';
import 'package:kasby/core/utils/safe_getx.dart';

/// Result of a referral code lookup against the database.
class ReferralCodeLookup {
  final String referrerId;
  final String canonicalCode;

  const ReferralCodeLookup({
    required this.referrerId,
    required this.canonicalCode,
  });
}

/// Service responsible for all referral-related operations:
/// - Validating referral codes during registration
/// - Processing referral commissions on investments
/// - Sending notifications to referrers
class ReferralService {
  ReferralService._();

  static final RegExp _codeFormat = RegExp(r'^K[A-Z0-9]{4,}$');

  static void _log(
    String message, {
    required String method,
    bool isError = false,
    dynamic error,
    Map<String, Object?>? params,
  }) {
    SafeGetx.debugTrace(
      className: 'ReferralService',
      method: method,
      feature: 'Core',
      status: isError ? 'ERROR' : 'INFO',
      message: message,
      params: params,
      error: error,
    );
  }

  /// Normalize referral code input (uppercase, strip hyphens for comparison).
  static String normalizeCode(String code) {
    return code.trim().toUpperCase().replaceAll('-', '');
  }

  /// Display format: K12345 (no hyphen), e.g. kXXXXX not k-XXXXX.
  static String formatDisplayCode(String? code) {
    if (code == null || code.trim().isEmpty) return '---';
    return normalizeCode(code);
  }

  /// Validate K0001-style format: K + at least 4 alphanumeric chars.
  static bool isValidFormat(String code) {
    return _codeFormat.hasMatch(normalizeCode(code));
  }

  /// Validate a referral code before registration.
  /// Returns lookup details if valid, null otherwise.
  static Future<ReferralCodeLookup?> validateReferralCode(String code) async {
    final normalized = normalizeCode(code);
    if (normalized.isEmpty || !isValidFormat(normalized)) return null;

    try {
      final result = await SupabaseService.client.rpc(
        'validate_referral_code',
        params: {'p_code': code.trim()},
      );

      final payload = _coerceJsonMap(result);
      if (payload == null || payload['valid'] != true) {
        _log(
          'Referral code not found',
          method: 'validateReferralCode',
          params: {
            'codeLength': normalized.length,
            'reason': payload?['reason'] ?? 'unknown',
          },
        );
        return null;
      }

      final referrerId = payload['referrer_id'] as String?;
      final canonicalCode = payload['referral_code'] as String?;
      if (referrerId == null || canonicalCode == null) return null;

      _log(
        'Referral code validated',
        method: 'validateReferralCode',
        params: {'referrerId': referrerId},
      );
      return ReferralCodeLookup(
        referrerId: referrerId,
        canonicalCode: canonicalCode,
      );
    } catch (e) {
      _log(
        'Error validating referral code',
        method: 'validateReferralCode',
        isError: true,
        error: e,
      );
      return null;
    }
  }

  static Map<String, dynamic>? _coerceJsonMap(dynamic result) {
    if (result is Map<String, dynamic>) return result;
    if (result is Map) return result.cast<String, dynamic>();
    return null;
  }

  /// Link a new user to a referrer after successful registration.
  /// Called after signup with the referrer's ID.
  static Future<bool> linkReferral({
    required String newUserId,
    required String referrerId,
  }) async {
    try {
      await SupabaseService.client
          .from('profiles')
          .update({'referred_by': referrerId})
          .eq('id', newUserId);

      _log(
        'User linked to referrer',
        method: 'linkReferral',
        params: {'newUserId': newUserId, 'referrerId': referrerId},
      );

      await SupabaseService.logActivity(
        action: 'REFERRAL_LINKED',
        details: 'User $newUserId was referred by $referrerId',
        severity: 'info',
      );

      return true;
    } catch (e) {
      _log(
        'Error linking referral',
        method: 'linkReferral',
        isError: true,
        error: e,
      );
      return false;
    }
  }

  /// Process referral commission when an investment is made.
  static Future<void> processReferralCommission({
    required double investmentAmount,
    String? investmentId,
    String? planName,
  }) async {
    if (!SupabaseService.isLoggedIn) return;

    try {
      final result = await SupabaseService.client.rpc(
        'process_referral_commission',
        params: {
          'p_investor_id': SupabaseService.userId!,
          'p_investment_amount': investmentAmount,
          'p_investment_id': investmentId,
          'p_plan_name': planName,
        },
      );

      final Map<String, dynamic>? response =
          result is Map ? Map<String, dynamic>.from(result as Map) : null;

      if (response != null && response['success'] == true) {
        final commission = response['commission'] as num?;
        _log(
          'Referral commission processed',
          method: 'processReferralCommission',
          params: {'commission': commission?.toStringAsFixed(2)},
        );
      } else {
        _log(
          'No referral commission to process',
          method: 'processReferralCommission',
          params: {'message': response?['message'] ?? 'no referrer'},
        );
      }
    } catch (e) {
      _log(
        'Error processing referral commission',
        method: 'processReferralCommission',
        isError: true,
        error: e,
      );
    }
  }

  /// Fetch referral earnings for the current user (as a referrer).
  static Future<List<Map<String, dynamic>>> fetchMyReferralEarnings() async {
    if (!SupabaseService.isLoggedIn) return [];

    try {
      final response = await SupabaseService.client
          .from('referral_earnings')
          .select('*, investor:investor_id(full_name)')
          .eq('referrer_id', SupabaseService.userId!)
          .order('created_at', ascending: false)
          .limit(50);

      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      _log(
        'Error fetching referral earnings',
        method: 'fetchMyReferralEarnings',
        isError: true,
        error: e,
      );
      return [];
    }
  }

  /// Get total referral earnings for the current user.
  static Future<double> fetchTotalReferralEarnings() async {
    if (!SupabaseService.isLoggedIn) return 0.0;

    try {
      final response = await SupabaseService.client
          .from('referral_earnings')
          .select('commission_amount')
          .eq('referrer_id', SupabaseService.userId!);

      double total = 0.0;
      for (final row in (response as List)) {
        total += (row['commission_amount'] as num).toDouble();
      }
      return total;
    } catch (e) {
      _log(
        'Error fetching total referral earnings',
        method: 'fetchTotalReferralEarnings',
        isError: true,
        error: e,
      );
      return 0.0;
    }
  }
}
