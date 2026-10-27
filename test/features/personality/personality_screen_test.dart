import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simulator_psikotes_it/app/routes.dart';
import 'package:simulator_psikotes_it/core/widgets/app_button.dart';
import 'package:simulator_psikotes_it/core/widgets/option_tile.dart';
import 'package:simulator_psikotes_it/core/widgets/skeleton_list.dart';
import 'package:simulator_psikotes_it/domain/models/codes.dart';
import 'package:simulator_psikotes_it/domain/services/personality.dart';
import 'package:simulator_psikotes_it/features/personality/personality_providers.dart';

import '../../core/golden_helper.dart' show expectTouchTargets48;
import '../../support/fake_repositories.dart';
import '../../support/fixtures.dart';
import '../../support/pump_app.dart';
import '../../support/text_fit.dart';

final String poolText = File('assets/personality_pool.json').readAsStringSync();

Future<AppHarness> openS14(
  WidgetTester tester, {
  Future<String> Function(String)? reader,
  ProfileRole role = ProfileRole.qa,
  double textScale = 1,
  int seed = 7,
}) async {
  final app = await pumpApp(
    tester,
    profiles: FakeProfileRepository([activeProfile(role: role)]),
    textScale: textScale,
    overrides: [
      personalityAssetReaderProvider
          .overrideWithValue(reader ?? (_) async => poolText),
    ],
  );
  await app.go(Routes.psikotes);
  unawaited(app.router.push(Routes.kepribadianPath(seed)));
  await tester.pumpAndSettle();
  return app;
}

Finder button(String label) => find.widgetWithText(AppButton, label);

Future<void> tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.tap(f);
  await tester.pumpAndSettle();
}

/// Menjawab semua soal: A untuk soal genap, B untuk ganjil.
Future<void> answerAll(WidgetTester tester) async {
  for (var i = 0; i < PersonalityPairs.defaultCount; i++) {
    await tap(tester, find.byType(OptionTile).at(i.isEven ? 0 : 1));
    final last = i == PersonalityPairs.defaultCount - 1;
    await tap(tester, button(last ? 'Lihat profil' : 'Berikutnya'));
  }
}

