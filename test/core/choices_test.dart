import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simulator_psikotes_it/core/widgets/app_chip.dart';
import 'package:simulator_psikotes_it/core/widgets/option_tile.dart';
import 'package:simulator_psikotes_it/core/widgets/segmented_control.dart';

import 'golden_helper.dart';

void main() {
  group('OptionTile', () {
    Widget all() => scene([
          OptionTile(letter: 'A', label: '24', selected: false, onTap: () {}),
          OptionTile(letter: 'B', label: '31', selected: true, onTap: () {}),
          OptionTile(
              letter: 'C', label: longSentence, selected: false, onTap: () {}),
          OptionTile(
              letter: 'D', label: longSentence, selected: true, onTap: () {}),
        ], gap: 8);

    testWidgets('golden', (tester) async {
      await pumpScene(tester, all());
      await expectGolden(tester, 'option_tile');
    });

    testWidgets('target 48 dan teks panjang tidak terpotong di skala 2,0',
        (tester) async {
      await pumpScene(tester, all(), textScale: 2);
      expectTouchTargets48(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('terpilih tidak menggeser tata letak', (tester) async {
      await pumpScene(
        tester,
        OptionTile(letter: 'A', label: 'Satu', selected: false, onTap: () {}),
      );
      final before = tester.getSize(find.byType(OptionTile));
      await pumpScene(
        tester,
        OptionTile(letter: 'A', label: 'Satu', selected: true, onTap: () {}),
      );
      expect(tester.getSize(find.byType(OptionTile)), before);
    });

    testWidgets('semantik menyebut huruf dan isi opsi', (tester) async {
      await pumpScene(
        tester,
        OptionTile(letter: 'C', label: '48', selected: true, onTap: () {}),
      );
      expect(
        tester.getSemantics(find.byType(OptionTile)),
        matchesSemantics(
          label: 'Opsi C, 48',
          isButton: true,
          isSelected: true,
          hasSelectedState: true,
          hasTapAction: true,
        ),
      );
    });
  });

  group('AppChip', () {
    Widget all() => scene([
          Wrap(spacing: 8, children: [
            AppChip(label: 'Semua', selected: true, onTap: () {}),
            AppChip(label: 'Psikotes', selected: false, onTap: () {}),
            AppChip(label: 'Capture', selected: false, onTap: () {}),
            AppChip(label: 'Wawancara', selected: false, onTap: () {}),
          ]),
          AppChip(label: longLabel, selected: false, onTap: () {}),
        ]);

    testWidgets('golden', (tester) async {
      await pumpScene(tester, all());
      await expectGolden(tester, 'app_chip');
    });

    testWidgets('area sentuh 48 dan label panjang tidak terpotong',
        (tester) async {
      await pumpScene(tester, all(), textScale: 2);
      expectTouchTargets48(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('tinggi tampilan 44', (tester) async {
      await pumpScene(
        tester,
        Align(
          alignment: Alignment.centerLeft,
          child: AppChip(label: 'Semua', selected: false, onTap: () {}),
        ),
      );
      final visual = find.descendant(
        of: find.byType(AppChip),
        matching: find.byType(AnimatedContainer),
      );
      expect(tester.getSize(visual).height, 44);
    });
  });

  group('SegmentedControl', () {
    Widget all() => scene([
          SegmentedControl(
            options: const ['Latihan', 'Simulasi'],
            selectedIndex: 0,
            onChanged: (_) {},
          ),
          SegmentedControl(
            options: const ['Mingguan', 'Bulanan'],
            selectedIndex: 1,
            onChanged: (_) {},
          ),
          SegmentedControl(
            options: const ['Terang', 'Gelap', 'Ikuti sistem'],
            selectedIndex: 2,
            onChanged: (_) {},
          ),
        ], gap: 12);

    testWidgets('golden', (tester) async {
      await pumpScene(tester, all());
      await expectGolden(tester, 'segmented_control');
    });

    testWidgets('tinggi total 48, target 48, tidak terpotong di skala 2,0',
        (tester) async {
      await pumpScene(tester, all());
      expect(tester.getSize(find.byType(SegmentedControl).first).height, 48);
      await pumpScene(tester, all(), textScale: 2);
      expectTouchTargets48(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('ketuk segmen memanggil indeks', (tester) async {
      int? picked;
      await pumpScene(
        tester,
        SegmentedControl(
          options: const ['Latihan', 'Simulasi'],
          selectedIndex: 0,
          onChanged: (i) => picked = i,
        ),
      );
      await tester.tap(find.text('Simulasi'));
      expect(picked, 1);
    });
  });
}
