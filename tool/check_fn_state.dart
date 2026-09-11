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
  print('=== Function exposed via OpenAPI (return type check) ===');
  final spec = await getJson('/') as Map<String, dynamic>?;
  final pathKeys = ((spec?['paths']) as Map<String, dynamic>? ?? {}).keys.toList();
  final fnPaths = pathKeys.where((p) => p.contains('fn_cron_distribute_daily_profits')).toList();
  print('fn_cron paths: $fnPaths');
  for (final p in fnPaths) {
    final ops = (spec?['paths']?[p]) as Map<String, dynamic>?;
    for (final e in ops!.entries) {
      print('  method=${e.key} | value=${jsonEncode(e.value)}');
    }
  }

  print('\n=== Recent system_logs (profit_distribution, last 2 days) ===');
  final since = DateTime.now().toUtc().subtract(const Duration(days: 2)).toIso8601String();
  final logs = await getJson(
      '/system_logs?created_at=gte.$since&order=created_at.desc&limit=20') as List?;
  print('count: ${logs?.length}');
  for (final l in logs ?? <dynamic>[]) {
    print('- ${l['created_at']} | actor=${l['actor_role']} | action=${l['action']} | entity=${l['entity_id']} | details=${l['details']}');
  }

  print('\n=== All profit transactions ever (recent 10) ===');
  final txs = await getJson(
      '/transactions?type=eq.profit&order=created_at.desc&limit=10') as List?;
  print('count: ${txs?.length}');
  for (final t in txs ?? <dynamic>[]) {
    print('- user=${t['user_id']?.toString().substring(0, 8)} | wallet=${t['wallet_id']} | amt=${t['amount']} | at=${t['created_at']} | title=${t['title']}');
  }

  _client.close(force: true);
}