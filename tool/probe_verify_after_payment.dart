import 'dart:convert';
import 'dart:io';

const supabaseUrl = 'https://majnuiypsgosbzsaeefc.supabase.co';
const serviceKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1ham51aXlwc2dvc2J6c2FlZWZjIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MjA3MDk3NSwiZXhwIjoyMDg3NjQ2OTc1fQ.5EoQZEgv9HmYLYIlF14vzd6u3qNX9LmJB-RtzE4sA1Q';

final _client = HttpClient();

Future<List<dynamic>> getRows(String path) async {
  final req = await _client.openUrl('GET', Uri.parse('$supabaseUrl/rest/v1$path'));
  req.headers.set('apikey', serviceKey);
  req.headers.set('Authorization', 'Bearer $serviceKey');
  final res = await req.close();
  final body = await res.transform(utf8.decoder).join();
  if (res.statusCode != 200) {
    print('HTTP ${res.statusCode} for $path: $body');
    return [];
  }
  return jsonDecode(body) as List<dynamic>;
}

Future<void> main() async {
  final since = '2026-09-11T20:39:30';

  print('=== A. profit_distribution_failed AFTER 20:39:30 (should be 0) ===');
  final fails = await getRows('/system_logs?action=eq.profit_distribution_failed&created_at=gt.$since&select=created_at,entity_id,details&limit=10');
  print('count: ${fails.length}');
  for (final f in fails.cast<Map<String, dynamic>>()) {
    print('  ${f['created_at']} | ${f['entity_id']} | ${jsonEncode(f['details'])}');
  }

  print('\n=== B. Profit transactions in the 20:40 batch ===');
  final txns = await getRows('/transactions?type=eq.profit&created_at=gte.$since&created_at=lt.2026-09-11T21:00:00&select=user_id,amount,wallet_id&limit=500');
  final total = txns.cast<Map<String, dynamic>>().fold<double>(0, (s, t) => s + (t['amount'] as num).toDouble());
  final users = <String, int>{};
  for (final t in txns.cast<Map<String, dynamic>>()) {
    users[t['user_id'] as String] = (users[t['user_id']] ?? 0) + 1;
  }
  print('count: ${txns.length}, total paid: \$$total, distinct users: ${users.length}');
  for (final e in users.entries) {
    print('  ${e.key} -> ${e.value} txs');
  }

  print('\n=== C. Investments updated in the 20:40 batch ===');
  final invs = await getRows('/user_investments?status=eq.active&select=id,user_id,auto_restart_enabled,next_payout_at,last_profit_at,actual_profit&last_profit_at=gte.$since&limit=500');
  final autoTrue = invs.cast<Map<String, dynamic>>().where((i) => i['auto_restart_enabled'] == true).length;
  final withNext = invs.cast<Map<String, dynamic>>().where((i) => i['next_payout_at'] != null).length;
  print('updated count: ${invs.length}, auto_restart_enabled=true: $autoTrue, next_payout_at set: $withNext');

  print('\n=== D. STILL-DUE active investments (should be 0) ===');
  final due = await getRows('/user_investments?status=eq.active&next_payout_at=lte.2026-09-11T21:00:00&select=id,user_id,next_payout_at&limit=50');
  print('count: ${due.length}');
  for (final d in due.cast<Map<String, dynamic>>()) {
    print('  ${d['id']} | ${d['user_id']} | ${d['next_payout_at']}');
  }

  print('\n=== E. create_investment RPC signature now ===');
  final req = await _client.openUrl('GET', Uri.parse('$supabaseUrl/rest/v1/'));
  req.headers.set('apikey', serviceKey);
  req.headers.set('Authorization', 'Bearer $serviceKey');
  final resp = await req.close();
  final specBody = await resp.transform(utf8.decoder).join();
  if (resp.statusCode == 200) {
    final spec = jsonDecode(specBody) as Map<String, dynamic>;
    final path = spec['paths']?['/rpc/create_investment'] as Map<String, dynamic>?;
    final args = ((path?['post'] as Map<String, dynamic>?)?['parameters'] as List?)?.firstWhere((p) => p is Map && p['name'] == 'args', orElse: () => null);
    print('  args schema: ${jsonEncode((args as Map?)?['schema'])}');
    final cronPath = spec['paths']?['/rpc/fn_cron_distribute_daily_profits'] as Map<String, dynamic>?;
    print('  fn_cron present: ${cronPath != null}');
    final ensure = spec['paths']?['/rpc/ensure_user_wallet'] as Map<String, dynamic>?;
    print('  ensure_user_wallet present: ${ensure != null}');
  } else {
    print('  HTTP ${resp.statusCode}: $specBody');
  }

  _client.close(force: true);
}