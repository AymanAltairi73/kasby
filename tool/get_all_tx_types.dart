import 'dart:convert';
import 'dart:io';

const supabaseUrl = 'https://majnuiypsgosbzsaeefc.supabase.co';
const serviceKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1ham51aXlwc2dvc2J6c2FlZWZjIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MjA3MDk3NSwiZXhwIjoyMDg3NjQ2OTc1fQ.5EoQZEgv9HmYLYIlF14vzd6u3qNX9LmJB-RtzE4sA1Q';

final _client = HttpClient();

Future<void> main() async {
  // Query all distinct types by fetching type column from all rows
  int offset = 0;
  final allTypes = <String>{};
  while (true) {
    final uri = Uri.parse(
      '$supabaseUrl/rest/v1/transactions?select=type&limit=1000&offset=$offset',
    );
    final req = await _client.openUrl('GET', uri);
    req.headers.set('apikey', serviceKey);
    req.headers.set('Authorization', 'Bearer $serviceKey');
    final res = await req.close();
    final body = await res.transform(utf8.decoder).join();
    final list = jsonDecode(body) as List;
    if (list.isEmpty) break;
    for (final row in list) {
      if (row['type'] != null) {
        allTypes.add(row['type'].toString());
      }
    }
    if (list.length < 1000) break;
    offset += 1000;
  }

  print('ALL DISTINCT TYPE VALUES PRESENT IN TRANSACTIONS TABLE:');
  for (final t in allTypes) {
    print("  '$t',");
  }

  _client.close(force: true);
}
