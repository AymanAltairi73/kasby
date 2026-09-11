import 'dart:convert';
import 'dart:io';

const supabaseUrl = 'https://majnuiypsgosbzsaeefc.supabase.co';
const serviceKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1ham51aXlwc2dvc2J6c2FlZWZjIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MjA3MDk3NSwiZXhwIjoyMDg3NjQ2OTc1fQ.5EoQZEgv9HmYLYIlF14vzd6u3qNX9LmJB-RtzE4sA1Q';

final _client = HttpClient();

Future<dynamic> getJson(String path) async {
  final req = await _client.openUrl('GET', Uri.parse('$supabaseUrl/rest/v1$path'));
  req.headers.set('apikey', serviceKey);
  req.headers.set('Authorization', 'Bearer $serviceKey');
  final res = await req.close();
  final body = await res.transform(utf8.decoder).join();
  if (res.statusCode != 200) {
    print('HTTP ${res.statusCode} for $path: $body');
    return null;
  }
  return jsonDecode(body);
}

Future<void> main() async {
  final planIds = [
    '3f5970b6-b0c1-4bdd-9a1c-bc8ec45a401e',
    'dee3913b-3162-471f-ab4c-8dc264145f67',
    '550e8400-e29b-41d4-a716-446655440000',
    '550e8400-e29b-41d4-a716-446655440001',
    '715bcd9b-45bf-42e1-ada3-86e0b8bc572f',
    'e45516df-66ec-474d-86b9-fd1f65ab125c',
    'b8ea727b-ff71-48f7-8ea2-4397d6295674',
    '59b22f1c-2b86-4507-aeb0-602c6344d18a',
    '7a6077b2-b039-42f6-a0ec-b8195306166d',
    '4b504b27-da68-4254-beef-9151dad44cf0',
  ];
  final plans = await getJson(
      '/investment_plans?id=in.(${planIds.join(',')})&select=id,name_ar,name_en,duration_days,profit_percentage,is_active') as List?;
  for (final p in plans ?? <dynamic>[]) {
    print('- id=${p['id']} | name_ar=${p['name_ar']} | dur=${p['duration_days']} | pct=${p['profit_percentage']} | active=${p['is_active']}');
  }

  print('\n=== Simulate formulas per plan ===');
  final map = <String, dynamic>{};
  for (final p in plans ?? <dynamic>[]) {
    map[p['id'] as String] = p;
  }
  final invs = [
    {'label': 'Hussein 529156c7 (expected 50)', 'expected': 50.0, 'plan': 'dee3913b-3162-471f-ab4c-8dc264145f67'},
    {'label': 'bronze 50 (expected 3)', 'expected': 3.0, 'plan': '3f5970b6-b0c1-4bdd-9a1c-bc8ec45a401e'},
    {'label': 'bronze 100 (expected 6)', 'expected': 6.0, 'plan': '3f5970b6-b0c1-4bdd-9a1c-bc8ec45a401e'},
    {'label': '5000 plan 715bcd9b (expected 500)', 'expected': 500.0, 'plan': '715bcd9b-45bf-42e1-ada3-86e0b8bc572f'},
    {'label': '750 plan e45516df (expected 60)', 'expected': 60.0, 'plan': 'e45516df-66ec-474d-86b9-fd1f65ab125c'},
  ];
  for (final inv in invs) {
    final pl = map[inv['plan']];
    final dur = pl?['duration_days'] as num?;
    final expected = inv['expected'] as double;
    final byDuration = dur == null ? 'N/A' : (expected / dur).toStringAsFixed(4);
    final byPct = 'formula amount*pct/365 need amount';
    print('- ${inv['label']}: expected=$expected dur=$dur -> expected/dur=$byDuration | $byPct');
  }

  _client.close(force: true);
}