import 'dart:convert';
import 'dart:io';

const supabaseUrl = 'https://majnuiypsgosbzsaeefc.supabase.co';
const serviceKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1ham51aXlwc2dvc2J6c2FlZWZjIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MjA3MDk3NSwiZXhwIjoyMDg3NjQ2OTc1fQ.5EoQZEgv9HmYLYIlF14vzd6u3qNX9LmJB-RtzE4sA1Q';

Future<dynamic> get(String path) async {
  final client = HttpClient();
  final req = await client.openUrl('GET', Uri.parse('$supabaseUrl$path'));
  req.headers.set('apikey', serviceKey);
  req.headers.set('Authorization', 'Bearer $serviceKey');
  final res = await req.close();
  final body = await res.transform(utf8.decoder).join();
  return jsonDecode(body);
}

void main() async {
  // Let's inspect all profit transactions created on 2026-09-19 at 23:10 UTC!
  final recentProfits = await get(
      '/rest/v1/transactions?type=eq.profit&created_at=gte.2026-09-19T23:00:00Z&select=id,user_id,amount,reference_id,created_at');
  
  print('Total profit transactions created at 2026-09-19 23:10 UTC: ${recentProfits.length}');
  double recentSum = 0.0;
  for (final tx in recentProfits) {
    final amt = (tx['amount'] as num?)?.toDouble() ?? 0.0;
    recentSum += amt;
    print('  - Inv: ${tx['reference_id']} | User: ${tx['user_id']} | Amount: \$$amt | Time: ${tx['created_at']}');
  }
  print('Sum of profit transactions created at 2026-09-19 23:10 UTC: \$$recentSum');
}
