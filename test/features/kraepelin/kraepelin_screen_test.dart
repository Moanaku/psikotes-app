import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:question_engine/question_engine.dart';
import 'package:simulator_psikotes_it/app/routes.dart';
import 'package:simulator_psikotes_it/core/widgets/app_button.dart';
import 'package:simulator_psikotes_it/domain/models/codes.dart';
import 'package:simulator_psikotes_it/features/kraepelin/kraepelin_screen.dart';

import '../../core/golden_helper.dart' show expectTouchTargets48;
import '../../support/fake_repositories.dart';
import '../../support/fixtures.dart';
import '../../support/pump_app.dart';
import '../../support/text_fit.dart';

const int seed = 21;

Future<AppHarness> openKrp(
  WidgetTester tester, {
  int columns = 2,
  int seconds = 15,
  double textScale = 1,
}) async {
  final app = await pumpApp(
    tester,
    profiles: FakeProfileRepository([activeProfile()]),
    textScale: textScale,
  );
  await app.go(Routes.psikotes);
  unawaited(app.router
      .push(Routes.kraepelinPath(seed, columns: columns, seconds: seconds)));
  await tester.pumpAndSettle();
  return app;
}

Finder button(String label) => find.widgetWithText(AppButton, label);

Future<void> tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.tap(f);
  await tester.pump();
}

Future<void> typeDigit(WidgetTester tester, int d) => tap(tester, button('$d'));

