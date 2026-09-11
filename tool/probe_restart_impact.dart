import 'dart:convert';
import 'dart:io';

const supabaseUrl = 'https://majnuiypsgosbzsaeefc.supabase.co';
const serviceKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1ham51aXlwc2dvc2J6c2FlZWZjIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MjA3MDk3NSwiZXhwIjoyMDg3NjQ2OTc1fQ.5EoQZEgv9HmYLYIlF14vzd6u3qNX9LmJB-RtzE4sA1Q';

final _client = HttpClient();

Future<List<dynamic>> getRows(String path) async {
  final req = await _client.openUrl('GET', Uri.parse('$supabaseUrl/rest/v1$path'));
  req.headers.set('apikey', serviceKey);
  req.headers.set('Authorization', 'Bearer $serviceKey');
  final res = await req.close();
  final body = await res.transform(utf8.decoder).join();
  if (res.statusCode != 200) {
    print('HTTP ${res.statusCode} for $path: $body');
    return [];
  }
  return jsonDecode(body) as List<dynamic>;
}

Future<void> main() async {
  const users = [
    'a1000001-0000-4000-8000-000000000004',
    '7ce89452-c4d8-4867-8343-558148cc2bd9',
  ];
  for (final u in users) {
    final subs = await getRows('/subscriptions?user_id=eq.$u&select=id,tier,is_yearly,status,start_date,end_date,expires_at');
    final prof = await getRows('/profiles?select=id,account_tier&id=eq.$u');
    print('USER $u TABLE rows: ${subs.length}');
    for (final s in subs) {
      print('  SUB ${jsonEncode(s)}');
    }
    print('  PROFILE ${jsonEncode(prof)}');
  }

  final allActive = await getRows('/subscriptions?status=eq.active&select=user_id,tier,end_date&limit=20');
  print('ALL ACTIVE SUBSCRIPTIONS (first 20): ${allActive.length}');
  for (final s in allActive) {
    print('  ${jsonEncode(s)}');
  }

  final vip = await getRows('/profiles?account_tier=in.(premium,vip)&select=id,account_tier&limit=20');
  print('PREMIUM/VIP PROFILES (first 20): ${vip.length}');
  for (final p in vip) {
    print('  ${jsonEncode(p)}');
  }

  final activeInv = await getRows('/user_investments?status=eq.active&select=user_id,auto_restart_enabled,next_payout_at,last_profit_at,plan_id&limit=500');
  final byUser = <String, List<Map<String, dynamic>>>{};
  for (final i in activeInv.cast<Map<String, dynamic>>()) {
    byUser.putIfAbsent(i['user_id'] as String, () => []).add(i);
  }
  print('ACTIVE-INVESTMENT USERS: ${byUser.length}, total active: ${activeInv.length}');
  for (final e in byUser.entries) {
    final autoOn = e.value.where((i) => i['auto_restart_enabled'] == true).length;
    final due = e.value.where((i) => i['next_payout_at'] != null && (DateTime.parse(i['next_payout_at'] as String).isBefore(DateTime.now()))).length;
    print('  ${e.key} total=${e.value.length} auto_restart=true=${autoOn} overdue=${due}');
  }
  _client.close(force: true);
}