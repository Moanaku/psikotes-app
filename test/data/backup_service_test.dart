import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:question_engine/question_engine.dart';
import 'package:simulator_psikotes_it/data/backup/drift_backup_service.dart';
import 'package:simulator_psikotes_it/data/db/app_database.dart';
import 'package:simulator_psikotes_it/data/repositories/capture_repository.dart';
import 'package:simulator_psikotes_it/data/repositories/mistake_repository.dart';
import 'package:simulator_psikotes_it/data/repositories/profile_repository.dart';
import 'package:simulator_psikotes_it/data/repositories/session_repository.dart';
import 'package:simulator_psikotes_it/data/repositories/settings_repository.dart';
import 'package:simulator_psikotes_it/domain/models/codes.dart';
import 'package:simulator_psikotes_it/domain/models/notebook.dart';
import 'package:simulator_psikotes_it/domain/models/session.dart';
import 'package:simulator_psikotes_it/domain/repositories/repositories.dart';
import 'package:simulator_psikotes_it/domain/services/backup.dart';

import 'db_helper.dart' as h;

final DateTime now = DateTime.utc(2026, 10, 22, 8);

/// Perangkat berisi data di setiap tabel.
Future<void> seed(AppDatabase db) async {
  final profiles = DriftProfileRepository(db);
  final pid = await profiles.save(h.profile(aktif: true));
  await profiles.setCv(pid, 'Nama Rahasia, 0812-0000-0000, rahasia@contoh.id');
  await profiles.save(h.profile(nama: 'Profil kedua'));

  final logId = await DriftCompanyLogRepository(db).save(CompanyTestLog(
    perusahaan: 'PT Maju',
    tanggal: DateTime.utc(2026, 9, 30),
    subtes: const ['verbal', 'figural'],
    tipeBaru: const ['lipat kertas'],
    catatan: 'Waktu kurang.',
  ));
  final capId = await DriftCaptureRepository(db).save(CapturedQuestion(
    teks: 'Soal rahasia perusahaan?',
    opsi: const ['a', 'b', 'c'],
    kunci: 1,
    pembahasan: 'Karena b.',
    kategori: 'lipat kertas',
    fotoPath: 'cap_abc.jpg',
    companyLogId: logId,
    dibuat: h.t0,
  ));

  final sessions = DriftSessionRepository(db);
  final sid = await sessions.start(NewSession(
    profileId: pid,
    mode: SessionMode.latihan,
    plan: h.plan(n: 3),
    mulai: h.t0,
  ));
  AnswerRecord answer(int posisi, {bool benar = true}) => AnswerRecord(
        sessionId: sid,
        posisi: posisi,
        tipe: 'FIG-MTX',
        kategori: 'figural',
        seed: 100 + posisi,
        kesulitan: Difficulty.medium,
        genVersi: 1,
        opsiDipilih: 1,
        benar: benar,
        durasiMs: 30000,
        label: benar ? SpeedLabel.benarCepat : SpeedLabel.salahLambat,
      );
  await sessions.recordAnswer(answer(0));
  final wrong = answer(1, benar: false);
  await sessions.recordAnswer(wrong);
  await sessions.recordAnswer(answer(2));
  await sessions.finish(sid, h.t0.add(const Duration(minutes: 10)));

  final mistakes = DriftMistakeRepository(db);
  await mistakes.upsertFromAnswer(wrong, h.t0);
  await mistakes.upsertFromAnswer(
    AnswerRecord(
      sessionId: sid,
      posisi: 5,
      tipe: PlanItem.captureTipe,
      kategori: 'lipat kertas',
      seed: 0,
      kesulitan: Difficulty.medium,
      genVersi: 0,
      sumber: AnswerSource.capture,
      refId: capId,
      benar: false,
      durasiMs: 1000,
      label: SpeedLabel.salahCepat,
    ),
    h.t0,
  );

  final settings = DriftSettingsRepository(db);
  await settings.setTheme(ThemeSetting.gelap);
  await settings.set(SettingKeys.penyediaAi, 'groq');
  await settings.set(SettingKeys.batasWawancaraHarian, '5');
}

