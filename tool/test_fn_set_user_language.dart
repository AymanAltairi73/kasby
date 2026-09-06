import 'dart:convert';
import 'dart:io';

const supabaseUrl = 'https://majnuiypsgosbzsaeefc.supabase.co';
const anonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1ham51aXlwc2dvc2J6c2FlZWZjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzIwNzA5NzUsImV4cCI6MjA4NzY0Njk3NX0.M9OIGMQVdF4EACNae8G4pObbumB1fz_kR_xOz1G7chc';
const serviceKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1ham51aXlwc2dvc2J6c2FlZWZjIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MjA3MDk3NSwiZXhwIjoyMDg3NjQ2OTc1fQ.5EoQZEgv9HmYLYIlF14vzd6u3qNX9LmJB-RtzE4sA1Q';

final _client = HttpClient();

Future<void> main() async {
  // 1. Authenticate Test Account
  final authUri = Uri.parse('$supabaseUrl/auth/v1/token?grant_type=password');
  final authReq = await _client.openUrl('POST', authUri);
  authReq.headers.set('apikey', anonKey);
  authReq.headers.set('Content-Type', 'application/json');
  authReq.write(
    jsonEncode({
      'email': 'aymanaltairi80@gmail.com',
      'password': 'zxcvbnmzx',
    }),
  );
  final authRes = await authReq.close();
  final authBody = await authRes.transform(utf8.decoder).join();
  final authJson = jsonDecode(authBody) as Map<String, dynamic>;

  if (authRes.statusCode != 200 || !authJson.containsKey('access_token')) {
    print('FAILED TO AUTHENTICATE TEST USER: $authBody');
    exit(1);
  }

  final token = authJson['access_token'] as String;
  final user = authJson['user'] as Map<String, dynamic>;
  final userId = user['id'] as String;

  print('Authenticated: $userId');

  // Check profile before
  var req = await _client.openUrl('GET', Uri.parse('$supabaseUrl/rest/v1/profiles?id=eq.$userId&select=id,language'));
  req.headers.set('apikey', serviceKey);
  req.headers.set('Authorization', 'Bearer $serviceKey');
  var res = await req.close();
  var body = await res.transform(utf8.decoder).join();
  print('Profile before: $body');

  // Call fn_set_user_language with 'en'
  var rpcReq = await _client.openUrl('POST', Uri.parse('$supabaseUrl/rest/v1/rpc/fn_set_user_language'));
  rpcReq.headers.set('apikey', anonKey);
  rpcReq.headers.set('Authorization', 'Bearer $token');
  rpcReq.headers.set('Content-Type', 'application/json');
  rpcReq.write(jsonEncode({'p_language': 'en'}));
  var rpcRes = await rpcReq.close();
  var rpcBody = await rpcRes.transform(utf8.decoder).join();
  print('RPC fn_set_user_language(en) status: ${rpcRes.statusCode}, body: $rpcBody');

  // Check profile after
  req = await _client.openUrl('GET', Uri.parse('$supabaseUrl/rest/v1/profiles?id=eq.$userId&select=id,language'));
  req.headers.set('apikey', serviceKey);
  req.headers.set('Authorization', 'Bearer $serviceKey');
  res = await req.close();
  body = await res.transform(utf8.decoder).join();
  print('Profile after: $body');

  // Check device_tokens
  req = await _client.openUrl('GET', Uri.parse('$supabaseUrl/rest/v1/device_tokens?user_id=eq.$userId&select=id,language,updated_at'));
  req.headers.set('apikey', serviceKey);
  req.headers.set('Authorization', 'Bearer $serviceKey');
  res = await req.close();
  body = await res.transform(utf8.decoder).join();
  print('Device tokens after: $body');

  _client.close(force: true);
}
