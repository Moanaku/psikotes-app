import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simulator_psikotes_it/core/widgets/empty_view.dart';
import 'package:simulator_psikotes_it/core/widgets/error_view.dart';
import 'package:simulator_psikotes_it/core/widgets/offline_view.dart';
import 'package:simulator_psikotes_it/core/widgets/skeleton_list.dart';

import 'golden_helper.dart';

void main() {
  group('EmptyView', () {
    Widget all() => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            EmptyView(
              title: 'Buku kesalahan masih kosong',
              message: 'Soal yang salah akan masuk ke sini dan muncul lagi '
                  'beberapa hari kemudian.',
              actionLabel: 'Mulai latihan',
              onAction: () {},
            ),
            EmptyView(
              title: 'Tidak ada kartu Capture yang jatuh tempo',
              message: 'Filter Capture tidak punya kartu hari ini.',
              actionLabel: 'Tampilkan semua',
              onAction: () {},
            ),
            const EmptyView(
              title: 'Tidak ada kartu jatuh tempo hari ini',
              message: 'Kartu berikutnya muncul 24 Oktober.',
            ),
          ],
        );

    goldenTest('golden', (tester) async {
      await pumpScene(tester, all());
      await expectGolden(tester, 'empty_view');
    });

    testWidgets('target 48 dan tidak terpotong di skala 2,0', (tester) async {
      await pumpScene(tester, all(), textScale: 2);
      expectTouchTargets48(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('tombol aksi memanggil onAction', (tester) async {
      var taps = 0;
      await pumpScene(
        tester,
        EmptyView(
          title: 'Kosong',
          message: 'Belum ada data.',
          actionLabel: 'Mulai latihan',
          onAction: () => taps++,
        ),
      );
      await tester.tap(find.text('Mulai latihan'));
      expect(taps, 1);
    });
  });

  group('SkeletonList', () {
    goldenTest('golden tanpa dan dengan ikon', (tester) async {
      await pumpScene(
        tester,
        const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SkeletonList(),
            SizedBox(height: 24),
            SkeletonList(rows: 2, withLeading: true),
          ],
        ),
      );
      await expectGolden(tester, 'skeleton_list');
    });

    testWidgets('bukan spinner, tiap baris min 56, punya label semantik',
        (tester) async {
      await pumpScene(tester, const SkeletonList(rows: 4));
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(tester.getSize(find.byType(SkeletonList)).height,
          greaterThanOrEqualTo(4 * 56));
      expect(find.bySemanticsLabel('Memuat daftar'), findsOneWidget);
    });
  });

  group('SkeletonList rata kiri', () {
    testWidgets('batang placeholder mulai di tepi kiri isi, tidak dipusatkan',
        (tester) async {
      await pumpScene(tester, const SkeletonList(rows: 2));
      final list = tester.getTopLeft(find.byType(SkeletonList));
      final bars = find.descendant(
        of: find.byType(SkeletonList),
        matching: find.byType(FractionallySizedBox),
      );
      expect(bars, findsNWidgets(4));
      for (final bar in bars.evaluate()) {
        final box = tester.getRect(find.byWidget(bar.widget));
        expect(box.left, list.dx + 16,
            reason: 'tepi kiri batang sejajar margin isi (16)');
        final inner = tester.getRect(find
            .descendant(
                of: find.byWidget(bar.widget), matching: find.byType(Container))
            .first);
        expect(inner.left, box.left);
      }
    });

    testWidgets('dengan ikon: batang mulai tepat setelah ikon', (tester) async {
      await pumpScene(tester, const SkeletonList(rows: 1, withLeading: true));
      final bar = tester.getRect(find
          .descendant(
              of: find.byType(SkeletonList),
              matching: find.byType(FractionallySizedBox))
          .first);
      expect(bar.left, 16 + 24 + 16);
    });
  });

  group('ErrorView', () {
    Widget view() => ErrorView(
          title: 'Rencana latihan tidak bisa disusun',
          message: 'Data profil gagal dibaca. Coba lagi, atau buka Pengaturan '
              'untuk memeriksa profil aktif.',
          onRetry: () {},
        );

    goldenTest('golden', (tester) async {
      await pumpScene(tester, view());
      await expectGolden(tester, 'error_view');
    });

    testWidgets('target 48 dan tidak terpotong di skala 2,0', (tester) async {
      await pumpScene(tester, view(), textScale: 2);
      expectTouchTargets48(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('"Coba lagi" memanggil onRetry', (tester) async {
      var retries = 0;
      await pumpScene(
        tester,
        ErrorView(
          title: 'Backup tidak bisa dibaca',
          message: 'Berkasnya bukan hasil ekspor dari app ini.',
          onRetry: () => retries++,
        ),
      );
      await tester.tap(find.text('Coba lagi'));
      expect(retries, 1);
    });
  });

  group('OfflineView', () {
    Widget view() => OfflineView(
          message: 'Wawancara butuh internet untuk menyusun pertanyaan.',
          stillWorks: 'Wawancara memakai kartu pertanyaan template. '
              'Psikotes tetap jalan seperti biasa.',
          actionLabel: 'Pakai kartu template',
          onAction: () {},
        );

    goldenTest('golden', (tester) async {
      await pumpScene(tester, view());
      await expectGolden(tester, 'offline_view');
    });

    testWidgets('menyebut yang tetap jalan, target 48, tidak terpotong',
        (tester) async {
      await pumpScene(tester, view(), textScale: 2);
      expect(find.textContaining('Psikotes tetap jalan'), findsOneWidget);
      expect(find.text('Tidak ada internet'), findsOneWidget);
      expectTouchTargets48(tester);
      expect(tester.takeException(), isNull);
    });
  });
}
