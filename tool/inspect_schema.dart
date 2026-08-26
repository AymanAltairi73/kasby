import 'dart:convert';
import 'dart:io';

const supabaseUrl = 'https://majnuiypsgosbzsaeefc.supabase.co';
const serviceKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1ham51aXlwc2dvc2J6c2FlZWZjIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MjA3MDk3NSwiZXhwIjoyMDg3NjQ2OTc1fQ.5EoQZEgv9HmYLYIlF14vzd6u3qNX9LmJB-RtzE4sA1Q';

final _client = HttpClient();

Future<void> main() async {
  // Query wallets table schema
  print('=== wallets table sample ===');
  var uri = Uri.parse('$supabaseUrl/rest/v1/wallets?limit=1&select=*');
  var req = await _client.openUrl('GET', uri);
  req.headers.set('apikey', serviceKey);
  req.headers.set('Authorization', 'Bearer $serviceKey');
  var res = await req.close();
  var body = await res.transform(utf8.decoder).join();
  print(body);

  print('');
  print('=== user_points table sample ===');
  uri = Uri.parse('$supabaseUrl/rest/v1/user_points?limit=1&select=*');
  req = await _client.openUrl('GET', uri);
  req.headers.set('apikey', serviceKey);
  req.headers.set('Authorization', 'Bearer $serviceKey');
  res = await req.close();
  body = await res.transform(utf8.decoder).join();
  print(body);

  print('');
  print('=== transactions table sample (1 row) ===');
  uri = Uri.parse('$supabaseUrl/rest/v1/transactions?limit=1&select=*&order=created_at.desc');
  req = await _client.openUrl('GET', uri);
  req.headers.set('apikey', serviceKey);
  req.headers.set('Authorization', 'Bearer $serviceKey');
  res = await req.close();
  body = await res.transform(utf8.decoder).join();
  print(body);

  // Check if there's an idempotency table
  print('');
  print('=== Check for idempotency_keys or similar table ===');
  uri = Uri.parse('$supabaseUrl/rest/v1/');
  req = await _client.openUrl('GET', uri);
  req.headers.set('apikey', serviceKey);
  req.headers.set('Authorization', 'Bearer $serviceKey');
  res = await req.close();
  body = await res.transform(utf8.decoder).join();
  final spec = jsonDecode(body) as Map<String, dynamic>;
  final defs = spec['definitions'] as Map<String, dynamic>?;
  if (defs != null) {
    final tables = defs.keys.where((k) =>
        k.contains('idemp') || k.contains('redeem') || k.contains('ksp'));
    print('Tables matching idemp/redeem/ksp: $tables');
  }

  // Check existing fn_deduct_effective_ksp for reference
  print('');
  print('=== fn_deduct_effective_ksp signature ===');
  uri = Uri.parse('$supabaseUrl/rest/v1/');
  req = await _client.openUrl('GET', uri);
  req.headers.set('apikey', serviceKey);
  req.headers.set('Authorization', 'Bearer $serviceKey');
  res = await req.close();
  body = await res.transform(utf8.decoder).join();
  final paths = (jsonDecode(body) as Map)['paths'] as Map<String, dynamic>?;
  if (paths != null) {
    final deductPath = paths['/rpc/fn_deduct_effective_ksp'];
    if (deductPath != null) {
      print(JsonEncoder.withIndent('  ').convert(deductPath));
    }
    final creditPath = paths['/rpc/fn_credit_reward_ksp'];
    if (creditPath != null) {
      print('');
      print('=== fn_credit_reward_ksp signature ===');
      print(JsonEncoder.withIndent('  ').convert(creditPath));
    }
  }

  _client.close(force: true);
}
