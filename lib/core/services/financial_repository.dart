import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:kasby/core/services/supabase_service.dart';
import 'package:kasby/core/services/crash_reporting_service.dart';
import 'package:kasby/core/services/crash_reporting/crash_error_category.dart';
import 'package:kasby/core/services/enterprise_operations_logger.dart';
import 'package:kasby/core/utils/safe_getx.dart';

/// Centralized financial RPC layer with idempotency persistence and error mapping.
class FinancialRepository {
  FinancialRepository._();

  static const _idempotencyPrefix = 'kasby_fin_idem_';
  static const _uuid = Uuid();

  static Future<String> _persistedIdempotencyKey(String operation) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_idempotencyPrefix$operation';
    final existing = prefs.getString(key);
    if (existing != null && existing.isNotEmpty) return existing;
    final fresh = _uuid.v4();
    await prefs.setString(key, fresh);
    return fresh;
  }

  static Future<void> clearIdempotencyKey(String operation) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_idempotencyPrefix$operation');
  }

  static Map<String, dynamic> _coerceMap(dynamic result) {
    if (result is Map<String, dynamic>) return result;
    if (result is Map) return result.cast<String, dynamic>();
    return {'success': false, 'error': 'Invalid response format'};
  }

  static String mapErrorMessage(
    Map<String, dynamic> response,
    String fallback,
  ) {
    // 1. Check machine-readable 'error' key first — maps to GetX translation keys
    final error = response['error']?.toString();
    if (error != null && error.isNotEmpty && error != 'null') {
      // Map known error codes to localized keys
      final errorKey = 'error_$error';
      final translated = errorKey.tr;
      // If GetX resolved it (not same as key), use it
      if (translated != errorKey) return translated;

      // Legacy pattern matching
      if (error.contains('PERMISSION_DENIED')) {
        return 'financial_permission_denied'.tr;
      }
      if (error.contains('SYSTEM_FROZEN')) return 'system_frozen'.tr;
      if (error.contains('insufficient_balance') ||
          error.contains('Insufficient balance')) {
        return 'insufficient_balance'.tr;
      }
      if (error.contains('Insufficient points')) {
        return 'insufficient_points'.tr;
      }
      if (error.contains('receiver_not_found') ||
          error.contains('Receiver not found')) {
        return 'receiver_not_found'.tr;
      }
      if (error.contains('pending withdrawal')) {
        return 'pending_withdrawal_exists'.tr;
      }
    }

    // 2. Structured balance detail — localized
    if (response['details'] != null && response['details'] is Map) {
      final details = response['details'] as Map;
      final available = (details['available_balance'] as num?)?.toDouble();
      final totalReq = (details['total_required'] as num?)?.toDouble();
      final fee = (details['fee'] as num?)?.toDouble() ?? 0;
      if (available != null && totalReq != null) {
        final feeStr = fee > 0
            ? ' (${'including_fees'.tr} \$${fee.toStringAsFixed(2)})'
            : '';
        return '${'insufficient_balance_detail'.tr} (\$${available.toStringAsFixed(2)}) / (\$${totalReq.toStringAsFixed(2)})$feeStr';
      }
    }

    // 3. Fallback to raw message (may be Arabic from backend)
    final message = response['message']?.toString();
    if (message != null && message.isNotEmpty && message != 'null') {
      return message;
    }

    return fallback;
  }

  static Future<Map<String, dynamic>> createWithdrawal({
    required double amount,
    required String agentId,
  }) async {
    final idempotencyKey = await _persistedIdempotencyKey(
      'withdraw_${amount.toStringAsFixed(2)}_$agentId',
    );

    try {
      final result = await SupabaseService.client.rpc(
        'create_withdrawal',
        params: {
          'p_amount': amount,
          'p_agent_id': agentId,
          'p_idempotency_key': idempotencyKey,
          'p_currency': 'USD',
        },
      );

      final response = _coerceMap(result);
      if (response['success'] == true) {
        await clearIdempotencyKey(
          'withdraw_${amount.toStringAsFixed(2)}_$agentId',
        );
      } else {
        await CrashReportingService.recordBusinessError(
          Exception(response['error']?.toString() ?? 'Withdraw failed'),
          category: CrashErrorCategory.wallet,
          operation: 'create_withdrawal',
          context: {'amount_range': CrashReportingService.balanceRange(amount)},
        );
      }
      return response;
    } catch (e, stack) {
      SafeGetx.debugTrace(
        className: 'FinancialRepository',
        method: 'createWithdrawal',
        feature: 'Wallet',
        status: 'ERROR',
        error: e,
        stackTrace: stack,
      );
      await CrashReportingService.recordBusinessError(
        e,
        category: CrashErrorCategory.wallet,
        operation: 'create_withdrawal',
      );
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> createTransfer({
    required double amount,
    required String receiverReferralCode,
    required bool isKsp,
  }) async {
    final normalizedCode = receiverReferralCode.trim();
    final operationKey = isKsp
        ? 'ksp_transfer'
        : 'usd_transfer_${amount.toStringAsFixed(2)}_$normalizedCode';
    final idempotencyKey = await _persistedIdempotencyKey(operationKey);

    try {
      final dynamic result;
      if (isKsp) {
        result = await SupabaseService.client.rpc(
          'fn_transfer_ksp',
          params: {
            'p_amount': amount.round(),
            'p_receiver_referral_code': normalizedCode,
            'p_idempotency_key': idempotencyKey,
          },
        );
      } else {
        result = await SupabaseService.client.rpc(
          'create_transfer',
          params: {
            'p_amount': amount,
            'p_receiver_referral_code': normalizedCode,
            'p_transfer_type': 'funds',
            'p_idempotency_key': idempotencyKey,
            // Disambiguates PostgREST when legacy 4-arg overload still exists.
            'p_fee_category': 'transfer',
          },
        );
      }

      final response = _coerceMap(result);
      if (response['success'] == true) {
        await clearIdempotencyKey(operationKey);
      } else {
        await CrashReportingService.recordBusinessError(
          Exception(response['error']?.toString() ?? 'Transfer failed'),
          category: CrashErrorCategory.wallet,
          operation: isKsp ? 'fn_transfer_ksp' : 'create_transfer',
        );
      }
      return response;
    } catch (e, stack) {
      SafeGetx.debugTrace(
        className: 'FinancialRepository',
        method: 'createTransfer',
        feature: 'Wallet',
        status: 'ERROR',
        error: e,
        stackTrace: stack,
      );
      await CrashReportingService.recordBusinessError(
        e,
        category: CrashErrorCategory.wallet,
        operation: isKsp ? 'fn_transfer_ksp' : 'create_transfer',
      );
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> createDeposit({
    required double amount,
    required String agentId,
  }) async {
    final idempotencyKey = await _persistedIdempotencyKey(
      'deposit_${amount.toStringAsFixed(2)}_$agentId',
    );

    try {
      EnterpriseOperationsLogger.log(
        domain: 'deposit',
        operation: 'create_deposit_request',
        phase: 'START',
        params: {'amount': amount.toStringAsFixed(2), 'agentId': agentId},
      );

      final result = await SupabaseService.client.rpc(
        'fn_create_deposit_request',
        params: {
          'p_amount': amount,
          'p_agent_id': agentId,
          'p_idempotency_key': idempotencyKey,
          'p_proof_url': null,
        },
      );

      final response = _coerceMap(result);
      if (response['success'] == true) {
        await clearIdempotencyKey(
          'deposit_${amount.toStringAsFixed(2)}_$agentId',
        );
        EnterpriseOperationsLogger.log(
          domain: 'deposit',
          operation: 'create_deposit_request',
          phase: 'COMPLETE',
          entityId: response['transaction_id']?.toString(),
        );
      } else {
        EnterpriseOperationsLogger.log(
          domain: 'deposit',
          operation: 'create_deposit_request',
          phase: 'FAIL',
          status: 'WARN',
          params: {'error': response['error']?.toString()},
        );
        await CrashReportingService.recordBusinessError(
          Exception(response['error']?.toString() ?? 'Deposit failed'),
          category: CrashErrorCategory.wallet,
          operation: 'fn_create_deposit_request',
        );
      }
      return response;
    } catch (e, stack) {
      SafeGetx.debugTrace(
        className: 'FinancialRepository',
        method: 'createDeposit',
        feature: 'Wallet',
        status: 'ERROR',
        error: e,
        stackTrace: stack,
      );
      await CrashReportingService.recordBusinessError(
        e,
        category: CrashErrorCategory.wallet,
        operation: 'fn_create_deposit_request',
      );
      rethrow;
    }
  }

  static Future<Map<String, dynamic>?> fetchTransactionDetails(
    String transactionId,
  ) async {
    try {
      final result = await SupabaseService.client.rpc(
        'fn_get_transaction_details',
        params: {'p_transaction_id': transactionId},
      );
      final response = _coerceMap(result);
      if (response['success'] == true) {
        return response['transaction'] as Map<String, dynamic>?;
      }
      return null;
    } catch (e) {
      SafeGetx.debugTrace(
        className: 'FinancialRepository',
        method: 'fetchTransactionDetails',
        feature: 'Wallet',
        status: 'ERROR',
        error: e,
      );
      return null;
    }
  }
}
