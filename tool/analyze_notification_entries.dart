import 'dart:io';

void main() {
  final file = File('tool/notification_generators_audit.txt');
  final lines = file.readAsLinesSync();
  String currentLocation = '';
  final entries = <Map<String, String>>[];
  Map<String, String>? currentEntry;

  for (int i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (line.startsWith('LOCATION: ')) {
      currentLocation = line.substring('LOCATION: '.length);
    } else if (line.startsWith('Line ')) {
      currentEntry = {
        'location': currentLocation,
        'line': line,
        'code': '',
      };
      entries.add(currentEntry);
    } else if (line == '---' || line.startsWith('=====')) {
      currentEntry = null;
    } else if (currentEntry != null) {
      currentEntry['code'] = (currentEntry['code'] ?? '') + line + '\n';
    }
  }

  print('Total entries found: ${entries.length}\n');
  final uniqueFuncs = <String>{};
  for (final e in entries) {
    final loc = e['location']!;
    final func = loc.split(' :: ').last;
    uniqueFuncs.add(func);
  }

  print('Distinct Functions generating notifications (${uniqueFuncs.length}):');
  for (final f in uniqueFuncs) {
    print('  - $f');
  }

  // Also print all titles/messages found in snippets
  print('\nHardcoded Titles & Messages extracted:');
  final titleRegex = RegExp(r"'([^']{2,100})'");
  final hardcodedStrings = <String>{};
  for (final e in entries) {
    for (final match in titleRegex.allMatches(e['code']!)) {
      final s = match.group(1)!;
      // if contains Arabic characters
      if (RegExp(r'[\u0600-\u06FF]').hasMatch(s)) {
        hardcodedStrings.add(s);
      }
    }
  }

  print('Found ${hardcodedStrings.length} Arabic notification strings:');
  for (final s in hardcodedStrings) {
    print('  • $s');
  }
}
