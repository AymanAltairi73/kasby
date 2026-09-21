import 'dart:convert';
import 'dart:io';

const supabaseUrl = 'https://majnuiypsgosbzsaeefc.supabase.co';
const serviceKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1ham51aXlwc2dvc2J6c2FlZWZjIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MjA3MDk3NSwiZXhwIjoyMDg3NjQ2OTc1fQ.5EoQZEgv9HmYLYIlF14vzd6u3qNX9LmJB-RtzE4sA1Q';

final _client = HttpClient();

Future<void> main() async {
  // Let's check OpenAPI to see all functions and schemas
  final uri = Uri.parse('$supabaseUrl/rest/v1/');
  final req = await _client.openUrl('GET', uri);
  req.headers.set('apikey', serviceKey);
  req.headers.set('Authorization', 'Bearer $serviceKey');
  final res = await req.close();
  final body = await res.transform(utf8.decoder).join();
  final spec = jsonDecode(body) as Map<String, dynamic>;
  final paths = (spec['paths'] as Map<String, dynamic>).keys.toList();
  print('Total paths in OpenAPI: ${paths.length}');
  
  final netPaths = paths.where((p) => p.toLowerCase().contains('net') || p.toLowerCase().contains('http')).toList();
  print('Net / HTTP paths: $netPaths');

  final cronPaths = paths.where((p) => p.toLowerCase().contains('cron')).toList();
  print('Cron paths: $cronPaths');

  _client.close(force: true);
}
