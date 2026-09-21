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
  final activeInvs = await get(
      '/rest/v1/user_investments?status=eq.active&select=id,user_id,plan_id,status,created_at,next_payout_at,last_profit_at,auto_restart_enabled,amount,expected_profit,actual_profit&order=created_at.asc');
  
  final profiles = await get('/rest/v1/profiles?select=id,full_name,email');
  final profMap = <String, Map<String, dynamic>>{};
  for (final p in profiles) profMap[p['id']] = Map<String, dynamic>.from(p);

  final plans = await get('/rest/v1/investment_plans?select=*');
  final planMap = <String, Map<String, dynamic>>{};
  for (final pl in plans) planMap[pl['id']] = Map<String, dynamic>.from(pl);

  final userInvs = <String, List<Map<String, dynamic>>>{};
  for (final inv in activeInvs) {
    final uid = inv['user_id'] as String;
    userInvs.putIfAbsent(uid, () => []).add(inv);
  }

  print('=== ALL 19 ACTIVE USERS (TOTAL 94 ACTIVE INVESTMENTS) ===');
  
  final the12Users = {
    'ae2321a7-b8bd-4959-91a8-196854c3cc32',
    '4675897b-20d5-4951-bc91-4da562215cc3',
    '5e5ba185-a26f-4c9a-8413-78affbf48995',
    '8f1720d1-69d5-4d29-a496-03e1f3ea81ab',
    '984fbc5a-663a-4207-b4c8-f086f93701ea',
    '34e3337d-7f01-45fa-8dba-b7488507df93',
    '8963306f-4a46-42ff-8394-4d02cd3c3500',
    'e5201c53-a47c-45c3-a776-c17d44b2c192',
    '7ce89452-c4d8-4867-8343-558148cc2bd9',
    'c33f59c4-ee76-4568-a767-534cfb9529e0',
    '33f6b995-1fae-4d29-b7fb-3cb765d18d19',
    '7adf3f78-5340-443b-a965-738ea29633d7',
  };

  int the12Count = 0;
  int theOther7Count = 0;

  for (final uid in userInvs.keys) {
    final list = userInvs[uid]!;
    final name = profMap[uid]?['full_name'] ?? 'Unknown';
    final email = profMap[uid]?['email'] ?? 'Unknown';
    final isOneOfThe12 = the12Users.contains(uid);
    if (isOneOfThe12) {
      the12Count += list.length;
    } else {
      theOther7Count += list.length;
      print('OTHER USER: $uid | $name ($email) | Investments: ${list.length}');
      for (final inv in list) {
        print('   Inv ${inv['id']} | Created: ${inv['created_at']} | NextPayout: ${inv['next_payout_at']} | AutoRestart: ${inv['auto_restart_enabled']} | Exp: ${inv['expected_profit']} | Act: ${inv['actual_profit']}');
      }
    }
  }

  print('\nSummary:');
  print('12 previously reported users: $the12Count investments');
  print('Remaining 7 active users: $theOther7Count investments');
  print('Total active: ${the12Count + theOther7Count} investments across ${userInvs.length} users');
}
