import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simulator_psikotes_it/core/theme/app_icons.dart';
import 'package:simulator_psikotes_it/core/widgets/app_bottom_nav.dart';
import 'package:simulator_psikotes_it/core/widgets/app_icon_button.dart';
import 'package:simulator_psikotes_it/core/widgets/app_top_bar.dart';

import 'golden_helper.dart';

void main() {
  group('AppTopBar', () {
    Widget all() => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppTopBar(title: 'Psikotes'),
            AppTopBar(
              title: 'Buku kesalahan',
              onBack: () {},
              actions: [
                AppIconButton(
                  icon: AppIcons.sliders,
                  label: 'Pengaturan',
                  onPressed: () {},
                ),
              ],
            ),
            AppTopBar(
              title:
                  'Pembahasan soal tentang deret angka dan selisih bertingkat',
              onBack: () {},
              actions: [
                AppIconButton(
                  icon: AppIcons.close,
                  label: 'Tutup',
                  onPressed: () {},
                ),
              ],
            ),
          ],
        );

    testWidgets('golden', (tester) async {
      await pumpScene(tester, all());
      await expectGolden(tester, 'app_top_bar');
    });

    testWidgets('tinggi minimal 56, judul panjang tidak terpotong di skala 2,0',
        (tester) async {
      await pumpScene(tester, all(), textScale: 2);
      expect(tester.getSize(find.byType(AppTopBar).first).height,
          greaterThanOrEqualTo(56));
      expectTouchTargets48(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('tombol kembali berlabel dan bekerja', (tester) async {
      var back = 0;
      await pumpScene(
        tester,
        AppTopBar(title: 'Hasil sesi', onBack: () => back++),
      );
      await tester.tap(find.byTooltip('Kembali'));
      expect(back, 1);
      expect(find.bySemanticsLabel('Kembali'), findsOneWidget);
    });
  });

  group('AppBottomNav', () {
    testWidgets('golden tab pertama dan ketiga aktif', (tester) async {
      await pumpScene(
        tester,
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBottomNav(currentIndex: 0, onSelected: (_) {}),
            const SizedBox(height: 16),
            AppBottomNav(currentIndex: 2, onSelected: (_) {}),
          ],
        ),
      );
      await expectGolden(tester, 'app_bottom_nav');
    });

    testWidgets('empat tab, ketuk memanggil indeks, target 48 dp',
        (tester) async {
      final tapped = <int>[];
      await pumpScene(
        tester,
        AppBottomNav(currentIndex: 1, onSelected: tapped.add),
      );
      for (final label in ['Beranda', 'Psikotes', 'Wawancara', 'Statistik']) {
        expect(find.text(label), findsOneWidget);
      }
      expectTouchTargets48(tester);
      await tester.tap(find.text('Statistik'));
      await tester.tap(find.text('Beranda'));
      expect(tapped, [3, 0]);
    });

    testWidgets('label tidak terpotong di skala 2,0 pada 360 dp',
        (tester) async {
      await pumpScene(
        tester,
        AppBottomNav(currentIndex: 2, onSelected: (_) {}),
        textScale: 2,
      );
      expect(tester.takeException(), isNull);
    });
  });
}
