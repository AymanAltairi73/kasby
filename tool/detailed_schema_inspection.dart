import 'dart:convert';
import 'dart:io';

const supabaseUrl = 'https://majnuiypsgosbzsaeefc.supabase.co';
const serviceKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1ham51aXlwc2dvc2J6c2FlZWZjIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MjA3MDk3NSwiZXhwIjoyMDg3NjQ2OTc1fQ.5EoQZEgv9HmYLYIlF14vzd6u3qNX9LmJB-RtzE4sA1Q';

final _client = HttpClient();

Future<void> main() async {
  // Fetch OpenAPI spec definition for profiles, notifications, device_tokens, transactions
  final specUri = Uri.parse('$supabaseUrl/rest/v1/');
  final req = await _client.openUrl('GET', specUri);
  req.headers.set('apikey', serviceKey);
  req.headers.set('Authorization', 'Bearer $serviceKey');
  final res = await req.close();
  final body = await res.transform(utf8.decoder).join();
  final spec = jsonDecode(body) as Map<String, dynamic>;
  final defs = spec['definitions'] as Map<String, dynamic>? ?? {};

  final tables = ['profiles', 'notifications', 'device_tokens', 'transactions', 'investment_plans'];
  for (final t in tables) {
    print('================================================================');
    print('TABLE: $t');
    print('================================================================');
    final tableDef = defs[t];
    if (tableDef == null) {
      print('Not found in definitions');
      continue;
    }
    final props = tableDef['properties'] as Map<String, dynamic>? ?? {};
    final required = tableDef['required'] as List? ?? [];
    print('Columns (${props.length}):');
    for (final entry in props.entries) {
      final col = entry.key;
      final type = entry.value['type'];
      final format = entry.value['format'];
      final desc = entry.value['description'];
      final isReq = required.contains(col) ? ' [REQUIRED]' : '';
      print('  - $col : $type ($format)$isReq ${desc != null ? '/* $desc */' : ''}');
    }
    print('');
  }

  _client.close(force: true);
}
