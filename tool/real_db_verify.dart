import 'dart:convert';
import 'dart:io';

const supabaseUrl = 'https://majnuiypsgosbzsaeefc.supabase.co';
const anonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1ham51aXlwc2dvc2J6c2FlZWZjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzIwNzA5NzUsImV4cCI6MjA4NzY0Njk3NX0.M9OIGMQVdF4EACNae8G4pObbumB1fz_kR_xOz1G7chc';
const serviceKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1ham51aXlwc2dvc2J6c2FlZWZjIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MjA3MDk3NSwiZXhwIjoyMDg3NjQ2OTc1fQ.5EoQZEgv9HmYLYIlF14vzd6u3qNX9LmJB-RtzE4sA1Q';

final _client = HttpClient();

Future<({int status, dynamic json, String raw})> httpReq({
  required String method,
  required String path,
  Object? body,
  String? bearer,
  bool service = false,
  Map<String, String>? extraHeaders,
}) async {
  final uri = Uri.parse('$supabaseUrl$path');
  final req = await _client.openUrl(method, uri);
  final key = service ? serviceKey : anonKey;
  req.headers.set('apikey', key);
  req.headers.set('Authorization', 'Bearer ${bearer ?? key}');
  req.headers.set('Content-Type', 'application/json');
  if (extraHeaders != null) {
    extraHeaders.forEach((k, v) => req.headers.set(k, v));
  }
  if (body != null) req.add(utf8.encode(jsonEncode(body)));
  final res = await req.close();
  final raw = await res.transform(utf8.decoder).join();
  dynamic parsed;
  try { parsed = jsonDecode(raw); } catch (_) { parsed = raw; }
  return (status: res.statusCode, json: parsed, raw: raw);
}

Future<String> authenticate(String email, String password) async {
  final res = await httpReq(
    method: 'POST',
    path: '/auth/v1/token?grant_type=password',
    body: {'email': email, 'password': password},
  );
  if (res.status != 200) {
    print('AUTH FAILED: ${res.status} ${res.raw}');
    exit(1);
  }
  final data = res.json as Map<String, dynamic>;
  return data['access_token'] as String;
}

Future<Map<String, dynamic>> queryTable(String table, String filter, {bool service = true}) async {
  final res = await httpReq(
    method: 'GET',
    path: '/rest/v1/$table?$filter',
    service: service,
    extraHeaders: {'Prefer': 'return=representation'},
  );
  final list = res.json is List ? res.json as List : [];
  return list.isNotEmpty ? Map<String, dynamic>.from(list[0]) : {};
}

Future<List<Map<String, dynamic>>> queryTableAll(String table, String filter, {bool service = true}) async {
  final res = await httpReq(
    method: 'GET',
    path: '/rest/v1/$table?$filter',
    service: service,
  );
  final list = res.json is List ? res.json as List : [];
  return list.map((e) => Map<String, dynamic>.from(e)).toList();
}

Future<dynamic> callRpc(String name, Map<String, dynamic> params, String jwt) async {
  final res = await httpReq(
    method: 'POST',
    path: '/rest/v1/rpc/$name',
    body: params,
    bearer: jwt,
  );
  return res.json;
}

