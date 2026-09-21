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
  final previous12Users = {
    'ae2321a7-b8bd-4959-91a8-196854c3cc32': 'المهندس محمد العراقي.',
    '4675897b-20d5-4951-bc91-4da562215cc3': 'ايمن الطيري بواحمد',
    '5e5ba185-a26f-4c9a-8413-78affbf48995': 'ايمن احمد الطيري (ابو اسد)',
    '8f1720d1-69d5-4d29-a496-03e1f3ea81ab': 'المهندس ايمن احمد',
    '984fbc5a-663a-4207-b4c8-f086f93701ea': 'ابو سعد',
    '34e3337d-7f01-45fa-8dba-b7488507df93': 'حسين شهاب احمد كزار',
    '8963306f-4a46-42ff-8394-4d02cd3c3500': 'سجاد',
    'e5201c53-a47c-45c3-a776-c17d44b2c192': 'ليث',
    '7ce89452-c4d8-4867-8343-558148cc2bd9': 'ايمن احمد',
    'c33f59c4-ee76-4568-a767-534cfb9529e0': 'سجاد البطاط',
    '33f6b995-1fae-4d29-b7fb-3cb765d18d19': 'مختبر تطبيق كاسبي',
    '7adf3f78-5340-443b-a965-738ea29633d7': 'مبارك الطيري',
  };

  // Inspect each of the 12 users in detail
  for (final entry in previous12Users.entries) {
    final uid = entry.key;
    final name = entry.value;

    final invs = await get('/rest/v1/user_investments?user_id=eq.$uid&select=*');
    final activeInvs = invs.where((i) => i['status'] == 'active').toList();
    final nonActiveInvs = invs.where((i) => i['status'] != 'active').toList();

    print('User: $name ($uid)');
    print('  Total invs: ${invs.length} | Active: ${activeInvs.length} | Non-Active: ${nonActiveInvs.length}');
    
    for (final inv in activeInvs) {
      final exp = (inv['expected_profit'] as num?)?.toDouble() ?? 0.0;
      final act = (inv['actual_profit'] as num?)?.toDouble() ?? 0.0;
      final rem = exp - act;
      print('    ACTIVE Inv: ${inv['id']} | NextPayout: ${inv['next_payout_at']} | AutoRestart: ${inv['auto_restart_enabled']} | Exp: $exp | Act: $act | Rem: $rem');
    }
    for (final inv in nonActiveInvs) {
      final exp = (inv['expected_profit'] as num?)?.toDouble() ?? 0.0;
      final act = (inv['actual_profit'] as num?)?.toDouble() ?? 0.0;
      print('    NON-ACTIVE Inv: ${inv['id']} | Status: ${inv['status']} | Exp: $exp | Act: $act');
    }
  }
}
