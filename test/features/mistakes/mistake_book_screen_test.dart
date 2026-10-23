import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:question_engine/question_engine.dart';
import 'package:simulator_psikotes_it/app/routes.dart';
import 'package:simulator_psikotes_it/core/theme/app_tokens.dart';
import 'package:simulator_psikotes_it/core/widgets/app_button.dart';
import 'package:simulator_psikotes_it/core/widgets/app_chip.dart';
import 'package:simulator_psikotes_it/core/widgets/error_view.dart';
import 'package:simulator_psikotes_it/core/widgets/list_row.dart';
import 'package:simulator_psikotes_it/core/widgets/skeleton_list.dart';
import 'package:simulator_psikotes_it/domain/models/codes.dart';
import 'package:simulator_psikotes_it/domain/models/notebook.dart';
import 'package:simulator_psikotes_it/domain/models/session.dart';
import 'package:simulator_psikotes_it/domain/providers.dart';
import 'package:simulator_psikotes_it/features/mistakes/mistake_book_screen.dart';

import '../../core/screen_contrast_test.dart' show contrast;
import '../../support/fake_repositories.dart';
import '../../support/fixtures.dart';
import '../../support/pump_app.dart';

MistakeCard mc(
  int id, {
  int days = -1,
  String tipe = 'FIG-MTX',
  AnswerSource source = AnswerSource.engine,
  CardStatus status = CardStatus.aktif,
  int streak = 0,
  int interval = 1,
}) =>
    MistakeCard(
      id: id,
      tipe: tipe,
      kategori: source == AnswerSource.capture ? 'lipat kertas' : 'figural',
      seed: source == AnswerSource.engine ? id : null,
      sumber: source,
      refId: source == AnswerSource.engine ? null : id,
      jatuhTempo: appNow.add(Duration(days: days)),
      intervalHari: interval,
      streakBenar: streak,
      status: status,
      dibuat: appNow.subtract(const Duration(days: 9)),
    );

Future<AppHarness> openBook(
  WidgetTester tester,
  List<MistakeCard> cards, {
  FakeMistakeRepository? repo,
  FakeSessionRepository? sessions,
  FakeCaptureRepository? captures,
  double textScale = 1,
  List<Override> overrides = const [],
}) async {
  final app = await pumpApp(
    tester,
    profiles: FakeProfileRepository([activeProfile()]),
    mistakes: repo ?? FakeMistakeRepository(cards),
    sessions: sessions,
    captures: captures,
    textScale: textScale,
    overrides: overrides,
  );
  await app.go(Routes.bukuKesalahan);
  return app;
}

