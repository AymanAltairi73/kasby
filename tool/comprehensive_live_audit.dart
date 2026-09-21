import 'dart:convert';
import 'dart:io';

const supabaseUrl = 'https://majnuiypsgosbzsaeefc.supabase.co';
const serviceKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1ham51aXlwc2dvc2J6c2FlZWZjIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MjA3MDk3NSwiZXhwIjoyMDg3NjQ2OTc1fQ.5EoQZEgv9HmYLYIlF14vzd6u3qNX9LmJB-RtzE4sA1Q';

Future<dynamic> get(String path) async {
  final client = HttpClient();
  final req = await client.openUrl('GET', Uri.parse('$supabaseUrl$path'));
  req.headers.set('apikey', serviceKey);
  req.headers.set('Authorization', 'Bearer $serviceKey');
  final res = await req.close();
  final body = await res.transform(utf8.decoder).join();
  return jsonDecode(body);
}

void main() async {
  print('=== COMPREHENSIVE LIVE DB RECONCILIATION AUDIT ===\n');

  // 1. Fetch Plans
  final plans = await get('/rest/v1/investment_plans?select=*');
  final planMap = <String, Map<String, dynamic>>{};
  for (final pl in plans) {
    planMap[pl['id'] as String] = Map<String, dynamic>.from(pl);
  }

  // 2. Fetch Profiles
  final profiles = await get('/rest/v1/profiles?select=id,full_name,email');
  final profMap = <String, Map<String, dynamic>>{};
  for (final pr in profiles) {
    profMap[pr['id'] as String] = Map<String, dynamic>.from(pr);
  }

  // 3. Fetch All 94 Active Investments
  final activeInvs = await get(
      '/rest/v1/user_investments?status=eq.active&select=*&order=created_at.asc');
  print('Loaded ${activeInvs.length} active investments.');

  // 4. Fetch All Profit Transactions in the database
  final profitTxns = await get(
      '/rest/v1/transactions?type=eq.profit&select=id,user_id,wallet_id,amount,reference_id,created_at,status&order=created_at.asc');
  print('Loaded ${profitTxns.length} existing profit transactions in DB.');

  // Index profit transactions by reference_id (which is investment_id)
  final txnsByInv = <String, List<Map<String, dynamic>>>{};
  for (final tx in profitTxns) {
    final ref = tx['reference_id']?.toString() ?? '';
    if (ref.isNotEmpty) {
      txnsByInv.putIfAbsent(ref, () => []).add(Map<String, dynamic>.from(tx));
    }
  }

  // Fetch all notifications with type daily_profit
  final profitNotifs = await get(
      '/rest/v1/notifications?type=eq.daily_profit&select=id,user_id,entity_id,created_at');
  final notifsByInv = <String, List<Map<String, dynamic>>>{};
  for (final n in profitNotifs) {
    final ent = n['entity_id']?.toString() ?? '';
    if (ent.isNotEmpty) {
      notifsByInv.putIfAbsent(ent, () => []).add(Map<String, dynamic>.from(n));
    }
  }

  final failureStart = DateTime.parse('2026-09-12T20:41:00Z');
  final fixTime = DateTime.parse('2026-09-20T00:00:00Z');
  final now = DateTime.now().toUtc();

  final userSummaries = <String, Map<String, dynamic>>{};
  final investmentReconciliations = <Map<String, dynamic>>[];
  final cycleReconciliations = <Map<String, dynamic>>[];

  double totalExpectedProfitAll = 0.0;
  double totalAlreadyPaidAll = 0.0;
  double totalUnpaidAll = 0.0;
  double totalRemainingCapAll = 0.0;
  double totalBoundedRecoverable = 0.0;
  double totalUnboundedTheoretical = 0.0;
  int totalMissedCyclesAll = 0;

  for (final inv in activeInvs) {
    final invId = inv['id'] as String;
    final userId = inv['user_id'] as String;
    final planId = inv['plan_id'] as String;
    final plan = planMap[planId] ?? {};
    final planName = plan['name_ar'] ?? plan['name_en'] ?? 'Unknown';
    final planDays = (plan['duration_days'] as num?)?.toInt() ?? 30;

    final profile = profMap[userId] ?? {};
    final userName = profile['full_name'] ?? 'Unknown';
    final userEmail = profile['email'] ?? 'Unknown';

    final principal = (inv['amount'] as num?)?.toDouble() ?? 0.0;
    final expectedProfit = (inv['expected_profit'] as num?)?.toDouble() ?? 0.0;
    final actualProfit = (inv['actual_profit'] as num?)?.toDouble() ?? 0.0;
    final remainingCap = (expectedProfit - actualProfit).clamp(0.0, double.infinity);
    final dailyProfit = planDays > 0 ? (expectedProfit / planDays) : 0.0;
    final dailyProfitRounded = double.parse(dailyProfit.toStringAsFixed(2));

    final createdAt = DateTime.parse(inv['created_at'] as String);
    final nextPayoutAt = inv['next_payout_at'] != null
        ? DateTime.parse(inv['next_payout_at'] as String)
        : null;
    final autoRestart = inv['auto_restart_enabled'] == true;

    // Existing transactions for this investment
    final existingTxns = txnsByInv[invId] ?? [];
    final existingNotifs = notifsByInv[invId] ?? [];

    // Calculate missed cycles during the outage window (from 2026-09-12 20:41 to 2026-09-20 00:00)
    // An investment was eligible for daily cycles if it was created before/during outage and active
    int missedCycles = 0;
    final missedDates = <DateTime>[];

    // Evaluate day by day between failureStart and fixTime
    DateTime cycleCursor = createdAt.isAfter(failureStart)
        ? createdAt.add(const Duration(hours: 24))
        : failureStart;

    while (cycleCursor.isBefore(fixTime)) {
      // Check if a transaction exists on this date (+/- 12 hours)
      bool alreadyPaid = false;
      for (final tx in existingTxns) {
        final txDate = DateTime.parse(tx['created_at'] as String);
        if (txDate.difference(cycleCursor).inHours.abs() < 18) {
          alreadyPaid = true;
          break;
        }
      }
      if (!alreadyPaid) {
        missedCycles++;
        missedDates.add(cycleCursor);
      }
      cycleCursor = cycleCursor.add(const Duration(hours: 24));
    }

    // Only consider investments with missed cycles or next_payout_at past failureStart
    final theoreticalMissed = dailyProfitRounded * missedCycles;
    final payableBounded = (theoreticalMissed > remainingCap) ? remainingCap : theoreticalMissed;

    totalExpectedProfitAll += expectedProfit;
    totalAlreadyPaidAll += actualProfit;
    totalUnpaidAll += (expectedProfit - actualProfit);
    totalRemainingCapAll += remainingCap;
    totalUnboundedTheoretical += theoreticalMissed;
    totalBoundedRecoverable += payableBounded;
    totalMissedCyclesAll += missedCycles;

    for (final mDate in missedDates) {
      cycleReconciliations.add({
        'investment_id': invId,
        'user_id': userId,
        'expected_payout_date': mDate.toIso8601String(),
        'tx_exists': false,
        'tx_ref': null,
        'tx_amount': 0.0,
        'notification_exists': false,
        'wallet_credited': false,
        'already_paid': false,
        'payable_amount': dailyProfitRounded,
      });
    }

    final invRow = {
      'investment_id': invId,
      'user_id': userId,
      'user_name': userName,
      'user_email': userEmail,
      'plan': planName,
      'start_date': inv['created_at'],
      'end_date': inv['end_date'],
      'principal': principal,
      'expected_total_profit': expectedProfit,
      'already_paid_profit': actualProfit,
      'remaining_profit_cap': remainingCap,
      'daily_profit': dailyProfitRounded,
      'missed_cycles': missedCycles,
      'unbounded_missed_amount': double.parse(theoreticalMissed.toStringAsFixed(2)),
      'proposed_backfill_amount': double.parse(payableBounded.toStringAsFixed(2)),
      'status': inv['status'],
      'auto_restart': autoRestart,
      'next_payout_at': inv['next_payout_at'],
      'existing_tx_count': existingTxns.length,
    };
    investmentReconciliations.add(invRow);

    if (payableBounded > 0) {
      userSummaries.putIfAbsent(userId, () => {
        'user_id': userId,
        'user_name': userName,
        'user_email': userEmail,
        'investments_count': 0,
        'total_principal': 0.0,
        'total_expected': 0.0,
        'total_already_paid': 0.0,
        'total_remaining_cap': 0.0,
        'total_missed_cycles': 0,
        'unbounded_theoretical': 0.0,
        'bounded_payable': 0.0,
      });
      final u = userSummaries[userId]!;
      u['investments_count'] = (u['investments_count'] as int) + 1;
      u['total_principal'] = (u['total_principal'] as double) + principal;
      u['total_expected'] = (u['total_expected'] as double) + expectedProfit;
      u['total_already_paid'] = (u['total_already_paid'] as double) + actualProfit;
      u['total_remaining_cap'] = (u['total_remaining_cap'] as double) + remainingCap;
      u['total_missed_cycles'] = (u['total_missed_cycles'] as int) + missedCycles;
      u['unbounded_theoretical'] = (u['unbounded_theoretical'] as double) + theoreticalMissed;
      u['bounded_payable'] = (u['bounded_payable'] as double) + payableBounded;
    }
  }

  // Save audit data to JSON for comprehensive analysis
  final auditResults = {
    'summary': {
      'total_active_investments_db': activeInvs.length,
      'total_affected_users': userSummaries.length,
      'total_affected_investments': investmentReconciliations.where((i) => (i['proposed_backfill_amount'] as double) > 0).length,
      'total_missed_cycles': totalMissedCyclesAll,
      'total_expected_profit_all_active': totalExpectedProfitAll,
      'total_already_paid_all_active': totalAlreadyPaidAll,
      'total_unpaid_all_active': totalUnpaidAll,
      'total_remaining_cap_all_active': totalRemainingCapAll,
      'total_unbounded_theoretical_missed': totalUnboundedTheoretical,
      'total_bounded_recoverable_profit': totalBoundedRecoverable,
    },
    'users': userSummaries.values.toList(),
    'investments': investmentReconciliations,
    'missed_cycles_count': cycleReconciliations.length,
  };

  File('tool/live_audit_results.json').writeAsStringSync(jsonEncode(auditResults));
  print('Audit completed successfully. Results saved to tool/live_audit_results.json');
  print('Summary:');
  print(jsonEncode(auditResults['summary']));
}
