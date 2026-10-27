import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// Teks kode (pseudocode) dengan font monospasi dari token `AppType.code`.
/// Indentasi awal tiap baris dipertahankan, dan baris panjang dipatahkan pada
/// spasi dengan indentasi gantung: baris lanjutan menjorok [hang] karakter dari
/// indentasi barisnya, jadi struktur blok tetap terbaca di layar sempit dan
/// skala huruf besar. Bukan kartu: tanpa latar atau bingkai.
class CodeBlock extends StatelessWidget {
  const CodeBlock({super.key, required this.text, this.hang = 2});

  final String text;

  /// Jorok baris lanjutan, dalam karakter.
  final int hang;

  /// Memecah [text] menjadi baris sepanjang paling banyak [cols] karakter.
  /// Murni; dipakai [build] dan test.
  static List<String> wrap(String text, int cols, {int hang = 2}) {
    final out = <String>[];
    for (final raw in text.split('\n')) {
      final trimmed = raw.trimLeft();
      final indent = raw.length - trimmed.length;
      if (trimmed.isEmpty) {
        out.add('');
        continue;
      }
      var first = true;
      var rest = trimmed;
      while (true) {
        final pad = indent + (first ? 0 : hang);
        final room = (cols - pad).clamp(1, 1 << 20);
        if (rest.length <= room) {
          out.add(' ' * pad + rest);
          break;
        }
        var cut = rest.lastIndexOf(' ', room);
        // Kata lebih panjang dari sisa ruang dipatahkan paksa.
        if (cut <= 0) cut = room;
        out.add(' ' * pad + rest.substring(0, cut).trimRight());
        rest = rest.substring(cut).trimLeft();
        first = false;
        if (rest.isEmpty) break;
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.tokens.colors;
    final style = AppType.code(c.ink);
    final scaler = MediaQuery.textScalerOf(context);
    return Semantics(
      container: true,
      label: text,
      excludeSemantics: true,
      child: LayoutBuilder(
        builder: (context, box) {
          final painter = TextPainter(
            text: TextSpan(text: '0', style: style),
            textDirection: Directionality.of(context),
            textScaler: scaler,
          )..layout();
          final charWidth = painter.width;
          painter.dispose();
          final cols = box.hasBoundedWidth && charWidth > 0
              ? (box.maxWidth / charWidth).floor()
              : 1 << 20;
          return Text(
            wrap(text, cols, hang: hang).join('\n'),
            style: style,
            softWrap: false,
          );
        },
      ),
    );
  }
}
