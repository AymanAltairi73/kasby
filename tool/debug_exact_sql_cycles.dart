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
  final plans = await get('/rest/v1/investment_plans?select=*');
  final planMap = <String, Map<String, dynamic>>{};
  for (final pl in plans) planMap[pl['id']] = Map<String, dynamic>.from(pl);

  final profiles = await get('/rest/v1/profiles?select=id,full_name,email');
  final profMap = <String, Map<String, dynamic>>{};
  for (final pr in profiles) profMap[pr['id']] = Map<String, dynamic>.from(pr);

  final allProfitTxns = await get('/rest/v1/transactions?type=eq.profit&select=id,user_id,amount,reference_id,created_at');
  
  // Exact SQL query
  final invs = await get('/rest/v1/user_investments?status=eq.active&created_at=lt.2026-09-20T00:00:00Z&select=*&order=created_at.asc');
  
  final strictInvs = invs.where((i) => i['next_payout_at'] != null || i['auto_restart_enabled'] == true).toList();
  print('Total strict investments: ${strictInvs.length}');

  final failureStart = DateTime.parse('2026-09-12T20:41:00Z');
  final failureEnd = DateTime.parse('2026-09-20T00:00:00Z');

  int totalCycles = 0;
  double totalAmount = 0.0;
  final usersWithPayout = <String, Map<String, dynamic>>{};
  final skippedInvs = <String, String>{};

  for (final inv in strictInvs) {
    final invId = inv['id'] as String;
    final userId = inv['user_id'] as String;
    final plan = planMap[inv['plan_id']] ?? {};
    final duration = (plan['duration_days'] as num?)?.toInt() ?? 30;

    final expectedProfit = (inv['expected_profit'] as num?)?.toDouble() ?? 0.0;
    final actualProfit = (inv['actual_profit'] as num?)?.toDouble() ?? 0.0;
    double remCap = (expectedProfit - actualProfit).clamp(0.0, double.infinity);

    if (remCap <= 0.001) {
      skippedInvs[invId] = 'remCap <= 0.001';
      continue;
    }

    final dailyProfit = double.parse((expectedProfit / duration).toStringAsFixed(2));
    if (dailyProfit <= 0) {
      skippedInvs[invId] = 'dailyProfit <= 0';
      continue;
    }

    final createdAt = DateTime.parse(inv['created_at'] as String);
    DateTime cycleCursor = createdAt.add(const Duration(hours: 24));
    if (cycleCursor.isBefore(failureStart)) {
      cycleCursor = failureStart;
    }

    int invCycles = 0;
    double invAmount = 0.0;

    while (cycleCursor.isBefore(failureEnd)) {
      final cycleDateStr = cycleCursor.toIso8601String().substring(0, 10);
      final refId = 'historical_profit:$invId:$cycleDateStr';

      // Replicate EXACT SQL:
      // WHERE user_id = v_inv.user_id
      //   AND (reference_id = v_deterministic_ref OR (type = 'profit' AND reference_id = v_inv.id::TEXT AND ABS(EXTRACT(EPOCH FROM (created_at - v_cycle_cursor))) < 64800))
      bool alreadyPaid = false;
      for (final tx in allProfitTxns) {
        if (tx['user_id'] != userId) continue;
        final txRef = tx['reference_id']?.toString() ?? '';
        if (txRef == refId) {
          alreadyPaid = true;
          break;
        }
        if (tx['type'] == 'profit' && txRef == invId) {
          final txCreatedAt = DateTime.parse(tx['created_at'] as String);
          final diffSec = txCreatedAt.difference(cycleCursor).inSeconds.abs();
          if (diffSec < 64800) {
            alreadyPaid = true;
            break;
          }
        }
      }

      if (alreadyPaid) {
        cycleCursor = cycleCursor.add(const Duration(hours: 24));
        continue;
      }

      double payable = remCap < dailyProfit ? remCap : dailyProfit;
      if (payable <= 0.001) {
        break;
      }

      invCycles++;
      invAmount += payable;
      remCap -= payable;
      totalCycles++;
      totalAmount += payable;

      cycleCursor = cycleCursor.add(const Duration(hours: 24));
    }

    if (invCycles > 0) {
      usersWithPayout.putIfAbsent(userId, () => {
        'user_id': userId,
        'name': profMap[userId]?['full_name'],
        'email': profMap[userId]?['email'],
        'cycles': 0,
        'amount': 0.0,
        'investments': 0,
      });
      final u = usersWithPayout[userId]!;
      u['cycles'] = (u['cycles'] as int) + invCycles;
      u['amount'] = (u['amount'] as double) + invAmount;
      u['investments'] = (u['investments'] as int) + 1;
    } else {
      skippedInvs[invId] = '0 cycles eligible (either all paid or cycle cursor past failureEnd)';
    }
  }

  print('Matched Users: ${usersWithPayout.length}');
  print('Total Cycles: $totalCycles');
  print('Total Amount: $totalAmount');
  print('\nUsers:');
  for (final u in usersWithPayout.values) {
    print('  ${u['name']} (${u['email']}) -> Inv: ${u['investments']}, Cycles: ${u['cycles']}, Amount: \$${(u['amount'] as double).toStringAsFixed(4)}');
  }

  print('\nSkipped Investments:');
  for (final entry in skippedInvs.entries) {
    print('  ${entry.key}: ${entry.value}');
  }
}
