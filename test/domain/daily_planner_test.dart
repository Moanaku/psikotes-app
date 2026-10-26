import 'package:flutter_test/flutter_test.dart';
import 'package:question_engine/question_engine.dart';
import 'package:simulator_psikotes_it/domain/models/codes.dart';
import 'package:simulator_psikotes_it/domain/models/notebook.dart';
import 'package:simulator_psikotes_it/domain/models/session.dart';
import 'package:simulator_psikotes_it/domain/models/session_state.dart';
import 'package:simulator_psikotes_it/domain/services/daily_planner.dart';
import 'package:simulator_psikotes_it/domain/services/default_daily_planner.dart';
import 'package:simulator_psikotes_it/domain/services/practice_history.dart';
import 'package:simulator_psikotes_it/domain/services/seed_allocator.dart';
import 'package:simulator_psikotes_it/domain/services/weakness_model.dart';

import '../support/fake_repositories.dart';
import '../support/fixtures.dart';
import '../support/pump_app.dart' show appNow;

final registered = GeneratorRegistry.types.toSet();

int _seq = 0;

AnswerRecord ans(
  QuestionType type, {
  int? seed,
  bool benar = true,
  int ms = 43000,
  AnswerSource sumber = AnswerSource.engine,
  bool dijawab = true,
}) =>
    AnswerRecord(
      sessionId: 1,
      posisi: _seq,
      tipe: type.code,
      kategori: type.category.code,
      seed: seed ?? 1000 + _seq++,
      kesulitan: Difficulty.medium,
      genVersi: 1,
      sumber: sumber,
      refId: sumber == AnswerSource.engine ? null : 1,
      opsiDipilih: dijawab ? 0 : null,
      benar: benar,
      durasiMs: ms,
      label: benar ? SpeedLabel.benarCepat : SpeedLabel.salahCepat,
    );

MistakeCard dueCard(
  int id,
  QuestionType type, {
  AnswerSource sumber = AnswerSource.engine,
  int daysAgo = 1,
}) =>
    MistakeCard(
      id: id,
      tipe: type.code,
      kategori: type.category.code,
      seed: 500 + id,
      sumber: sumber,
      refId: sumber == AnswerSource.engine ? null : id,
      jatuhTempo: appNow.subtract(Duration(days: daysAgo)),
      intervalHari: 1,
      streakBenar: 0,
      status: CardStatus.aktif,
      dibuat: appNow.subtract(const Duration(days: 5)),
    );

/// Riwayat dengan Matriks 3x3 terlemah, Deret angka kuat, lainnya kosong.
List<AnswerRecord> historyWithWeakMatrix() => [
      for (var i = 0; i < 10; i++) ans(QuestionType.figMtx, benar: i < 2),
      for (var i = 0; i < 10; i++) ans(QuestionType.numSeq),
    ];

DefaultDailyPlanner planner({
  List<AnswerRecord> history = const [],
  List<MistakeCard> due = const [],
  Set<QuestionType>? available,
}) =>
    DefaultDailyPlanner(
      answers: FakeSessionRepository()..history = [...history],
      mistakes: FakeMistakeRepository(due),
      available: available ?? registered,
    );

Map<QuestionType, int> countByType(Iterable<PlanItem> items) {
  final m = <QuestionType, int>{};
  for (final i in items) {
    m[i.type!] = (m[i.type!] ?? 0) + 1;
  }
  return m;
}

int blockCount(DailyPlan p, PlanBlockKind kind) =>
    p.blocks.where((b) => b.kind == kind).fold(0, (a, b) => a + b.count);

