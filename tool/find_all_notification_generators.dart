import 'dart:convert';
import 'dart:io';

void main() {
  final dirs = [Directory('supabase/migrations'), Directory('sql')];
  final notifFunctions = <String, List<String>>{};

  for (final dir in dirs) {
    if (!dir.existsSync()) continue;
    for (final file in dir.listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.sql')) continue;
      String content;
      try {
        content = file.readAsStringSync();
      } catch (_) {
        try {
          content = file.readAsStringSync(encoding: latin1);
        } catch (_) {
          continue;
        }
      }
      if (!content.contains('notifications') && !content.contains('fn_create_notification')) continue;

      // Extract functions
      final lines = content.split('\n');
      String currentFunction = 'TOP_LEVEL';
      for (int i = 0; i < lines.length; i++) {
        final line = lines[i];
        final matchFunc = RegExp(r'CREATE\s+(?:OR\s+REPLACE\s+)?FUNCTION\s+([a-zA-Z0-9_\."]+)', caseSensitive: false).firstMatch(line);
        if (matchFunc != null) {
          currentFunction = matchFunc.group(1)!;
        }

        if (line.contains('notifications') || line.contains('fn_create_notification')) {
          if (line.contains('INSERT INTO') || line.contains('fn_create_notification') || line.contains('PERFORM')) {
            final key = '${file.path} :: $currentFunction';
            notifFunctions.putIfAbsent(key, () => []);
            // grab 3 lines around
            final snippet = lines.sublist(
              i > 1 ? i - 1 : 0,
              i + 5 < lines.length ? i + 5 : lines.length,
            ).join('\n');
            notifFunctions[key]!.add('Line $i:\n$snippet\n---');
          }
        }
      }
    }
  }

  final buffer = StringBuffer();
  buffer.writeln('=== FOUND ${notifFunctions.length} LOCATIONS GENERATING NOTIFICATIONS ===\n');
  notifFunctions.forEach((k, v) {
    buffer.writeln('LOCATION: $k');
    for (final s in v) {
      buffer.writeln(s);
    }
    buffer.writeln('====================================================\n');
  });

  File('tool/notification_generators_audit.txt').writeAsStringSync(buffer.toString(), encoding: utf8);
  print('Done. Wrote ${notifFunctions.length} locations to tool/notification_generators_audit.txt');
}
