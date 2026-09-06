import 'dart:convert';
import 'dart:io';

const supabaseUrl = 'https://majnuiypsgosbzsaeefc.supabase.co';
const serviceKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1ham51aXlwc2dvc2J6c2FlZWZjIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MjA3MDk3NSwiZXhwIjoyMDg3NjQ2OTc1fQ.5EoQZEgv9HmYLYIlF14vzd6u3qNX9LmJB-RtzE4sA1Q';

final _client = HttpClient();

Future<dynamic> getJson(String endpoint) async {
  final uri = Uri.parse('$supabaseUrl/rest/v1/$endpoint');
  final req = await _client.openUrl('GET', uri);
  req.headers.set('apikey', serviceKey);
  req.headers.set('Authorization', 'Bearer $serviceKey');
  final res = await req.close();
  final body = await res.transform(utf8.decoder).join();
  if (res.statusCode >= 200 && res.statusCode < 300) {
    return jsonDecode(body);
  } else {
    print('Error $endpoint (${res.statusCode}): $body');
    return null;
  }
}

Future<void> main() async {
  print('=== 1. FETCHING THE THREE INVESTMENTS ===');
  final ids = [
    '81402050-0685-4aaa-8d8a-198bc7fca27d',
    '9c9d6ed9-c42c-40b6-8140-06e362160cb8',
    'a1efde21-7546-4b53-9923-61a93d863934',
  ];

  for (final id in ids) {
    final res = await getJson('user_investments?id=eq.$id');
    print('\n--- Investment: $id ---');
    if (res is List && res.isNotEmpty) {
      final inv = res.first as Map<String, dynamic>;
      final encoder = JsonEncoder.withIndent('  ');
      print(encoder.convert(inv));
    } else {
      print('Not found: $res');
    }
  }

  print('\n=== 2. CHECKING ALL ACTIVE INVESTMENTS WITH NULL next_payout_at ===');
  final nullPayouts = await getJson('user_investments?status=eq.active&next_payout_at=is.null&select=id,user_id,amount,status,auto_restart_enabled,next_payout_at,last_profit_at,created_at');
  if (nullPayouts is List) {
    print('Found ${nullPayouts.length} active investments with next_payout_at IS NULL:');
    for (final row in nullPayouts) {
      print(row);
    }
  }

  print('\n=== 3. CHECKING USER SUBSCRIPTION STATE FOR THESE USERS ===');
  // Find distinct user_ids
  final allThree = await getJson('user_investments?id=in.(${ids.join(",")})&select=id,user_id');
  if (allThree is List) {
    final userIds = allThree.map((e) => e['user_id'] as String).toSet().toList();
    print('User IDs: $userIds');
    for (final uid in userIds) {
      print('\n-- Profiles for user: $uid --');
      final prof = await getJson('profiles?id=eq.$uid');
      print(prof);

      print('-- Subscriptions for user: $uid --');
      final subs = await getJson('subscriptions?user_id=eq.$uid');
      print(subs);
    }
  }

  _client.close(force: true);
}