void main() {
  group('komposisi 50/30/20', () {
    test('tiap bagian paling jauh satu soal dari angka eksak, jumlahnya N', () {
      for (var n = 5; n <= 60; n++) {
        final c = DefaultDailyPlanner.compose(n, dueAvailable: 1000);
        expect(c.total, n, reason: 'N=$n');
        expect(c.weakest - n * 0.5, inExclusiveRange(-1, 1), reason: 'N=$n');
        expect(c.due - n * 0.3, inExclusiveRange(-1, 1), reason: 'N=$n');
        expect(c.mixed - n * 0.2, inExclusiveRange(-1, 1), reason: 'N=$n');
      }
    });

    test('contoh: 20 soal menjadi 10, 6, 4 dan 15 soal menjadi 8, 4, 3', () {
      var c = DefaultDailyPlanner.compose(20, dueAvailable: 99);
      expect((c.weakest, c.due, c.mixed), (10, 6, 4));
      c = DefaultDailyPlanner.compose(15, dueAvailable: 99);
      expect((c.weakest, c.due, c.mixed), (8, 4, 3));
    });

    test('kartu kurang: sisa jatah kartu diisi dari kelemahan', () {
      final c = DefaultDailyPlanner.compose(20, dueAvailable: 2);
      expect((c.weakest, c.due, c.mixed), (14, 2, 4));
      final none = DefaultDailyPlanner.compose(20, dueAvailable: 0);
      expect((none.weakest, none.due, none.mixed), (16, 0, 4));
    });

    test('rencana nyata: 50% tipe terlemah, 30% kartu, 20% campuran', () async {
      final cards = [
        for (var i = 0; i < 12; i++)
          dueCard(i + 1, i.isEven ? QuestionType.numAri : QuestionType.logSyl),
      ];
      final plan = await planner(history: historyWithWeakMatrix(), due: cards)
          .plan(activeProfile(), appNow);

      // 43 detik per soal dari riwayat: 900 / 43 = 21 soal.
      expect(plan.session.items.length, 21);
      expect(blockCount(plan, PlanBlockKind.weakest), 11);
      expect(blockCount(plan, PlanBlockKind.due), 6);
      expect(blockCount(plan, PlanBlockKind.mixed), 4);
      expect(plan.blocks.map((b) => b.kind), [
        PlanBlockKind.weakest,
        PlanBlockKind.due,
        PlanBlockKind.mixed,
      ]);

      final items = plan.session.items;
      expect(
        items.take(11).every((i) => i.type == QuestionType.figMtx),
        isTrue,
        reason: 'bagian kelemahan: tipe dengan skor kelemahan tertinggi',
      );
      expect(plan.blocks.first.type, QuestionType.figMtx);
      expect(
        items.skip(11).take(6).map((i) => i.type),
        [
          QuestionType.numAri,
          QuestionType.logSyl,
          QuestionType.numAri,
          QuestionType.logSyl,
          QuestionType.numAri,
          QuestionType.logSyl,
        ],
        reason: 'kartu jatuh tempo tertua lebih dulu, tipe sama, seed baru',
      );
      for (var i = 0; i < 6; i++) {
        expect(items[11 + i].seed, isNot(cards[i].seed),
            reason: 'ulangan memakai seed baru');
        expect(items[11 + i].cardId, cards[i].id,
            reason: 'ulangan menjadwal ulang kartunya saat sesi selesai');
      }
      expect(items.take(11).every((i) => i.cardId == null), isTrue);
      expect(items.skip(17).every((i) => i.cardId == null), isTrue);
      expect(items.skip(17).length, 4);
    });

    test('kartu kurang dari jatah: sisanya diisi dari kelemahan', () async {
      final plan = await planner(
        history: historyWithWeakMatrix(),
        due: [dueCard(1, QuestionType.numAri), dueCard(2, QuestionType.logSyl)],
      ).plan(activeProfile(), appNow);
      expect(plan.session.items.length, 21);
      expect(blockCount(plan, PlanBlockKind.due), 2);
      expect(blockCount(plan, PlanBlockKind.mixed), 4);
      expect(blockCount(plan, PlanBlockKind.weakest), 15);
    });

    test('tanpa kartu jatuh tempo: bagian kartu hilang', () async {
      final plan = await planner(history: historyWithWeakMatrix())
          .plan(activeProfile(), appNow);
      expect(plan.blocks.map((b) => b.kind),
          [PlanBlockKind.weakest, PlanBlockKind.mixed]);
      expect(blockCount(plan, PlanBlockKind.weakest), 17);
    });

    test('kartu bank dan tipe tak terdaftar tidak dipakai', () async {
      final plan = await planner(
        history: historyWithWeakMatrix(),
        due: [
          dueCard(2, QuestionType.vrbSyn, sumber: AnswerSource.bank),
          dueCard(3, QuestionType.vrbSyn),
        ],
      ).plan(activeProfile(), appNow);
      expect(blockCount(plan, PlanBlockKind.due), 0);
      expect(plan.session.items.length, 21);
    });

    test('kartu Capture jadi butir yang sama, terhubung ke kartunya', () async {
      final plan = await planner(
        history: historyWithWeakMatrix(),
        due: [
          dueCard(1, QuestionType.numAri, sumber: AnswerSource.capture),
          dueCard(3, QuestionType.numAri),
        ],
      ).plan(activeProfile(), appNow);
      expect(blockCount(plan, PlanBlockKind.due), 2);
      final capture = plan.session.items.firstWhere((i) => i.isCapture);
      expect(capture.refId, 1);
      expect(capture.cardId, 1);
      expect(capture.tipeCode, PlanItem.captureTipe);
      expect(plan.session.items.where((i) => i.cardId == 3), hasLength(1));
    });

    test('tanpa riwayat dan tanpa kartu: seluruhnya campuran sesuai bobot',
        () async {
      final plan = await planner().plan(activeProfile(), appNow);
      expect(plan.session.items.length, 21,
          reason: 'median perkiraan engine 43 detik');
      expect(plan.estimatedMinutes, 15);
      expect(plan.blocks.single.kind, PlanBlockKind.mixed);
      expect(plan.blocks.single.count, 21);
      final byCategory = <String, int>{};
      for (final i in plan.session.items) {
        byCategory[i.subtes] = (byCategory[i.subtes] ?? 0) + 1;
      }
      expect(byCategory.keys.toSet(), {'numerik', 'logika', 'figural'});
      expect(plan.session.subtes, isEmpty);
    });

    test('jumlah soal mengikuti median waktu riwayat', () async {
      final slow = await planner(
        history: [
          for (var i = 0; i < 6; i++) ans(QuestionType.numSeq, ms: 90000)
        ],
      ).plan(activeProfile(), appNow);
      expect(slow.session.items.length, 10, reason: '900 / 90');
      expect(slow.estimatedMinutes, 15);

      final fast = await planner(
        history: [
          for (var i = 0; i < 6; i++) ans(QuestionType.numSeq, ms: 2000)
        ],
      ).plan(activeProfile(), appNow);
      expect(fast.session.items.length, DefaultDailyPlanner.maxQuestions);
    });

    test('tanpa tipe tersedia: rencana kosong tanpa bagian', () async {
      final plan = await planner(available: {}).plan(activeProfile(), appNow);
      expect(plan.session.items, isEmpty);
      expect(plan.blocks, isEmpty);
      expect(plan.estimatedMinutes, 0);
    });
  });

  group('tanggal tes kurang dari 7 hari', () {
    DateTime day(int offset) =>
        DateTime.utc(2026, 10, 22).add(Duration(days: offset));

    Future<DailyPlan> planFor(DateTime? date) => planner(
          history: historyWithWeakMatrix(),
        ).plan(activeProfile(tanggalTes: date), appNow);

    test('3 hari lagi: satu subtes simulasi di akhir rencana', () async {
      final plan = await planFor(day(3));
      expect(plan.blocks.last.kind, PlanBlockKind.simulation);
      expect(plan.blocks.last.kategori, 'figural',
          reason: 'kategori tipe terlemah');
      expect(plan.blocks.last.count, 10,
          reason: 'jumlah soal figural di profil');
      expect(plan.blocks.last.minutes, 3);
      expect(plan.session.items.length, 21 + 10);
      expect(plan.estimatedMinutes, 15 + 3);

      // Rencana sah untuk SessionController: dua subtes, yang terakhir bertimer.
      final ranges = SubtestRange.of(plan.session);
      expect(ranges.length, 2);
      expect(ranges[0].duration, isNull);
      expect(ranges[0].jumlah, 21);
      expect(ranges[1].duration, const Duration(minutes: 3));
      expect(ranges[1].kategori, 'figural');
      for (var i = ranges[1].start; i < ranges[1].end; i++) {
        expect(plan.session.items[i].kategoriCode, 'figural');
      }
    });

    test('batas: hari ini sampai 6 hari lagi memakai simulasi, 7 tidak',
        () async {
      for (final offset in [0, 1, 6]) {
        final plan = await planFor(day(offset));
        expect(plan.blocks.last.kind, PlanBlockKind.simulation,
            reason: '$offset hari');
      }
      for (final offset in [7, 14, -1]) {
        final plan = await planFor(day(offset));
        expect(
          plan.blocks.map((b) => b.kind),
          isNot(contains(PlanBlockKind.simulation)),
          reason: '$offset hari',
        );
      }
      final none = await planFor(null);
      expect(none.blocks.map((b) => b.kind),
          isNot(contains(PlanBlockKind.simulation)));
    });

    test('tanpa riwayat: kategori berbobot terbesar', () async {
      final plan = await planner().plan(
        activeProfile(tanggalTes: day(2)),
        appNow,
      );
      expect(plan.blocks.last.kind, PlanBlockKind.simulation);
      // QA CCAT-style: Numerik dan Logika sama-sama 0,2727 (Verbal 0,2728
      // belum punya soal); imbang jatuh ke urutan blueprint, jadi Numerik.
      expect(plan.blocks.last.kategori, 'numerik');
    });
  });

  group('tanpa pengulangan (tipe, seed) dalam 30 hari', () {
    test('rencana kedua tidak memakai satu pun soal rencana pertama', () async {
      final first = await planner().plan(activeProfile(), appNow);
      final seen = {
        for (final i in first.session.items) SeedAllocator.key(i.type!, i.seed),
      };
      expect(seen.length, first.session.items.length);

      // Semua soal rencana pertama sudah dikerjakan, lalu rencana disusun lagi
      // pada detik yang sama sehingga calon seed-nya persis sama.
      final history = [
        for (final i in first.session.items)
          ans(i.type!, seed: i.seed, benar: i.seed.isEven),
      ];
      final second =
          await planner(history: history).plan(activeProfile(), appNow);
      expect(second.session.items, isNotEmpty);
      for (final i in second.session.items) {
        expect(seen, isNot(contains(SeedAllocator.key(i.type!, i.seed))),
            reason: '${i.tipeCode} seed ${i.seed}');
      }
      final own = {
        for (final i in second.session.items)
          SeedAllocator.key(i.type!, i.seed),
      };
      expect(own.length, second.session.items.length,
          reason: 'tidak kembar di rencana yang sama');
    });

    test('hanya soal engine yang dihitung sebagai sudah muncul', () {
      final history = PracticeHistory([
        ans(QuestionType.numSeq, seed: 5),
        ans(QuestionType.numSeq, seed: 6, sumber: AnswerSource.capture),
        ans(QuestionType.vrbSyn, seed: 7, sumber: AnswerSource.bank),
      ]);
      expect(history.seenKeys, {SeedAllocator.key(QuestionType.numSeq, 5)});
    });
  });

  group('skor kelemahan', () {
    final blueprint = activeProfile().blueprint;
    final types = WeaknessScoring.candidates(blueprint, registered);

    test('w = 1 - (benar + 1) / (jumlah + 2); tanpa data 0,5', () {
      const none = TypeScore(type: QuestionType.numSeq, benar: 0, jumlah: 0);
      expect(none.weakness, 0.5);
      expect(none.accuracy, 0.5);
      const allWrong =
          TypeScore(type: QuestionType.numSeq, benar: 0, jumlah: 10);
      expect(allWrong.weakness, closeTo(1 - 1 / 12, 1e-9));
      const allRight =
          TypeScore(type: QuestionType.numSeq, benar: 10, jumlah: 10);
      expect(allRight.weakness, closeTo(1 - 11 / 12, 1e-9));
      const oneWrong =
          TypeScore(type: QuestionType.numSeq, benar: 0, jumlah: 1);
      expect(oneWrong.weakness, closeTo(2 / 3, 1e-9),
          reason:
              'penghalus: satu salah belum menjadikan tipe terlemah mutlak');
    });

    test('tipe tanpa data di antara yang lemah dan yang kuat', () {
      final ranked = WeaknessScoring.rank(
        PracticeHistory([
          for (var i = 0; i < 10; i++) ans(QuestionType.figMtx, benar: false),
          for (var i = 0; i < 10; i++) ans(QuestionType.numSeq),
        ]),
        blueprint,
        types,
      );
      expect(ranked.first.type, QuestionType.figMtx);
      expect(ranked.last.type, QuestionType.numSeq);
      final silent = ranked.firstWhere((s) => s.type == QuestionType.logSyl);
      expect(silent.weakness, 0.5);
      expect(silent.jumlah, 0);
      expect(ranked.indexOf(silent), inExclusiveRange(0, ranked.length - 1));
    });

    test('soal tidak dijawab tidak ikut menurunkan kelemahan', () {
      final history = PracticeHistory([
        for (var i = 0; i < 20; i++)
          ans(QuestionType.figMtx, benar: false, dijawab: false),
        ans(QuestionType.figMtx),
        ans(QuestionType.figMtx, benar: false),
      ]);
      final s = WeaknessScoring.rank(history, blueprint, types)
          .firstWhere((s) => s.type == QuestionType.figMtx);
      expect((s.benar, s.jumlah), (1, 2),
          reason: 'hanya dua jawaban yang diisi yang dihitung');
    });

    test('hanya 30 jawaban terbaru per tipe', () {
      // Daftar riwayat berurutan dari yang terbaru: 30 benar, lalu 10 salah.
      final history = PracticeHistory([
        for (var i = 0; i < 30; i++) ans(QuestionType.figMtx),
        for (var i = 0; i < 10; i++) ans(QuestionType.figMtx, benar: false),
      ]);
      final s = WeaknessScoring.rank(history, blueprint, types)
          .firstWhere((s) => s.type == QuestionType.figMtx);
      expect((s.benar, s.jumlah), (30, 30));
    });

    test('imbang diurutkan menurut bobot kategori lalu katalog', () {
      final ranked =
          WeaknessScoring.rank(PracticeHistory(const []), blueprint, types);
      expect(ranked.map((s) => s.weakness).toSet(), {0.5});
      // Numerik dan Logika sama berbobot (0,2727) dan sama-sama tanpa data;
      // imbang jatuh ke urutan katalog, Deret angka lebih dulu.
      expect(ranked.first.type, QuestionType.numSeq);
      expect(ranked.last.type.category.code, 'figural',
          reason: 'Figural berbobot terkecil');
    });

    test('kandidat: hanya kategori aktif berbobot yang punya soal', () {
      expect(types.map((t) => t.category.code).toSet(),
          {'numerik', 'logika', 'figural'});
      expect(
          WeaknessScoring.candidates(blueprint, {QuestionType.vrbSyn}), isEmpty,
          reason: 'VRB-SYN belum punya generator terdaftar');
    });
  });

  group('HistoryWeaknessModel', () {
    test('belum ada riwayat: daftar kosong', () async {
      final model = HistoryWeaknessModel(FakeSessionRepository(), registered);
      expect(await model.weakest(activeProfile(), appNow), isEmpty);
    });

    test('tiga tipe terlemah yang punya data, dari yang terlemah', () async {
      final repo = FakeSessionRepository()
        ..history = [
          for (var i = 0; i < 10; i++) ans(QuestionType.figMtx, benar: i < 2),
          for (var i = 0; i < 10; i++) ans(QuestionType.numSeq, benar: i < 6),
          for (var i = 0; i < 10; i++) ans(QuestionType.logSyl, benar: i < 8),
          for (var i = 0; i < 10; i++) ans(QuestionType.numAri),
        ];
      final model = HistoryWeaknessModel(repo, registered);
      final w = await model.weakest(activeProfile(), appNow);
      expect(w.map((e) => e.type), [
        QuestionType.figMtx,
        QuestionType.numSeq,
        QuestionType.logSyl,
      ]);
      expect(w.first.answered, 10);
      expect(w.first.accuracy, closeTo(3 / 12, 1e-9));
    });
  });
}
