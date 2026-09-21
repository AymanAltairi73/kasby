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
  // Check loans table
  final loans = await get('/rest/v1/loans?select=*');
  print('Total loans in DB: ${loans.length}');
  
  // Check collateral locked on investments
  final lockedInvs = await get('/rest/v1/user_investments?is_collateral_locked=eq.true&select=id,user_id,amount,expected_profit,actual_profit');
  print('Investments with is_collateral_locked = true: ${lockedInvs.length}');
  for (final inv in lockedInvs) {
    print('  Locked inv: ${inv['id']} | user: ${inv['user_id']} | amount: ${inv['amount']}');
  }

  // Check wallets for USD
  final wallets = await get('/rest/v1/wallets?currency=eq.USD&select=id,user_id,available_balance,profit_balance');
  print('Total USD wallets in DB: ${wallets.length}');
}
