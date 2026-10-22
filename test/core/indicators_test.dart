import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simulator_psikotes_it/core/widgets/number_bubble.dart';
import 'package:simulator_psikotes_it/core/widgets/quadrant_grid.dart';
import 'package:simulator_psikotes_it/core/widgets/score_bar.dart';
import 'package:simulator_psikotes_it/core/widgets/stat_row.dart';
import 'package:simulator_psikotes_it/core/widgets/status_tag.dart';

import 'golden_helper.dart';

void main() {
  group('NumberBubble', () {
    Widget all({VoidCallback? onTap}) => scene([
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (var i = 1; i <= 12; i++)
              NumberBubble(
                number: i,
                onTap: onTap,
                state: i < 7
                    ? NumberBubbleState.answered
                    : i == 7
                        ? NumberBubbleState.current
                        : NumberBubbleState.unanswered,
              ),
          ]),
        ]);

    testWidgets('golden', (tester) async {
      await pumpScene(tester, all());
      await expectGolden(tester, 'number_bubble');
      expect(
          tester.getSize(find.byType(NumberBubble).first), const Size(32, 32));
    });

    testWidgets('bila bisa diketuk, area sentuh 48', (tester) async {
      var taps = 0;
      await pumpScene(tester, all(onTap: () => taps++));
      expectTouchTargets48(tester);
      await tester.tap(find.text('3'));
      expect(taps, 1);
    });

    testWidgets('semantik menyebut nomor dan status', (tester) async {
      await pumpScene(
        tester,
        const NumberBubble(number: 7, state: NumberBubbleState.current),
      );
      expect(
          find.bySemanticsLabel('Soal 7, sedang dikerjakan'), findsOneWidget);
    });
  });

  group('ScoreBar', () {
    Widget all() => scene([
          const ScoreBar(label: 'Numerik', value: 0.82, valueLabel: '82%'),
          const ScoreBar(label: 'Verbal', value: 0.64, valueLabel: '64%'),
          const ScoreBar(
            label: 'Figural induktif',
            value: 0.38,
            valueLabel: '38%',
            weakest: true,
          ),
          const ScoreBar(label: 'Kosong', value: 0, valueLabel: '0%'),
          const ScoreBar(label: longLabel, value: 1, valueLabel: '100%'),
        ]);

    testWidgets('golden', (tester) async {
      await pumpScene(tester, all());
      await expectGolden(tester, 'score_bar');
    });

    testWidgets('label panjang tidak terpotong di skala 2,0', (tester) async {
      await pumpScene(tester, all(), textScale: 2);
      expect(tester.takeException(), isNull);
    });

    testWidgets('nilai dibaca sebagai teks, kelemahan terbesar disebut',
        (tester) async {
      await pumpScene(
        tester,
        const ScoreBar(
          label: 'Figural',
          value: 0.38,
          valueLabel: '38%',
          weakest: true,
        ),
      );
      expect(find.text('38%'), findsOneWidget);
      expect(find.bySemanticsLabel('Figural: 38%, kelemahan terbesar'),
          findsOneWidget);
    });
  });

  group('StatusTag', () {
    Widget all() => scene([
          const Wrap(spacing: 8, runSpacing: 8, children: [
            StatusTag(label: 'Belum'),
            StatusTag(label: 'Hari ini', kind: StatusTagKind.attention),
            StatusTag(label: 'Kuat', kind: StatusTagKind.strong),
            StatusTag(label: 'Terlemah', kind: StatusTagKind.attention),
          ]),
          const StatusTag(label: 'Tersedia di versi 1.1'),
          const StatusTag(label: longLabel, kind: StatusTagKind.strong),
        ], gap: 8);

    testWidgets('golden', (tester) async {
      await pumpScene(tester, all());
      await expectGolden(tester, 'status_tag');
    });

    testWidgets('tinggi minimal 24 dan tidak terpotong di skala 2,0',
        (tester) async {
      await pumpScene(tester, all(), textScale: 2);
      for (final tag in find.byType(StatusTag).evaluate()) {
        expect(tester.getSize(find.byWidget(tag.widget)).height,
            greaterThanOrEqualTo(24));
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('tinggi 24 pada skala 1,0', (tester) async {
      await pumpScene(
        tester,
        const Align(
          alignment: Alignment.centerLeft,
          child: StatusTag(label: 'Kuat', kind: StatusTagKind.strong),
        ),
      );
      expect(tester.getSize(find.byType(StatusTag)).height, 24);
    });
  });

  group('StatRow', () {
    Widget all() => scene([
          const StatRow(items: [
            StatItem(value: '120', label: 'menit minggu ini'),
            StatItem(value: '8', label: 'sesi selesai'),
            StatItem(value: '5', label: 'hari beruntun'),
          ]),
          const StatRow(items: [
            StatItem(value: '1.250', label: longLabel),
            StatItem(value: '12', label: 'sesi'),
            StatItem(value: '31', label: 'hari beruntun tanpa jeda'),
          ]),
        ], gap: 24);

    testWidgets('golden', (tester) async {
      await pumpScene(tester, all());
      await expectGolden(tester, 'stat_row');
    });

    testWidgets('keterangan panjang tidak terpotong di skala 2,0',
        (tester) async {
      await pumpScene(tester, all(), textScale: 2);
      expect(tester.takeException(), isNull);
    });
  });

  group('QuadrantGrid', () {
    Widget all() => scene([
          const QuadrantGrid(cells: [
            QuadrantCell(title: 'Benar dan cepat', count: 9, correct: true),
            QuadrantCell(title: 'Benar tapi lambat', count: 5, correct: true),
            QuadrantCell(
              title: 'Salah dan cepat',
              count: 3,
              correct: false,
              note: 'Terburu-buru',
            ),
            QuadrantCell(
              title: 'Salah dan lambat',
              count: 3,
              correct: false,
              note: 'Belum paham pola',
            ),
          ]),
        ]);

    testWidgets('golden', (tester) async {
      await pumpScene(tester, all());
      await expectGolden(tester, 'quadrant_grid');
    });

    testWidgets('empat sel, tiap sel punya ikon dan tidak terpotong di 2,0',
        (tester) async {
      await pumpScene(tester, all(), textScale: 2);
      expect(find.byIcon(Icons.check), findsNWidgets(2));
      expect(find.byIcon(Icons.close), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });
  });
}
