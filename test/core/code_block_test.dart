import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simulator_psikotes_it/core/theme/app_tokens.dart';
import 'package:simulator_psikotes_it/core/widgets/code_block.dart';

import '../support/pump_app.dart';
import '../support/text_fit.dart';

void main() {
  group('CodeBlock.wrap', () {
    test('baris pendek dan indentasi awal dipertahankan', () {
      expect(CodeBlock.wrap('x <- 1\n  y <- 2', 40), ['x <- 1', '  y <- 2']);
    });

    test('baris panjang dipatahkan di spasi dengan indentasi gantung', () {
      final lines =
          CodeBlock.wrap('  jika x <= 10 dan y != 3 maka tampilkan x', 20);
      expect(lines.first.startsWith('  jika'), isTrue);
      expect(lines.length, greaterThan(1));
      for (final l in lines.skip(1)) {
        expect(l.startsWith('    '), isTrue,
            reason: 'indent 2 + gantung 2: "$l"');
      }
      for (final l in lines) {
        expect(l.length, lessThanOrEqualTo(20), reason: l);
      }
      expect(lines.map((l) => l.trim()).join(' '),
          'jika x <= 10 dan y != 3 maka tampilkan x');
    });

    test('kata lebih panjang dari lebar dipatahkan paksa', () {
      final lines = CodeBlock.wrap('abcdefghijklmnop', 6);
      expect(lines.every((l) => l.length <= 6), isTrue);
      expect(lines.join().replaceAll(' ', ''), 'abcdefghijklmnop');
    });

    test('baris kosong tetap ada', () {
      expect(CodeBlock.wrap('a\n\nb', 10), ['a', '', 'b']);
    });
  });

  group('font kode', () {
    test('token memakai IBM Plex Mono 14/20', () {
      final s = AppType.code(const Color(0xFF000000));
      expect(s.fontFamily, 'IBMPlexMono');
      expect(s.fontSize, 14);
      expect(s.height, 20 / 14);
    });

    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets('skala $scale: glyph <= >= != <- tampil dan tidak meluap',
          (tester) async {
        await pumpScreen(
          tester,
          const Scaffold(
            body: Padding(
              padding: EdgeInsets.all(16),
              child: CodeBlock(
                text: 'jika a <= b dan c >= d atau e != f maka\n'
                    '  x <- x + 1\n'
                    '  tampilkan hasil perhitungan terakhir dari x',
              ),
            ),
          ),
          textScale: scale,
        );
        expect(tester.takeException(), isNull);
        final text = tester.widget<Text>(find.byType(Text));
        expect(text.style!.fontFamily, 'IBMPlexMono');
        expect(text.data, contains('<='));
        expect(text.data, contains('!='));
        expect(text.data, contains('<-'));
        // Tiap baris muat dalam lebar layar 360 dp (dikurangi margin).
        expect(tester.getSize(find.byType(Text)).width, lessThanOrEqualTo(328));
        expectNoMidWordBreaks(tester);
      });
    }
  });
}
