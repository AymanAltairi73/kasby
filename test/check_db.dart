import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('Check DB columns', () async {
    final client = SupabaseClient(
      'https://majnuiypsgosbzsaeefc.supabase.co',
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1ham51aXlwc2dvc2J6c2FlZWZjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzIwNzA5NzUsImV4cCI6MjA4NzY0Njk3NX0.M9OIGMQVdF4EACNae8G4pObbumB1fz_kR_xOz1G7chc',
    );
    
    try {
      print('Checking if reactions exists on chat_messages...');
      await client.from('chat_messages').select('reactions').limit(1);
      print('SUCCESS: reactions exists!');
    } catch (e) {
      print('ERROR for reactions: $e');
    }
  });
}
