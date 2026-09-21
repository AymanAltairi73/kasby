import 'dart:convert';
import 'dart:io';

const supabaseUrl = 'https://majnuiypsgosbzsaeefc.supabase.co';
const serviceKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1ham51aXlwc2dvc2J6c2FlZWZjIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MjA3MDk3NSwiZXhwIjoyMDg3NjQ2OTc1fQ.5EoQZEgv9HmYLYIlF14vzd6u3qNX9LmJB-RtzE4sA1Q';

final _client = HttpClient();

Future<void> main() async {
  // Check if net schema or http responses are exposed or if we can see system logs
  for (final path in [
    '/rest/v1/net._http_response?order=created.desc&limit=5',
    '/rest/v1/_http_response?limit=5',
    '/rest/v1/system_logs?action=like.*fcm*&limit=5',
    '/rest/v1/system_logs?severity=eq.warning&limit=5'
  ]) {
    final uri = Uri.parse('$supabaseUrl$path');
    final req = await _client.openUrl('GET', uri);
    req.headers.set('apikey', serviceKey);
    req.headers.set('Authorization', 'Bearer $serviceKey');
    final res = await req.close();
    final body = await res.transform(utf8.decoder).join();
    print('$path: ${res.statusCode} -> ${body.substring(0, body.length > 250 ? 250 : body.length)}');
  }

  _client.close(force: true);
}
