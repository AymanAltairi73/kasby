import 'package:get/get.dart';
import 'package:kasby/core/services/enterprise_operations_logger.dart';
import 'package:kasby/core/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Secure self-service account deletion via the delete-own-account edge function.
class AccountDeletionService {
  AccountDeletionService._();

  static Future<void> deleteOwnAccount() async {
    final userId = SupabaseService.userId;
    if (userId == null) {
      throw AuthException('cannot_verify_identity'.tr);
    }

    EnterpriseOperationsLogger.log(
      domain: 'account_deletion',
      operation: 'self_delete_account',
      phase: 'START',
      userId: userId,
    );

    final response = await SupabaseService.client.functions.invoke(
      'delete-own-account',
      body: const {},
    );

    if (response.status != 200) {
      final data = response.data;
      String message = 'unexpected_error'.tr;
      if (data is Map) {
        final raw = data['error'] ?? data['message'];
        if (raw is String && raw.isNotEmpty) {
          message = raw;
        }
      }
      EnterpriseOperationsLogger.log(
        domain: 'account_deletion',
        operation: 'self_delete_account',
        phase: 'FAIL',
        status: 'ERROR',
        userId: userId,
        params: {'httpStatus': response.status},
      );
      throw AuthException(message);
    }

    EnterpriseOperationsLogger.log(
      domain: 'account_deletion',
      operation: 'self_delete_account',
      phase: 'COMPLETE',
      userId: userId,
    );
  }
}
