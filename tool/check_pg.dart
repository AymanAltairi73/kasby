import 'dart:convert';
import 'dart:io';

const supabaseUrl = 'https://majnuiypsgosbzsaeefc.supabase.co';
const serviceKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1ham51aXlwc2dvc2J6c2FlZWZjIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MjA3MDk3NSwiZXhwIjoyMDg3NjQ2OTc1fQ.5EoQZEgv9HmYLYIlF14vzd6u3qNX9LmJB-RtzE4sA1Q';

final _client = HttpClient();

Future<void> main() async {
  // Check triggers on user_investments or definition of create_investment
  // We can call /rpc with custom queries or check table information_schema if accessible
  // Let's test what tables/views are accessible via serviceKey
  for (final endpoint in [
    'user_investments?limit=1',
  ]) {
    final uri = Uri.parse('$supabaseUrl/rest/v1/$endpoint');
    final req = await _client.openUrl('GET', uri);
    req.headers.set('apikey', serviceKey);
    req.headers.set('Authorization', 'Bearer $serviceKey');
    final res = await req.close();
    final body = await res.transform(utf8.decoder).join();
    print('$endpoint: ${res.statusCode}');
  }

  _client.close(force: true);
}
