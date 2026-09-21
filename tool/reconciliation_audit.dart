import 'dart:convert';
import 'dart:io';

const supabaseUrl = 'https://majnuiypsgosbzsaeefc.supabase.co';
const serviceKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1ham51aXlwc2dvc2J6c2FlZWZjIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MjA3MDk3NSwiZXhwIjoyMDg3NjQ2OTc1fQ.5EoQZEgv9HmYLYIlF14vzd6u3qNX9LmJB-RtzE4sA1Q';

final _client = HttpClient();

Future<dynamic> get(String path) async {
  final uri = Uri.parse('$supabaseUrl$path');
  final req = await _client.openUrl('GET', uri);
  req.headers.set('apikey', serviceKey);
  req.headers.set('Authorization', 'Bearer $serviceKey');
  final res = await req.close();
  final body = await res.transform(utf8.decoder).join();
  try {
    return jsonDecode(body);
  } catch (_) {
    return body;
  }
}

Future<void> main() async {
  print('=================================================================');
  print('          PHASE 1 & 2: FINANCIAL RECONCILIATION AUDIT            ');
  print('=================================================================\n');

  // 1. Last successful profit transactions in the database
  print('── 1. LAST SUCCESSFUL PROFIT TRANSACTIONS (type=profit) ──');
  final lastProfits = await get('/rest/v1/transactions?type=eq.profit&order=created_at.desc&limit=5');
  if (lastProfits is List) {
    for (final p in lastProfits) {
      print('Txn ${p['id']} | User ${p['user_id']} | Amount: \$${p['amount']} | Created: ${p['created_at']} | Desc: ${p['description']}');
    }
  }

  // 2. First failure in system_logs
  print('\n── 2. OLDEST SYSTEM_LOG EXCEPTION FOR profit_distribution_item_exception ──');
  final oldestLog = await get('/rest/v1/system_logs?action=eq.profit_distribution_item_exception&order=created_at.asc&limit=3');
  if (oldestLog is List) {
    for (final l in oldestLog) {
      print('Log ${l['id']} | Created: ${l['created_at']} | Details: ${l['details']}');
    }
  }

  // 3. Investment Plans lookup map
  final plansList = await get('/rest/v1/investment_plans?select=*');
  final plansMap = <String, Map<String, dynamic>>{};
  if (plansList is List) {
    for (final p in plansList) {
      plansMap[p['id']] = Map<String, dynamic>.from(p);
    }
  }

  // 4. Query all active investments
  print('\n── 3. AUDITING ALL ACTIVE USER INVESTMENTS ──');
  final activeInvs = await get('/rest/v1/user_investments?status=eq.active&select=*');
  final now = DateTime.now().toUtc();
  print('Current UTC time: ${now.toIso8601String()}');
  print('Total active investments found: ${(activeInvs as List).length}\n');

  int dueCount = 0;
  double totalMissingAmount = 0.0;
  final affectedUsers = <String>{};

  final reportRows = <Map<String, dynamic>>[];

  for (final inv in activeInvs) {
    final invId = inv['id'] as String;
    final userId = inv['user_id'] as String;
    final planId = inv['plan_id'] as String;
    final plan = plansMap[planId] ?? {};
    final planName = plan['name_ar'] ?? plan['name_en'] ?? 'Unknown';
    final planDays = (plan['duration_days'] as num?)?.toInt() ?? 30;

    final amount = (inv['amount'] as num?)?.toDouble() ?? 0.0;
    final expectedProfit = (inv['expected_profit'] as num?)?.toDouble() ?? 0.0;
    final actualProfit = (inv['actual_profit'] as num?)?.toDouble() ?? 0.0;
    final startDate = inv['start_date'] != null ? DateTime.parse(inv['start_date']) : null;
    final endDate = inv['end_date'] != null ? DateTime.parse(inv['end_date']) : null;
    final lastProfitAt = inv['last_profit_at'] != null ? DateTime.parse(inv['last_profit_at']) : null;
    final nextPayoutAt = inv['next_payout_at'] != null ? DateTime.parse(inv['next_payout_at']) : null;
    final autoRestart = inv['auto_restart_enabled'] == true;

    final dailyProfit = planDays > 0 ? (expectedProfit / planDays) : 0.0;

    // Check if payout is due
    final isDue = nextPayoutAt != null && now.isAfter(nextPayoutAt);
    if (isDue) {
      dueCount++;
      affectedUsers.add(userId);

      // Calculate how many days since nextPayoutAt
      final diff = now.difference(nextPayoutAt);
      final missedCycles = (diff.inHours / 24).floor() + 1;
      // Missing amount for these missed cycles
      final potentialMissedAmount = (dailyProfit * missedCycles);
      totalMissingAmount += potentialMissedAmount;

      reportRows.add({
        'investment_id': invId,
        'user_id': userId,
        'plan': planName,
        'principal': amount,
        'start_date': startDate?.toIso8601String(),
        'end_date': endDate?.toIso8601String(),
        'duration_days': planDays,
        'expected_profit': expectedProfit,
        'actual_profit': actualProfit,
        'daily_profit': double.parse(dailyProfit.toStringAsFixed(2)),
        'last_profit_at': lastProfitAt?.toIso8601String(),
        'next_payout_at': nextPayoutAt.toIso8601String(),
        'missed_cycles': missedCycles,
        'amount_missing': double.parse(potentialMissedAmount.toStringAsFixed(2)),
        'auto_restart': autoRestart,
        'is_due': true,
      });
    }
  }

  print('Due investments count: $dueCount');
  print('Distinct affected users count: ${affectedUsers.length}');
  print('Estimated total missed profit amount across all cycles: \$${totalMissingAmount.toStringAsFixed(2)}');

  // Print first 10 rows of detailed report
  print('\nSample 10 Affected Investments:');
  for (final r in reportRows.take(10)) {
    print('Inv: ${r['investment_id']} | User: ${r['user_id']} | Plan: ${r['plan']} | Principal: \$${r['principal']} | Expected: \$${r['expected_profit']} | Paid: \$${r['actual_profit']} | Daily: \$${r['daily_profit']} | NextPayout: ${r['next_payout_at']} | MissedCycles: ${r['missed_cycles']} | Missing: \$${r['amount_missing']}');
  }

  // 5. How does fn_cron_distribute_daily_profits currently advance next_payout_at?
  print('\n── 4. CURRENT RPC PAYOUT CYCLE LOGIC IN DB ──');
  print('In 20260912000000_non_subscribed_investment_lifecycle.sql:');
  print('Daily profit = ROUND(expected_profit / duration_days, 2)');
  print('For subscribed & auto_restart: next_payout_at = GREATEST(now, next_payout_at) + INTERVAL 24 hours');
  print('For non-subscribed: next_payout_at = NULL, status = not_active (requires user to manually click start next cycle!)');

  _client.close(force: true);
}
