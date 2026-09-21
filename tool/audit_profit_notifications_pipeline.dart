import 'dart:convert';
import 'dart:io';

const supabaseUrl = 'https://majnuiypsgosbzsaeefc.supabase.co';
const serviceKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1ham51aXlwc2dvc2J6c2FlZWZjIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MjA3MDk3NSwiZXhwIjoyMDg3NjQ2OTc1fQ.5EoQZEgv9HmYLYIlF14vzd6u3qNX9LmJB-RtzE4sA1Q';
const anonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1ham51aXlwc2dvc2J6c2FlZWZjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzIwNzA5NzUsImV4cCI6MjA4NzY0Njk3NX0.M9OIGMQVdF4EACNae8G4pObbumB1fz_kR_xOz1G7chc';

final _client = HttpClient();

Future<dynamic> get(String path) async {
  final uri = Uri.parse('$supabaseUrl$path');
  final req = await _client.openUrl('GET', uri);
  req.headers.set('apikey', serviceKey);
  req.headers.set('Authorization', 'Bearer $serviceKey');
  final res = await req.close();
  final body = await res.transform(utf8.decoder).join();
  try {
    return jsonDecode(body);
  } catch (_) {
    return body;
  }
}

Future<dynamic> postRpc(String name, Map<String, dynamic> params) async {
  final uri = Uri.parse('$supabaseUrl/rest/v1/rpc/$name');
  final req = await _client.openUrl('POST', uri);
  req.headers.set('apikey', serviceKey);
  req.headers.set('Authorization', 'Bearer $serviceKey');
  req.headers.set('Content-Type', 'application/json');
  req.write(jsonEncode(params));
  final res = await req.close();
  final body = await res.transform(utf8.decoder).join();
  try {
    return jsonDecode(body);
  } catch (_) {
    return body;
  }
}

Future<void> main() async {
  print('=== 1. CHECK RECENT NOTIFICATIONS ===');
  final recentNotifs = await get('/rest/v1/notifications?order=created_at.desc&limit=10');
  print(JsonEncoder.withIndent('  ').convert(recentNotifs));

  print('\n=== 2. CHECK PROFIT NOTIFICATIONS SPECIFICALLY ===');
  final profitNotifs = await get('/rest/v1/notifications?type=eq.daily_profit&order=created_at.desc&limit=5');
  print(JsonEncoder.withIndent('  ').convert(profitNotifs));

  print('\n=== 3. CHECK ANY INVESTMENT NOTIFICATIONS ===');
  final invNotifs = await get('/rest/v1/notifications?entity_type=eq.investment&order=created_at.desc&limit=5');
  print(JsonEncoder.withIndent('  ').convert(invNotifs));

  print('\n=== 4. CHECK RECENT INVESTMENT PROFIT TRANSACTIONS ===');
  final txns = await get('/rest/v1/transactions?type=eq.investment_profit&order=created_at.desc&limit=5');
  print(JsonEncoder.withIndent('  ').convert(txns));

  print('\n=== 5. CHECK ACTIVE USER INVESTMENTS ===');
  final activeInvs = await get('/rest/v1/user_investments?status=eq.active&limit=5');
  print(JsonEncoder.withIndent('  ').convert(activeInvs));

  print('\n=== 6. CHECK DEVICE TOKENS TABLE ===');
  final tokens = await get('/rest/v1/device_tokens?order=updated_at.desc&limit=10');
  print(JsonEncoder.withIndent('  ').convert(tokens));

  print('\n=== 7. CHECK PROFILES WITH FCM TOKENS ===');
  final profileTokens = await get('/rest/v1/profiles?fcm_token=not.is.null&select=id,full_name,fcm_token,language&limit=5');
  print(JsonEncoder.withIndent('  ').convert(profileTokens));

  print('\n=== 8. TEST SEND-FCM FUNCTION DIRECTLY ===');
  try {
    final uri = Uri.parse('$supabaseUrl/functions/v1/send-fcm');
    final req = await _client.openUrl('POST', uri);
    req.headers.set('Authorization', 'Bearer kasby_internal_fcm_secret_2026_x972f');
    req.headers.set('Content-Type', 'application/json');
    req.write(jsonEncode({
      'token': 'dummy_test_token_for_validation_1234567890',
      'title': 'Test Title',
      'body': 'Test Body',
      'data': {'type': 'daily_profit'}
    }));
    final res = await req.close();
    final body = await res.transform(utf8.decoder).join();
    print('send-fcm response (${res.statusCode}): $body');
  } catch (e) {
    print('send-fcm call error: $e');
  }

  print('\n=== 9. CHECK SYSTEM SETTINGS (pause_profits) ===');
  final settings = await get('/rest/v1/system_settings?select=*&limit=1');
  print(JsonEncoder.withIndent('  ').convert(settings));

  _client.close(force: true);
}
