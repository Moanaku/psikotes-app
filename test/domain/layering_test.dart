import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Aturan lapisan (docs/02-arsitektur.md): domain Dart murni, tidak mengimpor
/// `package:flutter` atau `data/`, dan hanya `SystemClock` yang membaca jam
/// sistem.
void main() {
  final files = Directory('lib/domain')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  test('domain tidak mengimpor Flutter atau lapisan data', () {
    expect(files, isNotEmpty);
    for (final f in files) {
      final imports = f
          .readAsLinesSync()
          .where((l) => l.startsWith('import ') || l.startsWith('export '));
      for (final line in imports) {
        expect(line, isNot(contains('package:flutter')), reason: f.path);
        expect(line, isNot(contains('data/')), reason: f.path);
      }
    }
  });

  test('DateTime.now() hanya di SystemClock', () {
    for (final f in files) {
      final src = f.readAsStringSync();
      final n = 'DateTime.now()'.allMatches(src).length;
      final isClock = f.uri.pathSegments.last == 'clock.dart' &&
          f.parent.uri.pathSegments.contains('services');
      expect(n, isClock ? 1 : 0, reason: f.path);
    }
  });
}
