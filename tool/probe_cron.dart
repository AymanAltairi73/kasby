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
  print('=== ALL active investments (page1) ===');
  final invs = await getJson('/user_investments?status=eq.active&order=created_at.desc&limit=100') as List?;
  print('count: ${invs?.length}');
  final users = <String>{};
  for (final inv in invs ?? <dynamic>[]) {
    final u = inv['user_id'] as String;
    final np = inv['next_payout_at'] as String?;
    final auto = inv['auto_restart_enabled'];
    print('- inv=${inv['id']} | user=$u | auto=$auto | next_payout=$np | amount=${inv['amount']} | expected=${inv['expected_profit']} | plan=${inv['plan_id']} | last_profit=${inv['last_profit_at']}');
    users.add(u);
  }

  print('\n=== Wallets for all active-investment users ===');
  final userIds = users.join(',');
  final wallets = await getJson('/wallets?user_id=in.($userIds)&select=id,user_id,currency,available_balance,profit_balance,invested_balance,is_frozen') as List?;
  final walletUsers = <String>{};
  for (final w in wallets ?? <dynamic>[]) {
    walletUsers.add(w['user_id'] as String);
    print('- user=${w['user_id']} | wallet=${w['id']} | cur=${w['currency']} | avail=${w['available_balance']} | frozen=${w['is_frozen']}');
  }

  print('\n=== Users WITHOUT any wallet row (missing wallet) ===');
  for (final u in users) {
    if (!walletUsers.contains(u)) print('  MISSING WALLET -> $u');
  }

  print('\n=== Due investments (next_payout_at <= now) ===');
  for (final inv in invs ?? <dynamic>[]) {
    final np = inv['next_payout_at'] as String?;
    if (np != null && DateTime.parse(np).isBefore(DateTime.now())) {
      print('- inv=${inv['id']} | user=${inv['user_id']} | auto=${inv['auto_restart_enabled']} | next_payout=$np');
    }
  }

  _client.close(force: true);
}