import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simulator_psikotes_it/core/widgets/choice_row.dart';
import 'package:simulator_psikotes_it/domain/models/codes.dart';
import 'package:simulator_psikotes_it/features/onboarding/onboarding_draft.dart';

import '../../support/pump_app.dart';

bool selected(WidgetTester tester, String title) =>
    tester.widget<ChoiceRow>(find.widgetWithText(ChoiceRow, title)).selected;

void main() {
  testWidgets('S01 tampil dengan lima pilihan dan QA terpilih', (tester) async {
    await pumpApp(tester);
    expect(find.text('Langkah 1 dari 3'), findsOneWidget);
    expect(find.text('Kamu melamar sebagai apa?'), findsOneWidget);
    expect(find.byType(ChoiceRow), findsNWidgets(5));
    for (final t in [
      'QA Engineer',
      'Mobile / App Developer',
      'IT Business Analyst',
      'Umum, tanpa role',
      'Lainnya',
    ]) {
      expect(find.text(t), findsOneWidget);
    }
    expect(selected(tester, 'QA Engineer'), isTrue);
    expect(selected(tester, 'Lainnya'), isFalse);
    expect(find.text('Bisa membuat lebih dari satu profil nanti.'),
        findsOneWidget);
  });

  testWidgets('Lanjut aktif sejak awal dan membuka S02', (tester) async {
    final app = await pumpApp(tester);
    await tester.tap(find.text('Lanjut'));
    await tester.pumpAndSettle();
    expect(app.location, '/onboarding/profil');
    expect(find.text('Profil tes target'), findsOneWidget);
    expect(find.text('2 / 3'), findsOneWidget);
  });

  testWidgets('memilih role menggeser pilihan dan menyimpannya di draf',
      (tester) async {
    final app = await pumpApp(tester);
    await tester.tap(find.text('IT Business Analyst'));
    await tester.pumpAndSettle();
    expect(selected(tester, 'IT Business Analyst'), isTrue);
    expect(selected(tester, 'QA Engineer'), isFalse);
    expect(app.container.read(onboardingDraftProvider).role, ProfileRole.ba);
  });

  testWidgets('memilih role mengubah bobot yang tampil di S02', (tester) async {
    await pumpApp(tester);
    // QA, CCAT-style plus Kraepelin (A104): 0,30 / 0,30 / 0,20 x 1,5 /
    // 0,20 / Kraepelin 0,20 (bobot dasar terkecil) x 1,5, dibagi 1,40:
    // verbal, numerik, logika, Kraepelin 21%, figural 14%.
    await tester.tap(find.text('Lanjut'));
    await tester.pumpAndSettle();
    expect(find.text('Bobot 21% di latihan campuran'), findsNWidgets(4));
    expect(find.text('Bobot 14% di latihan campuran'), findsOneWidget);

    await tester.tap(find.byTooltip('Kembali ke pilihan role'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Umum, tanpa role'));
    await tester.tap(find.text('Lanjut'));
    await tester.pumpAndSettle();
    // Umum: bobot dasar CCAT 30/30/20/20.
    expect(find.text('Bobot 30% di latihan campuran'), findsNWidgets(2));
    expect(find.text('Bobot 20% di latihan campuran'), findsNWidgets(2));
    expect(find.text('Bobot 27% di latihan campuran'), findsNothing);
  });

  test('role Mobile Dev menyalakan Modul IT; role lain mematikannya (A101)',
      () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final draft = c.read(onboardingDraftProvider.notifier);
    bool it() => c
        .read(onboardingDraftProvider)
        .subtests
        .firstWhere((s) => s.kategori == 'it')
        .aktif;
    expect(it(), isFalse);
    draft.selectRole(ProfileRole.mobile);
    expect(it(), isTrue);
    // Ganti format tetap mempertahankan subtes khusus role.
    draft.selectFormat(TestFormat.bank);
    expect(it(), isTrue);
    draft.selectRole(ProfileRole.ba);
    expect(it(), isFalse);
    // Subtes lain tidak ikut berubah.
    expect(
      [
        for (final s in c.read(onboardingDraftProvider).subtests)
          if (s.aktif) s.kategori,
      ],
      ['verbal', 'numerik', 'figural', 'kraepelin', 'kepribadian'],
    );
  });

  test('QA menyalakan Kraepelin di CCAT-style; role lain tidak (A104)', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final draft = c.read(onboardingDraftProvider.notifier);
    List<String> active() => [
          for (final s in c.read(onboardingDraftProvider).subtests)
            if (s.aktif) s.kategori,
        ];
    expect(active(), ['verbal', 'numerik', 'logika', 'figural', 'kraepelin']);
    draft.selectRole(ProfileRole.ba);
    expect(active(), ['verbal', 'numerik', 'logika', 'figural']);
    draft.selectRole(ProfileRole.qa);
    expect(active(), ['verbal', 'numerik', 'logika', 'figural', 'kraepelin']);
  });

  testWidgets('pilihan role bertahan saat kembali dari S02', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Mobile / App Developer'));
    await tester.tap(find.text('Lanjut'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Kembali ke pilihan role'));
    await tester.pumpAndSettle();
    expect(selected(tester, 'Mobile / App Developer'), isTrue);
  });

  for (final scale in [1.3, 2.0]) {
    testWidgets('teks terpanjang tidak meluap di skala $scale dan 360 dp',
        (tester) async {
      await pumpApp(tester, textScale: scale);
      expect(tester.takeException(), isNull);
      // Seluruh baris pilihan bisa digulir ke layar dan tiap target >= 48.
      for (final r in tester.widgetList<ChoiceRow>(find.byType(ChoiceRow))) {
        final size = tester.getSize(find.byWidget(r));
        expect(size.height, greaterThanOrEqualTo(48));
        expect(size.width, 360);
      }
      final button = tester.getSize(find.text('Lanjut'));
      expect(button.height, greaterThan(0));
      await tester.drag(
          find.byType(SingleChildScrollView), const Offset(0, -2000));
      await tester.pump();
      expect(find.text('Bisa membuat lebih dari satu profil nanti.'),
          findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('pembaca layar: judul adalah header dan pilihan berstatus',
      (tester) async {
    final handle = tester.ensureSemantics();
    await pumpApp(tester);
    expect(
      tester.getSemantics(find.text('Kamu melamar sebagai apa?')),
      matchesSemantics(
        label: 'Kamu melamar sebagai apa?',
        isHeader: true,
        textDirection: TextDirection.ltr,
      ),
    );
    final qa =
        tester.getSemantics(find.widgetWithText(ChoiceRow, 'QA Engineer'));
    expect(qa.flagsCollection.isChecked, isTrue);
    handle.dispose();
  });
}
