import 'dart:convert';
import 'dart:io';

const supabaseUrl = 'https://majnuiypsgosbzsaeefc.supabase.co';
const serviceKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1ham51aXlwc2dvc2J6c2FlZWZjIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MjA3MDk3NSwiZXhwIjoyMDg3NjQ2OTc1fQ.5EoQZEgv9HmYLYIlF14vzd6u3qNX9LmJB-RtzE4sA1Q';

final _client = HttpClient();

Future<void> main() async {
  // Fetch sample notifications from database across different types/categories
  final uri = Uri.parse(
    '$supabaseUrl/rest/v1/notifications?select=*&order=created_at.desc&limit=20',
  );
  final req = await _client.openUrl('GET', uri);
  req.headers.set('apikey', serviceKey);
  req.headers.set('Authorization', 'Bearer $serviceKey');
  final res = await req.close();
  final body = await res.transform(utf8.decoder).join();
  final list = jsonDecode(body) as List;

  print('=== RECENT NOTIFICATIONS IN DATABASE (${list.length} rows) ===');
  for (final item in list) {
    print('• Title: ${item['title']}');
    print('  Message: ${item['message']}');
    print('  Type/Category: ${item['type']} / ${item['category']}');
    print('  Created: ${item['created_at']}');
    print('');
  }

  _client.close(force: true);
}
