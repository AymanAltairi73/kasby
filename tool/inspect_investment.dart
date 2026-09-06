import 'dart:convert';
import 'dart:io';

const supabaseUrl = 'https://majnuiypsgosbzsaeefc.supabase.co';
const serviceKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1ham51aXlwc2dvc2J6c2FlZWZjIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MjA3MDk3NSwiZXhwIjoyMDg3NjQ2OTc1fQ.5EoQZEgv9HmYLYIlF14vzd6u3qNX9LmJB-RtzE4sA1Q';

final _client = HttpClient();

Future<void> main() async {
  final id = 'a1efde21-7546-4b53-9923-61a93d863934';
  final uri = Uri.parse('$supabaseUrl/rest/v1/user_investments?id=eq.$id');
  final req = await _client.openUrl('GET', uri);
  req.headers.set('apikey', serviceKey);
  req.headers.set('Authorization', 'Bearer $serviceKey');
  final res = await req.close();
  final body = await res.transform(utf8.decoder).join();
  print('Investment record:\n$body');

  // Test fn_toggle_auto_restart
  final rpcReq = await _client.openUrl('POST', Uri.parse('$supabaseUrl/rest/v1/rpc/fn_toggle_auto_restart'));
  rpcReq.headers.set('apikey', serviceKey);
  rpcReq.headers.set('Authorization', 'Bearer $serviceKey');
  rpcReq.headers.set('Content-Type', 'application/json');
  rpcReq.write(jsonEncode({'p_investment_id': id, 'p_enabled': true}));
  final rpcRes = await rpcReq.close();
  final rpcBody = await rpcRes.transform(utf8.decoder).join();
  print('fn_toggle_auto_restart status: ${rpcRes.statusCode}, body: $rpcBody');

  // Test fn_start_next_cycle
  final cycleReq = await _client.openUrl('POST', Uri.parse('$supabaseUrl/rest/v1/rpc/fn_start_next_cycle'));
  cycleReq.headers.set('apikey', serviceKey);
  cycleReq.headers.set('Authorization', 'Bearer $serviceKey');
  cycleReq.headers.set('Content-Type', 'application/json');
  cycleReq.write(jsonEncode({'p_investment_id': id}));
  final cycleRes = await cycleReq.close();
  final cycleBody = await cycleRes.transform(utf8.decoder).join();
  print('fn_start_next_cycle status: ${cycleRes.statusCode}, body: $cycleBody');

  _client.close(force: true);
}
