import 'dart:convert';
import 'dart:io';

const supabaseUrl = 'https://majnuiypsgosbzsaeefc.supabase.co';
const serviceKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1ham51aXlwc2dvc2J6c2FlZWZjIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MjA3MDk3NSwiZXhwIjoyMDg3NjQ2OTc1fQ.5EoQZEgv9HmYLYIlF14vzd6u3qNX9LmJB-RtzE4sA1Q';

final _client = HttpClient();

Future<void> main() async {
  final invUri = Uri.parse('$supabaseUrl/rest/v1/user_investments?status=eq.active&select=*,investment:investment_plans(*)');
  final invReq = await _client.openUrl('GET', invUri);
  invReq.headers.set('apikey', serviceKey);
  invReq.headers.set('Authorization', 'Bearer $serviceKey');
  final invRes = await invReq.close();
  final list = jsonDecode(await invRes.transform(utf8.decoder).join()) as List;
  print('Found ${list.length} active investments:');
  for (final inv in list) {
    print('ID: ${inv['id']} | Amount: ${inv['amount']} | Rate: ${inv['profit_percentage']}% | Start: ${inv['start_date']} | End: ${inv['end_date']} | NextPayout: ${inv['next_payout_at']} | AutoRestart: ${inv['auto_restart_enabled']} | Plan: ${inv['investment']?['name_ar']} (days: ${inv['investment']?['duration_days']})');
  }
  _client.close(force: true);
}
