import 'package:kasby/core/models/recurring_investment_model.dart';
import 'package:kasby/core/services/supabase_service.dart';
import 'package:kasby/core/utils/safe_getx.dart';

class RecurringInvestmentService {
  RecurringInvestmentService._();

  static const _table = 'recurring_investments';

  static Future<List<RecurringInvestmentModel>> fetchAll() async {
    return SafeGetx.traceAsync(
      className: 'RecurringInvestmentService',
      method: 'fetchAll',
      feature: 'RecurringInvestment',
      operation: () async {
        if (!SupabaseService.isLoggedIn) return [];
        try {
          final response = await SupabaseService.client
              .from(_table)
              .select()
              .eq('user_id', SupabaseService.userId!)
              .order('created_at', ascending: false);

          return (response as List)
              .map((json) => RecurringInvestmentModel.fromJson(json))
              .toList();
        } catch (e) {
          if (_isTableNotFoundError(e)) return [];
          rethrow;
        }
      },
      onSuccessParams: (result) => {'count': result.length},
    );
  }

  static Future<RecurringInvestmentModel?> create({
    required String planId,
    required double amount,
    required String frequency,
    int? customDays,
    String? planName,
  }) async {
    return SafeGetx.traceAsync(
      className: 'RecurringInvestmentService',
      method: 'create',
      feature: 'RecurringInvestment',
      params: {
        'planId': planId,
        'amount': amount,
        'frequency': frequency,
        'customDays': customDays,
      },
      operation: () async {
        if (!SupabaseService.isLoggedIn) return null;
        try {
          final nextDate = _calculateNextExecution(frequency, customDays);
          final data = {
            'user_id': SupabaseService.userId!,
            'plan_id': planId,
            'plan_name': planName,
            'amount': amount,
            'frequency': frequency,
            'custom_days': customDays,
            'status': 'active',
            'next_execution_date': nextDate.toIso8601String(),
            'total_executions': 0,
            'successful_executions': 0,
            'failed_executions': 0,
          };

          final response = await SupabaseService.client
              .from(_table)
              .insert(data)
              .select()
              .single();

          return RecurringInvestmentModel.fromJson(response);
        } catch (e) {
          if (_isTableNotFoundError(e)) return null;
          rethrow;
        }
      },
    );
  }

  static Future<bool> pause(String id) async {
    return SafeGetx.traceAsync(
      className: 'RecurringInvestmentService',
      method: 'pause',
      feature: 'RecurringInvestment',
      params: {'id': id},
      operation: () async {
        try {
          await SupabaseService.client
              .from(_table)
              .update({
                'status': 'paused',
                'updated_at': DateTime.now().toIso8601String(),
              })
              .eq('id', id);
          return true;
        } catch (e) {
          if (_isTableNotFoundError(e)) return false;
          rethrow;
        }
      },
    );
  }

  static Future<bool> resume(String id, {String? frequency, int? customDays}) async {
    return SafeGetx.traceAsync(
      className: 'RecurringInvestmentService',
      method: 'resume',
      feature: 'RecurringInvestment',
      params: {'id': id},
      operation: () async {
        try {
          final freq = frequency ?? 'monthly';
          final nextDate = _calculateNextExecution(freq, customDays);
          await SupabaseService.client
              .from(_table)
              .update({
                'status': 'active',
                'next_execution_date': nextDate.toIso8601String(),
                'updated_at': DateTime.now().toIso8601String(),
              })
              .eq('id', id);
          return true;
        } catch (e) {
          if (_isTableNotFoundError(e)) return false;
          rethrow;
        }
      },
    );
  }

  static Future<bool> cancel(String id) async {
    return SafeGetx.traceAsync(
      className: 'RecurringInvestmentService',
      method: 'cancel',
      feature: 'RecurringInvestment',
      params: {'id': id},
      operation: () async {
        try {
          await SupabaseService.client
              .from(_table)
              .update({
                'status': 'cancelled',
                'next_execution_date': null,
                'updated_at': DateTime.now().toIso8601String(),
              })
              .eq('id', id);
          return true;
        } catch (e) {
          if (_isTableNotFoundError(e)) return false;
          rethrow;
        }
      },
    );
  }

  static Future<RecurringInvestmentModel?> edit(
    String id, {
    double? amount,
    String? frequency,
    int? customDays,
  }) async {
    return SafeGetx.traceAsync(
      className: 'RecurringInvestmentService',
      method: 'edit',
      feature: 'RecurringInvestment',
      params: {'id': id, 'amount': amount, 'frequency': frequency},
      operation: () async {
        try {
          final updates = <String, dynamic>{
            'updated_at': DateTime.now().toIso8601String(),
          };
          if (amount != null) updates['amount'] = amount;
          if (frequency != null) {
            updates['frequency'] = frequency;
            updates['next_execution_date'] =
                _calculateNextExecution(frequency, customDays).toIso8601String();
          }
          if (customDays != null) updates['custom_days'] = customDays;

          final response = await SupabaseService.client
              .from(_table)
              .update(updates)
              .eq('id', id)
              .select()
              .single();

          return RecurringInvestmentModel.fromJson(response);
        } catch (e) {
          if (_isTableNotFoundError(e)) return null;
          rethrow;
        }
      },
    );
  }

  static DateTime _calculateNextExecution(String frequency, int? customDays) {
    final now = DateTime.now();
    switch (frequency) {
      case 'daily':
        return now.add(const Duration(days: 1));
      case 'weekly':
        return now.add(const Duration(days: 7));
      case 'monthly':
        return DateTime(now.year, now.month + 1, now.day);
      case 'custom':
        return now.add(Duration(days: customDays ?? 30));
      default:
        return now.add(const Duration(days: 30));
    }
  }

  static bool _isTableNotFoundError(Object e) {
    final msg = e.toString().toLowerCase();
    return msg.contains('relation') && msg.contains('does not exist') ||
        msg.contains('404') ||
        msg.contains('not found') && msg.contains('table');
  }
}
