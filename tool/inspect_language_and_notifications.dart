import 'dart:convert';
import 'dart:io';

const supabaseUrl = 'https://majnuiypsgosbzsaeefc.supabase.co';
const serviceKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1ham51aXlwc2dvc2J6c2FlZWZjIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MjA3MDk3NSwiZXhwIjoyMDg3NjQ2OTc1fQ.5EoQZEgv9HmYLYIlF14vzd6u3qNX9LmJB-RtzE4sA1Q';

final _client = HttpClient();

Future<void> main() async {
  // 1. Inspect profiles table columns
  print('=== PROFILES TABLE (1 row) ===');
  var uri = Uri.parse('$supabaseUrl/rest/v1/profiles?limit=1&select=*');
  var req = await _client.openUrl('GET', uri);
  req.headers.set('apikey', serviceKey);
  req.headers.set('Authorization', 'Bearer $serviceKey');
  var res = await req.close();
  var body = await res.transform(utf8.decoder).join();
  print(body);

  // 2. Inspect OpenAPI spec for fn_set_user_language and other notification/language RPCs
  print('\n=== OPENAPI SPEC CHECK ===');
  uri = Uri.parse('$supabaseUrl/rest/v1/');
  req = await _client.openUrl('GET', uri);
  req.headers.set('apikey', serviceKey);
  req.headers.set('Authorization', 'Bearer $serviceKey');
  res = await req.close();
  body = await res.transform(utf8.decoder).join();
  final spec = jsonDecode(body) as Map<String, dynamic>;
  final paths = spec['paths'] as Map<String, dynamic>? ?? {};

  final langPaths = paths.keys.where((k) => k.toLowerCase().contains('lang') || k.toLowerCase().contains('locale') || k.toLowerCase().contains('notif'));
  print('Matching RPCs:');
  for (final p in langPaths) {
    print('  $p');
  }

  if (paths.containsKey('/rpc/fn_set_user_language')) {
    print('\nfn_set_user_language definition:');
    print(JsonEncoder.withIndent('  ').convert(paths['/rpc/fn_set_user_language']));
  } else {
    print('\nfn_set_user_language NOT FOUND in OpenAPI paths!');
  }

  // 3. Inspect device_tokens table columns
  print('\n=== DEVICE_TOKENS TABLE (1 row) ===');
  uri = Uri.parse('$supabaseUrl/rest/v1/device_tokens?limit=1&select=*');
  req = await _client.openUrl('GET', uri);
  req.headers.set('apikey', serviceKey);
  req.headers.set('Authorization', 'Bearer $serviceKey');
  res = await req.close();
  body = await res.transform(utf8.decoder).join();
  print(body);

  _client.close(force: true);
}
