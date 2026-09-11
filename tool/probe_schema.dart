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
  print('=== subscriptions sample row (columns present) ===');
  final subs = await getJson('/subscriptions?limit=3') as List?;
  print('rows: ${subs?.length}');
  for (final s in subs ?? <dynamic>[]) {
    print('- $s');
  }

  print('\n=== profiles sample (account_tier / plans) ===');
  final profs = await getJson('/profiles?select=id,account_tier&limit=10') as List?;
  print('rows: ${profs?.length}');
  for (final p in profs ?? <dynamic>[]) {
    print('- ${p['id']?.toString().substring(0, 8)} | tier=${p['account_tier']}');
  }

  print('\n=== All tables OpenAPI paths w/ subscriptions / profiles ===');
  final spec = await getJson('/') as Map<String, dynamic>?;
  final pathKeys = ((spec?['paths']) as Map<String, dynamic>? ?? {}).keys.toList();
  final relevant = pathKeys.where((p) => p.startsWith('/subscriptions') || p.startsWith('/profiles')).take(12).toList();
  print(relevant);

  print('\n=== try selecting known-expensive fields on subscriptions ===');
  final tryCols = ['id,user_id,status,plan,plan_id,type,started_at,created_at,ends_at,end_date,expires_at,updated_at'];
  final s2 = await getJson('/subscriptions?select=id,user_id,status&limit=3');
  print('basic select: $s2');

  _client.close(force: true);
}