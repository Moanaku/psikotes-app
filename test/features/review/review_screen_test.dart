import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:question_engine/question_engine.dart';
import 'package:simulator_psikotes_it/core/theme/app_tokens.dart';
import 'package:simulator_psikotes_it/core/widgets/figure_view.dart';
import 'package:simulator_psikotes_it/core/widgets/list_row.dart';
import 'package:simulator_psikotes_it/core/widgets/skeleton_list.dart';
import 'package:simulator_psikotes_it/domain/models/codes.dart';
import 'package:simulator_psikotes_it/domain/models/question_guides.dart';
import 'package:simulator_psikotes_it/domain/models/session.dart';
import 'package:simulator_psikotes_it/domain/providers.dart';
import 'package:simulator_psikotes_it/features/review/review_screen.dart';

import '../../core/golden_helper.dart' show expectTouchTargets48;
import '../../support/fake_repositories.dart';
import '../../support/fixtures.dart';
import '../../support/pump_app.dart';
import 'review_test_support.dart';

const mixed = [
  Outcome.benarCepat,
  Outcome.salahCepat,
  Outcome.benarLambat,
  Outcome.dilewati,
];

Future<AppHarness> openReview(
  WidgetTester tester,
  FakeSessionRepository sessions,
  int id,
  int n, {
  FakeMistakeRepository? mistakes,
  FakeProfileRepository? profiles,
  double textScale = 1,
  List<Override> overrides = const [],
}) async {
  final app = await pumpApp(
    tester,
    profiles: profiles ?? FakeProfileRepository([activeProfile()]),
    sessions: sessions,
    mistakes: mistakes,
    textScale: textScale,
    overrides: overrides,
  );
  await app.go('/hasil/$id/soal/$n');
  return app;
}

Question questionOf(SessionPlan plan, int i) =>
    buildFromRegistry(plan.items[i]);

