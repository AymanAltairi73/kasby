import 'dart:convert';
import 'dart:io';

const supabaseUrl = 'https://majnuiypsgosbzsaeefc.supabase.co';
const serviceKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1ham51aXlwc2dvc2J6c2FlZWZjIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MjA3MDk3NSwiZXhwIjoyMDg3NjQ2OTc1fQ.5EoQZEgv9HmYLYIlF14vzd6u3qNX9LmJB-RtzE4sA1Q';

final _client = HttpClient();

Future<void> main() async {
  // Test sending a real FCM message to the active token
  final token = 'eos75oImRUyCxmjAynSgK7:APA91bH9QK9lLDudabyHHfVO8orfqymmclucHkJE5G00VVx9c990QUaKUm_5NNb8c9QuSU-gd6sA9x7j9TMpIVz7Oi3CEi1vdPPXtJrbhP41ghA821--hQA';
  
  final uri = Uri.parse('$supabaseUrl/functions/v1/send-fcm');
  final req = await _client.openUrl('POST', uri);
  req.headers.set('Authorization', 'Bearer kasby_internal_fcm_secret_2026_x972f');
  req.headers.set('Content-Type', 'application/json');
  req.add(utf8.encode(jsonEncode({
    'token': token,
    'title': 'اختبار الإشعار 🧪',
    'body': 'اختبار وصول الإشعار عبر FCM v1',
    'data': {
      'type': 'daily_profit',
      'entity_type': 'investment',
      'deep_link': '/my-investments',
      'role_target': 'user'
    }
  })));
  final res = await req.close();
  final body = await res.transform(utf8.decoder).join();
  print('Direct send-fcm response (${res.statusCode}): $body');

  _client.close(force: true);
}
