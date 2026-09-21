import 'dart:convert';
import 'dart:io';

const supabaseUrl = 'https://majnuiypsgosbzsaeefc.supabase.co';
const serviceKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1ham51aXlwc2dvc2J6c2FlZWZjIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MjA3MDk3NSwiZXhwIjoyMDg3NjQ2OTc1fQ.5EoQZEgv9HmYLYIlF14vzd6u3qNX9LmJB-RtzE4sA1Q';

final _client = HttpClient();

Future<dynamic> get(String path) async {
  final uri = Uri.parse('$supabaseUrl$path');
  final req = await _client.openUrl('GET', uri);
  req.headers.set('apikey', serviceKey);
  req.headers.set('Authorization', 'Bearer $serviceKey');
  final res = await req.close();
  final body = await res.transform(utf8.decoder).join();
  try {
    return jsonDecode(body);
  } catch (_) {
    return body;
  }
}

Future<void> main() async {
  print('=== RECENT NOTIFICATIONS (COUNT & SAMPLES) ===');
  final notifs = await get('/rest/v1/notifications?order=created_at.desc&limit=5');
  for (final n in notifs) {
    print('ID: ${n['id']} | type: ${n['type']} | title: ${n['title']} | created: ${n['created_at']} | user: ${n['user_id']}');
  }

  print('\n=== PROFIT NOTIFICATIONS (COUNT & SAMPLES) ===');
  final profitNotifs = await get('/rest/v1/notifications?type=eq.daily_profit&order=created_at.desc&limit=5');
  print('Found profitNotifs: ${(profitNotifs as List).length}');
  for (final n in profitNotifs) {
    print(n);
  }

  print('\n=== RECENT PROFIT TRANSACTIONS ===');
  final txns = await get('/rest/v1/transactions?type=eq.investment_profit&order=created_at.desc&limit=5');
  print('Found profit txns: ${(txns as List).length}');
  for (final t in txns) {
    print('Txn ID: ${t['id']} | user: ${t['user_id']} | amount: ${t['amount']} | status: ${t['status']} | desc: ${t['description']} | created: ${t['created_at']}');
  }

  print('\n=== CHECK IF ANY NOTIFICATION WITH "ربح" OR "أرباح" IN TITLE ===');
  final arNotifs = await get('/rest/v1/notifications?title=like.*أرباح*&order=created_at.desc&limit=5');
  print('Found arNotifs: ${(arNotifs as List).length}');
  for (final n in arNotifs) {
    print(n);
  }

  _client.close(force: true);
}
