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
  // Let's check مبارك الطيري (7adf3f78-5340-443b-a965-738ea29633d7)
  // And ايمن الطيري بواحمد (4675897b-20d5-4951-bc91-4da562215cc3)
  // And ابو سعد (984fbc5a-663a-4207-b4c8-f086f93701ea)
  final usersToCheck = [
    '7adf3f78-5340-443b-a965-738ea29633d7',
    '4675897b-20d5-4951-bc91-4da562215cc3',
    '984fbc5a-663a-4207-b4c8-f086f93701ea',
  ];

  for (final uid in usersToCheck) {
    final invs = await get('/rest/v1/user_investments?user_id=eq.$uid&status=eq.active&select=*');
    print('User $uid: ${invs.length} active invs');
    for (final inv in invs) {
      print('  Inv: ${inv['id']} | Created: ${inv['created_at']} | NextPayout: ${inv['next_payout_at']} | Exp: ${inv['expected_profit']} | Act: ${inv['actual_profit']}');
      // Check transactions
      final txs = await get('/rest/v1/transactions?user_id=eq.$uid&select=id,type,amount,reference_id,created_at');
      print('    Transactions (${txs.length}):');
      for (final t in txs) {
        print('      - ${t['created_at']} | Type: ${t['type']} | Amount: ${t['amount']} | Ref: ${t['reference_id']}');
      }
    }
  }
}
