import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simulator_psikotes_it/app/routes.dart';
import 'package:simulator_psikotes_it/core/widgets/app_button.dart';
import 'package:simulator_psikotes_it/core/widgets/app_chip.dart';
import 'package:simulator_psikotes_it/core/widgets/app_top_bar.dart';
import 'package:simulator_psikotes_it/core/widgets/error_view.dart';
import 'package:simulator_psikotes_it/core/widgets/list_row.dart';
import 'package:simulator_psikotes_it/core/widgets/score_bar.dart';
import 'package:simulator_psikotes_it/core/widgets/skeleton_list.dart';
import 'package:simulator_psikotes_it/domain/models/codes.dart';
import 'package:simulator_psikotes_it/domain/models/knowledge.dart';
import 'package:simulator_psikotes_it/domain/models/notebook.dart';
import 'package:simulator_psikotes_it/domain/services/knowledge_bank.dart';
import 'package:simulator_psikotes_it/features/knowledge/knowledge_providers.dart';

import '../../core/golden_helper.dart' show expectTouchTargets48;
import '../../support/fake_repositories.dart';
import '../../support/fixtures.dart';
import '../../support/knowledge_fixtures.dart';
import '../../support/pump_app.dart';
import '../../support/text_fit.dart';

Future<AppHarness> openS19(
  WidgetTester tester, {
  KnowledgeBank? bank,
  String? rawBank,
  Future<String> Function(String)? reader,
  FakeKnowledgeRepository? knowledge,
  FakeMistakeRepository? mistakes,
  ProfileRole role = ProfileRole.qa,
  double textScale = 1,
  String path = Routes.pengetahuan,
}) async {
  final text = rawBank ?? bankJson((bank ?? smallBank()).items);
  final app = await pumpApp(
    tester,
    profiles: FakeProfileRepository([activeProfile(role: role)]),
    knowledge: knowledge,
    mistakes: mistakes,
    textScale: textScale,
    overrides: [
      knowledgeAssetReaderProvider
          .overrideWithValue(reader ?? (_) async => text),
    ],
  );
  await app.go(Routes.psikotes);
  unawaited(app.router.push(path));
  await tester.pumpAndSettle();
  return app;
}

Finder button(String label) => find.widgetWithText(AppButton, label);

Future<void> tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.tap(f);
  await tester.pumpAndSettle();
}

AppChip chip(WidgetTester tester, String label) =>
    tester.widget<AppChip>(find.widgetWithText(AppChip, label));

Finder level(String name) => find.widgetWithText(ScoreBar, name);

Future<void> startLevel(WidgetTester tester, String name) =>
    tap(tester, level(name));

KnowledgeProgress mastered(String id, {bool ok = true}) => KnowledgeProgress(
      butirId: id,
      level: KnowledgeLevel.fromIdCode(id.split('-')[2])!,
      terakhir: DateTime.utc(2026, 10, 1),
      dikuasai: ok,
    );

