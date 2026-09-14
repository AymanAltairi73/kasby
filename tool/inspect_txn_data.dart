import 'dart:convert';
import 'dart:io';

const supabaseUrl = 'https://majnuiypsgosbzsaeefc.supabase.co';
const serviceKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1ham51aXlwc2dvc2J6c2FlZWZjIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MjA3MDk3NSwiZXhwIjoyMDg3NjQ2OTc1fQ.5EoQZEgv9HmYLYIlF14vzd6u3qNX9LmJB-RtzE4sA1Q';

final _client = HttpClient();

Future<void> main() async {
  // 1. Check distinct currencies in transactions table
  final uriCurrencies = Uri.parse('$supabaseUrl/rest/v1/transactions?select=currency&limit=1000');
  final req1 = await _client.openUrl('GET', uriCurrencies);
  req1.headers.set('apikey', serviceKey);
  req1.headers.set('Authorization', 'Bearer $serviceKey');
  final res1 = await req1.close();
  final body1 = await res1.transform(utf8.decoder).join();
  final list1 = jsonDecode(body1) as List;
  final currencies = list1.map((e) => e['currency']).toSet();
  print('Distinct currencies in transactions table: $currencies');

  // 2. Check distinct types in transactions table
  final uriTypes = Uri.parse('$supabaseUrl/rest/v1/transactions?select=type&limit=1000');
  final req2 = await _client.openUrl('GET', uriTypes);
  req2.headers.set('apikey', serviceKey);
  req2.headers.set('Authorization', 'Bearer $serviceKey');
  final res2 = await req2.close();
  final body2 = await res2.transform(utf8.decoder).join();
  final list2 = jsonDecode(body2) as List;
  final types = list2.map((e) => e['type']).toSet();
  print('Distinct types in transactions table: $types');

  // 3. Sample 5 rows from transactions
  final uriSample = Uri.parse('$supabaseUrl/rest/v1/transactions?select=*&order=created_at.desc&limit=5');
  final req3 = await _client.openUrl('GET', uriSample);
  req3.headers.set('apikey', serviceKey);
  req3.headers.set('Authorization', 'Bearer $serviceKey');
  final res3 = await req3.close();
  final body3 = await res3.transform(utf8.decoder).join();
  print('Recent 5 transactions:\n$body3');

  // 4. Sample 5 rows from point_history
  final uriPoints = Uri.parse('$supabaseUrl/rest/v1/point_history?select=*&order=created_at.desc&limit=5');
  final req4 = await _client.openUrl('GET', uriPoints);
  req4.headers.set('apikey', serviceKey);
  req4.headers.set('Authorization', 'Bearer $serviceKey');
  final res4 = await req4.close();
  final body4 = await res4.transform(utf8.decoder).join();
  print('Recent 5 point_history:\n$body4');

  _client.close(force: true);
}
