import 'dart:convert';
import 'dart:io';

const supabaseUrl = 'https://majnuiypsgosbzsaeefc.supabase.co';
const serviceKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1ham51aXlwc2dvc2J6c2FlZWZjIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MjA3MDk3NSwiZXhwIjoyMDg3NjQ2OTc1fQ.5EoQZEgv9HmYLYIlF14vzd6u3qNX9LmJB-RtzE4sA1Q';

final _client = HttpClient();

Future<dynamic> getJson(String path) async {
  final req = await _client.openUrl('GET', Uri.parse('$supabaseUrl/rest/v1$path'));
  req.headers.set('apikey', serviceKey);
  req.headers.set('Authorization', 'Bearer $serviceKey');
  final res = await req.close();
  final body = await res.transform(utf8.decoder).join();
  if (res.statusCode != 200) {
    print('HTTP ${res.statusCode} for $path: $body');
    return null;
  }
  return jsonDecode(body);
}

Future<void> main() async {
  final now = DateTime.now().toUtc().toIso8601String();

  print('=== A. Still-due active investments (should be 0 / near-0) ===');
  final stillDue = await getJson(
      '/user_investments?status=eq.active&next_payout_at=lte.$now&select=id,user_id,auto_restart_enabled,next_payout_at,last_profit_at,amount,expected_profit&limit=50')
      as List?;
  print('count: ${stillDue?.length}');
  for (final inv in stillDue ?? <dynamic>[]) {
    print('- inv=${inv['id']} | user=${inv['user_id']} | auto=${inv['auto_restart_enabled']} | next=${inv['next_payout_at']} | last_profit=${inv['last_profit_at']}');
  }

  print('\n=== B. Recent profit transactions (last 24h, wallet_id check) ===');
  final since = DateTime.now().toUtc().subtract(const Duration(hours: 24)).toIso8601String();
  final txs = await getJson(
      '/transactions?type=eq.profit&created_at=gte.$since&select=id,user_id,wallet_id,amount,created_at&order=created_at.desc&limit=30')
      as List?;
  print('count: ${txs?.length}');
  var nullWallet = 0;
  for (final t in txs ?? <dynamic>[]) {
    final w = t['wallet_id'];
    if (w == null) nullWallet++;
    print('- user=${t['user_id']?.toString().substring(0, 8)} | wallet=$w | amt=${t['amount']} | at=${t['created_at']}');
  }
  print('null wallet count: $nullWallet');

  print('\n=== C. Wallet balances for the two focus users ===');
  final list = (await getJson('/wallets?select=id,user_id,available_balance,profit_balance,invested_balance&limit=1000') as List?) ?? [];
  final u1 = 'a1000001-0000-4000-8000-000000000004';
  final u2 = '7ce89452-c4d8-4867-8343-558148cc2bd9';
  for (final w in list) {
    if (w['user_id'] == u1 || w['user_id'] == u2) {
      print('- user=${w['user_id'].toString().substring(0, 8)} | wallet=${w['id']} | avail=${w['available_balance']} | profit=${w['profit_balance']} | invested=${w['invested_balance']}');
    }
  }

  print('\n=== D. Failing user investments cycle state ===');
  final invs = (await getJson('/user_investments?user_id=eq.$u2&status=eq.active&select=id,auto_restart_enabled,next_payout_at,last_profit_at,actual_profit,amount,expected_profit') as List?) ?? [];
  for (final inv in invs) {
    print('- inv=${inv['id'].toString().substring(0, 8)} | auto=${inv['auto_restart_enabled']} | next=${inv['next_payout_at']} | last=${inv['last_profit_at']} | actual=${inv['actual_profit']} | amt=${inv['amount']} | exp=${inv['expected_profit']}');
  }

  _client.close(force: true);
}