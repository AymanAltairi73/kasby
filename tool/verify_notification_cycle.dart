import 'dart:convert';
import 'dart:io';

const supabaseUrl = 'https://majnuiypsgosbzsaeefc.supabase.co';
const anonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1ham51aXlwc2dvc2J6c2FlZWZjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzIwNzA5NzUsImV4cCI6MjA4NzY0Njk3NX0.M9OIGMQVdF4EACNae8G4pObbumB1fz_kR_xOz1G7chc';
const serviceRoleKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1ham51aXlwc2dvc2J6c2FlZWZjIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MjA3MDk3NSwiZXhwIjoyMDg3NjQ2OTc1fQ.5EoQZEgv9HmYLYIlF14vzd6u3qNX9LmJB-RtzE4sA1Q';

final _client = HttpClient();

class VerificationResult {
  final String operation;
  final String status;
  final String details;
  final Map<String, dynamic>? notificationRow;

  VerificationResult({
    required this.operation,
    required this.status,
    required this.details,
    this.notificationRow,
  });
}

Future<void> main() async {
  print('=================================================================');
  print('       KASBY NOTIFICATION CYCLE REAL DATABASE VERIFICATION       ');
  print('=================================================================\n');

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
    print('❌ FAILED TO AUTHENTICATE TEST USER: $authBody');
    exit(1);
  }

  final token = authJson['access_token'] as String;
  final user = authJson['user'] as Map<String, dynamic>;
  final userId = user['id'] as String;

  print('✅ Authenticated test user: ${user['email']} (ID: $userId)');

  final results = <VerificationResult>[];

  // Helper to query latest notification for test user
  Future<Map<String, dynamic>?> getLatestNotification({
    DateTime? createdAfter,
  }) async {
    var url =
        '$supabaseUrl/rest/v1/notifications?user_id=eq.$userId&order=created_at.desc&limit=1';
    if (createdAfter != null) {
      url += '&created_at=gt.${createdAfter.toIso8601String()}';
    }
    final req = await _client.openUrl('GET', Uri.parse(url));
    req.headers.set('apikey', serviceRoleKey);
    req.headers.set('Authorization', 'Bearer $serviceRoleKey');
    final res = await req.close();
    final body = await res.transform(utf8.decoder).join();
    final list = jsonDecode(body) as List;
    return list.isNotEmpty ? list.first as Map<String, dynamic> : null;
  }

  // Helper to call user RPC
  Future<Map<String, dynamic>> callRpc(
    String rpcName, [
    Map<String, dynamic>? params,
  ]) async {
    final uri = Uri.parse('$supabaseUrl/rest/v1/rpc/$rpcName');
    final req = await _client.openUrl('POST', uri);
    req.headers.set('apikey', anonKey);
    req.headers.set('Authorization', 'Bearer $token');
    req.headers.set('Content-Type', 'application/json');
    req.write(jsonEncode(params ?? {}));
    final res = await req.close();
    final body = await res.transform(utf8.decoder).join();
    try {
      final json = jsonDecode(body);
      if (json is Map<String, dynamic>) return json;
      return {'result': json, 'statusCode': res.statusCode};
    } catch (_) {
      return {'raw': body, 'statusCode': res.statusCode};
    }
  }

  // Ensure test account has enough reward KSP for redemption test
  final topupReq = await _client.openUrl(
    'PATCH',
    Uri.parse('$supabaseUrl/rest/v1/user_points?user_id=eq.$userId'),
  );
  topupReq.headers.set('apikey', serviceRoleKey);
  topupReq.headers.set('Authorization', 'Bearer $serviceRoleKey');
  topupReq.headers.set('Content-Type', 'application/json');
  topupReq.write(jsonEncode({'current_balance': 10000}));
  final topupRes = await topupReq.close();
  await topupRes.drain();

  // --- TEST 1: KSP -> USD Redemption Notification ---
  print('\n-----------------------------------------------------------------');
  print('TEST 1: KSP -> USD Redemption Notification Cycle');
  print('-----------------------------------------------------------------');
  final t1Start = DateTime.now().toUtc();
  final rpcResult = await callRpc('fn_redeem_ksp_to_wallet', {
    'p_ksp_amount': 1000,
    'p_idempotency_key':
        'test_notif_${userId}_${t1Start.millisecondsSinceEpoch}',
  });

  if (rpcResult['success'] == true) {
    await Future.delayed(const Duration(milliseconds: 500));
    final notif = await getLatestNotification(createdAfter: t1Start);
    if (notif != null) {
      print('✅ SUCCESS: Notification row created!');
      print('   ID: ${notif['id']}');
      print('   Title: ${notif['title']}');
      print('   Message: ${notif['message']}');
      print('   Type: ${notif['type']} | Category: ${notif['category']}');
      print('   DeepLink: ${notif['deep_link']}');
      results.add(
        VerificationResult(
          operation: '1. KSP -> USD Redemption',
          status: 'PASS',
          details: 'RPC succeeded and written notification row ${notif['id']}',
          notificationRow: notif,
        ),
      );
    } else {
      print('❌ FAIL: RPC succeeded but no notification row was found');
      results.add(
        VerificationResult(
          operation: '1. KSP -> USD Redemption',
          status: 'FAIL',
          details: 'RPC succeeded but notification record was missing',
        ),
      );
    }
  } else {
    print('ℹ️ RPC Result: $rpcResult');
    results.add(
      VerificationResult(
        operation: '1. KSP -> USD Redemption',
        status: 'FAIL',
        details: 'RPC execution failed: ${rpcResult['error']}',
      ),
    );
  }

  // --- TEST 2: Financial Failure Safety (Invalid Redemption) ---
  print('\n-----------------------------------------------------------------');
  print('TEST 2: Financial Failure Safety (No Notification on Error)');
  print('-----------------------------------------------------------------');
  final t2Start = DateTime.now().toUtc();
  final invalidResult = await callRpc('fn_redeem_ksp_to_wallet', {
    'p_ksp_amount': 999999999, // Insufficient points
    'p_idempotency_key':
        'test_fail_${userId}_${t2Start.millisecondsSinceEpoch}',
  });

  await Future.delayed(const Duration(milliseconds: 500));
  final failNotif = await getLatestNotification(createdAfter: t2Start);
  if (invalidResult['success'] != true && failNotif == null) {
    print('✅ SUCCESS: Invalid financial RPC failed AND NO notification was sent!');
    results.add(
      VerificationResult(
        operation: 'Financial Failure Safety (Failed RPC)',
        status: 'PASS',
        details: 'Failed operation correctly generated 0 notification records',
      ),
    );
  } else {
    print(
      '❌ FAIL: Financial failure produced notification or unexpected state',
    );
    results.add(
      VerificationResult(
        operation: 'Financial Failure Safety (Failed RPC)',
        status: 'FAIL',
        details: 'Notification row was created on failed financial RPC!',
      ),
    );
  }

  // --- TEST 3: Audit All Notification Records in Database for Test User ---
  print('\n-----------------------------------------------------------------');
  print('TEST 3: Audit Notification History & Schema Compliance');
  print('-----------------------------------------------------------------');
  final historyReq = await _client.openUrl(
    'GET',
    Uri.parse(
      '$supabaseUrl/rest/v1/notifications?user_id=eq.$userId&order=created_at.desc&limit=50',
    ),
  );
  historyReq.headers.set('apikey', serviceRoleKey);
  historyReq.headers.set('Authorization', 'Bearer $serviceRoleKey');
  final historyRes = await historyReq.close();
  final historyBody = await historyRes.transform(utf8.decoder).join();
  final historyList = jsonDecode(historyBody) as List;

  print('Found ${historyList.length} notification records for test account:');
  final typeCounts = <String, int>{};
  for (final row in historyList) {
    final type = (row['type'] ?? row['category'] ?? 'unknown').toString();
    typeCounts[type] = (typeCounts[type] ?? 0) + 1;
  }
  typeCounts.forEach((k, v) => print('  • $k: $v records'));

  // Print Summary Table
  print('\n=================================================================');
  print('                  NOTIFICATION VERIFICATION SUMMARY              ');
  print('=================================================================');
  for (final res in results) {
    print('${res.status.padRight(6)} | ${res.operation.padRight(35)} | ${res.details}');
  }

  _client.close(force: true);
}
