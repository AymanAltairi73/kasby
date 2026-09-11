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
  const u = '7ce89452-c4d8-4867-8343-558148cc2bd9';

  print('=== INVESTMENTS of $u ===');
  final invs = await getRows('/user_investments?user_id=eq.$u&order=created_at&limit=20');
  for (final i in invs.cast<Map<String, dynamic>>()) {
    print(jsonEncode({
      for (final k in ['id', 'status', 'amount', 'auto_restart_enabled', 'next_payout_at', 'last_profit_at', 'actual_profit', 'expected_profit', 'start_date', 'end_date', 'created_at', 'transaction_id'])
        k: i[k],
    }));
  }

  print('\n=== SUBSCRIPTIONS (expires_at check — proves migration applied?) ===');
  final subs = await getRows('/subscriptions?user_id=eq.$u&select=id,tier,status,expires_at,end_date');
  for (final s in subs.cast<Map<String, dynamic>>()) {
    print(jsonEncode(s));
  }

  print('\n=== RECENT TRANSACTIONS for $u (last 12) ===');
  final txns = await getRows('/transactions?user_id=eq.$u&order=created_at.desc&limit=12&select=id,type,amount,status,wallet_id,created_at,description');
  for (final t in txns.cast<Map<String, dynamic>>()) {
    print('${t['created_at']} | ${t['type']} | \$${t['amount']} | ${t['status']} | wallet=${t['wallet_id']} | ${t['description']}');
  }

  print('\n=== RECENT PROFIT TRANSACTIONS last 24h (any user) ===');
  final profits = await getRows('/transactions?type=eq.profit&select=user_id,amount,wallet_id,created_at&created_at=gte.2026-09-11T00:00:00&limit=30');
  print('count: ${profits.length}');
  for (final t in profits.cast<Map<String, dynamic>>()) {
    print('${t['created_at']} | ${t['user_id']} | \$${t['amount']} | wallet=${t['wallet_id']}');
  }

  print('\n=== RECENT system_logs (last 15) ===');
  final logs = await getRows('/system_logs?order=created_at.desc&limit=15');
  for (final l in logs.cast<Map<String, dynamic>>()) {
    print('${l['created_at']} | ${l['action']} | ${l['entity_id'] ?? ''} | ${jsonEncode(l['details'] ?? {})} | ${l['severity']}');
  }

  print('\n=== BACKEND RPC SIGNATURE (has fn changed? cron still there?) ===');
  final spec = await getRows('/') == null ? [] : await _probeRpc();
  _client.close(force: true);
}

Future<List<dynamic>> _probeRpc() async {
  final req = await _client.openUrl('GET', Uri.parse('$supabaseUrl/rest/v1/'));
  req.headers.set('apikey', serviceKey);
  req.headers.set('Authorization', 'Bearer $serviceKey');
  final res = await req.close();
  final body = await res.transform(utf8.decoder).join();
  if (res.statusCode != 200) return [];
  final spec = jsonDecode(body) as Map<String, dynamic>;
  final paths = (spec['paths'] as Map<String, dynamic>? ?? {}).keys.toList();
  for (final t in ['/rpc/create_investment', '/rpc/fn_cron_distribute_daily_profits', '/rpc/fn_start_next_cycle']) {
    final pathMap = paths.contains(t) ? (spec['paths']?[t] as Map<String, dynamic>?) : null;
    final post = pathMap?['post'] as Map<String, dynamic>?;
    final args = (post?['parameters'] as List?)?.firstWhere((p) => p is Map && p['name'] == 'args', orElse: () => null);
    print('$t -> ${jsonEncode((args as Map?)?.containsKey('schema') == true ? (args as Map)['schema'] : null)}');
  }
  return [];
}