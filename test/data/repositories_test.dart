import 'package:drift/drift.dart' show Variable;
import 'package:flutter_test/flutter_test.dart';
import 'package:simulator_psikotes_it/data/db/app_database.dart';
import 'package:simulator_psikotes_it/data/repositories/capture_repository.dart';
import 'package:simulator_psikotes_it/data/repositories/mistake_repository.dart';
import 'package:simulator_psikotes_it/data/repositories/profile_repository.dart';
import 'package:simulator_psikotes_it/data/repositories/session_repository.dart';
import 'package:simulator_psikotes_it/data/repositories/settings_repository.dart';
import 'package:simulator_psikotes_it/domain/models/codes.dart';
import 'package:simulator_psikotes_it/domain/models/notebook.dart';
import 'package:simulator_psikotes_it/domain/models/profile.dart';
import 'package:simulator_psikotes_it/domain/models/session.dart';
import 'package:simulator_psikotes_it/domain/repositories/repositories.dart';

import 'db_helper.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = memoryDb());
  tearDown(() => db.close());

  group('ProfileRepository', () {
    test('profil pertama otomatis aktif, berikutnya tidak', () async {
      final repo = DriftProfileRepository(db);
      final a = await repo.save(profile(nama: 'A'));
      final b = await repo.save(profile(nama: 'B'));
      expect((await repo.active())!.id, a);
      expect((await repo.byId(b))!.aktif, isFalse);
    });

    test('menyimpan profil aktif menonaktifkan yang lain (tepat satu aktif)',
        () async {
      final repo = DriftProfileRepository(db);
      await repo.save(profile(nama: 'A'));
      final b = await repo.save(profile(nama: 'B', aktif: true));
      final all = await repo.watchAll().first;
      expect(all.where((p) => p.aktif).map((p) => p.id), [b]);
    });

    test('setActive memindahkan aktif dan menolak id yang tidak ada', () async {
      final repo = DriftProfileRepository(db);
      final a = await repo.save(profile(nama: 'A'));
      final b = await repo.save(profile(nama: 'B'));
      await repo.setActive(b);
      expect((await repo.active())!.id, b);
      await repo.setActive(a);
      expect((await repo.watchAll().first).where((p) => p.aktif), hasLength(1));
      expect(() => repo.setActive(999), throwsStateError);
      // Gagal tidak boleh meninggalkan keadaan tanpa profil aktif.
      expect((await repo.active())!.id, a);
    });

    test('blueprint, tanggal, dan CV kembali utuh; update tidak mengubah aktif',
        () async {
      final repo = DriftProfileRepository(db);
      final id = await repo.save(profile());
      final p = (await repo.byId(id))!;
      expect(p.role, ProfileRole.qa);
      expect(p.tanggalTes, DateTime.utc(2026, 11, 3));
      expect(p.cvTeks, 'ringkasan CV');
      expect(p.blueprint.subtes, hasLength(2));
      expect(p.blueprint.subtes[1].aktif, isFalse);
      expect(p.blueprint.bobot['verbal'], 0.6);
      await repo.save(profile(nama: 'Baru', id: id));
      final updated = (await repo.byId(id))!;
      expect(updated.nama, 'Baru');
      expect(updated.aktif, isTrue);
    });

    test(
        'save pada profil yang ada tidak menghapus CV; setCv mengisi dan menghapus',
        () async {
      final repo = DriftProfileRepository(db);
      final id = await repo.save(profile());
      final noCv = TestProfile(
        id: id,
        nama: 'Ganti nama',
        role: ProfileRole.qa,
        formatTes: TestFormat.ccat,
        dibuat: t0,
      );
      await repo.save(noCv);
      expect((await repo.byId(id))!.nama, 'Ganti nama');
      expect((await repo.byId(id))!.cvTeks, 'ringkasan CV');
      await repo.setCv(id, null);
      expect((await repo.byId(id))!.cvTeks, isNull);
      await repo.setCv(id, 'CV baru');
      expect((await repo.byId(id))!.cvTeks, 'CV baru');
      expect(() => repo.setCv(99, 'x'), throwsStateError);
    });

    test('watchAll memancarkan perubahan', () async {
      final repo = DriftProfileRepository(db);
      final emissions = <int>[];
      final sub = repo.watchAll().listen((l) => emissions.add(l.length));
      await Future<void>.delayed(Duration.zero);
      await repo.save(profile());
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await sub.cancel();
      expect(emissions, containsAllInOrder([0, 1]));
    });
  });

  group('SessionRepository', () {
    test('sesi belum selesai bisa dilanjutkan dengan rencana dan jawaban',
        () async {
      final s = await seedSession(db);
      final repo = DriftSessionRepository(db);
      await repo.recordAnswer(answer(s.sessionId));
      await repo.recordAnswer(
          answer(s.sessionId, seed: 101, pilih: null, benar: false));
      await repo.updateProgress(s.sessionId, 2,
          deadline: t0.add(const Duration(minutes: 5)));

      final snap = (await repo.unfinished())!;
      expect(snap.session.id, s.sessionId);
      expect(snap.session.posisi, 2);
      expect(snap.session.deadline, t0.add(const Duration(minutes: 5)));
      expect(snap.session.plan.items, hasLength(4));
      expect(snap.session.plan.items.first.seed, 100);
      expect(snap.session.plan.subtes.single.menit, 5);
      expect(snap.answers.map((a) => a.opsiDipilih), [1, null]);
      expect(snap.answers.last.benar, isFalse);
    });

    test('finish menghitung skor dari rencana: soal tak dijawab dihitung salah',
        () async {
      final s = await seedSession(db, items: 4);
      final repo = DriftSessionRepository(db);
      await repo.recordAnswer(answer(s.sessionId, seed: 100));
      await repo.recordAnswer(answer(s.sessionId, seed: 101));
      await repo.recordAnswer(answer(s.sessionId, seed: 102, benar: false));
      final skor =
          await repo.finish(s.sessionId, t0.add(const Duration(minutes: 3)));
      expect(skor, 50.0);
      final done = (await repo.byId(s.sessionId))!;
      expect(done.selesai, t0.add(const Duration(minutes: 3)));
      expect(done.skor, 50.0);
      expect(await repo.unfinished(), isNull);
    });

    test('sesi tanpa jawaban benar berskor 0, bukan galat', () async {
      final s = await seedSession(db);
      expect(await DriftSessionRepository(db).finish(s.sessionId, t0), 0.0);
    });

    test(
        'updateProgress tanpa deadline membiarkan deadline; clearDeadline menghapusnya',
        () async {
      final s = await seedSession(db);
      final repo = DriftSessionRepository(db);
      final deadline = t0.add(const Duration(minutes: 5));
      await repo.updateProgress(s.sessionId, 1, deadline: deadline);
      await repo.updateProgress(s.sessionId, 2);
      var rec = (await repo.byId(s.sessionId))!;
      expect(rec.posisi, 2);
      expect(rec.deadline, deadline);
      await repo.updateProgress(s.sessionId, 3, clearDeadline: true);
      rec = (await repo.byId(s.sessionId))!;
      expect(rec.posisi, 3);
      expect(rec.deadline, isNull);
    });

    test('menjawab ulang soal yang sama menggantikan jawaban, bukan menambah',
        () async {
      final s = await seedSession(db, items: 2);
      final repo = DriftSessionRepository(db);
      await repo
          .recordAnswer(answer(s.sessionId, posisi: 0, benar: false, pilih: 2));
      await repo
          .recordAnswer(answer(s.sessionId, posisi: 0, benar: true, pilih: 1));
      await repo
          .recordAnswer(answer(s.sessionId, posisi: 0, benar: true, pilih: 1));
      final answers = await DriftAnswerRepository(db).forSession(s.sessionId);
      expect(answers, hasLength(1));
      expect(answers.single.opsiDipilih, 1);
      expect(await repo.finish(s.sessionId, t0), 50.0);
    });

    test('jawaban non-engine tanpa refId ditolak', () async {
      final s = await seedSession(db);
      expect(
        () => DriftSessionRepository(db).recordAnswer(
            answer(s.sessionId, sumber: AnswerSource.bank, tipe: 'VRB-SYN')),
        throwsArgumentError,
      );
    });

    test('unfinished disaring menurut profil bila diminta', () async {
      final profiles = DriftProfileRepository(db);
      final a = await profiles.save(profile(nama: 'A'));
      final b = await profiles.save(profile(nama: 'B'));
      final repo = DriftSessionRepository(db);
      final sa = await repo.start(NewSession(
          profileId: a, mode: SessionMode.latihan, plan: plan(), mulai: t0));
      expect((await repo.unfinished(profileId: a))!.session.id, sa);
      expect(await repo.unfinished(profileId: b), isNull);
      expect((await repo.unfinished())!.session.id, sa);
    });

    test('kunci asing ditegakkan: jawaban untuk sesi yang tidak ada ditolak',
        () async {
      await seedSession(db);
      expect(
        () => DriftSessionRepository(db).recordAnswer(answer(999)),
        throwsA(anything),
      );
    });

    test('sesi yang tidak ada ditolak jelas', () async {
      final repo = DriftSessionRepository(db);
      expect(() => repo.finish(5, t0), throwsStateError);
      expect(() => repo.updateProgress(5, 1), throwsStateError);
    });

    test(
        'AnswerRepository: forSession berurutan, since menyaring menurut waktu mulai sesi',
        () async {
      final profileId = await DriftProfileRepository(db).save(profile());
      final sessions = DriftSessionRepository(db);
      final old = await sessions.start(NewSession(
          profileId: profileId,
          mode: SessionMode.latihan,
          plan: plan(),
          mulai: t0));
      final recent = await sessions.start(NewSession(
          profileId: profileId,
          mode: SessionMode.simulasi,
          plan: plan(),
          mulai: t0.add(const Duration(days: 20))));
      await sessions.recordAnswer(answer(old, seed: 1));
      await sessions.recordAnswer(answer(recent, seed: 2));
      await sessions.recordAnswer(answer(recent, seed: 3));

      final repo = DriftAnswerRepository(db);
      expect((await repo.forSession(recent)).map((a) => a.seed), [2, 3]);
      final since = await repo.since(t0.add(const Duration(days: 10)));
      expect(since.map((a) => a.seed), [3, 2]); // terbaru dulu
    });
  });

  group('MistakeRepository', () {
    late DriftMistakeRepository repo;
    late int sessionId;

    setUp(() async {
      repo = DriftMistakeRepository(db);
      sessionId = (await seedSession(db)).sessionId;
    });

    test('jawaban benar tidak membuat kartu', () async {
      expect(await repo.upsertFromAnswer(answer(sessionId), t0), isNull);
      expect(
          await repo.watchDue(t0.add(const Duration(days: 30))).first, isEmpty);
    });

    test(
        'jawaban salah membuat kartu jatuh tempo besok; salah lagi memperbarui, tidak menggandakan',
        () async {
      final wrong = answer(sessionId, seed: 7, benar: false);
      final c1 = (await repo.upsertFromAnswer(wrong, t0))!;
      expect(c1.status, CardStatus.aktif);
      expect(c1.intervalHari, 1);
      expect(c1.streakBenar, 0);
      expect(c1.jatuhTempo, t0.add(const Duration(days: 1)));

      final later = t0.add(const Duration(days: 5));
      final c2 = (await repo.upsertFromAnswer(wrong, later))!;
      expect(c2.id, c1.id);
      expect(c2.jatuhTempo, later.add(const Duration(days: 1)));
      expect(c2.dibuat, t0);
      final due = await repo.watchDue(later.add(const Duration(days: 2))).first;
      expect(due, hasLength(1));
    });

    test('seed berbeda atau tipe berbeda membuat kartu terpisah', () async {
      await repo.upsertFromAnswer(answer(sessionId, seed: 1, benar: false), t0);
      await repo.upsertFromAnswer(answer(sessionId, seed: 2, benar: false), t0);
      await repo.upsertFromAnswer(
          answer(sessionId, seed: 1, benar: false, tipe: 'FIG-SEQ'), t0);
      final due = await repo.watchDue(t0.add(const Duration(days: 2))).first;
      expect(due, hasLength(3));
    });

    test('soal Capture dikenali dari (sumber, ref_id), bukan seed', () async {
      final a = answer(sessionId,
          sumber: AnswerSource.capture,
          refId: 42,
          tipe: 'lipat-kertas',
          benar: false,
          seed: 0);
      final c1 = (await repo.upsertFromAnswer(a, t0))!;
      final c2 =
          (await repo.upsertFromAnswer(a, t0.add(const Duration(days: 1))))!;
      expect(c2.id, c1.id);
      final other = await repo.upsertFromAnswer(
          answer(sessionId,
              sumber: AnswerSource.capture,
              refId: 43,
              tipe: 'lipat-kertas',
              benar: false,
              seed: 0),
          t0);
      expect(other!.id, isNot(c1.id));
    });

    test('watchDue hanya kartu aktif yang sudah jatuh tempo, terlama dulu',
        () async {
      final a = (await repo.upsertFromAnswer(
          answer(sessionId, seed: 1, benar: false), t0))!;
      final b = (await repo.upsertFromAnswer(
          answer(sessionId, seed: 2, benar: false),
          t0.subtract(const Duration(days: 3))))!;
      final now = t0.add(const Duration(hours: 12));
      expect((await repo.watchDue(now).first).map((c) => c.id), [b.id]);
      final later = t0.add(const Duration(days: 2));
      expect((await repo.watchDue(later).first).map((c) => c.id), [b.id, a.id]);
    });

    test(
        'tangga ulangan: benar 3, 7 hari, lalu dikuasai; salah kembali ke 1 hari',
        () async {
      final c = (await repo.upsertFromAnswer(
          answer(sessionId, seed: 9, benar: false), t0))!;
      var now = t0.add(const Duration(days: 1));
      var card = await repo.applyReview(c.id, true, now);
      expect((card.streakBenar, card.intervalHari), (1, 3));
      expect(card.jatuhTempo, now.add(const Duration(days: 3)));

      now = card.jatuhTempo;
      card = await repo.applyReview(c.id, true, now);
      expect((card.streakBenar, card.intervalHari), (2, 7));

      card = await repo.applyReview(c.id, false, now);
      expect((card.streakBenar, card.intervalHari), (0, 1));
      expect(card.status, CardStatus.aktif);

      for (var i = 0; i < 3; i++) {
        card = await repo.applyReview(c.id, true, now);
      }
      expect(card.status, CardStatus.dikuasai);
      expect(card.streakBenar, 3);
      expect(await repo.watchDue(now.add(const Duration(days: 60))).first,
          isEmpty);
    });

    test(
        'butir bank dikenali dari (sumber, tipe, nomor): tidak berlipat dan tidak tertukar',
        () async {
      AnswerRecord bank(String tipe, int nomor) => answer(sessionId,
          sumber: AnswerSource.bank,
          tipe: tipe,
          refId: nomor,
          benar: false,
          seed: 0);
      final a1 = (await repo.upsertFromAnswer(bank('VRB-SYN', 42), t0))!;
      final a2 = (await repo.upsertFromAnswer(bank('VRB-SYN', 42), t0))!;
      final other = (await repo.upsertFromAnswer(bank('VRB-ANA', 42), t0))!;
      expect(a2.id, a1.id);
      expect(other.id, isNot(a1.id));
    });

    test(
        'jawaban salah non-engine tanpa refId ditolak, bukan membuat kartu ganda',
        () async {
      final bad = answer(sessionId,
          sumber: AnswerSource.pengetahuan, tipe: 'KB-QA', benar: false);
      expect(() => repo.upsertFromAnswer(bad, t0), throwsArgumentError);
      expect(
          await repo.watchDue(t0.add(const Duration(days: 2))).first, isEmpty);
    });

    test('kartu yang tidak ada ditolak', () async {
      expect(() => repo.applyReview(77, true, t0), throwsStateError);
    });
  });

  group('CaptureRepository dan CompanyLogRepository', () {
    CapturedQuestion cq(
            {int? id, int? log, int kunci = 1, List<String>? opsi}) =>
        CapturedQuestion(
          id: id,
          teks: 'Lipat kertas dua kali, lalu dilubangi. Hasilnya?',
          opsi: opsi ?? const ['A', 'B', 'C'],
          kunci: kunci,
          pembahasan: 'Karena simetri.',
          kategori: 'lipat kertas',
          fotoPath: '/lokal/foto1.jpg',
          companyLogId: log,
          dibuat: t0,
        );

    test('soal tangkapan tersimpan, dibaca, diperbarui, dan dihapus', () async {
      final repo = DriftCaptureRepository(db);
      final id = await repo.save(cq());
      final c = (await repo.byId(id))!;
      expect(c.opsi, ['A', 'B', 'C']);
      expect(c.kunci, 1);
      expect(c.fotoPath, '/lokal/foto1.jpg');
      expect(c.dibuat, t0);
      await repo.save(cq(id: id, kunci: 2));
      expect((await repo.byId(id))!.kunci, 2);
      expect(await repo.watchAll().first, hasLength(1));
      await repo.delete(id);
      expect(await repo.byId(id), isNull);
    });

    test('soal tidak sah ditolak sebelum menyentuh database', () async {
      final repo = DriftCaptureRepository(db);
      expect(() => repo.save(cq(kunci: 3)), throwsArgumentError);
      expect(() => repo.save(cq(opsi: const ['A'])), throwsArgumentError);
      expect(
          () => repo.save(cq(opsi: List.filled(7, 'x'))), throwsArgumentError);
      expect(await repo.watchAll().first, isEmpty);
    });

    test('catatan tes perusahaan tersimpan dan terhubung ke soal tangkapan',
        () async {
      final logs = DriftCompanyLogRepository(db);
      final logId = await logs.save(CompanyTestLog(
        perusahaan: 'PT Contoh',
        tanggal: DateTime.utc(2026, 10, 20),
        subtes: const ['verbal', 'figural'],
        tipeBaru: const ['lipat kertas'],
        catatan: 'Waktu ketat.',
      ));
      final log = (await logs.byId(logId))!;
      expect(log.subtes, ['verbal', 'figural']);
      expect(log.tipeBaru, ['lipat kertas']);
      expect(log.tanggal, DateTime.utc(2026, 10, 20));

      final captures = DriftCaptureRepository(db);
      final id = await captures.save(cq(log: logId));
      expect((await captures.byId(id))!.companyLogId, logId);
      expect(() => captures.save(cq(log: 999)), throwsA(anything));
    });
  });

  group('SettingsRepository', () {
    test('menyimpan, menimpa, dan memancarkan nilai', () async {
      final repo = DriftSettingsRepository(db);
      expect(await repo.get(SettingKeys.penyediaAi), isNull);
      final seen = <String?>[];
      final sub = repo.watch(SettingKeys.penyediaAi).listen(seen.add);
      await Future<void>.delayed(Duration.zero);
      await repo.set(SettingKeys.penyediaAi, 'gemini');
      await repo.set(SettingKeys.penyediaAi, 'groq');
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await sub.cancel();
      expect(await repo.get(SettingKeys.penyediaAi), 'groq');
      expect(seen.first, isNull);
      expect(seen.last, 'groq');
    });

    test('tema: bawaan terang, nilai tersimpan, nilai rusak kembali ke terang',
        () async {
      final repo = DriftSettingsRepository(db);
      expect(await repo.theme(), ThemeSetting.terang);
      await repo.setTheme(ThemeSetting.gelap);
      expect(await repo.theme(), ThemeSetting.gelap);
      await repo.set(SettingKeys.tema, 'ungu');
      expect(await repo.theme(), ThemeSetting.terang);
    });
  });

  group('skema', () {
    test('indeks yang ditulis di docs/03-data-model.md ada', () async {
      final rows = await db
          .customSelect("SELECT name FROM sqlite_master WHERE type = 'index'")
          .get();
      final names = rows.map((r) => r.read<String>('name')).toSet();
      expect(
        names,
        containsAll([
          'idx_session_profile_mulai',
          'idx_session_selesai',
          'idx_answer_session_posisi',
          'idx_answer_tipe_id',
          'idx_answer_kategori_id',
          'idx_mistake_status_due',
        ]),
      );
    });

    test('ketujuh tabel v1 ada dengan nama dari dokumen', () async {
      final rows = await db
          .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
          .get();
      final names = rows.map((r) => r.read<String>('name')).toSet();
      expect(
        names,
        containsAll([
          'test_profile',
          'session',
          'answer',
          'mistake_card',
          'captured_question',
          'company_test_log',
          'app_setting',
        ]),
      );
    });

    test('waktu disimpan sebagai epoch milidetik UTC', () async {
      final id = await DriftProfileRepository(db).save(profile());
      final raw = await db.customSelect(
          'SELECT dibuat, tanggal_tes FROM test_profile WHERE id = ?',
          variables: [Variable.withInt(id)]).getSingle();
      expect(raw.read<int>('dibuat'), t0.millisecondsSinceEpoch);
      expect(raw.read<int>('tanggal_tes'),
          DateTime.utc(2026, 11, 3).millisecondsSinceEpoch);
    });
  });
}
