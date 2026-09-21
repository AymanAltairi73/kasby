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
  return jsonDecode(body);
}

Future<void> main() async {
  final plansList = await get('/rest/v1/investment_plans?select=*');
  final plansMap = <String, Map<String, dynamic>>{};
  for (final p in plansList) {
    plansMap[p['id']] = Map<String, dynamic>.from(p);
  }

  final profilesList = await get('/rest/v1/profiles?select=id,full_name,email');
  final profilesMap = <String, Map<String, dynamic>>{};
  for (final pr in profilesList) {
    profilesMap[pr['id']] = Map<String, dynamic>.from(pr);
  }

  final activeInvs = await get('/rest/v1/user_investments?status=eq.active&select=*&order=created_at.asc');
  final now = DateTime.now().toUtc();

  final userSummary = <String, Map<String, dynamic>>{};
  final invDetails = <Map<String, dynamic>>[];

  for (final inv in activeInvs) {
    final nextPayoutAt = inv['next_payout_at'] != null ? DateTime.parse(inv['next_payout_at']) : null;
    if (nextPayoutAt == null || !now.isAfter(nextPayoutAt)) continue;

    final invId = inv['id'] as String;
    final userId = inv['user_id'] as String;
    final planId = inv['plan_id'] as String;
    final plan = plansMap[planId] ?? {};
    final planName = plan['name_ar'] ?? plan['name_en'] ?? 'Unknown';
    final planDays = (plan['duration_days'] as num?)?.toInt() ?? 30;

    final profile = profilesMap[userId] ?? {};
    final userName = profile['full_name'] ?? 'Unknown';
    final userEmail = profile['email'] ?? 'Unknown';

    final amount = (inv['amount'] as num?)?.toDouble() ?? 0.0;
    final expectedProfit = (inv['expected_profit'] as num?)?.toDouble() ?? 0.0;
    final actualProfit = (inv['actual_profit'] as num?)?.toDouble() ?? 0.0;
    final remainingProfit = expectedProfit - actualProfit;
    final dailyProfit = planDays > 0 ? (expectedProfit / planDays) : 0.0;

    final diff = now.difference(nextPayoutAt);
    final missedCycles = (diff.inHours / 24).floor() + 1;
    final potentialMissedAmount = (dailyProfit * missedCycles);

    // Bound by remaining profit
    final safeMissingAmount = potentialMissedAmount > remainingProfit ? remainingProfit : potentialMissedAmount;

    final row = {
      'investment_id': invId,
      'user_id': userId,
      'user_name': userName,
      'user_email': userEmail,
      'plan': planName,
      'principal': amount,
      'expected_profit': expectedProfit,
      'actual_profit': actualProfit,
      'remaining_profit': remainingProfit,
      'daily_profit': double.parse(dailyProfit.toStringAsFixed(2)),
      'next_payout_at': nextPayoutAt.toIso8601String(),
      'missed_cycles': missedCycles,
      'amount_missing': double.parse(safeMissingAmount.toStringAsFixed(2)),
      'auto_restart': inv['auto_restart_enabled'] == true,
    };
    invDetails.add(row);

    if (!userSummary.containsKey(userId)) {
      userSummary[userId] = {
        'user_id': userId,
        'user_name': userName,
        'user_email': userEmail,
        'investment_count': 0,
        'total_principal': 0.0,
        'total_expected': 0.0,
        'total_already_paid': 0.0,
        'total_missing': 0.0,
      };
    }

    final u = userSummary[userId]!;
    u['investment_count'] = (u['investment_count'] as int) + 1;
    u['total_principal'] = (u['total_principal'] as double) + amount;
    u['total_expected'] = (u['total_expected'] as double) + expectedProfit;
    u['total_already_paid'] = (u['total_already_paid'] as double) + actualProfit;
    u['total_missing'] = (u['total_missing'] as double) + safeMissingAmount;
  }

  // Save report to markdown
  final buf = StringBuffer();
  buf.writeln('# KASBY FINANCIAL RECONCILIATION REPORT: MISSED PROFITS AUDIT');
  buf.writeln('**Audit Date:** ${now.toIso8601String()}');
  buf.writeln('**Affected Period:** From `2026-09-11 20:40:00 UTC` to `${now.toIso8601String()}`');
  buf.writeln('**Total Affected Investments:** ${invDetails.length}');
  buf.writeln('**Total Affected Users:** ${userSummary.length}');
  
  double grandTotalMissing = 0.0;
  for (final u in userSummary.values) {
    grandTotalMissing += (u['total_missing'] as double);
  }
  buf.writeln('**Grand Total Potential Missed Amount:** \$${grandTotalMissing.toStringAsFixed(2)}\n');

  buf.writeln('## 1. Summary by User\n');
  buf.writeln('| User ID | Name | Email | Investments | Total Principal | Total Expected | Total Paid | Missed Payouts |');
  buf.writeln('|---|---|---|---|---|---|---|---|');
  for (final u in userSummary.values) {
    buf.writeln('| `${u['user_id']}` | ${u['user_name']} | ${u['user_email']} | ${u['investment_count']} | \$${(u['total_principal'] as double).toStringAsFixed(2)} | \$${(u['total_expected'] as double).toStringAsFixed(2)} | \$${(u['total_already_paid'] as double).toStringAsFixed(2)} | **\$${(u['total_missing'] as double).toStringAsFixed(2)}** |');
  }

  buf.writeln('\n## 2. Detailed Breakdown per Investment\n');
  buf.writeln('| Investment ID | User | Plan | Principal | Daily Payout | Next Payout Expected | Missed Cycles | Potential Missing | Remaining Cap | Auto Restart |');
  buf.writeln('|---|---|---|---|---|---|---|---|---|---|');
  for (final d in invDetails) {
    buf.writeln('| `${d['investment_id'].toString().substring(0, 8)}...` | ${d['user_name']} | ${d['plan']} | \$${d['principal']} | \$${d['daily_profit']} | `${d['next_payout_at']}` | ${d['missed_cycles']} | **\$${d['amount_missing']}** | \$${d['remaining_profit'].toStringAsFixed(2)} | ${d['auto_restart']} |');
  }

  final reportFile = File('tool/financial_reconciliation_report.md');
  reportFile.writeAsStringSync(buf.toString());
  print('Report successfully written to ${reportFile.path}');
  print('Total Affected Users: ${userSummary.length}');
  print('Total Affected Investments: ${invDetails.length}');
  print('Grand Total Missed: \$${grandTotalMissing.toStringAsFixed(2)}');

  _client.close(force: true);
}
