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
  print('=== DEEP ANALYSIS OF POPULATION & DIFFERENCES ===\n');

  final plans = await get('/rest/v1/investment_plans?select=*');
  final planMap = <String, Map<String, dynamic>>{};
  for (final pl in plans) planMap[pl['id']] = Map<String, dynamic>.from(pl);

  final profiles = await get('/rest/v1/profiles?select=id,full_name,email');
  final profMap = <String, Map<String, dynamic>>{};
  for (final pr in profiles) profMap[pr['id']] = Map<String, dynamic>.from(pr);

  final allActiveInvs = await get('/rest/v1/user_investments?status=eq.active&select=*&order=created_at.asc');
  final allProfitTxns = await get('/rest/v1/transactions?type=eq.profit&select=id,user_id,amount,reference_id,created_at&order=created_at.asc');

  final txnsByInv = <String, List<Map<String, dynamic>>>{};
  for (final tx in allProfitTxns) {
    final ref = tx['reference_id']?.toString() ?? '';
    if (ref.isNotEmpty) {
      txnsByInv.putIfAbsent(ref, () => []).add(Map<String, dynamic>.from(tx));
    }
  }

  // The 12 users from previous report:
  final userGroup12 = {
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

  print('Total active investments in DB: ${allActiveInvs.length}');
  
  // Categorize the 94 investments:
  // 1. Group 12 users: 70 investments
  //    - 56 were due and active during outage
  //    - 14 were not due / next_payout_at null / past
  // 2. Group 7 users: 24 investments
  //    - all 24 had next_payout_at null and auto_restart false

  final invs56 = <Map<String, dynamic>>[];
  final invs14 = <Map<String, dynamic>>[];
  final invs24 = <Map<String, dynamic>>[];

  for (final inv in allActiveInvs) {
    final uid = inv['user_id'] as String;
    final nextPayout = inv['next_payout_at'];
    final autoRestart = inv['auto_restart_enabled'] == true;

    if (userGroup12.contains(uid)) {
      // In group of 12 users
      if (nextPayout != null || autoRestart) {
        invs56.add(inv);
      } else {
        invs14.add(inv);
      }
    } else {
      // In group of 7 users
      invs24.add(inv);
    }
  }

  print('Group 12 users due investments (56): ${invs56.length}');
  print('Group 12 users non-due investments (14): ${invs14.length}');
  print('Group 7 other users investments (24): ${invs24.length}');

  // Print exact details of the 7 users
  final group7Users = <String, Map<String, dynamic>>{};
  for (final inv in invs24) {
    final uid = inv['user_id'] as String;
    group7Users.putIfAbsent(uid, () => {
      'user_id': uid,
      'name': profMap[uid]?['full_name'] ?? 'Unknown',
      'email': profMap[uid]?['email'] ?? 'Unknown',
      'investments': <Map<String, dynamic>>[],
    });
    (group7Users[uid]!['investments'] as List).add(inv);
  }

  print('\n=== THE 7 USERS AND THEIR 24 INVESTMENTS ===');
  for (final entry in group7Users.entries) {
    final u = entry.value;
    print('User: ${u['name']} (${u['email']}) | ID: ${u['user_id']} | Count: ${(u['investments'] as List).length}');
    for (final inv in u['investments'] as List) {
      print('   - Inv ${inv['id']} | Created: ${inv['created_at']} | NextPayout: ${inv['next_payout_at']} | AutoRestart: ${inv['auto_restart_enabled']} | Exp: ${inv['expected_profit']} | Act: ${inv['actual_profit']}');
    }
  }

  print('\n=== THE 14 INVESTMENTS OF THE 12 USERS EXCLUDED IN PREVIOUS REPORT ===');
  for (final inv in invs14) {
    final uid = inv['user_id'] as String;
    print('User: ${profMap[uid]?['full_name']} | Inv: ${inv['id']} | Created: ${inv['created_at']} | NextPayout: ${inv['next_payout_at']} | AutoRestart: ${inv['auto_restart_enabled']} | Exp: ${inv['expected_profit']} | Act: ${inv['actual_profit']}');
  }
}
