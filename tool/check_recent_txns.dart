import 'dart:convert';
import 'dart:io';

const supabaseUrl = 'https://majnuiypsgosbzsaeefc.supabase.co';
const serviceKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1ham51aXlwc2dvc2J6c2FlZWZjIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MjA3MDk3NSwiZXhwIjoyMDg3NjQ2OTc1fQ.5EoQZEgv9HmYLYIlF14vzd6u3qNX9LmJB-RtzE4sA1Q';

final _client = HttpClient();

Future<dynamic> get(String path) async {
  final uri = Uri.parse('$supabaseUrl$path');
  final req = await _client.openUrl('GET', uri);
  req.headers.set('apikey', serviceKey);
  req.headers.set('Authorization', 'Bearer $serviceKey');
  final res = await req.close();
  final body = await res.transform(utf8.decoder).join();
  return jsonDecode(body);
}

Future<void> main() async {
  print('=== RECENT 10 TRANSACTIONS OF ANY TYPE ===');
  final txns = await get('/rest/v1/transactions?order=created_at.desc&limit=10');
  for (final t in txns) {
    print('ID: ${t['id']} | type: ${t['type']} | amount: ${t['amount']} | user: ${t['user_id']} | created: ${t['created_at']} | desc: ${t['description']}');
  }

  print('\n=== CRON JOBS (cron.job) ===');
  try {
    final jobs = await get('/rest/v1/rpc/get_cron_jobs');
    print(jobs);
  } catch (e) {
    print('cron RPC error: $e');
  }

  _client.close(force: true);
}