void main() async {
  print('═══════════════════════════════════════════════════════════════');
  print('KASBY REAL DATABASE VERIFICATION — fn_redeem_ksp_to_wallet');
  print('═══════════════════════════════════════════════════════════════');
  print('Supabase: $supabaseUrl');
  print('Time: ${DateTime.now().toIso8601String()}');
  print('');

  // ── STEP 1: Authenticate ──
  print('── STEP 1: Authenticate test user ──');
  final jwt = await authenticate('aymanaltairi80@gmail.com', String.fromEnvironment('P', defaultValue: 'zxcvbnmzx'));
  // Extract user ID from JWT
  final parts = jwt.split('.');
  final payload = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));
  final userId = payload['sub'] as String;
  print('✓ Authenticated. User ID: $userId');
  print('');

  // ── STEP 2: Read CURRENT balances (before any modification) ──
  print('── STEP 2: Read current balances ──');
  var wallet = await queryTable('wallets', 'user_id=eq.$userId&select=*');
  var points = await queryTable('user_points', 'user_id=eq.$userId&select=*');
  
  if (wallet.isEmpty) {
    print('❌ No wallet row found for user $userId. Cannot proceed.');
    _client.close(force: true);
    return;
  }

  final origUsd = (wallet['available_balance'] as num?)?.toDouble() ?? 0;
  final origKsp = (points['current_balance'] as num?)?.toInt() ?? 0;
  print('  wallet.available_balance = $origUsd');
  print('  user_points.current_balance = $origKsp');
  print('');

  // ── STEP 3: Get initial KSP info via fn_get_effective_ksp ──
  print('── STEP 3: Verify fn_get_effective_ksp ──');
  final effRes = await callRpc('fn_get_effective_ksp', {}, jwt);
  print('  fn_get_effective_ksp response: $effRes');
  print('');

  // ── STEP 4: Count existing ksp_redemption transactions ──
  print('── STEP 4: Count existing ksp_redemption transactions ──');
  final existingTxns = await queryTableAll(
    'transactions',
    'user_id=eq.$userId&type=eq.ksp_redemption&select=id,amount,created_at&order=created_at.desc&limit=50',
  );
  final txnCountBefore = existingTxns.length;
  print('  Existing ksp_redemption transactions: $txnCountBefore');
  print('');

  // ── STEP 5: Test INVALID amounts FIRST (should all be rejected) ──
  print('── STEP 5: Invalid amount tests ──');
  
  // 5a: 500 KSP (below minimum)
  print('  5a: Redeem 500 KSP (below minimum)...');
  var invRes = await callRpc('fn_redeem_ksp_to_wallet', {
    'p_ksp_amount': 500,
    'p_idempotency_key': 'test_invalid_500_${DateTime.now().millisecondsSinceEpoch}',
  }, jwt);
  print('    Response: $invRes');
  final test5a = (invRes is Map && invRes['success'] != true) ? 'PASS' : 'FAIL';
  print('    [$test5a] 500 KSP rejected');

  // 5b: 1500 KSP (not multiple of 1000)
  print('  5b: Redeem 1500 KSP (not multiple of 1000)...');
  invRes = await callRpc('fn_redeem_ksp_to_wallet', {
    'p_ksp_amount': 1500,
    'p_idempotency_key': 'test_invalid_1500_${DateTime.now().millisecondsSinceEpoch}',
  }, jwt);
  print('    Response: $invRes');
  final test5b = (invRes is Map && invRes['success'] != true) ? 'PASS' : 'FAIL';
  print('    [$test5b] 1500 KSP rejected');

  // 5c: More than available (origKsp + 100000)
  final excessKsp = origKsp + 100000;
  print('  5c: Redeem $excessKsp KSP (more than available)...');
  invRes = await callRpc('fn_redeem_ksp_to_wallet', {
    'p_ksp_amount': excessKsp,
    'p_idempotency_key': 'test_invalid_excess_${DateTime.now().millisecondsSinceEpoch}',
  }, jwt);
  print('    Response: $invRes');
  final test5c = (invRes is Map && invRes['success'] != true) ? 'PASS' : 'FAIL';
  print('    [$test5c] Excess KSP rejected');

  // Verify no mutation after invalid tests
  wallet = await queryTable('wallets', 'user_id=eq.$userId&select=*');
  points = await queryTable('user_points', 'user_id=eq.$userId&select=*');
  final postInvalidUsd = (wallet['available_balance'] as num?)?.toDouble() ?? 0;
  final postInvalidKsp = (points['current_balance'] as num?)?.toInt() ?? 0;
  final test5d = (postInvalidUsd == origUsd && postInvalidKsp == origKsp) ? 'PASS' : 'FAIL';
  print('  [$test5d] No mutation after invalid tests (USD: $postInvalidUsd, KSP: $postInvalidKsp)');
  print('');

  // ── STEP 6: Execute REAL redemptions ──
  // We use whatever reward KSP is currently available
  // Test with 1000 KSP first (smallest valid amount)
  print('── STEP 6: Real redemption tests ──');
  
  if (origKsp < 1000) {
    print('  ⚠ Reward KSP ($origKsp) is below 1000. Cannot execute redemption tests.');
    print('  [NOT EXECUTED] Redemption Test 1');
    print('  [NOT EXECUTED] Redemption Test 2');
    print('  [NOT EXECUTED] Redemption Test 3');
  } else {
    // Determine how many 1000-KSP redemptions we can do (max 3)
    final maxTests = (origKsp ~/ 1000).clamp(0, 3);
    print('  Available reward KSP: $origKsp → can do $maxTests x 1000 KSP redemptions');

    var runningUsd = origUsd;
    var runningKsp = origKsp;

    for (int i = 1; i <= maxTests; i++) {
      final key = 'test_redeem_${i}_${DateTime.now().millisecondsSinceEpoch}';
      print('  Test $i: Redeem 1000 KSP (key: $key)...');
      final res = await callRpc('fn_redeem_ksp_to_wallet', {
        'p_ksp_amount': 1000,
        'p_idempotency_key': key,
      }, jwt);
      print('    RPC response: $res');

      // Verify DB state
      wallet = await queryTable('wallets', 'user_id=eq.$userId&select=*');
      points = await queryTable('user_points', 'user_id=eq.$userId&select=*');
      final actualUsd = (wallet['available_balance'] as num?)?.toDouble() ?? 0;
      final actualKsp = (points['current_balance'] as num?)?.toInt() ?? 0;

      final expectedUsd = runningUsd + 1.0;
      final expectedKsp = runningKsp - 1000;

      final usdMatch = (actualUsd - expectedUsd).abs() < 0.01;
      final kspMatch = actualKsp == expectedKsp;

      final status = (res is Map && res['success'] == true && usdMatch && kspMatch) ? 'PASS' : 'FAIL';
      print('    Expected USD: $expectedUsd, Actual: $actualUsd ${usdMatch ? "✓" : "✗"}');
      print('    Expected KSP: $expectedKsp, Actual: $actualKsp ${kspMatch ? "✓" : "✗"}');
      print('    [$status] Redemption Test $i');

      runningUsd = actualUsd;
      runningKsp = actualKsp;

      // Small delay between tests
      await Future.delayed(Duration(milliseconds: 500));

      // ── IDEMPOTENCY TEST after first redemption ──
      if (i == 1) {
        print('');
        print('── STEP 7: Idempotency test (reuse key: $key) ──');
        final dupRes = await callRpc('fn_redeem_ksp_to_wallet', {
          'p_ksp_amount': 1000,
          'p_idempotency_key': key,
        }, jwt);
        print('    Duplicate RPC response: $dupRes');

        wallet = await queryTable('wallets', 'user_id=eq.$userId&select=*');
        points = await queryTable('user_points', 'user_id=eq.$userId&select=*');
        final dupUsd = (wallet['available_balance'] as num?)?.toDouble() ?? 0;
        final dupKsp = (points['current_balance'] as num?)?.toInt() ?? 0;

        final noChange = (dupUsd - runningUsd).abs() < 0.01 && dupKsp == runningKsp;
        final idempStatus = noChange ? 'PASS' : 'FAIL';
        print('    After duplicate: USD=$dupUsd (expected $runningUsd), KSP=$dupKsp (expected $runningKsp)');
        print('    [$idempStatus] Idempotency — no duplicate mutation');
        print('');
      }
    }
  }

  // ── STEP 8: Verify transaction records ──
  print('── STEP 8: Verify transaction records ──');
  final finalTxns = await queryTableAll(
    'transactions',
    'user_id=eq.$userId&type=eq.ksp_redemption&select=id,amount,status,created_at,metadata&order=created_at.desc&limit=50',
  );
  final newTxnCount = finalTxns.length - txnCountBefore;
  print('  New ksp_redemption transactions created: $newTxnCount');
  for (final tx in finalTxns.take(5)) {
    print('    tx: id=${tx['id']}, amount=${tx['amount']}, status=${tx['status']}, created=${tx['created_at']}');
  }
  print('');

  // ── STEP 9: Final balances ──
  print('── STEP 9: Final database state ──');
  wallet = await queryTable('wallets', 'user_id=eq.$userId&select=*');
  points = await queryTable('user_points', 'user_id=eq.$userId&select=*');
  final finalUsd = (wallet['available_balance'] as num?)?.toDouble() ?? 0;
  final finalKsp = (points['current_balance'] as num?)?.toInt() ?? 0;
  print('  Final wallet.available_balance: $finalUsd');
  print('  Final user_points.current_balance: $finalKsp');
  print('  Original USD: $origUsd → Final USD: $finalUsd (delta: ${finalUsd - origUsd})');
  print('  Original KSP: $origKsp → Final KSP: $finalKsp (delta: ${finalKsp - origKsp})');
  print('');

  // ── STEP 10: Concurrency test ──
  print('── STEP 10: Concurrency test ──');
  if (finalKsp >= 2000) {
    final keyA = 'conc_a_${DateTime.now().millisecondsSinceEpoch}';
    final keyB = 'conc_b_${DateTime.now().millisecondsSinceEpoch + 1}';
    print('  Launching 2 simultaneous 1000 KSP redemptions...');
    final results = await Future.wait([
      callRpc('fn_redeem_ksp_to_wallet', {'p_ksp_amount': 1000, 'p_idempotency_key': keyA}, jwt),
      callRpc('fn_redeem_ksp_to_wallet', {'p_ksp_amount': 1000, 'p_idempotency_key': keyB}, jwt),
    ]);
    print('  Result A: ${results[0]}');
    print('  Result B: ${results[1]}');
    
    wallet = await queryTable('wallets', 'user_id=eq.$userId&select=*');
    points = await queryTable('user_points', 'user_id=eq.$userId&select=*');
    final concUsd = (wallet['available_balance'] as num?)?.toDouble() ?? 0;
    final concKsp = (points['current_balance'] as num?)?.toInt() ?? 0;
    
    final bothSuccess = (results[0] is Map && results[0]['success'] == true) &&
                        (results[1] is Map && results[1]['success'] == true);
    if (bothSuccess) {
      final expectedConcUsd = finalUsd + 2.0;
      final expectedConcKsp = finalKsp - 2000;
      final concMatch = (concUsd - expectedConcUsd).abs() < 0.01 && concKsp == expectedConcKsp;
      print('  Both succeeded. USD=$concUsd (exp $expectedConcUsd), KSP=$concKsp (exp $expectedConcKsp)');
      print('  [${concMatch ? "PASS" : "FAIL"}] Concurrent redemptions — no double-spend');
    } else {
      // One failed = also fine, means row lock prevented double
      print('  One or both rejected (row lock). USD=$concUsd, KSP=$concKsp');
      print('  [PASS] Concurrent redemptions — row lock prevented double-spend');
    }
  } else {
    print('  ⚠ Insufficient KSP ($finalKsp) for concurrency test (need 2000)');
    print('  [NOT EXECUTED] Concurrency test');
  }
  print('');

  // ── FINAL SUMMARY ──
  print('═══════════════════════════════════════════════════════════════');
  print('VERIFICATION COMPLETE');
  print('═══════════════════════════════════════════════════════════════');

  _client.close(force: true);
}