void main() {
  testWidgets('soal pertama: dua pernyataan dari dua sifat, tanpa kunci',
      (tester) async {
    await openS14(tester);
    final pool = PersonalityPool.parse(poolText);
    final first = PersonalityPairs.build(pool, 7).first;
    expect(find.text('Papi-style'), findsOneWidget);
    expect(find.text('Soal 1 dari 24'), findsOneWidget);
    expect(
        find.text('Pilih yang paling menggambarkan dirimu.'), findsOneWidget);
    expect(find.text(first.a.teks), findsOneWidget);
    expect(find.text(first.b.teks), findsOneWidget);
    expect(find.textContaining('Tidak ada jawaban benar'), findsOneWidget);
    expect(find.textContaining('bukan diagnosis'), findsOneWidget);
    // Berikutnya baru aktif setelah memilih.
    expect(tester.widget<AppButton>(button('Berikutnya')).onPressed, isNull);
    await tap(tester, find.byType(OptionTile).first);
    expect(tester.widget<AppButton>(button('Berikutnya')).onPressed, isNotNull);
    // Memilih tidak menampilkan penanda benar atau salah.
    for (final t in tester.widgetList<OptionTile>(find.byType(OptionTile))) {
      expect(t.marks, isEmpty);
    }
  });

  testWidgets('Sebelumnya menyimpan pilihan soal sebelumnya', (tester) async {
    await openS14(tester);
    await tap(tester, find.byType(OptionTile).at(1));
    await tap(tester, button('Berikutnya'));
    expect(find.text('Soal 2 dari 24'), findsOneWidget);
    await tap(tester, button('Sebelumnya'));
    expect(find.text('Soal 1 dari 24'), findsOneWidget);
    final tiles = tester.widgetList<OptionTile>(find.byType(OptionTile));
    expect([for (final t in tiles) t.selected], [false, true]);
  });

  testWidgets('review: profil, arti tiap pilihan, dan sifat untuk role QA',
      (tester) async {
    await openS14(tester);
    await answerAll(tester);
    expect(find.text('Profil kecenderungan'), findsOneWidget);
    expect(find.text('Untuk QA Engineer'), findsOneWidget);
    expect(find.textContaining('Lowongan ini umumnya mencari'), findsOneWidget);
    expect(find.textContaining('keteraturan dan ketelitian'), findsWidgets);
    expect(find.textContaining('dipilih '), findsWidgets);
    await tester.scrollUntilVisible(
      find.text('Arti pilihanmu di soal 24'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Arti pilihanmu di soal 24'), findsOneWidget);
    // Tidak ada label benar atau salah di review.
    expect(find.text('Benar'), findsNothing);
    expect(find.text('Salah'), findsNothing);
  });

  testWidgets('role Umum: tidak ada daftar sifat per role', (tester) async {
    await openS14(tester, role: ProfileRole.umum);
    await answerAll(tester);
    expect(find.textContaining('sifat per role tidak ditampilkan'),
        findsOneWidget);
  });

  testWidgets('Ulangi dengan soal baru memakai seed lain', (tester) async {
    final app = await openS14(tester);
    await answerAll(tester);
    await tap(tester, button('Ulangi dengan soal baru'));
    expect(find.text('Soal 1 dari 24'), findsOneWidget);
    expect(app.location, startsWith('/kepribadian/'));
    expect(app.location, isNot(Routes.kepribadianPath(7)));
  });

  group('keluar', () {
    testWidgets('tanpa pilihan: langsung kembali ke katalog', (tester) async {
      final app = await openS14(tester);
      await tap(tester, find.byTooltip('Tutup sesi kepribadian'));
      expect(app.location, Routes.psikotes);
    });

    testWidgets('dengan pilihan: konfirmasi dulu, Tetap mengerjakan menutupnya',
        (tester) async {
      final app = await openS14(tester);
      await tap(tester, find.byType(OptionTile).first);
      await tap(tester, find.byTooltip('Tutup sesi kepribadian'));
      expect(find.textContaining('tidak disimpan'), findsOneWidget);
      await tap(tester, button('Tetap mengerjakan'));
      expect(find.textContaining('tidak disimpan'), findsNothing);
      await tap(tester, find.byTooltip('Tutup sesi kepribadian'));
      await tap(tester, button('Keluar dari sesi'));
      expect(app.location, Routes.psikotes);
    });
  });

  group('kondisi', () {
    testWidgets('memuat: skeleton, bukan spinner', (tester) async {
      final pending = Completer<String>();
      await pumpApp(
        tester,
        profiles: FakeProfileRepository([activeProfile()]),
        overrides: [
          personalityAssetReaderProvider
              .overrideWithValue((_) => pending.future),
        ],
      ).then((app) => app.router.go(Routes.kepribadianPath(1)));
      await tester.pump();
      await tester.pump();
      expect(find.byType(SkeletonList), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      pending.complete(poolText);
      await tester.pumpAndSettle();
      expect(find.text('Soal 1 dari 24'), findsOneWidget);
    });

    testWidgets('galat: sebab dan Coba lagi, tanpa teks exception',
        (tester) async {
      var calls = 0;
      await openS14(tester, reader: (_) async {
        calls++;
        if (calls == 1) return '{rusak';
        return poolText;
      });
      expect(find.text('Pernyataan tidak terbaca'), findsOneWidget);
      expect(find.textContaining('Exception'), findsNothing);
      await tap(tester, find.text('Coba lagi'));
      expect(find.text('Soal 1 dari 24'), findsOneWidget);
    });
  });

  group('keterbacaan', () {
    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets('soal dan review di 360 dp, teks ${(scale * 100).round()}%',
          (tester) async {
        await openS14(tester, textScale: scale);
        expect(tester.takeException(), isNull);
        expectNoMidWordBreaks(tester, reason: 'soal');
        await answerAll(tester);
        expect(tester.takeException(), isNull);
        expectNoMidWordBreaks(tester, reason: 'review');
      });
    }

    testWidgets('target sentuh 48 dp dan label tombol tutup', (tester) async {
      await openS14(tester);
      expectTouchTargets48(tester);
      expect(find.byTooltip('Tutup sesi kepribadian'), findsOneWidget);
      final semantics = tester.getSemantics(find.byType(OptionTile).first);
      expect(semantics.label, startsWith('Opsi A, Saya '));
    });
  });
}
