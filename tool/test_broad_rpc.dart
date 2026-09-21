import 'dart:convert';
import 'dart:io';

const supabaseUrl = 'https://majnuiypsgosbzsaeefc.supabase.co';
const serviceKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1ham51aXlwc2dvc2J6c2FlZWZjIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MjA3MDk3NSwiZXhwIjoyMDg3NjQ2OTc1fQ.5EoQZEgv9HmYLYIlF14vzd6u3qNX9LmJB-RtzE4sA1Q';

Future<dynamic> postRpc(String rpcName, Map<String, dynamic> params) async {
  final client = HttpClient();
  final req = await client.openUrl('POST', Uri.parse('$supabaseUrl/rest/v1/rpc/$rpcName'));
  req.headers.set('apikey', serviceKey);
  req.headers.set('Authorization', 'Bearer $serviceKey');
  req.headers.set('Content-Type', 'application/json');
  req.write(jsonEncode(params));
  final res = await req.close();
  final body = await res.transform(utf8.decoder).join();
  return jsonDecode(body);
}

void main() async {
  // Let's create a temporary helper or inspect the exact investments being counted by calling a query
  // Wait, can we call RPC with broad?
  final broadResult = await postRpc('fn_admin_reconcile_historical_profits', {
    'p_scope': 'broad',
    'p_dry_run': true,
  });
  print('BROAD RESULT: $broadResult');
}