void main() {
  final sheet = KrpSheet.generate(
      seed, KrpConfig.timed(columns: 2, secondsPerColumn: 15));

  testWidgets('pengantar menyebut kolom dan waktu; Mulai memulai kolom 1',
      (tester) async {
    await openKrp(tester);
    expect(find.text('Kraepelin / Pauli'), findsOneWidget);
    expect(find.text('2 kolom, 15 detik per kolom'), findsOneWidget);
    expect(find.textContaining('ketik angka terakhir'), findsOneWidget);
    await tap(tester, button('Mulai kolom 1'));
    expect(find.text('Kolom 1 dari 2, 0 isian'), findsOneWidget);
    expect(find.text('00:15'), findsOneWidget);
    // Pasangan pertama tampil di kotak sorot.
    expect(
      find.bySemanticsLabel(
          'Jumlahkan ${sheet.digits[0][0]} dan ${sheet.digits[0][1]}'),
      findsOneWidget,
    );
  });

  testWidgets('input angka cepat, kolom berganti otomatis, lalu hasil',
      (tester) async {
    final app = await openKrp(tester);
    await tap(tester, button('Mulai kolom 1'));
    // Kolom 1: tiga isian benar, satu salah.
    for (var i = 0; i < 3; i++) {
      await typeDigit(tester, sheet.answer(0, i));
    }
    await typeDigit(tester, (sheet.answer(0, 3) + 1) % 10);
    expect(find.text('Kolom 1 dari 2, 4 isian'), findsOneWidget);
    expect(
      find.bySemanticsLabel(
          'Jumlahkan ${sheet.digits[0][4]} dan ${sheet.digits[0][5]}'),
      findsOneWidget,
    );

    await app.tickSeconds(15);
    expect(find.text('Kolom 2 dari 2, 0 isian'), findsOneWidget);
    // Kolom 2: dua isian benar.
    await typeDigit(tester, sheet.answer(1, 0));
    await typeDigit(tester, sheet.answer(1, 1));
    await app.tickSeconds(15);
    await tester.pumpAndSettle();

    expect(find.text('Hasil tes'), findsOneWidget);
    // Kecepatan (4 + 2) / 2 = 3; ketelitian 5 dari 6 = 83%; selisih 4 - 2.
    expect(find.text('3'), findsWidgets);
    expect(find.text('83%'), findsOneWidget);
    expect(find.textContaining('5 benar dari 6 isian'), findsOneWidget);
    expect(find.textContaining('kolom tersibuk 4 isian, tersepi 2'),
        findsOneWidget);
    expect(find.byType(LineChart), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp('kolom 1 4 isian, kolom 2 2 isian')),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(find.text('Kolom 2'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('4 isian, 1 salah'), findsOneWidget);
    expect(find.text('2 isian, 0 salah'), findsOneWidget);
  });

  testWidgets('waktu habis saat app ditinggal: kolom terlewat dihitung kosong',
      (tester) async {
    final app = await openKrp(tester, columns: 3);
    await tap(tester, button('Mulai kolom 1'));
    await typeDigit(tester, sheet.answer(0, 0));
    await app.tickSeconds(31);
    expect(find.text('Kolom 3 dari 3, 0 isian'), findsOneWidget);
    expect(find.text('00:14'), findsOneWidget);
  });

  testWidgets('Ulangi dengan angka baru memakai seed lain dan kolom sama',
      (tester) async {
    final app = await openKrp(tester);
    await tap(tester, button('Mulai kolom 1'));
    await app.tickSeconds(30);
    await tester.pumpAndSettle();
    await tap(tester, button('Ulangi dengan angka baru'));
    await tester.pumpAndSettle();
    expect(app.location, startsWith('/kraepelin/'));
    expect(app.location, isNot(startsWith('/kraepelin/$seed?')));
    expect(app.location, endsWith('kolom=2&detik=15'));
    expect(find.text('2 kolom, 15 detik per kolom'), findsOneWidget);
  });

  group('keluar', () {
    testWidgets('sebelum mulai: langsung kembali', (tester) async {
      final app = await openKrp(tester);
      await tap(tester, find.byTooltip('Tutup tes Kraepelin'));
      await tester.pumpAndSettle();
      expect(app.location, Routes.psikotes);
    });

    testWidgets('saat berjalan: konfirmasi, lanjut, lalu keluar',
        (tester) async {
      final app = await openKrp(tester);
      await tap(tester, button('Mulai kolom 1'));
      await tap(tester, find.byTooltip('Tutup tes Kraepelin'));
      expect(find.textContaining('tidak disimpan'), findsOneWidget);
      await tap(tester, button('Lanjut mengerjakan'));
      expect(button('1'), findsOneWidget);
      await tap(tester, find.byTooltip('Tutup tes Kraepelin'));
      await tap(tester, button('Keluar dari tes'));
      await tester.pumpAndSettle();
      expect(app.location, Routes.psikotes);
    });
  });

  testWidgets('pengaturan rute di luar batas: kondisi kosong, tanpa crash',
      (tester) async {
    await openKrp(tester, columns: 500, seconds: 3);
    expect(find.text('Pengaturan tes tidak sah'), findsOneWidget);
    expect(button('Kembali ke katalog'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('katalog: QA memakai subtes Kraepelin profil (10 kolom, 60 dtk)',
      (tester) async {
    final app = await pumpApp(
      tester,
      // QA, CCAT-style: Kraepelin menyala dengan angka awal 10 kolom, 10
      // menit (A104).
      profiles: FakeProfileRepository([activeProfile(role: ProfileRole.qa)]),
    );
    await app.go(Routes.psikotes);
    await tester.ensureVisible(find.text('Kraepelin / Pauli'));
    await tester.tap(find.text('Kraepelin / Pauli'));
    await tester.pumpAndSettle();
    expect(app.location, endsWith('kolom=10&detik=60'));
    expect(find.text('10 kolom, 60 detik per kolom'), findsOneWidget);
  });

  group('keterbacaan', () {
    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets(
          'pengantar, tes, dan hasil di 360 dp, teks '
          '${(scale * 100).round()}%', (tester) async {
        final app = await openKrp(tester, textScale: scale);
        expect(tester.takeException(), isNull);
        expectNoMidWordBreaks(tester, reason: 'pengantar');
        await tap(tester, button('Mulai kolom 1'));
        expect(tester.takeException(), isNull);
        expectNoMidWordBreaks(tester, reason: 'tes');
        await typeDigit(tester, 5);
        await app.tickSeconds(30);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expectNoMidWordBreaks(tester, reason: 'hasil');
      });
    }

    testWidgets('tombol angka dan tutup minimal 48 dp, tutup berlabel',
        (tester) async {
      await openKrp(tester);
      await tap(tester, button('Mulai kolom 1'));
      expectTouchTargets48(tester);
      for (var d = 0; d <= 9; d++) {
        expect(tester.getSize(button('$d')).height, greaterThanOrEqualTo(48));
      }
      expect(find.byTooltip('Tutup tes Kraepelin'), findsOneWidget);
    });
  });

  test('oneDecimal: satu angka di belakang koma', () {
    expect(oneDecimal(Fraction(25, 2)), '12,5');
    expect(oneDecimal(Fraction(3)), '3');
    expect(oneDecimal(Fraction(2, 3)), '0,7');
  });
}
