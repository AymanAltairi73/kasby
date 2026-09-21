import 'dart:convert';
import 'dart:io';

const supabaseUrl = 'https://majnuiypsgosbzsaeefc.supabase.co';
const serviceKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1ham51aXlwc2dvc2J6c2FlZWZjIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MjA3MDk3NSwiZXhwIjoyMDg3NjQ2OTc1fQ.5EoQZEgv9HmYLYIlF14vzd6u3qNX9LmJB-RtzE4sA1Q';

final _client = HttpClient();

Future<void> main() async {
  // Let's test what tables / views in information_schema are exposed
  for (final path in [
    '/rest/v1/information_schema.check_constraints',
    '/rest/v1/pg_constraint',
  ]) {
    final uri = Uri.parse('$supabaseUrl$path');
    final req = await _client.openUrl('GET', uri);
    req.headers.set('apikey', serviceKey);
    req.headers.set('Authorization', 'Bearer $serviceKey');
    final res = await req.close();
    final body = await res.transform(utf8.decoder).join();
    print('$path: ${res.statusCode} -> ${body.substring(0, body.length > 200 ? 200 : body.length)}');
  }

  // Also let's try inserting a test row to transactions with different types to see what fails and what passes
  // We will do a test insert with dummy values that will fail or rollback, or test with type='investment_profit'
  final testTypes = [
    'investment_profit',
    'profit',
    'daily_profit',
    'investment_return',
    'deposit',
    'withdrawal',
    'transfer_in',
    'transfer_out',
    'reward',
    'loan_disbursement',
    'loan_repayment'
  ];

  for (final type in testTypes) {
    final uri = Uri.parse('$supabaseUrl/rest/v1/transactions');
    final req = await _client.openUrl('POST', uri);
    req.headers.set('apikey', serviceKey);
    req.headers.set('Authorization', 'Bearer $serviceKey');
    req.headers.set('Content-Type', 'application/json');
    req.headers.set('Prefer', 'return=minimal');
    // Using a fake user_id so if constraint passes it fails on foreign key (or we can see the exact error)
    req.write(jsonEncode({
      'user_id': '00000000-0000-0000-0000-000000000000',
      'wallet_id': '00000000-0000-0000-0000-000000000000',
      'type': type,
      'amount': 1.0,
      'currency': 'USD',
      'status': 'completed'
    }));
    final res = await req.close();
    final body = await res.transform(utf8.decoder).join();
    final isTypeCheck = body.contains('transactions_type_check');
    print('Type "$type" -> ${res.statusCode}: ${isTypeCheck ? "VIOLATES transactions_type_check" : "Passed type check! (Result: $body)"}');
  }

  _client.close(force: true);
}
