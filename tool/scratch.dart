import 'dart:io';

void main() {
  for (final path in [
    'supabase/migrations/20260623120000_admin_hardening_phase2.sql',
    'supabase/migrations/20260628120000_referral_financial_enterprise.sql',
  ]) {
    final file = File(path);
    final lines = file.readAsLinesSync();
    print('=== $path ===');
    for (int i = 0; i < lines.length; i++) {
      if (lines[i].contains('user_investments') && lines[i].contains('status') || lines[i].contains('status TEXT') || lines[i].contains('status VARCHAR')) {
        for (int j = (i - 2 < 0 ? 0 : i - 2); j < (i + 5 > lines.length ? lines.length : i + 5); j++) {
          print('${j + 1}: ${lines[j]}');
        }
      }
    }
  }
}
