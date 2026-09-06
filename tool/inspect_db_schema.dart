import 'dart:convert';
import 'dart:io';

const supabaseUrl = 'https://majnuiypsgosbzsaeefc.supabase.co';
const serviceKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1ham51aXlwc2dvc2J6c2FlZWZjIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MjA3MDk3NSwiZXhwIjoyMDg3NjQ2OTc1fQ.5EoQZEgv9HmYLYIlF14vzd6u3qNX9LmJB-RtzE4sA1Q';

final _client = HttpClient();

Future<void> main() async {
  // 1. Get 1 notification to see columns
  var req = await _client.openUrl('GET', Uri.parse('$supabaseUrl/rest/v1/notifications?limit=1'));
  req.headers.set('apikey', serviceKey);
  req.headers.set('Authorization', 'Bearer $serviceKey');
  var res = await req.close();
  var body = await res.transform(utf8.decoder).join();
  print('Notifications row: $body');

  // 2. Try inserting dummy notification with title_key to see if column exists
  // We can do a test select specifically for title_key, message_key, parameters
  var colReq = await _client.openUrl('GET', Uri.parse('$supabaseUrl/rest/v1/notifications?select=id,title_key,message_key,parameters&limit=1'));
  colReq.headers.set('apikey', serviceKey);
  colReq.headers.set('Authorization', 'Bearer $serviceKey');
  var colRes = await colReq.close();
  var colBody = await colRes.transform(utf8.decoder).join();
  print('Columns test status: ${colRes.statusCode}, body: $colBody');

  _client.close(force: true);
}
