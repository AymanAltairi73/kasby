import 'dart:convert';
import 'dart:io';

const supabaseUrl = 'https://majnuiypsgosbzsaeefc.supabase.co';
const serviceKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1ham51aXlwc2dvc2J6c2FlZWZjIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MjA3MDk3NSwiZXhwIjoyMDg3NjQ2OTc1fQ.5EoQZEgv9HmYLYIlF14vzd6u3qNX9LmJB-RtzE4sA1Q';

final _client = HttpClient();

Future<void> main() async {
  // Test pg-meta or sql endpoints
  print('Testing SQL endpoint options...');
  
  // Option 1: /pg/query or /rest/v1/
  final endpoints = [
    '/rest/v1/rpc/exec_sql',
    '/pg/query',
    '/api/pg-meta/default/query',
  ];

  for (final ep in endpoints) {
    final uri = Uri.parse('$supabaseUrl$ep');
    final req = await _client.openUrl('POST', uri);
    req.headers.set('apikey', serviceKey);
    req.headers.set('Authorization', 'Bearer $serviceKey');
    req.headers.set('Content-Type', 'application/json');
    req.add(utf8.encode(jsonEncode({'query': 'SELECT 1'})));
    final res = await req.close();
    final body = await res.transform(utf8.decoder).join();
    print('$ep → Status: ${res.statusCode}, Body: ${body.substring(0, body.length > 200 ? 200 : body.length)}');
  }

  _client.close(force: true);
}
