import 'dart:convert';
import 'dart:io';

const supabaseUrl = 'https://majnuiypsgosbzsaeefc.supabase.co';
const serviceKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1ham51aXlwc2dvc2J6c2FlZWZjIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MjA3MDk3NSwiZXhwIjoyMDg3NjQ2OTc1fQ.5EoQZEgv9HmYLYIlF14vzd6u3qNX9LmJB-RtzE4sA1Q';

final _client = HttpClient();

Future<void> main() async {
  final uri = Uri.parse('$supabaseUrl/rest/v1/user_investments?select=id,status,start_date,end_date,amount,profit_percentage,investment:investment_plans(name_ar,duration_days)&limit=10');
  final req = await _client.openUrl('GET', uri);
  req.headers.set('apikey', serviceKey);
  req.headers.set('Authorization', 'Bearer $serviceKey');
  final res = await req.close();
  final list = jsonDecode(await res.transform(utf8.decoder).join()) as List;
  for (final inv in list) {
    print('status: ${inv['status']} | start: ${inv['start_date']} | end: ${inv['end_date']} | plan: ${inv['investment']?['name_ar']} (duration_days: ${inv['investment']?['duration_days']})');
  }
  _client.close(force: true);
}
