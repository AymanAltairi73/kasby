import 'dart:convert';
import 'dart:io';

const supabaseUrl = 'https://majnuiypsgosbzsaeefc.supabase.co';
const serviceKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1ham51aXlwc2dvc2J6c2FlZWZjIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MjA3MDk3NSwiZXhwIjoyMDg3NjQ2OTc1fQ.5EoQZEgv9HmYLYIlF14vzd6u3qNX9LmJB-RtzE4sA1Q';

final _client = HttpClient();

Future<void> main() async {
  const failingUserId = 'a1000001-0000-4000-8000-000000000004';
  
  // 1. Check user4 in profiles
  final profileReq = await _client.openUrl('GET', Uri.parse('$supabaseUrl/rest/v1/profiles?id=eq.$failingUserId'));
  profileReq.headers.set('apikey', serviceKey);
  profileReq.headers.set('Authorization', 'Bearer $serviceKey');
  final profileRes = await profileReq.close();
  final profileBody = await profileRes.transform(utf8.decoder).join();
  print('Profile:\n$profileBody');

  // 2. Check user4 in wallets
  final walletReq = await _client.openUrl('GET', Uri.parse('$supabaseUrl/rest/v1/wallets?user_id=eq.$failingUserId'));
  walletReq.headers.set('apikey', serviceKey);
  walletReq.headers.set('Authorization', 'Bearer $serviceKey');
  final walletRes = await walletReq.close();
  final walletBody = await walletRes.transform(utf8.decoder).join();
  print('Wallets:\n$walletBody');

  // 3. Check user4 in user_investments
  final invReq = await _client.openUrl('GET', Uri.parse('$supabaseUrl/rest/v1/user_investments?user_id=eq.$failingUserId'));
  invReq.headers.set('apikey', serviceKey);
  invReq.headers.set('Authorization', 'Bearer $serviceKey');
  final invRes = await invReq.close();
  final invBody = await invRes.transform(utf8.decoder).join();
  print('Investments:\n$invBody');

  _client.close(force: true);
}