void main() {
  group('tampilan normal', () {
    testWidgets('dua angka, tombol ulangi, filter, dan baris kartu',
        (tester) async {
      await openBook(tester, [
        mc(1, days: -2),
        mc(2, days: 0, tipe: 'NUM-SEQ'),
        mc(3, days: 1, streak: 1, interval: 3),
        mc(4, days: 3, streak: 2, interval: 7, tipe: 'LOG-SYL'),
        mc(5,
            status: CardStatus.dikuasai,
            streak: 3,
            interval: 0,
            days: -20,
            tipe: 'NUM-ARI'),
      ]);
      expect(find.text('Buku kesalahan'), findsOneWidget);
      expect(find.text('2'), findsOneWidget, reason: 'jatuh tempo hari ini');
      expect(find.text('jatuh tempo hari ini'), findsOneWidget);
      expect(find.text('1'), findsOneWidget, reason: 'dikuasai');
      expect(find.text('sudah dikuasai'), findsOneWidget);
      expect(find.text('Ulangi yang jatuh tempo'), findsOneWidget);
      for (final f in ['Semua', 'Psikotes', 'Capture', 'Wawancara']) {
        expect(find.widgetWithText(AppChip, f), findsOneWidget, reason: f);
      }
      // Kartu dikuasai yang sudah lulus tidak ada di daftar.
      expect(find.byType(ListRow), findsNWidgets(4));
      expect(find.text('Hari ini'), findsNWidgets(2));
      expect(find.text('Besok'), findsOneWidget);
      expect(find.text('3 hari lagi'), findsOneWidget);
      expect(find.text('Matriks 3x3'), findsWidgets);
      // Baris dibaca pembaca layar sebagai satu kalimat utuh.
      final labels = [
        for (final row in find.byType(ListRow).evaluate())
          tester.getSemantics(find.byElementPredicate((e) => e == row)).label,
      ];
      expect(labels.where((l) => l.contains('Dikuasai 0 dari 3 kali')),
          hasLength(2));
      expect(labels.where((l) => l.contains('Dikuasai 1 dari 3 kali')),
          hasLength(1));
      expect(labels.where((l) => l.contains('Dikuasai 2 dari 3 kali')),
          hasLength(1));
      expect(labels.first, contains('Hari ini'));
    });

    testWidgets('kartu dikuasai menunggu pemeriksaan ulang tampil di daftar',
        (tester) async {
      await openBook(tester, [
        mc(1,
            status: CardStatus.dikuasai,
            streak: 3,
            interval: 14,
            days: -1,
            tipe: 'NUM-SEQ'),
      ]);
      expect(find.text('Psikotes, pemeriksaan ulang'), findsOneWidget);
      expect(find.text('Hari ini'), findsOneWidget);
      expect(
        tester.getSemantics(find.byType(ListRow)).label,
        contains('Dikuasai 3 dari 3 kali'),
      );
    });

    testWidgets('tombol kembali menuju beranda saat tak ada riwayat',
        (tester) async {
      final app = await openBook(tester, [mc(1)]);
      await tester.tap(find.bySemanticsLabel('Kembali'));
      await tester.pumpAndSettle();
      expect(app.location, '/');
    });
  });

  group('kondisi', () {
    testWidgets('kosong pertama kali: teks spek dan tombol Mulai latihan',
        (tester) async {
      final app = await openBook(tester, const []);
      expect(find.text('Buku kesalahan masih kosong'), findsOneWidget);
      expect(
        find.text('Soal yang salah akan masuk ke sini dan muncul lagi '
            'beberapa hari kemudian.'),
        findsOneWidget,
      );
      expect(find.text('Ulangi yang jatuh tempo'), findsNothing);
      await tester.tap(find.text('Mulai latihan'));
      await tester.pumpAndSettle();
      expect(app.location, Routes.psikotes);
    });

    testWidgets('filter kosong dibedakan dari kosong pertama kali',
        (tester) async {
      await openBook(tester, [mc(1), mc(2, days: 2)]);
      await tester.tap(find.widgetWithText(AppChip, 'Capture'));
      await tester.pumpAndSettle();
      expect(find.text('Tidak ada kartu Capture yang jatuh tempo.'),
          findsOneWidget);
      expect(find.text('Buku kesalahan masih kosong'), findsNothing);
      expect(find.byType(ListRow), findsNothing);
      expect(find.text('1'), findsOneWidget,
          reason: 'angka atas tidak ikut filter');

      await tester.tap(find.text('Tampilkan semua'));
      await tester.pumpAndSettle();
      expect(find.byType(ListRow), findsNWidgets(2));
    });

    testWidgets('filter Capture dan Psikotes menyaring baris', (tester) async {
      await openBook(tester, [
        mc(1),
        mc(2, source: AnswerSource.capture, tipe: 'lipat-kertas'),
      ]);
      expect(find.byType(ListRow), findsNWidgets(2));
      await tester.tap(find.widgetWithText(AppChip, 'Capture'));
      await tester.pumpAndSettle();
      expect(find.byType(ListRow), findsOneWidget);
      expect(find.text('lipat kertas'), findsOneWidget);
      await tester.tap(find.widgetWithText(AppChip, 'Psikotes'));
      await tester.pumpAndSettle();
      expect(find.byType(ListRow), findsOneWidget);
      expect(find.text('Matriks 3x3'), findsOneWidget);
    });

    testWidgets('semua sudah dikerjakan hari ini: tanggal kartu berikutnya',
        (tester) async {
      await openBook(tester, [mc(1, days: 3), mc(2, days: 5)]);
      expect(find.text('Tidak ada kartu jatuh tempo hari ini'), findsOneWidget);
      expect(find.text('Kartu berikutnya muncul 25 Oktober.'), findsOneWidget);
      expect(find.text('Ulangi yang jatuh tempo'), findsNothing);
      expect(find.byType(ListRow), findsNWidgets(2),
          reason: 'daftar tetap tampil');
    });

    testWidgets('semua kartu dikuasai: tanpa tanggal berikutnya',
        (tester) async {
      await openBook(tester, [
        mc(1, status: CardStatus.dikuasai, streak: 3, interval: 0, days: -30),
      ]);
      expect(find.text('Tidak ada kartu jatuh tempo hari ini'), findsOneWidget);
      expect(find.textContaining('Semua kartu sudah dikuasai'), findsOneWidget);
      expect(find.byType(ListRow), findsNothing);
    });

    testWidgets('memuat: skeleton berbentuk baris, bukan spinner',
        (tester) async {
      final repo = FakeMistakeRepository([mc(1)])..gate = Completer<void>();
      await openBook(tester, const [], repo: repo);
      expect(find.byType(SkeletonList), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      repo.gate!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(SkeletonList), findsNothing);
      expect(find.byType(ListRow), findsOneWidget);
    });

    testWidgets('galat: sebab, tanpa teks exception, dan Coba lagi pulih',
        (tester) async {
      final repo = FakeMistakeRepository([mc(1)])
        ..failWith = StateError('SQLITE_CORRUPT: tabel mistake_card');
      await openBook(tester, const [], repo: repo);
      expect(find.byType(ErrorView), findsOneWidget);
      expect(find.text('Buku kesalahan tidak bisa dibuka'), findsOneWidget);
      expect(find.textContaining('SQLITE'), findsNothing);
      expect(find.textContaining('StateError'), findsNothing);

      repo.failWith = null;
      await tester.tap(find.text('Coba lagi'));
      await tester.pumpAndSettle();
      expect(find.byType(ErrorView), findsNothing);
      expect(find.byType(ListRow), findsOneWidget);
    });
  });

  group('ulangi yang jatuh tempo', () {
    testWidgets('membuka sesi latihan: tipe sama, seed baru, terhubung kartu',
        (tester) async {
      final sessions = FakeSessionRepository();
      final app = await openBook(
        tester,
        [mc(1, days: -2), mc(2), mc(3, days: 4)],
        sessions: sessions,
      );
      await tester.tap(find.text('Ulangi yang jatuh tempo'));
      await tester.pumpAndSettle();

      expect(app.location, '/sesi/1');
      final session = sessions.sessions[1]!;
      expect(session.mode, SessionMode.latihan);
      final items = session.plan.items;
      expect(items.map((i) => i.cardId), [1, 2], reason: 'kartu 3 belum due');
      expect(items.map((i) => i.tipeCode), ['FIG-MTX', 'FIG-MTX']);
      expect(items[0].seed, isNot(1));
      expect(items[1].seed, isNot(2));
      expect(session.plan.subtes, isEmpty, reason: 'latihan tanpa timer');
    });

    testWidgets('selesai benar menjadwal ulang kartu lewat SM-2',
        (tester) async {
      final repo = FakeMistakeRepository([mc(1)]);
      final app = await openBook(tester, const [], repo: repo);
      await tester.tap(find.text('Ulangi yang jatuh tempo'));
      await tester.pumpAndSettle();

      final id = app.sessionState!.sessionId;
      expect(id, 1);
      await app.session.select(app.sessionState!.question!.correctIndex);
      await app.session.submit();
      await app.session.next();
      await tester.pumpAndSettle();

      expect(repo.reviews, [(1, true)]);
      final card = repo.cards.single;
      expect((card.streakBenar, card.intervalHari), (1, 3));
      expect(repo.cards, hasLength(1), reason: 'seed baru bukan kartu baru');
    });

    testWidgets('kartu Capture jatuh tempo: sesi dengan butir yang sama',
        (tester) async {
      final sessions = FakeSessionRepository();
      final app = await openBook(
        tester,
        [mc(1, source: AnswerSource.capture, tipe: PlanItem.captureTipe)],
        sessions: sessions,
        captures: FakeCaptureRepository([captured(1)]),
      );
      await tester.tap(find.text('Ulangi yang jatuh tempo'));
      await tester.pumpAndSettle();
      expect(app.location, startsWith('/sesi/'));
      final item = sessions.sessions.values.single.plan.items.single;
      expect(item.isCapture, isTrue);
      expect(item.refId, 1);
      expect(item.cardId, 1);
      expect(find.text('Soal 1'), findsOneWidget,
          reason: 'soal Capture tampil di layar sesi');
    });

    testWidgets('hanya kartu bank yang jatuh tempo: pesan, bukan sesi',
        (tester) async {
      final sessions = FakeSessionRepository();
      final app = await openBook(
        tester,
        [mc(1, source: AnswerSource.bank, tipe: 'VRB-SYN')],
        sessions: sessions,
      );
      await tester.tap(find.text('Ulangi yang jatuh tempo'));
      await tester.pumpAndSettle();
      expect(app.location, Routes.bukuKesalahan);
      expect(sessions.sessions, isEmpty);
      expect(find.textContaining('belum bisa diulang di sini'), findsOneWidget);
    });

    testWidgets('gagal menulis sesi: pesan tanpa exception, bisa dicoba lagi',
        (tester) async {
      final sessions = FakeSessionRepository()
        ..failStartWith = StateError('disk penuh');
      final app = await openBook(tester, [mc(1)], sessions: sessions);
      await tester.tap(find.text('Ulangi yang jatuh tempo'));
      await tester.pumpAndSettle();
      expect(app.location, Routes.bukuKesalahan);
      expect(find.textContaining('Ulangan belum dimulai'), findsOneWidget);
      expect(find.textContaining('disk penuh'), findsNothing);

      sessions.failStartWith = null;
      await tester.tap(find.text('Ulangi yang jatuh tempo'));
      await tester.pumpAndSettle();
      expect(app.location, '/sesi/1');
    });
  });

  group('pembahasan kartu', () {
    testWidgets('baris kartu membuka soal asal, kunci, dan jadwal',
        (tester) async {
      final app =
          await openBook(tester, [mc(1, days: 0, streak: 1, interval: 3)]);
      await tester.tap(find.byType(ListRow).first);
      await tester.pumpAndSettle();
      expect(app.location, '/buku-kesalahan/1');
      expect(find.text('Kartu kesalahan'), findsOneWidget);
      expect(find.text('Kunci'), findsOneWidget);
      expect(find.text('Kenapa'), findsOneWidget);
      expect(find.text('Pola dan trik'), findsOneWidget);
      expect(
          find.textContaining('Dikuasai 1 dari 3 kali. Muncul lagi hari ini.'),
          findsOneWidget);

      await tester.tap(find.text('Kembali ke buku kesalahan'));
      await tester.pumpAndSettle();
      expect(app.location, Routes.bukuKesalahan);
    });

    testWidgets('soal asal memakai kesulitan dari jawaban asalnya',
        (tester) async {
      final sessions = FakeSessionRepository();
      final plan = latihanPlan();
      final id = await seedSession(sessions,
          mode: SessionMode.latihan, plan: plan, finished: true);
      final answer = sessions.answersOf(id)[2]!; // FIG-MTX seed 50, easy
      final card = MistakeCard(
        id: 7,
        tipe: answer.tipe,
        kategori: answer.kategori,
        seed: answer.seed,
        sumber: AnswerSource.engine,
        jatuhTempo: appNow,
        intervalHari: 1,
        streakBenar: 0,
        status: CardStatus.aktif,
        dibuat: appNow,
      );
      final built = <PlanItem>[];
      final app = await openBook(
        tester,
        [card],
        sessions: sessions,
        overrides: [
          questionBuilderProvider.overrideWithValue((item) {
            built.add(item);
            return buildFromRegistry(item);
          }),
        ],
      );
      await app.go(Routes.kartuKesalahanPath(7));
      expect(find.text('Kunci'), findsOneWidget);
      expect(built, hasLength(1));
      expect(built.single.seed, 50, reason: 'seed asal, bukan seed baru');
      expect(built.single.difficulty, Difficulty.easy);
      expect(built.single.genVersi, answer.genVersi);
    });

    testWidgets('kartu tidak ditemukan', (tester) async {
      final app = await openBook(tester, [mc(1)]);
      await app.go(Routes.kartuKesalahanPath(99));
      expect(find.text('Kartu tidak ditemukan'), findsOneWidget);
      expect(find.text('Kembali ke buku kesalahan'), findsWidgets);
    });

    testWidgets('kartu Capture: soal, kunci, dan pembahasan', (tester) async {
      final app = await openBook(
        tester,
        [mc(1, source: AnswerSource.capture, tipe: PlanItem.captureTipe)],
        captures: FakeCaptureRepository([captured(1)]),
      );
      await app.go(Routes.kartuKesalahanPath(1));
      expect(find.text('Soal 1'), findsOneWidget);
      expect(find.text('Kunci'), findsOneWidget);
      expect(find.textContaining('lipat kertas, capture'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('kartu Capture yang soalnya dihapus: pesan, bukan crash',
        (tester) async {
      final app = await openBook(tester, [
        mc(1, source: AnswerSource.capture, tipe: PlanItem.captureTipe),
      ]);
      await app.go(Routes.kartuKesalahanPath(1));
      expect(find.textContaining('belum bisa dibuka'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('tema gelap', () {
    testWidgets('chip terpilih memakai onAccent agar terbaca di atas accent',
        (tester) async {
      await pumpScreen(
        tester,
        const MistakeBookScreen(),
        brightness: Brightness.dark,
        overrides: [
          profileRepositoryProvider
              .overrideWithValue(FakeProfileRepository([activeProfile()])),
          mistakeRepositoryProvider
              .overrideWithValue(FakeMistakeRepository([mc(1)])),
        ],
      );
      final text = tester.widget<Text>(
        find.descendant(
          of: find.widgetWithText(AppChip, 'Semua'),
          matching: find.text('Semua'),
        ),
      );
      expect(text.style!.color, AppColors.dark.onAccent);
      expect(contrast(AppColors.dark.onAccent, AppColors.dark.accent),
          greaterThanOrEqualTo(4.5));
    });
  });

  group('aksesibilitas dan teks panjang', () {
    testWidgets('target sentuh: tombol, chip, dan baris minimal 48 dp',
        (tester) async {
      await openBook(tester, [mc(1), mc(2, days: 2)]);
      expect(
        tester
            .getSize(find.widgetWithText(AppButton, 'Ulangi yang jatuh tempo'))
            .height,
        greaterThanOrEqualTo(48),
      );
      for (final chip in tester.widgetList<AppChip>(find.byType(AppChip))) {
        final size = tester.getSize(find.byWidget(chip));
        expect(size.height, greaterThanOrEqualTo(48), reason: chip.label);
      }
      for (final row in tester.widgetList<ListRow>(find.byType(ListRow))) {
        expect(tester.getSize(find.byWidget(row)).height,
            greaterThanOrEqualTo(56));
      }
      expect(find.bySemanticsLabel('Kembali'), findsOneWidget);
    });

    for (final scale in [1.3, 2.0]) {
      testWidgets('teks Indonesia terpanjang di 360 dp, skala $scale',
          (tester) async {
        await openBook(
          tester,
          [
            mc(1,
                tipe: 'tipe-buatan-pengguna-dengan-nama-sangat-panjang-sekali'),
            mc(2, days: 3, source: AnswerSource.capture, tipe: 'lipat-kertas'),
          ],
          textScale: scale,
        );
        expect(tester.takeException(), isNull);
        expect(find.text('Ulangi yang jatuh tempo'), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text('3 hari lagi'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(tester.takeException(), isNull);
      });
    }
  });
}
