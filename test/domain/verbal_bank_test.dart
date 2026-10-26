import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_test/flutter_test.dart';
import 'package:question_engine/question_engine.dart';
import 'package:simulator_psikotes_it/data/repositories/mistake_repository.dart';
import 'package:simulator_psikotes_it/domain/models/codes.dart';
import 'package:simulator_psikotes_it/domain/models/notebook.dart';
import 'package:simulator_psikotes_it/domain/models/session.dart';
import 'package:simulator_psikotes_it/domain/providers.dart';
import 'package:simulator_psikotes_it/domain/services/default_daily_planner.dart';
import 'package:simulator_psikotes_it/domain/services/diagnostic_planner.dart';
import 'package:simulator_psikotes_it/domain/services/item_allocator.dart';
import 'package:simulator_psikotes_it/domain/services/review_planner.dart';
import 'package:simulator_psikotes_it/domain/services/session_plan_builder.dart';
import 'package:simulator_psikotes_it/domain/services/verbal_bank.dart';
import 'package:simulator_psikotes_it/features/review/review_provider.dart';

import '../support/fake_repositories.dart';
import '../support/fixtures.dart';
import '../support/pump_app.dart' show appNow;
import 'session_harness.dart';

const _assetPath = 'assets/verbal_bank.json';

final String _source = File(_assetPath).readAsStringSync();
final VerbalBank bank = VerbalBank.parse(_source);

String _bankJson(List<Map<String, Object?>> soal, {int versi = 1}) =>
    jsonEncode({'versi': versi, 'soal': soal});

Map<String, Object?> _item({
  String id = 'VRB-SYN-0001',
  String type = 'VRB-SYN',
  String difficulty = 'easy',
  Object? options = const ['a', 'b', 'c', 'd'],
  Object? correctIndex = 0,
  Object? needsReview = false,
}) =>
    {
      'id': id,
      'type': type,
      'difficulty': difficulty,
      'stem': 'Soal?',
      'options': options,
      'correctIndex': correctIndex,
      'explanation': 'Karena begitu.',
      'needsReview': needsReview,
    };

