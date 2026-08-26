import 'dart:convert';
import 'dart:io';

const supabaseUrl = 'https://majnuiypsgosbzsaeefc.supabase.co';
const serviceKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1ham51aXlwc2dvc2J6c2FlZWZjIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MjA3MDk3NSwiZXhwIjoyMDg3NjQ2OTc1fQ.5EoQZEgv9HmYLYIlF14vzd6u3qNX9LmJB-RtzE4sA1Q';

final _client = HttpClient();

Future<void> main() async {
  // Check notifications table schema
  print('=== notifications table sample ===');
  final uri = Uri.parse('$supabaseUrl/rest/v1/notifications?limit=1&select=*');
  final req = await _client.openUrl('GET', uri);
  req.headers.set('apikey', serviceKey);
  req.headers.set('Authorization', 'Bearer $serviceKey');
  final res = await req.close();
  final body = await res.transform(utf8.decoder).join();
  print(body);

  // Check OpenAPI for fn_create_notification parameters
  print('');
  print('=== fn_create_notification definition ===');
  final specUri = Uri.parse('$supabaseUrl/rest/v1/');
  final req2 = await _client.openUrl('GET', specUri);
  req2.headers.set('apikey', serviceKey);
  req2.headers.set('Authorization', 'Bearer $serviceKey');
  final res2 = await req2.close();
  final specBody = await res2.transform(utf8.decoder).join();
  final spec = jsonDecode(specBody) as Map<String, dynamic>;
  final notifPath = spec['paths']?['/rpc/fn_create_notification'];
  if (notifPath != null) {
    print(JsonEncoder.withIndent('  ').convert(notifPath));
  }

  _client.close(force: true);
}
