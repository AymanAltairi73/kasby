import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:kasby/core/services/supabase_service.dart';

/// Service responsible for all referral-related operations:
/// - Validating referral codes during registration
/// - Processing referral commissions on investments
/// - Sending notifications to referrers
class ReferralService {
  ReferralService._();

  static const String _logTag = '[REFERRAL]';

  static void _log(String message, {bool isError = false, dynamic error}) {
    debugPrint('$_logTag ${isError ? "❌" : "ℹ️"} $message');
    if (error != null) debugPrint('$_logTag 🔴 Details: $error');
  }

  /// Validate a referral code before registration.
  /// Returns the referrer's user ID if valid, null otherwise.
  /// Also prevents self-referral (though at registration time the user doesn't exist yet,
  /// this is mainly used as a safeguard).
  static Future<String?> validateReferralCode(String code) async {
    if (code.trim().isEmpty) return null;

    try {
      final response = await SupabaseService.client
          .from('profiles')
          .select('id')
          .eq('referral_code', code.trim().toUpperCase())
          .maybeSingle();

      if (response == null) {
        _log('Referral code not found: $code');
        return null;
      }

      final referrerId = response['id'] as String;

      // Prevent self-referral (safeguard for edge cases)
      if (SupabaseService.userId != null && referrerId == SupabaseService.userId) {
        _log('Self-referral attempt blocked');
        return null;
      }

      _log('Referral code validated successfully: $code -> $referrerId');
      return referrerId;
    } catch (e) {
      _log('Error validating referral code', isError: true, error: e);
      return null;
    }
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
          .update({'referred_by_id': referrerId})
          .eq('id', newUserId);

      _log('User $newUserId linked to referrer $referrerId');

      // Log the referral activity
      await SupabaseService.logActivity(
        action: 'REFERRAL_LINKED',
        details: 'User $newUserId was referred by $referrerId',
        severity: 'info',
      );

      return true;
    } catch (e) {
      _log('Error linking referral', isError: true, error: e);
      return false;
    }
  }

  /// Process referral commission when an investment is made.
  /// This is called after a successful investment by a referred user.
  /// 
  /// The function:
  /// 1. Checks if the investor has a referrer
  /// 2. Calculates 2% commission
  /// 3. Records it in referral_earnings (with investment_id for idempotency)
  /// 4. Adds the commission to the referrer's wallet
  /// 5. Sends a notification to the referrer
  static Future<void> processReferralCommission({
    required double investmentAmount,
    String? investmentId,
  }) async {
    if (!SupabaseService.isLoggedIn) return;

    try {
      // Call the RPC function that handles everything atomically
      final result = await SupabaseService.client.rpc(
        'process_referral_commission',
        params: {
          'p_investor_id': SupabaseService.userId!,
          'p_investment_amount': investmentAmount,
          'p_investment_id': investmentId,
        },
      );

      final response = result as Map<String, dynamic>?;

      if (response != null && response['success'] == true) {
        final commission = response['commission'] as num?;
        final referrerName = response['referrer_name'] as String?;
        _log('Referral commission processed: \$${commission?.toStringAsFixed(2)} to $referrerName');
      } else {
        // No referrer or already processed - this is normal, not an error
        _log('No referral commission to process: ${response?['message'] ?? 'no referrer'}');
      }
    } catch (e) {
      // Don't throw - referral commission failure should not block the investment
      _log('Error processing referral commission', isError: true, error: e);
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
      _log('Error fetching referral earnings', isError: true, error: e);
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
      _log('Error fetching total referral earnings', isError: true, error: e);
      return 0.0;
    }
  }

  /// Generate a unique 5-character referral code (k-XXXXX).
  /// Uses uppercase alphanumeric characters.
  static String generateReferralCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // Excluded similar looking chars O, 0, I, 1
    final random = math.Random.secure();
    String code = '';
    for (int i = 0; i < 5; i++) {
      code += chars[random.nextInt(chars.length)];
    }
    return 'K-$code';
  }
}
