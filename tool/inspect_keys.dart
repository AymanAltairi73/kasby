import 'dart:convert';
import 'dart:io';

const supabaseUrl = 'https://majnuiypsgosbzsaeefc.supabase.co';
const serviceKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1ham51aXlwc2dvc2J6c2FlZWZjIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MjA3MDk3NSwiZXhwIjoyMDg3NjQ2OTc1fQ.5EoQZEgv9HmYLYIlF14vzd6u3qNX9LmJB-RtzE4sA1Q';

final _client = HttpClient();

Future<void> main() async {
  // Let's inspect user_investments columns by querying one row and inspecting keys
  final uri = Uri.parse('$supabaseUrl/rest/v1/user_investments?id=eq.81402050-0685-4aaa-8d8a-198bc7fca27d');
  final req = await _client.openUrl('GET', uri);
  req.headers.set('apikey', serviceKey);
  req.headers.set('Authorization', 'Bearer $serviceKey');
  final res = await req.close();
  final body = await res.transform(utf8.decoder).join();
  final list = jsonDecode(body) as List;
  if (list.isNotEmpty) {
    print('All keys in user_investments row:');
    final row = list.first as Map<String, dynamic>;
    row.forEach((k, v) {
      print('  $k: $v (${v.runtimeType})');
    });
  }

  // Let's also check transactions table for 81402050...
  final txnUri = Uri.parse('$supabaseUrl/rest/v1/transactions?reference_id=eq.81402050-0685-4aaa-8d8a-198bc7fca27d');
  final txnReq = await _client.openUrl('GET', txnUri);
  txnReq.headers.set('apikey', serviceKey);
  txnReq.headers.set('Authorization', 'Bearer $serviceKey');
  final txnRes = await txnReq.close();
  print('\nTransactions with reference_id: ${await txnRes.transform(utf8.decoder).join()}');

  // Let's check transaction row for transaction_id
  final txnId = list.first['transaction_id'];
  if (txnId != null) {
    final tUri = Uri.parse('$supabaseUrl/rest/v1/transactions?id=eq.$txnId');
    final tReq = await _client.openUrl('GET', tUri);
    tReq.headers.set('apikey', serviceKey);
    tReq.headers.set('Authorization', 'Bearer $serviceKey');
    final tRes = await tReq.close();
    print('\nTransaction by transaction_id: ${await tRes.transform(utf8.decoder).join()}');
  }

  _client.close(force: true);
}
