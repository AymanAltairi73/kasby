import 'dart:convert';
import 'dart:io';

const supabaseUrl = 'https://majnuiypsgosbzsaeefc.supabase.co';
const serviceKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1ham51aXlwc2dvc2J6c2FlZWZjIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MjA3MDk3NSwiZXhwIjoyMDg3NjQ2OTc1fQ.5EoQZEgv9HmYLYIlF14vzd6u3qNX9LmJB-RtzE4sA1Q';

final _client = HttpClient();

Future<void> main() async {
  // Check if any RPC runs sql or lets us inspect routines
  // We can query information_schema or pg_proc via rest if exposed, or check test_sql_endpoint.dart
  final file = File('tool/test_sql_endpoint.dart');
  if (file.existsSync()) {
    print('Found test_sql_endpoint.dart:');
    print(file.readAsStringSync());
  }
}
