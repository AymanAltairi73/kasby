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
  print('================================================================');
  print('    KASBY AUDITED BACKFILL DRY-RUN & IDEMPOTENCY SIMULATION     ');
  print('================================================================\n');

  final plans = await get('/rest/v1/investment_plans?select=*');
  final planMap = <String, Map<String, dynamic>>{};
  for (final pl in plans) planMap[pl['id']] = Map<String, dynamic>.from(pl);

  final profiles = await get('/rest/v1/profiles?select=id,full_name,email');
  final profMap = <String, Map<String, dynamic>>{};
  for (final pr in profiles) profMap[pr['id']] = Map<String, dynamic>.from(pr);

  final allActiveInvs = await get('/rest/v1/user_investments?status=eq.active&select=*&order=created_at.asc');
  final allProfitTxns = await get('/rest/v1/transactions?type=eq.profit&select=id,user_id,amount,reference_id,created_at&order=created_at.asc');

  final txnsByInv = <String, List<Map<String, dynamic>>>{};
  for (final tx in allProfitTxns) {
    final ref = tx['reference_id']?.toString() ?? '';
    if (ref.isNotEmpty) {
      txnsByInv.putIfAbsent(ref, () => []).add(Map<String, dynamic>.from(tx));
    }
  }

  final failureStart = DateTime.parse('2026-09-12T20:41:00Z');
  final fixTime = DateTime.parse('2026-09-20T00:00:00Z');

  // Global simulated state:
  // 1. Applied deterministic references
  final simulatedAppliedReferences = <String>{};
  // 2. Updated actual_profit per investment (reflecting committed payouts)
  final simulatedCumulativeProfit = <String, double>{};
  for (final inv in allActiveInvs) {
    simulatedCumulativeProfit[inv['id'] as String] = (inv['actual_profit'] as num?)?.toDouble() ?? 0.0;
  }

  Map<String, dynamic> runSimulation(String runName) {
    print('\n--- EXECUTING $runName ---');
    int eligibleUsers = 0;
    int eligibleInvestments = 0;
    int eligibleCycles = 0;
    double totalProposedPayout = 0.0;
    double minPayout = 999999.0;
    double maxPayout = 0.0;

    final userTotals = <String, Map<String, dynamic>>{};
    final invBreakdown = <Map<String, dynamic>>[];
    final cycleDetails = <Map<String, dynamic>>[];

    for (final inv in allActiveInvs) {
      final invId = inv['id'] as String;
      final userId = inv['user_id'] as String;
      final planId = inv['plan_id'] as String;
      final plan = planMap[planId] ?? {};
      final planName = plan['name_ar'] ?? plan['name_en'] ?? 'Unknown';
      final planDays = (plan['duration_days'] as num?)?.toInt() ?? 30;

      final principal = (inv['amount'] as num?)?.toDouble() ?? 0.0;
      final expectedProfit = (inv['expected_profit'] as num?)?.toDouble() ?? 0.0;
      
      // Current actual profit in simulated database:
      final currentActualProfit = simulatedCumulativeProfit[invId]!;
      final remainingCap = (expectedProfit - currentActualProfit).clamp(0.0, double.infinity);
      final dailyProfit = planDays > 0 ? (expectedProfit / planDays) : 0.0;
      final dailyProfitRounded = double.parse(dailyProfit.toStringAsFixed(2));

      final createdAt = DateTime.parse(inv['created_at'] as String);
      final existingTxns = txnsByInv[invId] ?? [];

      DateTime cycleCursor = createdAt.isAfter(failureStart)
          ? createdAt.add(const Duration(hours: 24))
          : failureStart;

      int missedCyclesForInv = 0;
      double invProposed = 0.0;

      // If cap is already exhausted, no payouts possible
      if (remainingCap > 0.001) {
        while (cycleCursor.isBefore(fixTime)) {
          final cycleDateStr = cycleCursor.toIso8601String().substring(0, 10);
          final deterministicRef = 'historical_profit:$invId:$cycleDateStr';

          // Check 1: Real DB transaction exists?
          bool realTxExists = false;
          for (final tx in existingTxns) {
            final txDate = DateTime.parse(tx['created_at'] as String);
            if (txDate.difference(cycleCursor).inHours.abs() < 18) {
              realTxExists = true;
              break;
            }
          }

          // Check 2: Cycle already applied in simulated previous run?
          final alreadyApplied = simulatedAppliedReferences.contains(deterministicRef);

          if (!realTxExists && !alreadyApplied) {
            // Check remaining profit cap
            if (invProposed + dailyProfitRounded <= remainingCap) {
              missedCyclesForInv++;
              invProposed += dailyProfitRounded;
              cycleDetails.add({
                'investment_id': invId,
                'user_id': userId,
                'cycle_date': cycleDateStr,
                'deterministic_ref': deterministicRef,
                'amount': dailyProfitRounded,
                'status': 'eligible',
              });
              if (dailyProfitRounded < minPayout) minPayout = dailyProfitRounded;
              if (dailyProfitRounded > maxPayout) maxPayout = dailyProfitRounded;
            }
          }

          cycleCursor = cycleCursor.add(const Duration(hours: 24));
        }
      }

      if (invProposed > 0) {
        eligibleInvestments++;
        eligibleCycles += missedCyclesForInv;
        totalProposedPayout += invProposed;

        final userName = profMap[userId]?['full_name'] ?? 'Unknown';
        final userEmail = profMap[userId]?['email'] ?? 'Unknown';

        invBreakdown.add({
          'investment_id': invId,
          'user_id': userId,
          'user_name': userName,
          'plan': planName,
          'principal': principal,
          'expected_total': expectedProfit,
          'already_paid': currentActualProfit,
          'remaining_cap': remainingCap,
          'missed_cycles': missedCyclesForInv,
          'proposed_payout': double.parse(invProposed.toStringAsFixed(2)),
        });

        userTotals.putIfAbsent(userId, () => {
          'user_id': userId,
          'user_name': userName,
          'user_email': userEmail,
          'investments': 0,
          'missed_cycles': 0,
          'total_payout': 0.0,
        });
        final u = userTotals[userId]!;
        u['investments'] = (u['investments'] as int) + 1;
        u['missed_cycles'] = (u['missed_cycles'] as int) + missedCyclesForInv;
        u['total_payout'] = (u['total_payout'] as double) + invProposed;
      }
    }

    if (totalProposedPayout == 0.0) {
      minPayout = 0.0;
    }

    print('Results for $runName:');
    print('  Eligible Users: ${userTotals.length}');
    print('  Eligible Investments: $eligibleInvestments');
    print('  Eligible Cycles: $eligibleCycles');
    print('  Total Proposed Payout: \$${totalProposedPayout.toStringAsFixed(2)}');
    print('  Min Payout per cycle: \$${minPayout.toStringAsFixed(2)}');
    print('  Max Payout per cycle: \$${maxPayout.toStringAsFixed(2)}');

    return {
      'run_name': runName,
      'eligible_users': userTotals.length,
      'eligible_investments': eligibleInvestments,
      'eligible_cycles': eligibleCycles,
      'total_proposed_payout': double.parse(totalProposedPayout.toStringAsFixed(2)),
      'min_payout': minPayout,
      'max_payout': maxPayout,
      'user_totals': userTotals.values.toList(),
      'inv_breakdown': invBreakdown,
      'cycle_details': cycleDetails,
    };
  }

  // --- RUN 1: FRESH DRY RUN ---
  final run1Results = runSimulation('RUN 1 (Fresh Dry Run)');

  // Now, commit RUN 1 changes into simulated state:
  for (final c in run1Results['cycle_details'] as List) {
    final invId = c['investment_id'] as String;
    final amount = c['amount'] as double;
    final ref = c['deterministic_ref'] as String;
    simulatedAppliedReferences.add(ref);
    simulatedCumulativeProfit[invId] = (simulatedCumulativeProfit[invId] ?? 0.0) + amount;
  }
  print('\n[SIMULATION] Committed ${simulatedAppliedReferences.length} payout records to simulated DB state.');

  // --- RUN 2: RE-RUN / IDEMPOTENCY SIMULATION ---
  final run2Results = runSimulation('RUN 2 (Idempotency Verification Run)');

  final summaryFile = {
    'run_1': run1Results,
    'run_2': run2Results,
  };
  File('tool/dry_run_simulation_report.json').writeAsStringSync(jsonEncode(summaryFile));
  print('\nComplete report saved to tool/dry_run_simulation_report.json');
}
