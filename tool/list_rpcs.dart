import 'dart:convert';
import 'dart:io';

const supabaseUrl = 'https://majnuiypsgosbzsaeefc.supabase.co';
const serviceKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1ham51aXlwc2dvc2J6c2FlZWZjIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MjA3MDk3NSwiZXhwIjoyMDg3NjQ2OTc1fQ.5EoQZEgv9HmYLYIlF14vzd6u3qNX9LmJB-RtzE4sA1Q';

final _client = HttpClient();

Future<void> main() async {
  // Query pg_proc for the RPC
  final uri = Uri.parse(
    '$supabaseUrl/rest/v1/rpc/fn_redeem_ksp_to_wallet',
  );
  final req = await _client.openUrl('POST', uri);
  req.headers.set('apikey', serviceKey);
  req.headers.set('Authorization', 'Bearer $serviceKey');
  req.headers.set('Content-Type', 'application/json');
  req.add(utf8.encode('{}'));
  final res = await req.close();
  final body = await res.transform(utf8.decoder).join();
  print('Direct RPC call status: ${res.statusCode}');
  print('Response: $body');
  print('');

  // List ALL functions that contain 'redeem' or 'ksp'
  print('Searching for existing RPCs containing "ksp" or "redeem"...');
  final searchUri = Uri.parse(
    '$supabaseUrl/rest/v1/rpc/fn_get_effective_ksp',
  );
  final req2 = await _client.openUrl('POST', searchUri);
  req2.headers.set('apikey', serviceKey);
  req2.headers.set('Authorization', 'Bearer $serviceKey');
  req2.headers.set('Content-Type', 'application/json');
  req2.add(utf8.encode('{}'));
  final res2 = await req2.close();
  final body2 = await res2.transform(utf8.decoder).join();
  print('fn_get_effective_ksp status: ${res2.statusCode}');
  print('Response: $body2');
  print('');

  // Use a raw SQL query via service role to check pg_proc
  // We can query information_schema.routines
  final sqlUri = Uri.parse(
    "$supabaseUrl/rest/v1/rpc/",
  );
  
  // Let's check the OpenAPI spec to find all available RPCs
  print('Fetching OpenAPI spec to list all RPCs...');
  final specUri = Uri.parse('$supabaseUrl/rest/v1/');
  final req3 = await _client.openUrl('GET', specUri);
  req3.headers.set('apikey', serviceKey);
  req3.headers.set('Authorization', 'Bearer $serviceKey');
  final res3 = await req3.close();
  final specBody = await res3.transform(utf8.decoder).join();
  
  // Extract all paths that contain 'rpc'
  try {
    final spec = jsonDecode(specBody) as Map<String, dynamic>;
    final paths = spec['paths'] as Map<String, dynamic>?;
    if (paths != null) {
      final rpcPaths = paths.keys.where((k) => k.contains('rpc/')).toList();
      print('Found ${rpcPaths.length} RPCs:');
      for (final p in rpcPaths) {
        if (p.toLowerCase().contains('ksp') || 
            p.toLowerCase().contains('redeem') ||
            p.toLowerCase().contains('wallet') ||
            p.toLowerCase().contains('transfer') ||
            p.toLowerCase().contains('points')) {
          print('  ★ $p');
        }
      }
      print('');
      print('All RPCs:');
      for (final p in rpcPaths) {
        print('  $p');
      }
    }
  } catch (e) {
    print('Could not parse OpenAPI spec: $e');
    // Print first 2000 chars of spec
    print(specBody.substring(0, specBody.length > 2000 ? 2000 : specBody.length));
  }

  _client.close(force: true);
}
