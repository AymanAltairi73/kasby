import 'dart:convert';
import 'dart:io';

const supabaseUrl = 'https://majnuiypsgosbzsaeefc.supabase.co';
const serviceKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1ham51aXlwc2dvc2J6c2FlZWZjIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MjA3MDk3NSwiZXhwIjoyMDg3NjQ2OTc1fQ.5EoQZEgv9HmYLYIlF14vzd6u3qNX9LmJB-RtzE4sA1Q';

final _client = HttpClient();

Future<void> main() async {
  print('Calling fn_cron_distribute_daily_profits...');
  final uri = Uri.parse('$supabaseUrl/rest/v1/rpc/fn_cron_distribute_daily_profits');
  final req = await _client.openUrl('POST', uri);
  req.headers.set('apikey', serviceKey);
  req.headers.set('Authorization', 'Bearer $serviceKey');
  req.headers.set('Content-Type', 'application/json');
  req.write(jsonEncode({}));
  final res = await req.close();
  final body = await res.transform(utf8.decoder).join();
  print('Status: ${res.statusCode}');
  print('Body: $body');

  _client.close(force: true);
}