/// Isi database sebagai teks, tanpa `diekspor` supaya bisa dibandingkan.
Future<Map<String, Object?>> snapshot(AppDatabase db) async {
  final json = jsonDecode(await DriftBackupService(db).export(now))
      as Map<String, Object?>;
  return (json['tabel']! as Map).cast<String, Object?>();
}

/// Semua sesi di [db] menurut nomor.
Future<List<SessionRecord>> allSessions(AppDatabase db) async {
  final repo = DriftSessionRepository(db);
  final rows =
      await db.customSelect('SELECT id FROM session ORDER BY id').get();
  return [for (final r in rows) (await repo.byId(r.read<int>('id')))!];
}

Future<String> exported(AppDatabase db) => DriftBackupService(db).export(now);

void main() {
  late AppDatabase db;
  late DriftBackupService service;

  setUp(() {
    db = h.memoryDb();
    service = DriftBackupService(db);
  });

  tearDown(() => db.close());

  group('ekspor', () {
    test('format, versi, waktu, dan semua tabel', () async {
      await seed(db);
      final root = jsonDecode(await service.export(now)) as Map;
      expect(root['format'], 'simulator-psikotes-backup');
      expect(root['versi'], 1);
      expect(root['diekspor'], now.millisecondsSinceEpoch);
      final tabel = (root['tabel'] as Map).cast<String, List>();
      expect(tabel.keys, [
        'test_profile',
        'company_test_log',
        'captured_question',
        'session',
        'answer',
        'mistake_card',
        'knowledge_progress',
        'app_setting',
      ]);
      expect(tabel['test_profile'], hasLength(2));
      expect(tabel['answer'], hasLength(3));
      expect(tabel['mistake_card'], hasLength(2));
      expect(tabel['captured_question'], hasLength(1));
      expect(tabel['app_setting'], hasLength(3));
      expect(tabel['knowledge_progress'], isEmpty);
    });

    test('teks CV mentah tidak diekspor', () async {
      await seed(db);
      final text = await service.export(now);
      expect(text, isNot(contains('cv_teks')));
      expect(text, isNot(contains('Nama Rahasia')));
      expect(text, isNot(contains('0812')));
      expect(text, isNot(contains('rahasia@contoh.id')));
    });

    test('key API tidak ikut, juga bila baris salah tulis ada di app_setting',
        () async {
      await seed(db);
      final settings = DriftSettingsRepository(db);
      await settings.set('api_key_gemini', 'AIzaSECRET-12345');
      await settings.set('API_KEY_GROQ', 'gsk_SECRET-67890');
      final text = await service.export(now);
      expect(text, isNot(contains('SECRET')));
      expect(text, isNot(contains('api_key')));
      final rows = (await snapshot(db))['app_setting']! as List;
      expect(rows, hasLength(3));
    });

    test('foto Capture tidak ikut: hanya nama berkas', () async {
      await seed(db);
      final rows = (await snapshot(db))['captured_question']! as List;
      expect((rows.single as Map)['foto_path'], 'cap_abc.jpg');
    });

    test('database kosong menghasilkan berkas sah yang bisa diimpor', () async {
      final text = await service.export(now);
      final other = h.memoryDb();
      addTearDown(other.close);
      final summary = await DriftBackupService(other).import(text);
      expect(summary.totalRows, 0);
    });
  });

  group('ekspor lalu impor di database bersih', () {
    test('semua tabel kembali sama persis', () async {
      await seed(db);
      final text = await service.export(now);

      final clean = h.memoryDb();
      addTearDown(clean.close);
      final summary = await DriftBackupService(clean).import(text);

      expect(await snapshot(clean), await snapshot(db));
      expect(summary.updated, 0);
      expect(summary.added, summary.totalRows);
      expect(summary.totalRows, greaterThan(10));
    });

    test('profil aktif tepat satu dan teks CV tidak dipulihkan', () async {
      await seed(db);
      final clean = h.memoryDb();
      addTearDown(clean.close);
      await DriftBackupService(clean).import(await service.export(now));

      final profiles = DriftProfileRepository(clean);
      final all = await profiles.watchAll().first;
      expect(all.where((p) => p.aktif), hasLength(1));
      expect((await profiles.active())!.nama, 'QA, CCAT');
      expect(all.every((p) => p.cvTeks == null), isTrue);
    });

    test('data terpulihkan bisa dipakai: kartu, soal Capture, catatan',
        () async {
      await seed(db);
      final clean = h.memoryDb();
      addTearDown(clean.close);
      await DriftBackupService(clean).import(await service.export(now));

      final cards = await DriftMistakeRepository(clean).watchAll().first;
      expect(cards.map((c) => c.sumber),
          containsAll([AnswerSource.engine, AnswerSource.capture]));
      final q = (await DriftCaptureRepository(clean).watchAll().first).single;
      expect(q.opsi, ['a', 'b', 'c']);
      expect(q.kunci, 1);
      expect(q.companyLogId, isNotNull);
      final log =
          (await DriftCompanyLogRepository(clean).watchAll().first).single;
      expect(log.tipeBaru, ['lipat kertas']);
      expect(await DriftSettingsRepository(clean).theme(), ThemeSetting.gelap);
    });

    test('impor dua kali tidak menggandakan apa pun', () async {
      await seed(db);
      final text = await service.export(now);
      final clean = h.memoryDb();
      addTearDown(clean.close);
      final target = DriftBackupService(clean);
      await target.import(text);
      final before = await snapshot(clean);
      final second = await target.import(text);
      expect(await snapshot(clean), before);
      expect(second.added, 0);
      expect(second.updated, 0);
    });
  });

  group('berkas ditolak', () {
    Future<void> expectRejected(
      String text,
      BackupProblem problem, {
      Matcher? message,
    }) async {
      await seed(db);
      final before = await snapshot(db);
      await expectLater(
        service.import(text),
        throwsA(
          isA<BackupException>()
              .having((e) => e.problem, 'problem', problem)
              .having((e) => e.message, 'message', message ?? isNotEmpty),
        ),
      );
      expect(await snapshot(db), before, reason: 'tidak ada yang berubah');
      await expectLater(service.preview(text), throwsA(isA<BackupException>()));
    }

    Map<String, Object?> valid() => jsonDecode(jsonEncode({
          'format': 'simulator-psikotes-backup',
          'versi': 1,
          'diekspor': now.millisecondsSinceEpoch,
          'tabel': <String, Object?>{},
        })) as Map<String, Object?>;

    const unreadable = 'Backup tidak bisa dibaca. Berkasnya bukan hasil ekspor '
        'dari app ini. Pilih berkas lain.';

    test('bukan JSON', () async {
      await expectRejected('bukan json {', BackupProblem.unreadable,
          message: equals(unreadable));
    });

    test('JSON lain dengan format salah', () async {
      await expectRejected('{"nama":"x"}', BackupProblem.unreadable,
          message: equals(unreadable));
      await expectRejected('[1,2,3]', BackupProblem.unreadable);
      await expectRejected(
        jsonEncode({...valid(), 'format': 'cadangan-lain'}),
        BackupProblem.unreadable,
      );
    });

    test('versi bukan bilangan bulat positif atau tabel hilang', () async {
      await expectRejected(
        jsonEncode({...valid(), 'versi': '1'}),
        BackupProblem.unreadable,
      );
      await expectRejected(
        jsonEncode({...valid(), 'versi': 0}),
        BackupProblem.unreadable,
      );
      await expectRejected(
        jsonEncode({...valid()}..remove('tabel')),
        BackupProblem.unreadable,
      );
    });

    test('versi lebih baru: pesan menyebut perlunya memperbarui app', () async {
      await expectRejected(
        jsonEncode({...valid(), 'versi': 2}),
        BackupProblem.newer,
        message: allOf(
          startsWith('Backup dibuat oleh versi app yang lebih baru'),
          contains('format versi 2'),
          endsWith('Perbarui app lalu coba lagi.'),
        ),
      );
    });

    test('baris dengan kode enum atau tipe yang salah', () async {
      await seed(db);
      final root = jsonDecode(await service.export(now)) as Map;
      Future<void> tamper(
        String table,
        void Function(Map row) edit,
      ) async {
        final copy = jsonDecode(jsonEncode(root)) as Map;
        edit(((copy['tabel'] as Map)[table] as List).first as Map);
        await expectRejected(jsonEncode(copy), BackupProblem.unreadable);
      }

      await tamper('test_profile', (r) => r['role'] = 'dukun');
      await tamper('test_profile', (r) => r['aktif'] = 2);
      await tamper('test_profile', (r) => r['blueprint_json'] = '{rusak');
      await tamper('session', (r) => r['mode'] = 'ujian');
      await tamper('session', (r) => r['rencana_json'] = '{"items":[{}]}');
      await tamper('answer', (r) => r['label'] = 'cepat');
      await tamper('answer', (r) => r['benar'] = 'ya');
      await tamper('mistake_card', (r) => r['status'] = 'selesai');
      await tamper('mistake_card', (r) => r['streak_benar'] = 9);
      await tamper('captured_question', (r) => r['opsi_json'] = '["satu"]');
      await tamper('captured_question', (r) => r['kunci'] = 7);
      await tamper('company_test_log', (r) => r['subtes_json'] = '[1,2]');
      await tamper('company_test_log', (r) => r.remove('perusahaan'));
    });

    test('rujukan ke baris yang tidak ada dan id kembar', () async {
      await seed(db);
      final root = jsonDecode(await service.export(now)) as Map;
      Map copy() => jsonDecode(jsonEncode(root)) as Map;

      final noProfile = copy();
      (((noProfile['tabel'] as Map)['session'] as List).first
          as Map)['profile_id'] = 999;
      await expectRejected(jsonEncode(noProfile), BackupProblem.unreadable);

      final noSession = copy();
      (((noSession['tabel'] as Map)['answer'] as List).first
          as Map)['session_id'] = 999;
      await expectRejected(jsonEncode(noSession), BackupProblem.unreadable);

      final noLog = copy();
      (((noLog['tabel'] as Map)['captured_question'] as List).first
          as Map)['company_log_id'] = 999;
      await expectRejected(jsonEncode(noLog), BackupProblem.unreadable);

      final dup = copy();
      final profiles = (dup['tabel'] as Map)['test_profile'] as List;
      (profiles[1] as Map)['id'] = (profiles[0] as Map)['id'];
      await expectRejected(jsonEncode(dup), BackupProblem.unreadable);

      final dupAnswer = copy();
      final answers = (dupAnswer['tabel'] as Map)['answer'] as List;
      (answers[1] as Map)['posisi'] = (answers[0] as Map)['posisi'];
      await expectRejected(jsonEncode(dupAnswer), BackupProblem.unreadable);
    });

    test('berkas terlalu besar', () async {
      await expectRejected(
        ' ' * (BackupFormat.maxBytes + 1),
        BackupProblem.unreadable,
      );
    });
  });

  group('satu transaksi', () {
    test('gagal di tengah: tidak ada tabel yang berubah', () async {
      await seed(db);
      final text = await service.export(now);

      final target = h.memoryDb();
      addTearDown(target.close);
      await DriftProfileRepository(target)
          .save(h.profile(nama: 'Profil lama', aktif: true));
      final before = await snapshot(target);

      final failing = DriftBackupService(
        target,
        afterTable: (table) async {
          if (table == 'answer') throw StateError('disk penuh');
        },
      );
      await expectLater(
        failing.import(text),
        throwsA(
          isA<BackupException>()
              .having((e) => e.problem, 'problem', BackupProblem.failed)
              .having((e) => e.message, 'message', isNot(contains('disk'))),
        ),
      );
      expect(await snapshot(target), before,
          reason: 'profil, catatan, soal, dan sesi yang sudah ditulis batal');

      // Setelah gagal, impor berikutnya berjalan normal.
      await DriftBackupService(target).import(text);
      expect(((await snapshot(target))['session']! as List), hasLength(1));
    });
  });

  group('penggabungan berdasarkan id', () {
    /// Perangkat lain yang sudah punya data sendiri dengan id yang sama.
    Future<AppDatabase> device() async {
      final d = h.memoryDb();
      addTearDown(d.close);
      return d;
    }

    Map<String, Object?> exportedWith(
      Map<String, Object?> base,
      void Function(Map<String, List> tabel) edit,
    ) {
      final copy = jsonDecode(jsonEncode(base)) as Map<String, Object?>;
      edit((copy['tabel']! as Map).cast<String, List>());
      return copy;
    }

    test('nomor sama dengan isi lain diberi nomor baru, tidak menimpa',
        () async {
      // Perangkat A: satu profil (id 1) dibuat t0.
      final a = await device();
      final repoA = DriftProfileRepository(a);
      await repoA.save(h.profile(nama: 'Versi lama', aktif: true));
      final base = jsonDecode(await DriftBackupService(a).export(now))
          as Map<String, Object?>;

      // Backup dari perangkat lain: profil dengan id 1 juga, tetapi profil
      // lain (dibuat sehari kemudian, nama lain).
      final other = exportedWith(base, (t) {
        final row = t['test_profile']!.first as Map;
        row['nama'] = 'Profil dari backup';
        row['aktif'] = 0;
        row['dibuat'] =
            h.t0.add(const Duration(days: 1)).millisecondsSinceEpoch;
      });
      final summary = await DriftBackupService(a).import(jsonEncode(other));
      final count = summary.tabel['test_profile']!;
      expect((count.added, count.renumbered, count.updated), (1, 1, 0));
      final all = await repoA.watchAll().first;
      expect(
          all.map((p) => p.nama).toSet(), {'Versi lama', 'Profil dari backup'},
          reason: 'profil lama tidak tertimpa');
      expect(all.map((p) => p.id).toSet(), hasLength(2));
      expect((await repoA.active())!.nama, 'Versi lama');

      // Berkas yang sama sekali lagi: sudah ada, tidak menggandakan.
      final again = await DriftBackupService(a).import(jsonEncode(other));
      expect(again.tabel['test_profile']!.kept, 1);
      expect(again.added, 0);
      expect(await repoA.watchAll().first, hasLength(2));
    });

    test('data di perangkat tidak hilang; profil aktif perangkat tetap aktif',
        () async {
      await seed(db);
      final text = await service.export(now);

      final other = await device();
      final repo = DriftProfileRepository(other);
      final own = await repo.save(h.profile(
        nama: 'Punya sendiri',
        aktif: true,
        dibuat: h.t0.add(const Duration(days: 7)),
      ));
      // Sesi sendiri dengan id yang akan bertabrakan (id 1).
      final ownSession = await DriftSessionRepository(other).start(NewSession(
        profileId: own,
        mode: SessionMode.simulasi,
        plan: h.plan(n: 2),
        mulai: h.t0.add(const Duration(days: 5)),
      ));
      expect(ownSession, 1);

      final summary = await DriftBackupService(other).import(text);

      final profiles = await repo.watchAll().first;
      expect(profiles.map((p) => p.nama),
          containsAll(['Punya sendiri', 'QA, CCAT', 'Profil kedua']));
      expect(profiles.where((p) => p.aktif), hasLength(1));
      expect((await repo.active())!.id, own);

      // Sesi sendiri utuh dan tetap milik profilnya.
      final sessions = DriftSessionRepository(other);
      final mine = await sessions.byId(ownSession);
      expect(mine!.mode, SessionMode.simulasi);
      expect(mine.profileId, own);

      // Sesi dari backup menempel ke profil dari backup, bukan ke profil
      // sendiri yang kebetulan bernomor sama.
      final imported =
          (await allSessions(other)).where((s) => s.id != ownSession).single;
      expect(imported.mode, SessionMode.latihan);
      final owner = await repo.byId(imported.profileId);
      expect(owner!.nama, 'QA, CCAT');
      expect(imported.profileId, isNot(own));
      expect(await DriftAnswerRepository(other).forSession(imported.id),
          hasLength(3));

      expect(summary.tabel['test_profile']!.renumbered, 1);
      expect(summary.tabel['session']!.renumbered, 1);
      expect(summary.tabel['session']!.kept, 0);
    });

    test('rujukan Capture, kartu, dan catatan ikut dipetakan ke nomor baru',
        () async {
      // Sumber: soal Capture (id 1) dalam catatan (id 1), kartu engine (id 1),
      // dan sesi yang merujuk ke soal Capture dan ke kartu itu.
      final src = await device();
      final srcProfile =
          await DriftProfileRepository(src).save(h.profile(aktif: true));
      final srcLog = await DriftCompanyLogRepository(src).save(CompanyTestLog(
        perusahaan: 'PT Sumber',
        tanggal: DateTime.utc(2026, 9, 1),
        subtes: const ['verbal'],
        tipeBaru: const [],
        catatan: '',
      ));
      final srcCapture =
          await DriftCaptureRepository(src).save(CapturedQuestion(
        teks: 'Soal sumber',
        opsi: const ['a', 'b'],
        kunci: 0,
        kategori: 'lipat kertas',
        companyLogId: srcLog,
        dibuat: h.t0,
      ));
      final srcCardAnswer = h.answer(0, seed: 777, benar: false);
      final srcCard = (await DriftMistakeRepository(src)
          .upsertFromAnswer(srcCardAnswer, h.t0))!;
      final srcSession = await DriftSessionRepository(src).start(NewSession(
        profileId: srcProfile,
        mode: SessionMode.latihan,
        plan: SessionPlan(
          items: [
            PlanItem.capture(
                refId: srcCapture, kategori: 'lipat kertas', subtes: 'x'),
            PlanItem(
              type: QuestionType.figMtx,
              seed: 778,
              difficulty: Difficulty.medium,
              genVersi: 1,
              subtes: 'figural',
              cardId: srcCard.id,
            ),
          ],
          subtes: const [SubtestPlan(kategori: 'figural', jumlah: 2, menit: 5)],
        ),
        mulai: h.t0,
      ));
      final captureAnswer = h.answer(
        srcSession,
        seed: 0,
        benar: false,
        tipe: PlanItem.captureTipe,
        sumber: AnswerSource.capture,
        refId: srcCapture,
      );
      await DriftSessionRepository(src).recordAnswer(captureAnswer);
      await DriftMistakeRepository(src).upsertFromAnswer(captureAnswer, h.t0);
      final text = await DriftBackupService(src).export(now);

      // Tujuan: sudah punya baris bernomor 1 di semua tabel, semuanya lain.
      final dst = await device();
      final dstProfile = await DriftProfileRepository(dst).save(h.profile(
        nama: 'Milik tujuan',
        aktif: true,
        dibuat: h.t0.add(const Duration(days: 9)),
      ));
      final dstLog = await DriftCompanyLogRepository(dst).save(CompanyTestLog(
        perusahaan: 'PT Tujuan',
        tanggal: DateTime.utc(2026, 8, 1),
        subtes: const [],
        tipeBaru: const [],
        catatan: '',
      ));
      final dstCapture =
          await DriftCaptureRepository(dst).save(CapturedQuestion(
        teks: 'Soal tujuan',
        opsi: const ['x', 'y'],
        kunci: 1,
        kategori: 'verbal',
        companyLogId: dstLog,
        dibuat: h.t0.add(const Duration(days: 9)),
      ));
      final dstCard = (await DriftMistakeRepository(dst)
          .upsertFromAnswer(h.answer(0, seed: 1, benar: false), h.t0))!;
      expect([dstProfile, dstLog, dstCapture, dstCard.id], [1, 1, 1, 1]);

      final summary = await DriftBackupService(dst).import(text);
      expect(summary.tabel['captured_question']!.renumbered, 1);
      expect(summary.tabel['company_test_log']!.renumbered, 1);

      // Soal Capture sumber punya nomor baru dan tetap terhubung ke catatan
      // sumber, bukan ke catatan tujuan.
      final captures = await DriftCaptureRepository(dst).watchAll().first;
      final imported = captures.singleWhere((q) => q.teks == 'Soal sumber');
      expect(imported.id, isNot(dstCapture));
      final log =
          await DriftCompanyLogRepository(dst).byId(imported.companyLogId!);
      expect(log!.perusahaan, 'PT Sumber');
      expect((await DriftCaptureRepository(dst).byId(dstCapture))!.companyLogId,
          dstLog,
          reason: 'soal tujuan tidak berubah');

      // Kartu sumber punya nomor baru; rencana sesi menunjuk ke nomor itu.
      final cards = await DriftMistakeRepository(dst).watchAll().first;
      final engineCard = cards.singleWhere((c) => c.seed == 777);
      final captureCard =
          cards.singleWhere((c) => c.sumber == AnswerSource.capture);
      expect(engineCard.id, isNot(dstCard.id));
      expect(captureCard.refId, imported.id);

      final session = (await allSessions(dst)).single;
      expect(session.profileId, isNot(dstProfile));
      expect((await DriftProfileRepository(dst).byId(session.profileId))!.aktif,
          isFalse);
      expect(session.plan.items[0].refId, imported.id);
      expect(session.plan.items[1].cardId, engineCard.id);
      final answers = await DriftAnswerRepository(dst).forSession(session.id);
      expect(answers.single.refId, imported.id);
    });

    test(
        'kartu untuk soal yang sama tidak digandakan; rencana memakai kartu '
        'perangkat', () async {
      final src = await device();
      final srcProfile =
          await DriftProfileRepository(src).save(h.profile(aktif: true));
      final srcCard = (await DriftMistakeRepository(src)
          .upsertFromAnswer(h.answer(0, seed: 55, benar: false), h.t0))!;
      await DriftSessionRepository(src).start(NewSession(
        profileId: srcProfile,
        mode: SessionMode.latihan,
        plan: SessionPlan(
          items: [
            PlanItem(
              type: QuestionType.figMtx,
              seed: 56,
              difficulty: Difficulty.medium,
              genVersi: 1,
              subtes: 'figural',
              cardId: srcCard.id,
            ),
          ],
          subtes: const [SubtestPlan(kategori: 'figural', jumlah: 1, menit: 5)],
        ),
        mulai: h.t0,
      ));
      final text = await DriftBackupService(src).export(now);

      final dst = await device();
      await DriftProfileRepository(dst).save(
          h.profile(aktif: true, dibuat: h.t0.add(const Duration(days: 1))));
      // Kartu soal yang sama (seed 55) dengan nomor lain di tujuan.
      final mistakes = DriftMistakeRepository(dst);
      await mistakes.upsertFromAnswer(h.answer(0, seed: 1, benar: false), h.t0);
      final same = (await mistakes.upsertFromAnswer(
          h.answer(0, seed: 55, benar: false), h.t0))!;
      expect(same.id, 2);

      final summary = await DriftBackupService(dst).import(text);
      expect(summary.tabel['mistake_card']!.added, 0);
      expect(summary.tabel['mistake_card']!.kept, 1);
      expect(await mistakes.watchAll().first, hasLength(2));
      final session = (await allSessions(dst)).single;
      expect(session.plan.items.single.cardId, same.id);
    });

    test(
        'impor berkas yang sama dua kali ke perangkat bernomor bentrok tidak '
        'menggandakan', () async {
      await seed(db);
      final text = await service.export(now);

      final other = await device();
      await DriftProfileRepository(other).save(h.profile(
        nama: 'Punya sendiri',
        aktif: true,
        dibuat: h.t0.add(const Duration(days: 7)),
      ));
      final target = DriftBackupService(other);
      final first = await target.import(text);
      expect(first.renumbered, greaterThan(0));
      final before = await snapshot(other);
      final second = await target.import(text);
      expect(second.added, 0);
      expect(second.renumbered, 0);
      expect(await snapshot(other), before);
    });

    test(
        'jawaban sesi dari backup menempel ke sesinya; id jawaban bentrok '
        'diberi id baru', () async {
      await seed(db);
      final text = await service.export(now);

      final other = await device();
      final repo = DriftProfileRepository(other);
      final own = await repo.save(h.profile(
        aktif: true,
        dibuat: h.t0.add(const Duration(days: 7)),
      ));
      final sessions = DriftSessionRepository(other);
      // Sesi id 1 dengan satu jawaban (id 1); nomornya sama dengan sesi backup
      // tetapi sesi lain (mulai berbeda).
      final old = await sessions.start(NewSession(
        profileId: own,
        mode: SessionMode.latihan,
        plan: h.plan(n: 1),
        mulai: h.t0.subtract(const Duration(days: 3)),
      ));
      await sessions.recordAnswer(AnswerRecord(
        sessionId: old,
        posisi: 0,
        tipe: 'NUM-SEQ',
        kategori: 'numerik',
        seed: 1,
        kesulitan: Difficulty.easy,
        genVersi: 1,
        opsiDipilih: 0,
        benar: true,
        durasiMs: 1,
        label: SpeedLabel.benarCepat,
      ));
      // Sesi kedua milik sendiri (id 2) dengan jawaban id 2 yang tidak boleh hilang.
      final keep = await sessions.start(NewSession(
        profileId: own,
        mode: SessionMode.latihan,
        plan: h.plan(n: 1),
        mulai: h.t0.add(const Duration(days: 30)),
      ));
      await sessions.recordAnswer(AnswerRecord(
        sessionId: keep,
        posisi: 0,
        tipe: 'NUM-ARI',
        kategori: 'numerik',
        seed: 2,
        kesulitan: Difficulty.easy,
        genVersi: 1,
        opsiDipilih: 0,
        benar: true,
        durasiMs: 1,
        label: SpeedLabel.benarCepat,
      ));

      await DriftBackupService(other).import(text);

      final answers = DriftAnswerRepository(other);
      final oldAnswers = await answers.forSession(old);
      expect(oldAnswers.single.tipe, 'NUM-SEQ',
          reason: 'jawaban sesi sendiri tidak diganti');
      final kept = await answers.forSession(keep);
      expect(kept.single.tipe, 'NUM-ARI');
      final imported = (await allSessions(other))
          .singleWhere((s) => s.id != old && s.id != keep);
      final carried = await answers.forSession(imported.id);
      expect(carried, hasLength(3));
      expect(carried.map((a) => a.tipe).toSet(), {'FIG-MTX'});
      final ids = [
        for (final s in [old, keep, imported.id])
          ...(await answers.forSession(s)).map((a) => a.id),
      ];
      expect(ids.toSet(), hasLength(ids.length), reason: 'id jawaban unik');
    });

    test('pengaturan yang sudah ada di perangkat tidak ditimpa', () async {
      await seed(db);
      final text = await service.export(now);
      final other = await device();
      await DriftSettingsRepository(other).setTheme(ThemeSetting.sistem);

      await DriftBackupService(other).import(text);

      final s = DriftSettingsRepository(other);
      expect(await s.theme(), ThemeSetting.sistem);
      expect(await s.get(SettingKeys.penyediaAi), 'groq',
          reason: 'kunci yang belum ada ditambahkan');
    });

    test('perangkat tanpa profil aktif: tepat satu profil menjadi aktif',
        () async {
      await seed(db);
      final root =
          jsonDecode(await service.export(now)) as Map<String, Object?>;
      final noActive = exportedWith(root, (t) {
        for (final r in t['test_profile']!) {
          (r as Map)['aktif'] = 0;
        }
      });
      final other = await device();
      await DriftBackupService(other).import(jsonEncode(noActive));
      final all = await DriftProfileRepository(other).watchAll().first;
      expect(all.where((p) => p.aktif), hasLength(1));
    });

    test('tabel pengetahuan v1.1 diterima tetapi belum dipakai', () async {
      final root =
          jsonDecode(await service.export(now)) as Map<String, Object?>;
      final withKnowledge = exportedWith(root, (t) {
        t['knowledge_progress'] = [
          {
            'butir_id': 'QA-001',
            'level': 'dasar',
            'terakhir': 1,
            'dikuasai': 1
          },
        ];
      });
      final summary = await service.import(jsonEncode(withKnowledge));
      expect(summary.tabel.containsKey('knowledge_progress'), isFalse);
    });
  });

  group('ringkasan sebelum menggabungkan', () {
    test('preview menghitung tanpa menulis', () async {
      await seed(db);
      final text = await service.export(now);
      final clean = h.memoryDb();
      addTearDown(clean.close);
      final target = DriftBackupService(clean);

      final summary = await target.preview(text);

      expect(summary.versi, 1);
      expect(summary.diekspor, now);
      expect(summary.tabel['test_profile']!.total, 2);
      expect(summary.tabel['test_profile']!.added, 2);
      expect(summary.tabel['answer']!.total, 3);
      expect(summary.added, summary.totalRows);
      final after = await snapshot(clean);
      expect(after['test_profile'], isEmpty);
      expect(after['answer'], isEmpty);
    });

    test('preview pada data yang sama: semua sudah ada', () async {
      await seed(db);
      final summary = await service.preview(await service.export(now));
      expect(summary.added, 0);
      expect(summary.updated, 0);
      expect(summary.tabel['test_profile']!.kept, 2);
    });
  });
}
