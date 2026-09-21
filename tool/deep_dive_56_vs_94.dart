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
  // Fetch active investments
  final activeInvs = await get(
      '/rest/v1/user_investments?status=eq.active&select=id,user_id,plan_id,status,created_at,next_payout_at,last_profit_at,auto_restart_enabled,amount,expected_profit,actual_profit&order=created_at.asc');
  
  print('Total ACTIVE investments: ${activeInvs.length}');
  
  final failureStart = DateTime.parse('2026-09-12T20:41:00Z');
  final fixTime = DateTime.parse('2026-09-20T00:00:00Z');
  final now = DateTime.now().toUtc();

  int createdBeforeFailure = 0;
  int createdDuringOutage = 0;
  int createdAfterFix = 0;

  int nextPayoutPastNow = 0;
  int nextPayoutPastFailure = 0;
  int nextPayoutFuture = 0;
  int nextPayoutNull = 0;

  final usersWithNextPayoutPast = <String>{};
  final usersActive = <String>{};

  for (final inv in activeInvs) {
    usersActive.add(inv['user_id'] as String);
    final createdAt = DateTime.parse(inv['created_at'] as String);
    if (createdAt.isBefore(failureStart)) {
      createdBeforeFailure++;
    } else if (createdAt.isBefore(fixTime)) {
      createdDuringOutage++;
    } else {
      createdAfterFix++;
    }

    if (inv['next_payout_at'] == null) {
      nextPayoutNull++;
    } else {
      final nextPayout = DateTime.parse(inv['next_payout_at'] as String);
      if (now.isAfter(nextPayout)) {
        nextPayoutPastNow++;
        usersWithNextPayoutPast.add(inv['user_id'] as String);
      } else {
        nextPayoutFuture++;
      }
      if (nextPayout.isAfter(failureStart) && nextPayout.isBefore(fixTime)) {
        nextPayoutPastFailure++;
      }
    }
  }

  print('Created BEFORE failure (2026-09-12): $createdBeforeFailure');
  print('Created DURING outage (2026-09-12 to 2026-09-20): $createdDuringOutage');
  print('Created AFTER fix (2026-09-20+): $createdAfterFix');
  print('---');
  print('next_payout_at is NULL: $nextPayoutNull');
  print('next_payout_at is in FUTURE: $nextPayoutFuture');
  print('next_payout_at is in PAST (now > next_payout_at): $nextPayoutPastNow across ${usersWithNextPayoutPast.length} users');
  print('Total active users: ${usersActive.length}');
}