void main() {
  group('isi bank sungguhan', () {
    test('150 soal per tipe dan 50 per kesulitan terbaca', () {
      expect(bank.items, hasLength(300));
      for (final type in VerbalBank.bankTypes) {
        expect(bank.items.where((q) => q.type == type), hasLength(150));
        for (final d in Difficulty.values) {
          expect(bank.pool(type, d), hasLength(50), reason: '${type.code} $d');
        }
      }
      expect(bank.types, VerbalBank.bankTypes);
    });

    test('setiap butir menjadi Question yang sah dengan satu kunci', () {
      for (final q in bank.items) {
        final question = bank.toQuestion(q, seed: 7);
        expect(question.validate(), isEmpty, reason: q.id);
        expect(question.options[question.correctIndex].content.text,
            q.options[q.correctIndex]);
        expect(question.estimatedSeconds, inInclusiveRange(5, 180));
      }
    });

    test('nomor butir cocok dengan id dan byRef menemukannya', () {
      for (final q in bank.items) {
        expect(bank.byRef(q.type, q.number), same(q));
      }
      expect(bank.byRef(QuestionType.vrbSyn, 9999), isNull);
    });
  });

  group('pemilihan butir', () {
    test('deterministik untuk seed dan kesulitan yang sama', () {
      for (final type in VerbalBank.bankTypes) {
        for (final d in Difficulty.values) {
          for (var seed = 0; seed < 200; seed += 7) {
            final a = bank.pick(type, d, seed)!;
            final b = bank.pick(type, d, seed)!;
            expect(a.id, b.id);
            expect(a.type, type);
            expect(a.difficulty, d);
          }
        }
      }
    });

    test('tanpa pengulangan: 50 butir medium habis dipakai tepat sekali', () {
      final taken = <String>{};
      for (var i = 0; i < 50; i++) {
        final q = bank.pick(QuestionType.vrbAna, Difficulty.medium, 31 * i,
            avoid: taken)!;
        expect(q.difficulty, Difficulty.medium);
        expect(taken.add(VerbalBank.keyOf(q.type.code, q.number)), isTrue);
      }
    });

    test('kesulitan habis: pindah ke kesulitan terdekat, tetap tanpa ulang',
        () {
      final taken = {
        for (final q in bank.pool(QuestionType.vrbSyn, Difficulty.medium))
          VerbalBank.keyOf(q.type.code, q.number),
      };
      final q =
          bank.pick(QuestionType.vrbSyn, Difficulty.medium, 3, avoid: taken)!;
      expect(q.difficulty, isNot(Difficulty.medium));
      expect(taken, isNot(contains(VerbalBank.keyOf(q.type.code, q.number))));
    });

    test('semua 150 butir sudah muncul: terpaksa berulang, bukan galat', () {
      final taken = {
        for (final q in bank.items) VerbalBank.keyOf(q.type.code, q.number),
      };
      final q =
          bank.pick(QuestionType.vrbSyn, Difficulty.hard, 5, avoid: taken);
      expect(q, isNotNull);
      expect(q!.difficulty, Difficulty.hard);
    });
  });

  group('validasi skema dan galat muat', () {
    test('butir needsReview dibuang', () {
      final b = VerbalBank.parse(_bankJson([
        _item(),
        _item(id: 'VRB-SYN-0002', needsReview: true),
      ]));
      expect(b.items.map((q) => q.id), ['VRB-SYN-0001']);
    });

    final broken = <String, String>{
      'bukan JSON': '{tidak lengkap',
      'akar bukan objek': '[]',
      'tanpa versi': jsonEncode({'soal': []}),
      'soal bukan daftar': jsonEncode({'versi': 1, 'soal': 'x'}),
      'id kembar': _bankJson([_item(), _item()]),
      'id tak cocok tipe': _bankJson([_item(id: 'VRB-ANA-0001')]),
      'tipe bukan bank': _bankJson([
        _item(id: 'NUM-SEQ-0001', type: 'NUM-SEQ'),
      ]),
      'tipe tak dikenal':
          _bankJson([_item(id: 'XXX-YYY-0001', type: 'XXX-YYY')]),
      'kesulitan tak dikenal': _bankJson([_item(difficulty: 'extreme')]),
      'opsi kurang dari dua': _bankJson([
        _item(options: ['a']),
      ]),
      'opsi kembar': _bankJson([
        _item(options: ['a', ' A ', 'c', 'd']),
      ]),
      'opsi bukan teks': _bankJson([
        _item(options: ['a', 2, 'c', 'd']),
      ]),
      'kunci di luar opsi': _bankJson([_item(correctIndex: 4)]),
      'kunci bukan angka': _bankJson([_item(correctIndex: '1')]),
    };
    broken.forEach((name, source) {
      test('skema rusak ($name) menjadi galat yang ditangani', () async {
        final state = await loadVerbalBank((_) async => source);
        expect(state.isFailed, isTrue);
        expect(state.bank, isNull);
        expect(state.error, isNotEmpty);
      });
    });

    test('bank kosong dianggap galat', () async {
      final state = await loadVerbalBank((_) async => _bankJson([]));
      expect(state.isFailed, isTrue);
    });

    test('asset hilang (pembacaan melempar) menjadi galat, bukan crash',
        () async {
      final state = await loadVerbalBank((path) async =>
          throw PlatformException(
              code: 'asset', message: 'Unable to load $path'));
      expect(state.isFailed, isTrue);
      expect(state.error, contains(_assetPath));
    });

    test('berkas sungguhan termuat', () async {
      final state = await loadVerbalBank((_) async => _source);
      expect(state.isFailed, isFalse);
      expect(state.bank!.items, hasLength(300));
    });

    test('belum dipasang bukan galat', () {
      const state = VerbalBankState.absent();
      expect(state.isFailed, isFalse);
      expect(state.bank, isNull);
    });
  });

  group('PlanItem bank', () {
    test('JSON bolak-balik dan withSubtes menjaga butir', () {
      const item = PlanItem.bank(
        type: QuestionType.vrbSyn,
        refId: 42,
        seed: 99,
        difficulty: Difficulty.hard,
        genVersi: 1,
        subtes: 'verbal',
        cardId: 3,
      );
      final back = PlanItem.fromJson(item.toJson());
      expect(back.isBank, isTrue);
      expect(back.source, AnswerSource.bank);
      expect(back.type, QuestionType.vrbSyn);
      expect(back.refId, 42);
      expect(back.seed, 99);
      expect(back.difficulty, Difficulty.hard);
      expect(back.cardId, 3);
      expect(back.tipeCode, 'VRB-SYN');
      expect(back.kategoriCode, 'verbal');
      final moved = back.withSubtes('campuran');
      expect(moved.isBank, isTrue);
      expect(moved.refId, 42);
      expect(moved.subtes, 'campuran');
    });
  });

  group('perencana dengan bank', () {
    final available = {...GeneratorRegistry.types, ...bank.types};

    test('latihan satu tipe: 10 butir bank berbeda dan deterministik', () {
      final a = SessionPlanBuilder.practice(QuestionType.vrbAna,
          now: appNow, bank: bank);
      final b = SessionPlanBuilder.practice(QuestionType.vrbAna,
          now: appNow, bank: bank);
      expect(a.items, hasLength(10));
      expect([for (final i in a.items) i.refId],
          [for (final i in b.items) i.refId]);
      expect(a.items.map((i) => i.refId).toSet(), hasLength(10));
      for (final i in a.items) {
        expect(i.isBank, isTrue);
        expect(i.genVersi, bank.versi);
        expect(i.subtes, 'verbal');
        expect(bank.byRef(i.type!, i.refId!), isNotNull);
      }
    });

    test('tanpa bank, tipe verbal tidak masuk rencana campuran', () {
      final blueprint = activeProfile(role: ProfileRole.umum).blueprint;
      final types = SessionPlanBuilder.mixedTypes(blueprint,
          count: 30, available: available);
      expect(types.where((t) => t.category.code == 'verbal'), isEmpty);
      final withBank = SessionPlanBuilder.mixedTypes(blueprint,
          count: 30, available: available, bank: bank);
      expect(withBank.where((t) => t.category.code == 'verbal'), isNotEmpty);
    });

    test('simulasi memuat subtes verbal dari bank tanpa butir kembar', () {
      final p = activeProfile(role: ProfileRole.umum, format: TestFormat.ccat);
      final sim = SessionPlanBuilder.simulation(p.blueprint,
          now: appNow, available: available, bank: bank)!;
      expect(sim.skipped, isNot(contains('verbal')));
      final verbal = [
        for (final i in sim.plan.items)
          if (i.isBank) i,
      ];
      expect(verbal, isNotEmpty);
      expect(verbal.map((i) => '${i.tipeCode}#${i.refId}').toSet(),
          hasLength(verbal.length));
      expect(sim.plan.subtes.map((s) => s.kategori), contains('verbal'));
    });

    test('diagnostik memuat verbal dan tiap tipe verbal sekali', () {
      final p = activeProfile(role: ProfileRole.umum, format: TestFormat.ccat);
      final d = DiagnosticPlanner.build(p.blueprint,
          now: appNow, available: available, bank: bank)!;
      expect(d.categories, contains('verbal'));
      final types = {
        for (final i in d.plan.items)
          if (i.isBank) i.type,
      };
      expect(types, VerbalBank.bankTypes);
      expect(d.skipped, isNot(contains('verbal')));
    });

    test('rencana harian memuat verbal dan tidak mengulang butir 30 hari',
        () async {
      final p = activeProfile(role: ProfileRole.umum, format: TestFormat.ccat);
      final history = <AnswerRecord>[];
      final seen = <String>{};
      for (var day = 0; day < 4; day++) {
        final planner = DefaultDailyPlanner(
          answers: FakeSessionRepository()..history = [...history],
          mistakes: FakeMistakeRepository(),
          available: available,
          bank: bank,
        );
        final plan = await planner.plan(
            p, appNow.add(Duration(days: day, seconds: day * 13)));
        final fromBank = [
          for (final i in plan.session.items)
            if (i.isBank) i,
        ];
        expect(fromBank, isNotEmpty, reason: 'hari $day');
        for (final i in fromBank) {
          final key = VerbalBank.keyOf(i.tipeCode, i.refId!);
          expect(seen.add(key), isTrue, reason: 'hari $day mengulang $key');
          history.insert(
            0,
            answerFor(i, history.length, sessionId: day + 1).copyWithBank(i),
          );
        }
      }
    });

    test('ItemAllocator tanpa bank memperlakukan tipe verbal sebagai engine',
        () {
      final alloc = ItemAllocator(5);
      expect(alloc.fromBank(QuestionType.vrbSyn), isFalse);
      expect(alloc.fromBank(QuestionType.numSeq), isFalse);
      expect(
          ItemAllocator(5, bank: bank).fromBank(QuestionType.vrbSyn), isTrue);
    });

    test('ulangan kartu bank memakai butir yang sama', () {
      final q = bank.items.first;
      final card = MistakeCard(
        id: 9,
        tipe: q.type.code,
        kategori: 'verbal',
        sumber: AnswerSource.bank,
        refId: q.number,
        jatuhTempo: appNow,
        intervalHari: 1,
        streakBenar: 0,
        status: CardStatus.aktif,
        dibuat: appNow,
      );
      final review = ReviewPlanner.build([card],
          now: appNow, available: available, bank: bank);
      final item = review.plan.items.single;
      expect(item.isBank, isTrue);
      expect(item.refId, q.number);
      expect(item.cardId, 9);
      expect(review.sameItems, isEmpty);

      final without =
          ReviewPlanner.build([card], now: appNow, available: available);
      expect(without.plan.items, isEmpty);
      expect(without.sameItems, hasLength(1));
    });
  });

  group('bank tidak termuat', () {
    test('soal bank menjadi questionFailed, bukan crash', () async {
      final bare = Harness();
      addTearDown(bare.dispose);
      final plan = SessionPlanBuilder.practice(QuestionType.vrbSyn,
          now: bare.clock.now(), count: 2, bank: bank);
      await bare.start(SessionMode.latihan, plan);
      expect(bare.s.question, isNull);
      expect(bare.s.questionFailed, isTrue);
    });
  });

  group('alur sesi verbal sampai pembahasan', () {
    late Harness h;

    setUp(() {
      h = Harness(
        overrides: (_) => [
          verbalBankStateProvider
              .overrideWithValue(VerbalBankState.loaded(bank)),
        ],
      );
    });
    tearDown(() => h.dispose());

    test('jawaban ditulis sumber=bank, kartu dibuat, pembahasan dari id bank',
        () async {
      final plan = SessionPlanBuilder.practice(QuestionType.vrbSyn,
          now: h.clock.now(), count: 3, bank: bank);
      await h.start(SessionMode.latihan, plan);
      final sessionId = h.s.sessionId;

      final q0 = h.s.question!;
      expect(q0.type, QuestionType.vrbSyn);
      expect(q0.stem.text,
          bank.byRef(QuestionType.vrbSyn, plan.items[0].refId!)!.stem);

      // soal 1 benar, soal 2 salah, soal 3 dilewati lewat akhiri sesi
      await h.c.select(h.rightOption());
      await h.c.submit();
      expect(h.s.feedback!.benar, isTrue);
      await h.c.next();
      final wrongStem = h.s.question!.stem.text;
      await h.c.select(h.wrongOption());
      await h.c.submit();
      expect(h.s.feedback!.benar, isFalse);
      await h.c.next();
      await h.c.finish();

      final answers = await h.answers(sessionId);
      for (var i = 0; i < 3; i++) {
        final a = answers[i]!;
        expect(a.sumber, AnswerSource.bank);
        expect(a.tipe, 'VRB-SYN');
        expect(a.kategori, 'verbal');
        expect(a.refId, plan.items[i].refId);
        expect(a.genVersi, bank.versi);
      }
      expect(answers[0]!.benar, isTrue);
      expect(answers[1]!.benar, isFalse);
      expect(answers[2]!.opsiDipilih, isNull);

      final cards = await DriftMistakeRepository(h.db).watchAll().first;
      expect(cards, hasLength(1));
      expect(cards.single.sumber, AnswerSource.bank);
      expect(cards.single.refId, plan.items[1].refId);
      expect(cards.single.tipe, 'VRB-SYN');

      // Pembahasan S09 dibuat ulang dari id bank.
      final review =
          await h.container.read(sessionReviewProvider(sessionId).future);
      final redone = review!.questionAt(1)!;
      expect(redone.stem.text, wrongStem);
      expect(redone.explanation, isNotEmpty);
      expect(redone.explanation,
          bank.byRef(QuestionType.vrbSyn, plan.items[1].refId!)!.explanation);

      // Riwayat 30 hari memuat butirnya, sehingga tidak muncul lagi.
      final history = await h.container
          .read(answerRepositoryProvider)
          .since(h.clock.now().subtract(const Duration(days: 30)));
      final seen = {
        for (final a in history)
          if (a.sumber == AnswerSource.bank) VerbalBank.keyOf(a.tipe, a.refId!),
      };
      expect(seen, hasLength(3));
    });

    test('versi bank berbeda: soal tidak bisa dibuat ulang', () {
      final item = PlanItem.bank(
        type: QuestionType.vrbSyn,
        refId: bank.pool(QuestionType.vrbSyn, Difficulty.easy).first.number,
        seed: 1,
        difficulty: Difficulty.easy,
        genVersi: bank.versi + 1,
        subtes: 'verbal',
      );
      expect(
          () => buildFromBank(bank, item), throwsA(isA<QuestionUnavailable>()));
    });
  });
}

extension on AnswerRecord {
  /// Salinan jawaban yang menandai asalnya dari bank.
  AnswerRecord copyWithBank(PlanItem item) => AnswerRecord(
        sessionId: sessionId,
        posisi: posisi,
        tipe: tipe,
        kategori: kategori,
        seed: seed,
        kesulitan: kesulitan,
        genVersi: genVersi,
        sumber: AnswerSource.bank,
        refId: item.refId,
        opsiDipilih: opsiDipilih,
        benar: benar,
        durasiMs: durasiMs,
        label: label,
      );
}
