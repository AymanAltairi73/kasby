import 'dart:convert';
import 'dart:io';

const supabaseUrl = 'https://majnuiypsgosbzsaeefc.supabase.co';
const serviceKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1ham51aXlwc2dvc2J6c2FlZWZjIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MjA3MDk3NSwiZXhwIjoyMDg3NjQ2OTc1fQ.5EoQZEgv9HmYLYIlF14vzd6u3qNX9LmJB-RtzE4sA1Q';

final _client = HttpClient();

Future<void> main() async {
  // Inspect single transaction to get column keys
  final txnReq = await _client.openUrl('GET', Uri.parse('$supabaseUrl/rest/v1/transactions?limit=1'));
  txnReq.headers.set('apikey', serviceKey);
  txnReq.headers.set('Authorization', 'Bearer $serviceKey');
  final txnRes = await txnReq.close();
  final txnBody = await txnRes.transform(utf8.decoder).join();
  print('Transaction sample:\n$txnBody');

  // Let's call rpc fn_cron_distribute_daily_profits directly and print response
  final rpcReq = await _client.openUrl('POST', Uri.parse('$supabaseUrl/rest/v1/rpc/fn_cron_distribute_daily_profits'));
  rpcReq.headers.set('apikey', serviceKey);
  rpcReq.headers.set('Authorization', 'Bearer $serviceKey');
  rpcReq.headers.set('Content-Type', 'application/json');
  rpcReq.write('{}');
  final rpcRes = await rpcReq.close();
  final rpcBody = await rpcRes.transform(utf8.decoder).join();
  print('fn_cron_distribute_daily_profits: ${rpcRes.statusCode} -> $rpcBody');

  _client.close(force: true);
}
