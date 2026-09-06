import 'dart:convert';
import 'dart:io';

const supabaseUrl = 'https://majnuiypsgosbzsaeefc.supabase.co';
const anonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1ham51aXlwc2dvc2J6c2FlZWZjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzIwNzA5NzUsImV4cCI6MjA4NzY0Njk3NX0.M9OIGMQVdF4EACNae8G4pObbumB1fz_kR_xOz1G7chc';
const serviceKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1ham51aXlwc2dvc2J6c2FlZWZjIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MjA3MDk3NSwiZXhwIjoyMDg3NjQ2OTc1fQ.5EoQZEgv9HmYLYIlF14vzd6u3qNX9LmJB-RtzE4sA1Q';

final _client = HttpClient();

Future<void> main() async {
  // Let's create a dedicated test user or reset password for testgo926@gmail.com (id: bb1a84d2-8c6b-49ab-a209-ac68683f4d1b)
  final userId = 'bb1a84d2-8c6b-49ab-a209-ac68683f4d1b';
  final testPass = 'TestPass123!@#';

  print('Updating test user password via Admin API...');
  final updateReq = await _client.openUrl('PUT', Uri.parse('$supabaseUrl/auth/v1/admin/users/$userId'));
  updateReq.headers.set('apikey', serviceKey);
  updateReq.headers.set('Authorization', 'Bearer $serviceKey');
  updateReq.headers.set('Content-Type', 'application/json');
  updateReq.write(jsonEncode({'password': testPass}));
  final updateRes = await updateReq.close();
  final updateBody = await updateRes.transform(utf8.decoder).join();
  print('Update status: ${updateRes.statusCode}');

  // Authenticate as this user
  print('Logging in as test user...');
  final authReq = await _client.openUrl('POST', Uri.parse('$supabaseUrl/auth/v1/token?grant_type=password'));
  authReq.headers.set('apikey', anonKey);
  authReq.headers.set('Content-Type', 'application/json');
  authReq.write(jsonEncode({'email': 'testgo926@gmail.com', 'password': testPass}));
  final authRes = await authReq.close();
  final authBody = await authRes.transform(utf8.decoder).join();
  final authJson = jsonDecode(authBody) as Map<String, dynamic>;
  final token = authJson['access_token'] as String;
  print('Logged in successfully! Token obtained.');

  // Test fn_set_user_language
  print('Calling fn_set_user_language with "en"...');
  final rpcReq = await _client.openUrl('POST', Uri.parse('$supabaseUrl/rest/v1/rpc/fn_set_user_language'));
  rpcReq.headers.set('apikey', anonKey);
  rpcReq.headers.set('Authorization', 'Bearer $token');
  rpcReq.headers.set('Content-Type', 'application/json');
  rpcReq.write(jsonEncode({'p_language': 'en'}));
  final rpcRes = await rpcReq.close();
  final rpcBody = await rpcRes.transform(utf8.decoder).join();
  print('fn_set_user_language(en) status: ${rpcRes.statusCode}, body: $rpcBody');

  // Check profiles table for this user
  final profReq = await _client.openUrl('GET', Uri.parse('$supabaseUrl/rest/v1/profiles?id=eq.$userId&select=id,language'));
  profReq.headers.set('apikey', serviceKey);
  profReq.headers.set('Authorization', 'Bearer $serviceKey');
  final profRes = await profReq.close();
  final profBody = await profRes.transform(utf8.decoder).join();
  print('Profile after setting "en": $profBody');

  // Now switch back to "ar"
  print('Calling fn_set_user_language with "ar"...');
  final rpcReq2 = await _client.openUrl('POST', Uri.parse('$supabaseUrl/rest/v1/rpc/fn_set_user_language'));
  rpcReq2.headers.set('apikey', anonKey);
  rpcReq2.headers.set('Authorization', 'Bearer $token');
  rpcReq2.headers.set('Content-Type', 'application/json');
  rpcReq2.write(jsonEncode({'p_language': 'ar'}));
  final rpcRes2 = await rpcReq2.close();
  final rpcBody2 = await rpcRes2.transform(utf8.decoder).join();
  print('fn_set_user_language(ar) status: ${rpcRes2.statusCode}, body: $rpcBody2');

  final profReq2 = await _client.openUrl('GET', Uri.parse('$supabaseUrl/rest/v1/profiles?id=eq.$userId&select=id,language'));
  profReq2.headers.set('apikey', serviceKey);
  profReq2.headers.set('Authorization', 'Bearer $serviceKey');
  final profRes2 = await profReq2.close();
  final profBody2 = await profRes2.transform(utf8.decoder).join();
  print('Profile after setting "ar": $profBody2');

  _client.close(force: true);
}
