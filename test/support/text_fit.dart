import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_fonts.dart';

/// Tidak ada kata yang terpaksa dipatahkan di tengah kata. Setiap kata di
/// setiap teks yang tampil diukur sendiri pada lebar teksnya; bila kata itu
/// sendirian pun memakai lebih dari satu baris, kata tersebut terpotong.
///
/// Font app sungguhan (Instrument Sans) harus termuat: pemeriksaan ini gagal
/// bila test mengukur dengan font cadangan ([expectAppFontLoaded]).
///
/// Teks yang dibatasi satu baris dengan elipsis tidak diperiksa: itu
/// pemotongan yang disengaja dan terlihat.
void expectNoMidWordBreaks(WidgetTester tester, {String? reason}) {
  expectAppFontLoaded();
  final broken = <String>[];
  for (final element in find.byType(RichText).evaluate()) {
    final box = element.renderObject;
    if (box is! RenderParagraph || !box.hasSize) continue;
    if (box.overflow == TextOverflow.ellipsis && box.maxLines == 1) continue;
    final width = box.size.width;
    final text = box.text.toPlainText();
    final flat = text.replaceAll(RegExp(r'\s+'), ' ');
    // Tanda hubung biasa adalah tempat putus yang sah ("CCAT-" lalu "style").
    final words = text
        .split(RegExp(r'[\s\u200B]+'))
        .expand((w) => w.split(RegExp(r'(?<=-)')));
    for (final word in words) {
      if (word.isEmpty) continue;
      final painter = TextPainter(
        text: TextSpan(text: word, style: box.text.style),
        textDirection: box.textDirection,
        textScaler: box.textScaler,
      )..layout(maxWidth: width);
      final lines = painter.computeLineMetrics().length;
      painter.dispose();
      if (lines > 1) {
        broken.add('"$word" (lebar ${width.toStringAsFixed(0)}, ukuran '
            '${box.text.style?.fontSize}, di "$flat")');
      }
    }
  }
  expect(broken, isEmpty, reason: reason ?? 'kata terpotong di tengah kata');
}
