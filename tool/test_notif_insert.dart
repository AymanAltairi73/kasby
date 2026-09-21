import 'dart:convert';
import 'dart:io';

const supabaseUrl = 'https://majnuiypsgosbzsaeefc.supabase.co';
const serviceKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1ham51aXlwc2dvc2J6c2FlZWZjIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MjA3MDk3NSwiZXhwIjoyMDg3NjQ2OTc1fQ.5EoQZEgv9HmYLYIlF14vzd6u3qNX9LmJB-RtzE4sA1Q';

final _client = HttpClient();

Future<void> main() async {
  final userId = 'c33f59c4-ee76-4568-a767-534cfb9529e0';

  print('Calling fn_create_notification for user $userId...');
  final uri = Uri.parse('$supabaseUrl/rest/v1/rpc/fn_create_notification');
  final req = await _client.openUrl('POST', uri);
  req.headers.set('apikey', serviceKey);
  req.headers.set('Authorization', 'Bearer $serviceKey');
  req.headers.set('Content-Type', 'application/json');
  req.add(utf8.encode(jsonEncode({
    'p_user_id': userId,
    'p_title': 'أرباح استثمار جديدة 💰',
    'p_body': 'تم إضافة أرباح بقيمة \$10.00 من مركز استثمار الذهب',
    'p_type': 'daily_profit',
    'p_entity_type': 'investment',
    'p_entity_id': '00000000-0000-0000-0000-000000000000',
    'p_deep_link': '/my-investments',
    'p_role_target': 'user',
    'p_priority': 'normal'
  })));
  final res = await req.close();
  final body = await res.transform(utf8.decoder).join();
  print('fn_create_notification status (${res.statusCode}): $body');

  // Let's query the notification row that was just created!
  if (res.statusCode == 200) {
    final notifId = jsonDecode(body);
    print('Checking created notification: $notifId');
    final notifUri = Uri.parse('$supabaseUrl/rest/v1/notifications?id=eq.$notifId');
    final notifReq = await _client.openUrl('GET', notifUri);
    notifReq.headers.set('apikey', serviceKey);
    notifReq.headers.set('Authorization', 'Bearer $serviceKey');
    final notifRes = await notifReq.close();
    final notifBody = await notifRes.transform(utf8.decoder).join();
    print(JsonEncoder.withIndent('  ').convert(jsonDecode(notifBody)));
  }

  _client.close(force: true);
}
