import 'dart:convert';
import 'dart:io';

const supabaseUrl = 'https://majnuiypsgosbzsaeefc.supabase.co';
const serviceKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1ham51aXlwc2dvc2J6c2FlZWZjIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MjA3MDk3NSwiZXhwIjoyMDg3NjQ2OTc1fQ.5EoQZEgv9HmYLYIlF14vzd6u3qNX9LmJB-RtzE4sA1Q';

final _client = HttpClient();

Future<void> main() async {
  // Query distinct transaction types
  final uri = Uri.parse('$supabaseUrl/rest/v1/transactions?select=type&limit=100');
  final req = await _client.openUrl('GET', uri);
  req.headers.set('apikey', serviceKey);
  req.headers.set('Authorization', 'Bearer $serviceKey');
  final res = await req.close();
  final body = await res.transform(utf8.decoder).join();
  
  final list = jsonDecode(body) as List;
  final types = list.map((e) => e['type']).toSet();
  print('Distinct transaction types in DB: $types');

  // Let's also check OpenAPI definitions to get the exact check constraint / enum values
  final specUri = Uri.parse('$supabaseUrl/rest/v1/');
  final req2 = await _client.openUrl('GET', specUri);
  req2.headers.set('apikey', serviceKey);
  req2.headers.set('Authorization', 'Bearer $serviceKey');
  final res2 = await req2.close();
  final specBody = await res2.transform(utf8.decoder).join();
  final spec = jsonDecode(specBody) as Map<String, dynamic>;
  final txDef = spec['definitions']?['transactions'];
  if (txDef != null) {
    print('Transactions definition properties:');
    print(JsonEncoder.withIndent('  ').convert(txDef['properties']?['type']));
  }

  _client.close(force: true);
}
