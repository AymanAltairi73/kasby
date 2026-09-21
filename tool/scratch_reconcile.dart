import 'dart:convert';
import 'dart:io';

const supabaseUrl = 'https://majnuiypsgosbzsaeefc.supabase.co';
const serviceKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1ham51aXlwc2dvc2J6c2FlZWZjIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MjA3MDk3NSwiZXhwIjoyMDg3NjQ2OTc1fQ.5EoQZEgv9HmYLYIlF14vzd6u3qNX9LmJB-RtzE4sA1Q';

Future<dynamic> get(String path) async {
  final client = HttpClient();
  final req = await client.openUrl('GET', Uri.parse('$supabaseUrl$path'));
  req.headers.set('apikey', serviceKey);
  req.headers.set('Authorization', 'Bearer $serviceKey');
  final res = await req.close();
  final body = await res.transform(utf8.decoder).join();
  return jsonDecode(body);
}

void main() async {
  final allInvs = await get(
      '/rest/v1/user_investments?select=id,user_id,plan_id,status,created_at,next_payout_at,last_profit_at,auto_restart_enabled,amount,expected_profit,actual_profit');
  print('Total user_investments in DB: ${allInvs.length}');

  final byStatus = <String, int>{};
  final usersAll = <String>{};
  final usersByStatus = <String, Set<String>>{};

  for (final inv in allInvs) {
    final s = inv['status']?.toString() ?? 'null';
    byStatus[s] = (byStatus[s] ?? 0) + 1;
    usersAll.add(inv['user_id'] as String);
    usersByStatus.putIfAbsent(s, () => <String>{}).add(inv['user_id'] as String);
  }

  print('Count by status: $byStatus');
  print('Total distinct users across all investments: ${usersAll.length}');
  for (final entry in usersByStatus.entries) {
    print('Status "${entry.key}": ${byStatus[entry.key]} investments across ${entry.value.length} users');
  }

  // Check what 56 and 94 correspond to:
  // Are there 56 active? Are there 94 total?
}
