import 'dart:convert';
import 'dart:io';

const supabaseUrl = 'https://majnuiypsgosbzsaeefc.supabase.co';
const anonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1ham51aXlwc2dvc2J6c2FlZWZjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzIwNzA5NzUsImV4cCI6MjA4NzY0Njk3NX0.M9OIGMQVdF4EACNae8G4pObbumB1fz_kR_xOz1G7chc';
const serviceKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1ham51aXlwc2dvc2J6c2FlZWZjIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MjA3MDk3NSwiZXhwIjoyMDg3NjQ2OTc1fQ.5EoQZEgv9HmYLYIlF14vzd6u3qNX9LmJB-RtzE4sA1Q';

final client = HttpClient();

Future<void> main() async {
  print('=== 1. Logging in with user credentials ===');
  final loginUri = Uri.parse('$supabaseUrl/auth/v1/token?grant_type=password');
  final loginReq = await client.openUrl('POST', loginUri);
  loginReq.headers.set('apikey', anonKey);
  loginReq.headers.set('Content-Type', 'application/json');
  loginReq.write(jsonEncode({
    'email': 'broayman422@gmail.com',
    'password': r'Ayman$_73',
  }));

  final loginRes = await loginReq.close();
  final loginBodyStr = await loginRes.transform(utf8.decoder).join();

  if (loginRes.statusCode != 200) {
    print('Login FAILED: status=${loginRes.statusCode}');
    print('Response: $loginBodyStr');
    client.close(force: true);
    return;
  }

  final loginData = jsonDecode(loginBodyStr) as Map<String, dynamic>;
  final accessToken = loginData['access_token'] as String;
  final user = loginData['user'] as Map<String, dynamic>;
  final userId = user['id'] as String;
  print('Login SUCCESS!');
  print('User ID: $userId');
  print('Email: ${user['email']}');

  print('\n=== 2. Fetching User Profile & Wallets ===');
  // Profile
  final profUri = Uri.parse('$supabaseUrl/rest/v1/profiles?id=eq.$userId&select=*');
  final profReq = await client.openUrl('GET', profUri);
  profReq.headers.set('apikey', anonKey);
  profReq.headers.set('Authorization', 'Bearer $accessToken');
  final profRes = await profReq.close();
  final profBodyStr = await profRes.transform(utf8.decoder).join();
  print('Profile: $profBodyStr');

  // Wallets
  final walletUri = Uri.parse('$supabaseUrl/rest/v1/wallets?user_id=eq.$userId&select=*');
  final walletReq = await client.openUrl('GET', walletUri);
  walletReq.headers.set('apikey', anonKey);
  walletReq.headers.set('Authorization', 'Bearer $accessToken');
  final walletRes = await walletReq.close();
  final walletBodyStr = await walletRes.transform(utf8.decoder).join();
  print('Wallets: $walletBodyStr');

  print('\n=== 3. Fetching Investment Plans (specifically Silver / فضة) ===');
  final plansUri = Uri.parse('$supabaseUrl/rest/v1/investment_plans?select=*');
  final plansReq = await client.openUrl('GET', plansUri);
  plansReq.headers.set('apikey', anonKey);
  plansReq.headers.set('Authorization', 'Bearer $accessToken');
  final plansRes = await plansReq.close();
  final plansBodyStr = await plansRes.transform(utf8.decoder).join();
  final plans = jsonDecode(plansBodyStr) as List;

  Map<String, dynamic>? silverPlan;
  for (final p in plans) {
    final title = (p['title'] ?? '').toString();
    final name = (p['name'] ?? '').toString();
    print('Plan: id=${p['id']}, title="$title", min=${p['min_amount']}, max=${p['max_amount']}, status=${p['status'] ?? p['is_active']}');
    if (title.contains('فضة') || title.toLowerCase().contains('silver') || name.contains('فضة') || name.toLowerCase().contains('silver')) {
      silverPlan = Map<String, dynamic>.from(p);
    }
  }

  if (silverPlan == null) {
    print('Silver plan not found by text match, checking all plans keys...');
    for (final p in plans) {
      print('Plan details: $p');
    }
    client.close(force: true);
    return;
  }

  print('\nFound Silver Plan:');
  print('  ID: ${silverPlan['id']}');
  print('  Title: ${silverPlan['title']}');
  print('  Min Amount: ${silverPlan['min_amount']}');
  print('  Max Amount: ${silverPlan['max_amount']}');
  print('  Duration (days): ${silverPlan['duration_days']}');
  print('  Expected Return: ${silverPlan['expected_return_rate'] ?? silverPlan['return_rate']}');

  final minAmount = (silverPlan['min_amount'] as num?)?.toDouble() ?? 10.0;
  final planId = silverPlan['id'];

  print('\n=== 4. Attempting to execute create_investment ===');
  final idempotencyKey = 'test-silver-${DateTime.now().millisecondsSinceEpoch}';
  final rpcUri = Uri.parse('$supabaseUrl/rest/v1/rpc/create_investment');
  final rpcReq = await client.openUrl('POST', rpcUri);
  rpcReq.headers.set('apikey', anonKey);
  rpcReq.headers.set('Authorization', 'Bearer $accessToken');
  rpcReq.headers.set('Content-Type', 'application/json');
  rpcReq.write(jsonEncode({
    'p_plan_id': planId,
    'p_amount': minAmount,
    'p_idempotency_key': idempotencyKey,
  }));

  final rpcRes = await rpcReq.close();
  final rpcBodyStr = await rpcRes.transform(utf8.decoder).join();
  print('create_investment HTTP status: ${rpcRes.statusCode}');
  print('create_investment Response: $rpcBodyStr');

  print('\n=== 5. Checking user investments ===');
  final invUri = Uri.parse('$supabaseUrl/rest/v1/user_investments?user_id=eq.$userId&select=*&order=created_at.desc&limit=5');
  final invReq = await client.openUrl('GET', invUri);
  invReq.headers.set('apikey', anonKey);
  invReq.headers.set('Authorization', 'Bearer $accessToken');
  final invRes = await invReq.close();
  final invBodyStr = await invRes.transform(utf8.decoder).join();
  print('User Investments: $invBodyStr');

  client.close(force: true);
}
