import 'dart:convert';
import 'dart:io';

const supabaseUrl = 'https://majnuiypsgosbzsaeefc.supabase.co';
const serviceKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1ham51aXlwc2dvc2J6c2FlZWZjIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MjA3MDk3NSwiZXhwIjoyMDg3NjQ2OTc1fQ.5EoQZEgv9HmYLYIlF14vzd6u3qNX9LmJB-RtzE4sA1Q';

final _client = HttpClient();

Future<String> get(String path) async {
  final req = await _client.openUrl('GET', Uri.parse('$supabaseUrl/rest/v1$path'));
  req.headers.set('apikey', serviceKey);
  req.headers.set('Authorization', 'Bearer $serviceKey');
  final res = await req.close();
  final body = await res.transform(utf8.decoder).join();
  return '${res.statusCode}: $body';
}

Future<void> main() async {
  const uid = '7ce89452-c4d8-4867-8343-558148cc2bd9';

  print('=== TRANSACTIONS sample (column layout) ===');
  print(await get('/transactions?limit=1'));

  print('\n=== Wallets of failing user ===');
  print(await get('/wallets?user_id=eq.$uid'));

  print('\n=== Active investments of failing user ===');
  print(await get(
      '/user_investments?user_id=eq.$uid&status=eq.active&order=created_at.desc'));

  print('\n=== All investments of failing user ===');
  print(await get('/user_investments?user_id=eq.$uid&order=created_at.desc'));

  print('\n=== Recent transactions of failing user ===');
  print(await get(
      '/transactions?user_id=eq.$uid&order=created_at.desc&limit=10'));

  print('\n=== Profile of failing user ===');
  print(await get('/profiles?id=eq.$uid'));

  _client.close(force: true);
}