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
  print('=== INVESTIGATING STRICT DRY RUN RESULT DISCREPANCY ===\n');

  // Check if any backfill transactions have been created (sanity check 10)
  final backfillTxns = await get(
      '/rest/v1/transactions?reference_id=like.historical_profit*&select=id,created_at,amount,reference_id');
  print('Historical backfill transactions in DB: ${backfillTxns.length}');

  // Check recent transactions (last 24 hours)
  final recentTxns = await get(
      '/rest/v1/transactions?order=created_at.desc&limit=25&select=id,user_id,type,amount,reference_id,created_at');
  print('\nMost recent 10 transactions in DB:');
  for (int i = 0; i < (recentTxns.length < 10 ? recentTxns.length : 10); i++) {
    final t = recentTxns[i];
    print('  - ${t['created_at']} | Type: ${t['type']} | Amount: ${t['amount']} | Ref: ${t['reference_id']} | User: ${t['user_id']}');
  }

  // Fetch all plans
  final plans = await get('/rest/v1/investment_plans?select=*');
  final planMap = <String, Map<String, dynamic>>{};
  for (final pl in plans) planMap[pl['id']] = Map<String, dynamic>.from(pl);

  // Fetch all profiles
  final profiles = await get('/rest/v1/profiles?select=id,full_name,email');
  final profMap = <String, Map<String, dynamic>>{};
  for (final pr in profiles) profMap[pr['id']] = Map<String, dynamic>.from(pr);

  // The 12 users from the previous report:
  final previous12Users = {
    'ae2321a7-b8bd-4959-91a8-196854c3cc32': 'المهندس محمد العراقي.',
    '4675897b-20d5-4951-bc91-4da562215cc3': 'ايمن الطيري بواحمد',
    '5e5ba185-a26f-4c9a-8413-78affbf48995': 'ايمن احمد الطيري (ابو اسد)',
    '8f1720d1-69d5-4d29-a496-03e1f3ea81ab': 'المهندس ايمن احمد',
    '984fbc5a-663a-4207-b4c8-f086f93701ea': 'ابو سعد',
    '34e3337d-7f01-45fa-8dba-b7488507df93': 'حسين شهاب احمد كزار',
    '8963306f-4a46-42ff-8394-4d02cd3c3500': 'سجاد',
    'e5201c53-a47c-45c3-a776-c17d44b2c192': 'ليث',
    '7ce89452-c4d8-4867-8343-558148cc2bd9': 'ايمن احمد',
    'c33f59c4-ee76-4568-a767-534cfb9529e0': 'سجاد البطاط',
    '33f6b995-1fae-4d29-b7fb-3cb765d18d19': 'مختبر تطبيق كاسبي',
    '7adf3f78-5340-443b-a965-738ea29633d7': 'مبارك الطيري',
  };

  // Exactly simulate SQL WHERE clause:
  // WHERE ui.status = 'active'
  //   AND ui.created_at < '2026-09-20 00:00:00+00'
  //   AND (p_scope = 'strict' AND (ui.next_payout_at IS NOT NULL OR ui.auto_restart_enabled = TRUE))
  final strictInvs = await get(
      '/rest/v1/user_investments?status=eq.active&created_at=lt.2026-09-20T00:00:00Z&select=*&order=created_at.asc');
  
  final filteredStrictInvs = <Map<String, dynamic>>[];
  for (final inv in strictInvs) {
    if (inv['next_payout_at'] != null || inv['auto_restart_enabled'] == true) {
      filteredStrictInvs.add(inv);
    }
  }

  print('\nTotal investments matching SQL strict query: ${filteredStrictInvs.length}');

  // Fetch all profit transactions in DB to test idempotency check
  final allProfitTxns = await get(
      '/rest/v1/transactions?type=eq.profit&select=id,user_id,amount,reference_id,created_at&order=created_at.asc');

  final txnsByInv = <String, List<Map<String, dynamic>>>{};
  for (final tx in allProfitTxns) {
    final ref = tx['reference_id']?.toString() ?? '';
    if (ref.isNotEmpty) {
      txnsByInv.putIfAbsent(ref, () => []).add(Map<String, dynamic>.from(tx));
    }
  }

  final failureStart = DateTime.parse('2026-09-12T20:41:00Z');
  final failureEnd = DateTime.parse('2026-09-20T00:00:00Z');

  int totalEligibleCycles = 0;
  double totalReconciledAmount = 0.0;
  final affectedUsersSet = <String>{};
  final userTotals = <String, Map<String, dynamic>>{};
  final invTotals = <String, Map<String, dynamic>>{};

  for (final inv in filteredStrictInvs) {
    final invId = inv['id'] as String;
    final userId = inv['user_id'] as String;
    final planId = inv['plan_id'] as String;
    final plan = planMap[planId] ?? {};
    final planDurationDays = (plan['duration_days'] as num?)?.toInt() ?? 30;

    final expectedProfit = (inv['expected_profit'] as num?)?.toDouble() ?? 0.0;
    final actualProfit = (inv['actual_profit'] as num?)?.toDouble() ?? 0.0;
    double remainingCap = (expectedProfit - actualProfit).clamp(0.0, double.infinity);

    if (remainingCap <= 0.001) continue;

    final dailyProfit = double.parse((expectedProfit / planDurationDays).toStringAsFixed(2));
    if (dailyProfit <= 0) continue;

    final createdAt = DateTime.parse(inv['created_at'] as String);
    DateTime cycleCursor = createdAt.add(const Duration(hours: 24));
    if (cycleCursor.isBefore(failureStart)) {
      cycleCursor = failureStart;
    }

    final existingTxns = txnsByInv[invId] ?? [];
    int invEligibleCycles = 0;
    double invReconciledAmount = 0.0;

    while (cycleCursor.isBefore(failureEnd)) {
      final cycleDateStr = cycleCursor.toIso8601String().substring(0, 10);
      final deterministicRef = 'historical_profit:$invId:$cycleDateStr';

      // Check existing transactions
      bool alreadyPaid = false;
      for (final tx in existingTxns) {
        final txRef = tx['reference_id']?.toString() ?? '';
        final txDate = DateTime.parse(tx['created_at'] as String);
        if (txRef == deterministicRef ||
            (tx['type'] == 'profit' &&
                txRef == invId &&
                txDate.difference(cycleCursor).inSeconds.abs() < 64800)) {
          alreadyPaid = true;
          break;
        }
      }

      if (!alreadyPaid) {
        double payable = remainingCap < dailyProfit ? remainingCap : dailyProfit;
        if (payable <= 0.001) break;

        totalEligibleCycles++;
        totalReconciledAmount += payable;
        remainingCap -= payable;
        invEligibleCycles++;
        invReconciledAmount += payable;

        affectedUsersSet.add(userId);
      }

      cycleCursor = cycleCursor.add(const Duration(hours: 24));
    }

    if (invEligibleCycles > 0) {
      invTotals[invId] = {
        'investment_id': invId,
        'user_id': userId,
        'plan': plan['name_ar'] ?? plan['name_en'] ?? 'Unknown',
        'eligible_cycles': invEligibleCycles,
        'reconciled_amount': invReconciledAmount,
        'actual_profit': actualProfit,
        'expected_profit': expectedProfit,
        'next_payout_at': inv['next_payout_at'],
        'auto_restart': inv['auto_restart_enabled'],
      };

      userTotals.putIfAbsent(userId, () => {
        'user_id': userId,
        'name': profMap[userId]?['full_name'] ?? 'Unknown',
        'email': profMap[userId]?['email'] ?? 'Unknown',
        'investments': 0,
        'cycles': 0,
        'amount': 0.0,
      });
      final u = userTotals[userId]!;
      u['investments'] = (u['investments'] as int) + 1;
      u['cycles'] = (u['cycles'] as int) + invEligibleCycles;
      u['amount'] = (u['amount'] as double) + invReconciledAmount;
    }
  }

  print('\n=== SIMULATED SQL FUNCTION RESULTS ===');
  print('Affected Users Count: ${affectedUsersSet.length}');
  print('Total Eligible Cycles: $totalEligibleCycles');
  print('Total Reconciled Amount: $totalReconciledAmount');

  print('\n=== USERS IN CURRENT STRICT RESULT (${userTotals.length} users) ===');
  for (final u in userTotals.values) {
    print('  - User: ${u['name']} (${u['email']}) | Inv Count: ${u['investments']} | Cycles: ${u['cycles']} | Amount: \$${(u['amount'] as double).toStringAsFixed(4)}');
  }

  print('\n=== CHECKING WHICH OF THE PREVIOUS 12 USERS ARE MISSING ===');
  for (final entry in previous12Users.entries) {
    if (!affectedUsersSet.contains(entry.key)) {
      print('MISSING USER: ${entry.value} (ID: ${entry.key})');
      // Investigate why this user is missing!
      final userInvs = await get('/rest/v1/user_investments?user_id=eq.${entry.key}&select=*');
      print('  Total investments for this user in DB: ${userInvs.length}');
      for (final ui in userInvs) {
        print('    Inv: ${ui['id']} | Status: ${ui['status']} | Created: ${ui['created_at']} | NextPayout: ${ui['next_payout_at']} | AutoRestart: ${ui['auto_restart_enabled']} | Exp: ${ui['expected_profit']} | Act: ${ui['actual_profit']}');
      }
    }
  }
}
