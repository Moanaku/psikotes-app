import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:simulator_psikotes_it/data/db/app_database.dart';
import 'package:simulator_psikotes_it/data/repositories/knowledge_repository.dart';
import 'package:simulator_psikotes_it/data/repositories/mistake_repository.dart';
import 'package:simulator_psikotes_it/domain/models/codes.dart';
import 'package:simulator_psikotes_it/domain/models/knowledge.dart';
import 'package:simulator_psikotes_it/domain/models/notebook.dart';
import 'package:simulator_psikotes_it/domain/services/knowledge_bank.dart';
import 'package:simulator_psikotes_it/domain/services/knowledge_service.dart';

import '../data/db_helper.dart';
import '../support/fake_clock.dart';
import '../support/knowledge_fixtures.dart';

KnowledgeProgress done(String id, {bool dikuasai = true, int day = 1}) =>
    KnowledgeProgress(
      butirId: id,
      level: KnowledgeLevel.dasar,
      terakhir: DateTime.utc(2026, 10, day),
      dikuasai: dikuasai,
    );

void main() {
  group('pemuat bank', () {
    test('bank sah dibaca lengkap dengan id, tipe kartu, dan nomor', () {
      final bank = KnowledgeBank.parse(bankJson(smallBank().items));
      expect(bank.items, hasLength(12));
      final item = bank.byId('KB-QA-D-003')!;
      expect(item.tipe, 'KB-QA-D');
      expect(item.number, 3);
      expect(item.sumber, 'ISTQB Foundation Syllabus');
      expect(item.needsVerification, isFalse);
      expect(bank.byCard('KB-QA-D', 3), same(item));
      expect(bank.byCard('KB-QA-D', 99), isNull);
      expect(bank.topics(KnowledgeRole.qa, KnowledgeLevel.dasar),
          ['siklus-bug', 'test-case']);
      expect(bank.of(KnowledgeRole.umum, KnowledgeLevel.dasar), hasLength(9),
          reason: 'Umum memilih lintas role');
    });

    test('bank kosong sah (belum diisi), bukan galat', () async {
      final state = await loadKnowledgeBank((_) async => bankJson(const []));
      expect(state.isFailed, isFalse);
      expect(state.bank!.isEmpty, isTrue);
    });

    for (final c in <(String, String)>[
      ('bukan JSON', '{rusak'),
      ('akar bukan objek', '[]'),
      ('versi hilang', '{"butir": []}'),
      ('butir bukan daftar', '{"versi": 1, "butir": {}}'),
    ]) {
      test('kegagalan menjadi kondisi galat, bukan crash: ${c.$1}', () async {
        final state = await loadKnowledgeBank((_) async => c.$2);
        expect(state.isFailed, isTrue);
        expect(state.bank, isNull);
      });
    }

    test('kegagalan baca berkas menjadi kondisi galat', () async {
      final state = await loadKnowledgeBank((_) async => throw StateError('x'));
      expect(state.isFailed, isTrue);
    });

    Map<String, Object?> valid() => {
          'id': 'KB-QA-D-001',
          'role': 'qa',
          'level': 'dasar',
          'topik': 'siklus-bug',
          'pertanyaan': 'P?',
          'jawabanModel': 'J.',
          'poinKunci': ['a', 'b'],
          'sumber': 'Rujukan',
          'needsVerification': false,
        };

    String wrap(List<Map<String, Object?>> b) =>
        jsonEncode({'versi': 1, 'dibuat': '2026-10-27', 'butir': b});

    for (final c in <(String, void Function(Map<String, Object?>))>[
      ('id tidak cocok dengan role', (m) => m['id'] = 'KB-BA-D-001'),
      ('id tidak cocok dengan level', (m) => m['id'] = 'KB-QA-L-001'),
      ('id berformat salah', (m) => m['id'] = 'QA-1'),
      ('role tidak dikenal', (m) => m['role'] = 'devops'),
      ('level tidak dikenal', (m) => m['level'] = 'pakar'),
      ('topik bukan slug', (m) => m['topik'] = 'Siklus Bug'),
      ('poin kunci hanya satu', (m) => m['poinKunci'] = ['a']),
      ('poin kunci ada yang kosong', (m) => m['poinKunci'] = ['a', ' ']),
      ('pertanyaan kosong', (m) => m['pertanyaan'] = ' '),
      ('needsVerification hilang', (m) => m.remove('needsVerification')),
      (
        'tanpa sumber tetapi tidak bertanda perlu verifikasi',
        (m) => m['sumber'] = null,
      ),
    ]) {
      test('skema salah ditolak: ${c.$1}', () {
        final m = valid();
        c.$2(m);
        expect(() => KnowledgeBank.parse(wrap([m])),
            throwsA(isA<KnowledgeBankFormatException>()));
      });
    }

    test('butir tanpa sumber yang bertanda perlu verifikasi diterima', () {
      final m = valid()
        ..['sumber'] = null
        ..['needsVerification'] = true;
      final bank = KnowledgeBank.parse(wrap([m]));
      expect(bank.items.single.needsVerification, isTrue);
      expect(bank.items.single.sumber, isNull);
    });

    test('id kembar ditolak', () {
      expect(() => KnowledgeBank.parse(wrap([valid(), valid()])),
          throwsA(isA<KnowledgeBankFormatException>()));
    });
  });

  group('pemilihan butir', () {
    final bank = smallBank();
    List<String> ids(List<KnowledgeItem> l) => [for (final i in l) i.id];

    test('urutan: jatuh tempo, belum pernah, belum dikuasai, dikuasai', () {
      final picked = KnowledgeSelector.pick(
        bank,
        role: KnowledgeRole.qa,
        level: KnowledgeLevel.dasar,
        progress: {
          'KB-QA-D-001': done('KB-QA-D-001'),
          'KB-QA-D-002': done('KB-QA-D-002', dikuasai: false),
        },
        dueIds: {'KB-QA-D-001'},
      );
      expect(ids(picked), ['KB-QA-D-001', 'KB-QA-D-003', 'KB-QA-D-002']);
    });

    test('yang dikuasai tetap muncul di mode role, paling akhir', () {
      final picked = KnowledgeSelector.pick(
        bank,
        role: KnowledgeRole.qa,
        level: KnowledgeLevel.dasar,
        progress: {
          for (final i in ['001', '002']) 'KB-QA-D-$i': done('KB-QA-D-$i')
        },
      );
      expect(ids(picked), ['KB-QA-D-003', 'KB-QA-D-001', 'KB-QA-D-002']);
    });

    test('yang belum dikuasai: penilaian terlama lebih dulu', () {
      final picked = KnowledgeSelector.pick(
        bank,
        role: KnowledgeRole.qa,
        level: KnowledgeLevel.dasar,
        progress: {
          'KB-QA-D-001': done('KB-QA-D-001', dikuasai: false, day: 9),
          'KB-QA-D-002': done('KB-QA-D-002', dikuasai: false, day: 3),
          'KB-QA-D-003': done('KB-QA-D-003', dikuasai: false, day: 5),
        },
      );
      expect(ids(picked), ['KB-QA-D-002', 'KB-QA-D-003', 'KB-QA-D-001']);
    });

    test('topik menyaring; batas jumlah dihormati', () {
      expect(
        ids(KnowledgeSelector.pick(bank,
            role: KnowledgeRole.qa,
            level: KnowledgeLevel.dasar,
            topik: 'test-case')),
        ['KB-QA-D-002'],
      );
      expect(
        KnowledgeSelector.pick(bank,
            role: KnowledgeRole.qa, level: KnowledgeLevel.dasar, count: 2),
        hasLength(2),
      );
    });

    test('level atau role tanpa butir menghasilkan daftar kosong', () {
      expect(
        KnowledgeSelector.pick(bank,
            role: KnowledgeRole.mobile, level: KnowledgeLevel.menengah),
        isEmpty,
      );
    });

    test('Umum: lintas role bergiliran dan melewati yang dikuasai', () {
      final picked = KnowledgeSelector.pick(
        bank,
        role: KnowledgeRole.umum,
        level: KnowledgeLevel.dasar,
        progress: {'KB-QA-D-001': done('KB-QA-D-001')},
      );
      // Urutan role: qa, mobile, ba, umum; satu butir per giliran.
      expect(ids(picked), [
        'KB-QA-D-002',
        'KB-MOB-D-001',
        'KB-BA-D-001',
        'KB-UM-D-001',
        'KB-QA-D-003',
        'KB-MOB-D-002',
        'KB-BA-D-002',
        'KB-UM-D-002',
      ]);
      expect(ids(picked), isNot(contains('KB-QA-D-001')));
    });

    test('Umum: semua dikuasai menghasilkan daftar kosong', () {
      final progress = {
        for (final i in bank.of(KnowledgeRole.umum, KnowledgeLevel.dasar))
          i.id: done(i.id),
      };
      expect(
        KnowledgeSelector.pick(bank,
            role: KnowledgeRole.umum,
            level: KnowledgeLevel.dasar,
            progress: progress),
        isEmpty,
      );
    });

    test('pilihan sama untuk keadaan yang sama (tanpa keacakan)', () {
      List<String> run() => ids(KnowledgeSelector.pick(bank,
          role: KnowledgeRole.umum, level: KnowledgeLevel.dasar));
      expect(run(), run());
    });

    test('rekap level: total dan dikuasai menurut cakupan', () {
      final t = KnowledgeSelector.tally(
        bank,
        role: KnowledgeRole.qa,
        level: KnowledgeLevel.dasar,
        progress: {
          'KB-QA-D-001': done('KB-QA-D-001'),
          'KB-QA-D-002': done('KB-QA-D-002', dikuasai: false),
        },
      );
      expect((t.total, t.mastered), (3, 1));
      final byTopic = KnowledgeSelector.tally(
        bank,
        role: KnowledgeRole.qa,
        level: KnowledgeLevel.dasar,
        topik: 'test-case',
      );
      expect((byTopic.total, byTopic.mastered), (1, 0));
    });

    test('dueIds mengenali kartu pengetahuan lewat tipe dan nomor', () {
      final due = [
        _card('KB-QA-D', 3),
        _card('KB-QA-D', 77), // butir tidak ada di bank
        _card('NUM-SEQ', 3, sumber: AnswerSource.engine),
      ];
      expect(KnowledgeService.dueIds(bank, due), {'KB-QA-D-003'});
    });
  });

  test('nama topik: akronim huruf besar', () {
    expect(KnowledgeItem.topicLabel('siklus-bug'), 'Siklus bug');
    expect(KnowledgeItem.topicLabel('bpmn'), 'BPMN');
    expect(KnowledgeItem.topicLabel('ci'), 'CI');
    expect(KnowledgeItem.topicLabel('arsitektur-mvvm'), 'Arsitektur MVVM');
    expect(KnowledgeItem.topicLabel('pengujian-api'), 'Pengujian API');
  });

  group('penilaian poin kunci (Lanjut)', () {
    test('perlu dua pertiga, dibulatkan ke atas', () {
      expect([
        for (final n in [2, 3, 4, 5, 6]) KeyPointScoring.needed(n)
      ], [
        2,
        2,
        3,
        4,
        4
      ]);
    });

    test('lulus tepat di ambang, gagal di bawahnya', () {
      expect(KeyPointScoring.passes(2, 3), isTrue);
      expect(KeyPointScoring.passes(1, 3), isFalse);
      expect(KeyPointScoring.passes(3, 4), isTrue);
      expect(KeyPointScoring.passes(2, 4), isFalse);
      expect(KeyPointScoring.passes(0, 2), isFalse);
    });
  });

  group('integrasi buku kesalahan (SM-2)', () {
    late AppDatabase db;
    late FakeClock clock;
    late KnowledgeService service;
    late DriftKnowledgeRepository progress;
    late DriftMistakeRepository mistakes;
    final item = kb(KnowledgeRole.qa, KnowledgeLevel.dasar, 1);

    setUp(() {
      db = memoryDb();
      clock = FakeClock(DateTime.utc(2026, 10, 22, 8));
      progress = DriftKnowledgeRepository(db);
      mistakes = DriftMistakeRepository(db);
      service = KnowledgeService(
        progress: progress,
        mistakes: mistakes,
        clock: clock,
      );
    });
    tearDown(() => db.close());

    test('Belum paham membuat kartu sumber pengetahuan jatuh tempo besok',
        () async {
      await service.judge(item, paham: false);
      final cards = await mistakes.watchAll().first;
      expect(cards, hasLength(1));
      final card = cards.single;
      expect(card.sumber, AnswerSource.pengetahuan);
      expect(card.tipe, 'KB-QA-D');
      expect(card.refId, 1);
      expect(card.kategori, 'pengetahuan');
      expect(card.jatuhTempo, DateTime.utc(2026, 10, 23, 8));
      expect(card.streakBenar, 0);
      final p = (await progress.all())[item.id]!;
      expect(p.dikuasai, isFalse);
      expect(p.terakhir, clock.now());
    });

    test('Belum paham dua kali tidak menggandakan kartu', () async {
      await service.judge(item, paham: false);
      clock.advance(const Duration(days: 2));
      await service.judge(item, paham: false);
      final cards = await mistakes.watchAll().first;
      expect(cards, hasLength(1));
      expect(cards.single.jatuhTempo, DateTime.utc(2026, 10, 25, 8));
    });

    test('Sudah paham pada butir tanpa kartu tidak membuat kartu', () async {
      await service.judge(item, paham: true);
      expect(await mistakes.watchAll().first, isEmpty);
      expect((await progress.all())[item.id]!.dikuasai, isTrue);
    });

    test('Sudah paham pada butir berkartu = ulangan benar SM-2', () async {
      await service.judge(item, paham: false);
      clock.advance(const Duration(days: 1));
      await service.judge(item, paham: true);
      var card = (await mistakes.watchAll().first).single;
      expect(card.streakBenar, 1);
      expect(card.intervalHari, 3);
      expect(card.jatuhTempo, DateTime.utc(2026, 10, 26, 8));

      clock.advance(const Duration(days: 3));
      await service.judge(item, paham: true);
      clock.advance(const Duration(days: 7));
      await service.judge(item, paham: true);
      card = (await mistakes.watchAll().first).single;
      expect(card.status, CardStatus.dikuasai);
      expect(card.streakBenar, 3);
    });

    test('Belum paham sesudah beberapa kali paham mengulang dari awal',
        () async {
      await service.judge(item, paham: false);
      clock.advance(const Duration(days: 1));
      await service.judge(item, paham: true);
      clock.advance(const Duration(days: 3));
      await service.judge(item, paham: false);
      final card = (await mistakes.watchAll().first).single;
      expect(card.streakBenar, 0);
      expect(card.intervalHari, 1);
      expect(card.status, CardStatus.aktif);
    });

    test('kartu pengetahuan jatuh tempo ikut daftar jatuh tempo', () async {
      await service.judge(item, paham: false);
      expect(await mistakes.watchDue(DateTime.utc(2026, 10, 22, 9)).first,
          isEmpty);
      final due = await mistakes.watchDue(DateTime.utc(2026, 10, 24)).first;
      expect(due.single.tipe, 'KB-QA-D');
    });
  });

  group('KnowledgeRepository', () {
    late AppDatabase db;
    setUp(() => db = memoryDb());
    tearDown(() => db.close());

    test('menyimpan, menggantikan, dan membaca ulang', () async {
      final repo = DriftKnowledgeRepository(db);
      await repo.save(done('KB-QA-D-001', dikuasai: false));
      await repo.save(done('KB-QA-D-001', day: 5));
      await repo.save(done('KB-BA-D-002'));
      final all = await repo.all();
      expect(all.keys, {'KB-QA-D-001', 'KB-BA-D-002'});
      expect(all['KB-QA-D-001']!.dikuasai, isTrue);
      expect(all['KB-QA-D-001']!.terakhir, DateTime.utc(2026, 10, 5));
    });

    test('baris dengan level tak dikenal dilewati, bukan menggagalkan daftar',
        () async {
      final repo = DriftKnowledgeRepository(db);
      await repo.save(done('KB-QA-D-001'));
      await db.customStatement(
        "INSERT INTO knowledge_progress (butir_id, level, terakhir, dikuasai) "
        "VALUES ('KB-X-Z-001', 'pakar', 1, 1)",
      );
      expect((await repo.all()).keys, {'KB-QA-D-001'});
    });

    test('watchAll memberi tahu saat ada penilaian baru', () async {
      final repo = DriftKnowledgeRepository(db);
      final seen = <int>[];
      final sub = repo.watchAll().listen((m) => seen.add(m.length));
      await pumpEventQueue();
      await repo.save(done('KB-QA-D-001'));
      await pumpEventQueue();
      await sub.cancel();
      expect(seen.first, 0);
      expect(seen.last, 1);
    });
  });
}

MistakeCard _card(
  String tipe,
  int ref, {
  AnswerSource sumber = AnswerSource.pengetahuan,
}) =>
    MistakeCard(
      id: ref,
      tipe: tipe,
      kategori: 'pengetahuan',
      sumber: sumber,
      refId: ref,
      jatuhTempo: DateTime.utc(2026, 10, 22),
      intervalHari: 1,
      streakBenar: 0,
      status: CardStatus.aktif,
      dibuat: DateTime.utc(2026, 10, 21),
    );