void main() {
  late FakeSessionRepository sessions;
  late int id;

  setUp(() async {
    sessions = FakeSessionRepository();
    id = await seedFinished(sessions, mixed);
  });

  group('tampilan soal salah', () {
    testWidgets('jenis soal, stem, blok, penjelasan, trik, dan waktu',
        (tester) async {
      final plan = sessions.sessions[id]!.plan;
      await openReview(tester, sessions, id, 2);
      final q = questionOf(plan, 1);

      expect(find.text('Pembahasan'), findsOneWidget);
      expect(find.text('Soal 2 dari 4'), findsOneWidget);
      expect(find.text('Numerik, hitungan cepat'), findsOneWidget);
      expect(find.text(q.stem.text!), findsOneWidget);
      expect(find.text('Salah'), findsOneWidget);
      expect(find.text('Jawabanmu'), findsOneWidget);
      expect(find.text('Kunci'), findsOneWidget);
      expect(find.text('Jawaban benar'), findsOneWidget);
      expect(find.text('A. ${q.options[0].content.text}'), findsWidgets);
      expect(find.text('Kenapa'), findsOneWidget);
      expect(find.text(q.explanation), findsOneWidget);
      expect(find.text('Pola dan trik'), findsOneWidget);
      expect(find.text(questionTypeTrick(QuestionType.numAri)), findsOneWidget);
      expect(find.textContaining('Waktumu 5 dtk, target'), findsOneWidget);
      expect(find.text('Salah, cepat'), findsOneWidget);
    });

    testWidgets('soal benar: blok Benar dengan waktu dan label',
        (tester) async {
      await openReview(tester, sessions, id, 1);
      expect(find.text('Benar'), findsOneWidget);
      expect(find.text('Benar, cepat'), findsOneWidget);
      expect(find.textContaining('Waktumu 30 dtk'), findsOneWidget);
    });

    testWidgets('soal dilewati: tanpa jawaban dan menyebut target',
        (tester) async {
      await openReview(tester, sessions, id, 4);
      expect(find.text('Tidak dijawab'), findsOneWidget,
          reason: 'judul blok jawabanmu');
      expect(find.text('Dilewati'), findsNothing);
      expect(find.textContaining('Tidak dijawab, target'), findsOneWidget);
    });

    testWidgets('soal bergambar: opsi dan blok jawaban memakai gambar',
        (tester) async {
      await openReview(tester, sessions, id, 3);
      expect(find.text('Matriks 3x3').evaluate().length, 0);
      expect(find.text('Figural, matriks 3x3'), findsOneWidget);
      expect(find.byType(FigureView), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });

  group('sakelar Masuk buku kesalahan', () {
    testWidgets('soal salah yang sudah punya kartu: Ya; dimatikan menghapus',
        (tester) async {
      final plan = sessions.sessions[id]!.plan;
      final mistakes = FakeMistakeRepository();
      await mistakes.upsertFromAnswer(sessions.answersOf(id)[1]!, appNow);
      await openReview(tester, sessions, id, 2, mistakes: mistakes);
      expect(plan.items.length, 4);
      expect(find.text('Ya'), findsOneWidget);
      expect(mistakes.cards.length, 1);

      await tester.ensureVisible(find.text('Masuk buku kesalahan'));
      await tester.tap(find.text('Masuk buku kesalahan'));
      await tester.pumpAndSettle();
      expect(find.text('Tidak'), findsOneWidget);
      expect(mistakes.cards, isEmpty);
    });

    testWidgets(
        'soal benar: Tidak; dinyalakan membuat kartu jatuh tempo '
        'besok', (tester) async {
      final mistakes = FakeMistakeRepository();
      await openReview(tester, sessions, id, 1, mistakes: mistakes);
      expect(find.text('Tidak'), findsOneWidget);
      await tester.ensureVisible(find.text('Masuk buku kesalahan'));
      await tester.tap(find.text('Masuk buku kesalahan'));
      await tester.pumpAndSettle();
      expect(find.text('Ya'), findsOneWidget);
      expect(mistakes.cards.length, 1);
      final card = mistakes.cards.single;
      expect(card.tipe, 'NUM-ARI');
      expect(card.status, CardStatus.aktif);
      expect(card.jatuhTempo, appNow.add(const Duration(days: 1)));
    });

    testWidgets('gagal menulis: pesan, keadaan tidak berubah, tanpa exception',
        (tester) async {
      final mistakes = FakeMistakeRepository();
      await openReview(tester, sessions, id, 1, mistakes: mistakes);
      mistakes.failWritesWith = StateError('disk penuh: SQLITE_FULL');
      await tester.ensureVisible(find.text('Masuk buku kesalahan'));
      await tester.tap(find.text('Masuk buku kesalahan'));
      await tester.pumpAndSettle();
      expect(
          find.textContaining('Buku kesalahan belum berubah'), findsOneWidget);
      expect(find.textContaining('SQLITE'), findsNothing);
      expect(find.text('Tidak'), findsOneWidget);
    });

    testWidgets('semantik: sakelar berstatus dan berlabel', (tester) async {
      final handle = tester.ensureSemantics();
      await openReview(tester, sessions, id, 1);
      expect(
          find.bySemanticsLabel('Masuk buku kesalahan, tidak'), findsOneWidget);
      expect(tester.widget<ListRow>(find.byType(ListRow)).onTap, isNotNull);
      handle.dispose();
    });
  });

  group('navigasi antar soal', () {
    testWidgets('Berikutnya dan Sebelumnya; batas di ujung', (tester) async {
      final app = await openReview(tester, sessions, id, 1);
      expect(find.widgetWithText(Widget, 'Sebelumnya'), findsNothing);
      await tester.tap(find.text('Berikutnya'));
      await tester.pumpAndSettle();
      expect(app.location, '/hasil/$id/soal/2');
      expect(find.text('Soal 2 dari 4'), findsOneWidget);
      await tester.tap(find.text('Sebelumnya'));
      await tester.pumpAndSettle();
      expect(app.location, '/hasil/$id/soal/1');
    });

    testWidgets('strip nomor: ketuk membuka soal itu', (tester) async {
      final app = await openReview(tester, sessions, id, 1);
      await tester.tap(find.bySemanticsLabel('Soal 3, benar'));
      await tester.pumpAndSettle();
      expect(app.location, '/hasil/$id/soal/3');
      expect(find.bySemanticsLabel('Soal 2, salah'), findsOneWidget);
    });

    testWidgets('kembali ke hasil', (tester) async {
      final app = await openReview(tester, sessions, id, 2);
      await tester.tap(find.bySemanticsLabel('Kembali'));
      await tester.pumpAndSettle();
      expect(app.location, '/hasil/$id');
    });
  });

  group('kondisi', () {
    testWidgets('soal tidak bisa dibuat ulang: pesan, tanpa crash',
        (tester) async {
      await openReview(
        tester,
        sessions,
        id,
        2,
        overrides: [
          questionBuilderProvider.overrideWithValue(
            (item) => throw QuestionUnavailable(item, 'versi beda'),
          ),
        ],
      );
      expect(
        find.text('Soal ini tidak bisa dibuat ulang. Hasil dan waktumu tetap '
            'tersimpan.'),
        findsOneWidget,
      );
      expect(find.text('Jawabanmu salah.'), findsOneWidget);
      expect(find.text('Masuk buku kesalahan'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('versi generator berbeda diperlakukan sama', (tester) async {
      final repo = FakeSessionRepository();
      const plan = SessionPlan(items: [
        PlanItem(
          type: QuestionType.numSeq,
          seed: 5,
          difficulty: Difficulty.easy,
          genVersi: 999,
          subtes: 'numerik',
        ),
      ]);
      final sid = await seedSession(repo,
          mode: SessionMode.latihan, plan: plan, finished: true);
      await openReview(tester, repo, sid, 1);
      expect(find.textContaining('tidak bisa dibuat ulang'), findsOneWidget);
    });

    testWidgets('nomor di luar rentang: soal tidak ditemukan', (tester) async {
      final app = await openReview(tester, sessions, id, 9);
      expect(find.text('Soal tidak ditemukan'), findsOneWidget);
      await tester.tap(find.text('Kembali ke hasil').last);
      await tester.pumpAndSettle();
      expect(app.location, '/hasil/$id');
    });

    testWidgets('memuat: skeleton', (tester) async {
      final gated = FakeProfileRepository([activeProfile()])
        ..watchGate = Completer<void>();
      await openReview(tester, sessions, id, 2, profiles: gated);
      expect(find.byType(SkeletonList), findsOneWidget);
      gated.watchGate!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Kenapa'), findsOneWidget);
    });

    testWidgets('galat: Coba lagi tanpa teks exception', (tester) async {
      sessions.failByIdWith = StateError('rusak: SQLITE_CORRUPT');
      await openReview(tester, sessions, id, 2);
      expect(find.text('Pembahasan tidak bisa dibuka'), findsOneWidget);
      expect(find.textContaining('SQLITE'), findsNothing);
      sessions.failByIdWith = null;
      await tester.tap(find.text('Coba lagi'));
      await tester.pumpAndSettle();
      expect(find.text('Kenapa'), findsOneWidget);
    });
  });

  group('semua tipe soal punya pembahasan', () {
    for (final type in GeneratorRegistry.types) {
      testWidgets(type.code, (tester) async {
        final repo = FakeSessionRepository();
        final plan = SessionPlan(
          items: [planItem(type, 77, type.category.code)],
        );
        final sid = await seedSession(repo,
            mode: SessionMode.latihan,
            plan: plan,
            finished: true,
            correct: (_) => false);
        await openReview(tester, repo, sid, 1);
        final q = questionOf(plan, 0);
        expect(q.explanation, isNotEmpty);
        expect(find.text(q.explanation), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('keterbacaan', () {
    for (final scale in [1.3, 2.0]) {
      for (final n in [2, 3]) {
        testWidgets('soal $n di 360 dp, teks ${(scale * 100).round()}%',
            (tester) async {
          await openReview(tester, sessions, id, n, textScale: scale);
          await tester.drag(
              find.byType(SingleChildScrollView), const Offset(0, -4000));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        });
      }
    }

    testWidgets('penjelasan terpanjang (silogisme) tampil penuh',
        (tester) async {
      final repo = FakeSessionRepository();
      final plan =
          SessionPlan(items: [planItem(QuestionType.logSyl, 20, 'logika')]);
      final sid = await seedSession(repo,
          mode: SessionMode.latihan,
          plan: plan,
          finished: true,
          correct: (_) => false);
      await openReview(tester, repo, sid, 1, textScale: 1.3);
      expect(find.text(questionOf(plan, 0).explanation), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('target sentuh minimal 48 dp', (tester) async {
      await openReview(tester, sessions, id, 2);
      expectTouchTargets48(tester);
    });

    testWidgets('tema gelap memakai token gelap', (tester) async {
      await pumpScreen(
        tester,
        ReviewScreen(sessionId: id, number: 2),
        brightness: Brightness.dark,
        height: 1600,
        overrides: [
          profileRepositoryProvider
              .overrideWithValue(FakeProfileRepository([activeProfile()])),
          sessionRepositoryProvider.overrideWithValue(sessions),
          answerRepositoryProvider.overrideWithValue(sessions),
          captureRepositoryProvider.overrideWithValue(FakeCaptureRepository()),
          mistakeRepositoryProvider.overrideWithValue(FakeMistakeRepository()),
        ],
      );
      expect(tester.takeException(), isNull);
      expect(tester.widget<Text>(find.text('Kenapa')).style?.color,
          AppColors.dark.ink);
    });
  });
}
