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
  final spec = await getJson('/') as Map<String, dynamic>?;
  final pathKeys = ((spec?['paths']) as Map<String, dynamic>? ?? {}).keys.toList();
  const targets = [
    '/rpc/create_investment',
    '/rpc/fn_cron_distribute_daily_profits',
    '/rpc/fn_start_next_cycle',
    '/rpc/ensure_user_wallet',
    '/rpc/fn_credit_profit',
  ];
  for (final t in targets) {
    print('=== $t ===');
    final found = pathKeys.where((p) => p == t).toList();
    if (found.isEmpty) {
      final similar = pathKeys.where((p) => p.contains(t.replaceAll('/rpc/', ''))).toList();
      print('  NOT FOUND. Similar: $similar');
      continue;
    }
    final post = ((spec?['paths']?[t]) as Map<String, dynamic>?)?['post'];
    final args = (post?['parameters'] as List?)?.firstWhere(
          (p) => p is Map && p['name'] == 'args',
          orElse: () => null,
        );
    final schema = (args as Map?)?['schema'] as Map?;
    print('  args schema: ${jsonEncode(schema)}');
  }
  _client.close(force: true);
}