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
  print('=== FULL wallets rows for both focus users ===');
  final u1 = 'a1000001-0000-4000-8000-000000000004';
  final u2 = '7ce89452-c4d8-4867-8343-558148cc2bd9';
  final include = 'id,user_id,currency,balance,available_balance,profit_balance,invested_balance,is_frozen,is_active,status,created_at,updated_at,*';
  final w = await getJson('/wallets?user_id=in.($u1,$u2)&select=$include') as List?;
  print('rows: ${w?.length}');
  for (final row in w ?? <dynamic>[]) {
    print(jsonEncode(row));
  }

  print('\n=== wallets real-time primary key / all columns by omitting select ===');
  final all = await getJson('/wallets?user_id=in.($u1,$u2)') as List?;
  print('rows: ${all?.length}');
  for (final row in all ?? <dynamic>[]) {
    print(jsonEncode(row));
  }

  print('\n=== auth.users sample (relationship check) ===');
  final users = await getJson('/profiles?select=id,account_tier,is_active,status&limit=5') as List?;
  print('rows: ${users?.length}');
  for (final u in users ?? <dynamic>[]) {
    print(jsonEncode(u));
  }

  _client.close(force: true);
}