void main() {
  group('S19 bank pengetahuan role', () {
    testWidgets('role profil terpilih, topik, tiga level, dan tombol sesi',
        (tester) async {
      final app = await openS19(tester);
      expect(app.location, '/pengetahuan');
      expect(find.text('Pengetahuan role'), findsOneWidget);
      expect(chip(tester, 'QA').selected, isTrue);
      expect(chip(tester, 'Umum').selected, isFalse);
      expect(find.textContaining('seputar QA'), findsOneWidget);
      expect(chip(tester, 'Semua topik').selected, isTrue);
      for (final t in [
        'Siklus bug',
        'Test case',
        'Strategi tes',
        'Flaky test'
      ]) {
        expect(find.widgetWithText(AppChip, t), findsOneWidget, reason: t);
      }
      final bars = tester.widgetList<ScoreBar>(find.byType(ScoreBar)).toList();
      expect([for (final b in bars) b.label], ['Dasar', 'Menengah', 'Lanjut']);
      expect([for (final b in bars) b.valueLabel],
          ['0 dari 3', '0 dari 0', '0 dari 3']);
      expect(button('Latihan 10 kartu'), findsOneWidget);
    });

    testWidgets('bottom nav tetap tampil dan tab Psikotes aktif',
        (tester) async {
      await openS19(tester);
      expect(find.text('Beranda'), findsOneWidget);
      expect(find.text('Psikotes'), findsWidgets);
    });

    testWidgets('role profil lain dipetakan; role lainnya memakai Umum',
        (tester) async {
      await openS19(tester, role: ProfileRole.mobile);
      expect(chip(tester, 'Mobile Dev').selected, isTrue);
      await openS19(tester, role: ProfileRole.lainnya);
      expect(chip(tester, 'Umum').selected, isTrue);
    });

    testWidgets('ganti role mengganti topik dan hitungan; topik direset',
        (tester) async {
      await openS19(tester);
      await tap(tester, find.widgetWithText(AppChip, 'Test case'));
      expect(chip(tester, 'Test case').selected, isTrue);
      expect(tester.widget<ScoreBar>(level('Dasar')).valueLabel, '0 dari 1');

      await tap(tester, find.widgetWithText(AppChip, 'IT BA'));
      expect(chip(tester, 'Semua topik').selected, isTrue);
      expect(find.widgetWithText(AppChip, 'Test case'), findsNothing);
      expect(find.widgetWithText(AppChip, 'Requirement'), findsOneWidget);
      expect(tester.widget<ScoreBar>(level('Dasar')).valueLabel, '0 dari 2');
    });

    testWidgets('kemajuan: n dari N dikuasai dihitung dari knowledge_progress',
        (tester) async {
      await openS19(
        tester,
        knowledge: FakeKnowledgeRepository({
          'KB-QA-D-001': mastered('KB-QA-D-001'),
          'KB-QA-D-002': mastered('KB-QA-D-002', ok: false),
        }),
      );
      expect(tester.widget<ScoreBar>(level('Dasar')).valueLabel, '1 dari 3');
      expect(
          tester.widget<ScoreBar>(level('Dasar')).value, closeTo(1 / 3, 1e-9));
    });

    testWidgets('level tanpa butir tidak bisa dibuka', (tester) async {
      await openS19(tester);
      await tap(tester, level('Menengah'));
      expect(find.text('Kartu 1 dari 3'), findsNothing);
      expect(find.text('Level'), findsOneWidget);
    });

    testWidgets('memuat bank: skeleton berbentuk daftar', (tester) async {
      final gate = Completer<String>();
      final app = await pumpApp(
        tester,
        profiles: FakeProfileRepository([activeProfile()]),
        overrides: [
          knowledgeAssetReaderProvider.overrideWithValue((_) => gate.future),
        ],
      );
      unawaited(app.router.push(Routes.pengetahuan));
      await tester.pump();
      await tester.pump();
      expect(find.byType(SkeletonList), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(
          find.widgetWithText(AppTopBar, 'Pengetahuan role'), findsOneWidget);
      gate.complete(bankJson(smallBank().items));
      await tester.pumpAndSettle();
      expect(find.byType(SkeletonList), findsNothing);
      expect(button('Latihan 10 kartu'), findsOneWidget);
    });

    testWidgets('berkas rusak: galat dengan Coba lagi, tanpa teks exception',
        (tester) async {
      var broken = true;
      await openS19(tester, reader: (_) async {
        if (broken) return '{rusak';
        return bankJson(smallBank().items);
      });
      expect(find.byType(ErrorView), findsOneWidget);
      expect(find.text('Bank pengetahuan tidak terbaca'), findsOneWidget);
      expect(find.textContaining('FormatException'), findsNothing);
      expect(find.textContaining('KnowledgeBank'), findsNothing);
      expect(button('Latihan 10 kartu'), findsNothing);

      broken = false;
      await tap(tester, find.text('Coba lagi'));
      expect(find.byType(ErrorView), findsNothing);
      expect(button('Latihan 10 kartu'), findsOneWidget);
    });

    testWidgets('berkas tidak bisa dibaca: galat yang sama', (tester) async {
      await openS19(tester, reader: (_) async => throw StateError('hilang'));
      expect(find.text('Bank pengetahuan tidak terbaca'), findsOneWidget);
      expect(find.text('Coba lagi'), findsOneWidget);
    });

    testWidgets('bank belum berisi: kondisi kosong, bukan galat',
        (tester) async {
      await openS19(tester, bank: KnowledgeBank.empty());
      expect(find.text('Belum ada kartu pengetahuan'), findsOneWidget);
      expect(find.byType(ErrorView), findsNothing);
      expect(button('Latihan 10 kartu'), findsNothing);
    });

    testWidgets('kemajuan gagal dibaca: galat, kemajuan tidak hilang',
        (tester) async {
      final knowledge = FakeKnowledgeRepository()
        ..failWatchWith = StateError('io');
      await openS19(tester, knowledge: knowledge);
      expect(find.text('Kemajuanmu tidak terbaca'), findsOneWidget);
      expect(find.textContaining('StateError'), findsNothing);
      knowledge.failWatchWith = null;
      await tap(tester, find.text('Coba lagi'));
      expect(button('Latihan 10 kartu'), findsOneWidget);
    });

    testWidgets('role tanpa butir sama sekali: pesan dan role lain tersedia',
        (tester) async {
      final bank =
          KnowledgeBank.of([kb(KnowledgeRole.qa, KnowledgeLevel.dasar, 1)]);
      await openS19(tester, bank: bank, role: ProfileRole.ba);
      expect(find.text('Belum ada kartu untuk role ini'), findsOneWidget);
      expect(find.byType(ScoreBar), findsNothing);
      await tap(tester, find.widgetWithText(AppChip, 'QA'));
      expect(find.text('Belum ada kartu untuk role ini'), findsNothing);
      expect(button('Latihan 10 kartu'), findsOneWidget);
    });

    testWidgets('tanpa profil aktif tidak ke S19 (router mengalihkan)',
        (tester) async {
      final app = await pumpApp(tester);
      await app.go(Routes.pengetahuan);
      expect(app.location, startsWith('/onboarding'));
    });

    testWidgets('semua dikuasai di Umum: pesan, tidak membuka sesi',
        (tester) async {
      final bank = smallBank();
      await openS19(
        tester,
        knowledge: FakeKnowledgeRepository({
          for (final i in bank.of(KnowledgeRole.umum, KnowledgeLevel.dasar))
            i.id: mastered(i.id),
        }),
        path: Routes.pengetahuanPath(role: 'umum'),
      );
      expect(tester.widget<ScoreBar>(level('Dasar')).valueLabel, '9 dari 9');
      await tap(tester, level('Dasar'));
      expect(find.text('Semua kartu level Dasar sudah kamu kuasai.'),
          findsOneWidget);
      expect(find.textContaining('Kartu 1 dari'), findsNothing);
    });

    testWidgets('Latihan 10 kartu membuka level pertama yang belum selesai',
        (tester) async {
      final bank = smallBank();
      final app = await openS19(
        tester,
        knowledge: FakeKnowledgeRepository({
          for (final i in bank.of(KnowledgeRole.qa, KnowledgeLevel.dasar))
            i.id: mastered(i.id),
        }),
      );
      await tap(tester, button('Latihan 10 kartu'));
      expect(app.location, startsWith('/pengetahuan/sesi/'));
      expect(find.text('QA, level Lanjut'), findsOneWidget);
    });

    testWidgets('kartu jatuh tempo didahulukan di sesi', (tester) async {
      final mistakes = FakeMistakeRepository([
        MistakeCard(
          id: 5,
          tipe: 'KB-QA-D',
          kategori: 'pengetahuan',
          sumber: AnswerSource.pengetahuan,
          refId: 3,
          jatuhTempo: DateTime.utc(2026, 10, 20),
          intervalHari: 1,
          streakBenar: 0,
          status: CardStatus.aktif,
          dibuat: DateTime.utc(2026, 10, 19),
        ),
      ]);
      await openS19(tester, mistakes: mistakes);
      await startLevel(tester, 'Dasar');
      expect(find.text('Pertanyaan QA Dasar nomor 3?'), findsOneWidget);
    });

    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets('skala $scale: tanpa meluap, kata utuh, sentuh 48 dp',
          (tester) async {
        await openS19(tester, textScale: scale);
        expect(tester.takeException(), isNull);
        expectNoMidWordBreaks(tester);
        await tester.drag(
            find.byType(SingleChildScrollView), const Offset(0, -2000));
        await tester.pump();
        expect(tester.takeException(), isNull);
        expectNoMidWordBreaks(tester);
        expectTouchTargets48(tester);
      });
    }
  });

  group('S20 sesi kartu', () {
    Future<AppHarness> openCards(
      WidgetTester tester, {
      String levelName = 'Dasar',
      KnowledgeBank? bank,
      FakeKnowledgeRepository? knowledge,
      FakeMistakeRepository? mistakes,
      double textScale = 1,
    }) async {
      final app = await openS19(
        tester,
        bank: bank,
        knowledge: knowledge,
        mistakes: mistakes,
        textScale: textScale,
      );
      await startLevel(tester, levelName);
      return app;
    }

    testWidgets('kartu pertama: pertanyaan, isian, jawaban model tertutup',
        (tester) async {
      await openCards(tester);
      expect(find.text('QA, level Dasar'), findsOneWidget);
      expect(find.text('Kartu 1 dari 3'), findsOneWidget);
      expect(find.text('Pertanyaan QA Dasar nomor 1?'), findsOneWidget);
      expect(find.text('Siklus bug'), findsOneWidget);
      expect(find.text('Perlu verifikasi'), findsOneWidget);
      expect(find.text('Jawabanmu (boleh dikosongkan)'), findsOneWidget);
      expect(find.text('Jawaban model'), findsNothing);
      expect(find.text('Poin kunci'), findsNothing);
      expect(button('Belum paham').evaluate().single.widget, isA<AppButton>());
      expect(tester.widget<AppButton>(button('Belum paham')).onPressed, isNull);
      expect(tester.widget<AppButton>(button('Sudah paham')).onPressed, isNull);
      expect(button('Buka jawaban'), findsOneWidget);
    });

    testWidgets('Buka jawaban: jawaban model, poin kunci, penilaian aktif',
        (tester) async {
      await openCards(tester);
      await tester.enterText(find.byType(TextField), 'jawaban saya');
      await tap(tester, button('Buka jawaban'));
      expect(find.text('Jawaban model'), findsOneWidget);
      expect(find.text('Jawaban model QA Dasar nomor 1.'), findsOneWidget);
      expect(find.text('Poin kunci'), findsOneWidget);
      expect(find.text('Poin dua'), findsOneWidget);
      expect(find.byType(ListRow), findsNothing,
          reason: 'level Dasar: poin kunci hanya dibaca');
      expect(find.text('Belum ada sumber. Periksa sendiri sebelum dipercaya.'),
          findsOneWidget);
      expect(
          tester.widget<AppButton>(button('Belum paham')).onPressed, isNotNull);
      expect(
          tester.widget<AppButton>(button('Sudah paham')).onPressed, isNotNull);
      expect(button('Buka jawaban'), findsNothing);
    });

    testWidgets('butir bersumber menampilkan sumbernya, tanpa tag verifikasi',
        (tester) async {
      await openCards(
        tester,
        bank: KnowledgeBank.of([
          kb(KnowledgeRole.qa, KnowledgeLevel.dasar, 3,
              sumber: 'ISTQB Foundation Syllabus'),
        ]),
      );
      expect(find.text('Perlu verifikasi'), findsNothing);
      await tap(tester, button('Buka jawaban'));
      expect(find.text('Sumber: ISTQB Foundation Syllabus'), findsOneWidget);
    });

    testWidgets('Belum paham: kartu buku kesalahan dibuat, lanjut ke kartu 2',
        (tester) async {
      final knowledge = FakeKnowledgeRepository();
      final app = await openCards(tester, knowledge: knowledge);
      await tap(tester, button('Buka jawaban'));
      await tap(tester, button('Belum paham'));
      expect(find.text('Kartu 2 dari 3'), findsOneWidget);
      expect(find.text('Jawaban model'), findsNothing,
          reason: 'kartu baru mulai tertutup');
      final card = app.mistakes.cards.single;
      expect(card.sumber, AnswerSource.pengetahuan);
      expect(card.tipe, 'KB-QA-D');
      expect(card.refId, 1);
      expect(knowledge.data['KB-QA-D-001']!.dikuasai, isFalse);
    });

    testWidgets('Sudah paham: kemajuan tersimpan, tanpa kartu baru',
        (tester) async {
      final knowledge = FakeKnowledgeRepository();
      final app = await openCards(tester, knowledge: knowledge);
      await tap(tester, button('Buka jawaban'));
      await tap(tester, button('Sudah paham'));
      expect(knowledge.data['KB-QA-D-001']!.dikuasai, isTrue);
      expect(app.mistakes.cards, isEmpty);
    });

    testWidgets('Sudah paham pada butir berkartu = ulangan benar SM-2',
        (tester) async {
      final mistakes = FakeMistakeRepository([
        MistakeCard(
          id: 5,
          tipe: 'KB-QA-D',
          kategori: 'pengetahuan',
          sumber: AnswerSource.pengetahuan,
          refId: 3,
          jatuhTempo: DateTime.utc(2026, 10, 20),
          intervalHari: 1,
          streakBenar: 0,
          status: CardStatus.aktif,
          dibuat: DateTime.utc(2026, 10, 19),
        ),
      ]);
      final app = await openCards(tester, mistakes: mistakes);
      await tap(tester, button('Buka jawaban'));
      await tap(tester, button('Sudah paham'));
      expect(app.mistakes.reviews, [(5, true)]);
      expect(app.mistakes.cards.single.streakBenar, 1);
    });

    testWidgets('level Lanjut: paham hanya bila poin kunci cukup dicentang',
        (tester) async {
      final knowledge = FakeKnowledgeRepository();
      await openCards(tester, levelName: 'Lanjut', knowledge: knowledge);
      expect(find.text('QA, level Lanjut'), findsOneWidget);
      await tap(tester, button('Buka jawaban'));
      expect(find.textContaining('Paling sedikit 2 dari 3'), findsOneWidget);
      expect(find.byType(ListRow), findsNWidgets(3));
      expect(tester.widget<AppButton>(button('Sudah paham')).onPressed, isNull);
      expect(
          tester.widget<AppButton>(button('Belum paham')).onPressed, isNotNull);

      await tap(tester, find.widgetWithText(ListRow, 'Poin satu'));
      expect(tester.widget<AppButton>(button('Sudah paham')).onPressed, isNull,
          reason: '1 dari 3 belum cukup');
      await tap(tester, find.widgetWithText(ListRow, 'Poin dua'));
      expect(
          tester.widget<AppButton>(button('Sudah paham')).onPressed, isNotNull);
      expect(find.text('Ada'), findsNWidgets(2));
      expect(find.text('Belum'), findsOneWidget);

      await tap(tester, find.widgetWithText(ListRow, 'Poin dua'));
      expect(tester.widget<AppButton>(button('Sudah paham')).onPressed, isNull,
          reason: 'centang bisa dibatalkan');

      await tap(tester, find.widgetWithText(ListRow, 'Poin dua'));
      await tap(tester, button('Sudah paham'));
      expect(knowledge.data['KB-QA-L-001']!.dikuasai, isTrue);
      expect(find.text('Kartu 2 dari 3'), findsOneWidget);
      await tap(tester, button('Buka jawaban'));
      expect(find.text('Belum'), findsNWidgets(3),
          reason: 'centang kartu sebelumnya tidak terbawa');
    });

    testWidgets('selesai: ringkasan, lalu kembali ke S19', (tester) async {
      final app = await openCards(tester);
      for (var i = 0; i < 3; i++) {
        await tap(tester, button('Buka jawaban'));
        await tap(tester, button(i == 1 ? 'Belum paham' : 'Sudah paham'));
      }
      expect(find.text('Sesi selesai'), findsOneWidget);
      expect(find.text('3 kartu dinilai.'), findsOneWidget);
      expect(find.text('2 kartu'), findsOneWidget);
      expect(find.text('1 kartu masuk ke buku kesalahan'), findsOneWidget);
      await tap(tester, button('Ke bank pengetahuan'));
      expect(app.location, '/pengetahuan');
      expect(tester.widget<ScoreBar>(level('Dasar')).valueLabel, '2 dari 3');
    });

    testWidgets('semua paham: tidak ada yang masuk buku kesalahan',
        (tester) async {
      await openCards(
        tester,
        bank: KnowledgeBank.of([kb(KnowledgeRole.qa, KnowledgeLevel.dasar, 1)]),
      );
      await tap(tester, button('Buka jawaban'));
      await tap(tester, button('Sudah paham'));
      expect(find.text('Tidak ada'), findsOneWidget);
    });

    testWidgets('gagal menyimpan: pesan tanpa exception, tetap di kartu ini',
        (tester) async {
      final knowledge = FakeKnowledgeRepository()
        ..failSaveWith = StateError('disk penuh');
      await openCards(tester, knowledge: knowledge);
      await tap(tester, button('Buka jawaban'));
      await tap(tester, button('Sudah paham'));
      expect(find.textContaining('Penilaian belum tersimpan'), findsOneWidget);
      expect(find.textContaining('StateError'), findsNothing);
      expect(find.text('Kartu 1 dari 3'), findsOneWidget);

      knowledge.failSaveWith = null;
      await tap(tester, button('Sudah paham'));
      expect(find.text('Kartu 2 dari 3'), findsOneWidget);
      expect(find.textContaining('Penilaian belum tersimpan'), findsNothing);
    });

    testWidgets('tutup sesi di tengah jalan: kemajuan kartu yang dinilai aman',
        (tester) async {
      final knowledge = FakeKnowledgeRepository();
      final app = await openCards(tester, knowledge: knowledge);
      await tap(tester, button('Buka jawaban'));
      await tap(tester, button('Sudah paham'));
      await tap(tester, find.byTooltip('Tutup sesi kartu'));
      expect(app.location, '/pengetahuan');
      expect(knowledge.data.keys, ['KB-QA-D-001']);
    });

    testWidgets('sesi yang tidak ada (app dibuka ulang): kondisi kosong',
        (tester) async {
      final app = await openS19(tester);
      await app.go('/pengetahuan/sesi/99');
      expect(find.text('Sesi kartu tidak ditemukan'), findsOneWidget);
      await tap(tester, button('Ke bank pengetahuan'));
      expect(app.location, '/pengetahuan');
    });

    testWidgets('Umum: kartu lintas role di satu sesi', (tester) async {
      await openS19(tester, path: Routes.pengetahuanPath(role: 'umum'));
      await startLevel(tester, 'Dasar');
      expect(find.text('Umum, level Dasar'), findsOneWidget);
      expect(find.text('Kartu 1 dari 9'), findsOneWidget);
      expect(find.text('Pertanyaan QA Dasar nomor 1?'), findsOneWidget);
    });

    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets('skala $scale: kartu Lanjut terbuka tanpa meluap',
          (tester) async {
        const long = 'Pertanyaan panjang tentang strategi pengujian '
            'perangkat lunak yang harus dijelaskan lengkap dengan contoh '
            'konkret dari proyek nyata?';
        final bank = KnowledgeBank.of([
          const KnowledgeItem(
            id: 'KB-QA-L-001',
            role: KnowledgeRole.qa,
            level: KnowledgeLevel.lanjut,
            topik: 'strategi-tes',
            pertanyaan: long,
            jawabanModel: 'Strategi tes menentukan apa yang diuji, seberapa '
                'dalam, dan dengan cara apa, berdasarkan risiko produk.',
            poinKunci: [
              'Pengujian berbasis risiko menentukan prioritas',
              'Piramida tes menyeimbangkan unit, integrasi, dan UI',
              'Otomasi dipakai untuk regresi yang stabil',
            ],
            needsVerification: true,
          ),
        ]);
        await openCards(tester,
            levelName: 'Lanjut', bank: bank, textScale: scale);
        expect(tester.takeException(), isNull);
        expectNoMidWordBreaks(tester);
        await tap(tester, button('Buka jawaban'));
        expect(tester.takeException(), isNull);
        expectNoMidWordBreaks(tester);
        await tester.drag(
            find.byType(SingleChildScrollView), const Offset(0, -3000));
        await tester.pump();
        expect(tester.takeException(), isNull);
        expectNoMidWordBreaks(tester);
        expectTouchTargets48(tester);
      });
    }
  });
}
