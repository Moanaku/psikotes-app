import 'package:flutter_test/flutter_test.dart';
import 'package:question_engine/question_engine.dart';
import 'package:simulator_psikotes_it/domain/models/codes.dart';
import 'package:simulator_psikotes_it/domain/models/session.dart';
import 'package:simulator_psikotes_it/domain/models/session_state.dart';
import 'package:simulator_psikotes_it/domain/providers.dart';
import 'package:simulator_psikotes_it/domain/services/scoring.dart';

import '../data/db_helper.dart' show t0;
import 'session_harness.dart';

void main() {
  late Harness h;

  setUp(() => h = Harness());
  tearDown(() => h.dispose());

  group('timer per subtes (simulasi)', () {
    test('deadline mutlak disimpan saat mulai; sisa waktu = deadline - jam',
        () async {
      await h.start(SessionMode.simulasi, simPlan());
      expect((await h.session()).deadline, t0.add(mins(5)));
      expect(h.s.remaining, mins(5));

      h.clock.advance(const Duration(seconds: 90));
      await h.c.tick();
      expect(h.s.remaining, mins(3.5));
      // Tidak ada penghitung yang ditulis: deadline di database tetap.
      expect((await h.session()).deadline, t0.add(mins(5)));
    });

    test(
        'waktu habis: pindah otomatis ke subtes berikutnya dengan durasi '
        'penuh, soal kosong dicatat dilewati', () async {
      await h.start(SessionMode.simulasi, simPlan());
      await h.c.select(h.rightOption());
      h.clock.advance(mins(5));
      await h.c.tick();

      expect(h.s.subtestIndex, 1);
      expect(h.s.posisi, 3);
      expect(h.s.remaining, mins(4));
      expect(h.s.notice!.subtest.index, 0);
      expect(h.s.notice!.sessionEnded, isFalse);

      final session = await h.session();
      expect(session.posisi, 3);
      expect(session.deadline, t0.add(mins(9)));
      final rows = await h.answers(h.s.sessionId);
      expect(rows[0]!.benar, isTrue);
      for (final p in [1, 2]) {
        expect(rows[p]!.opsiDipilih, isNull);
        expect(rows[p]!.benar, isFalse);
        expect(rows[p]!.label, SpeedLabel.salahLambat);
      }
      h.c.dismissNotice();
      expect(h.s.notice, isNull);
    });

    test('tepat di deadline dihitung habis', () async {
      await h.start(SessionMode.simulasi, simPlan());
      h.clock.advance(mins(5) - const Duration(milliseconds: 1));
      await h.c.tick();
      expect(h.s.subtestIndex, 0);
      expect(h.s.remaining, const Duration(milliseconds: 1));
      h.clock.advance(const Duration(milliseconds: 1));
      await h.c.tick();
      expect(h.s.subtestIndex, 1);
    });

    test('jawaban yang dikirim setelah deadline (sebelum tick) tidak dihitung',
        () async {
      await h.start(SessionMode.simulasi, simPlan());
      final option = h.rightOption();
      h.clock.advance(mins(5) + const Duration(seconds: 1));
      expect(await h.c.select(option), isFalse);
      expect(h.s.subtestIndex, 1);
      final rows = await h.answers(h.s.sessionId);
      expect(rows[0]!.opsiDipilih, isNull);
      expect(rows[3], isNull, reason: 'jawaban tidak pindah ke subtes baru');
    });

    test(
        'navigasi bebas di dalam subtes, tidak bisa kembali ke subtes '
        'sebelumnya', () async {
      await h.start(SessionMode.simulasi, simPlan());
      expect(h.s.canGoBack, isFalse);
      expect(await h.c.goTo(2), isTrue);
      expect(h.s.posisi, 2);
      expect((await h.session()).posisi, 2);
      expect(await h.c.previous(), isTrue);
      expect(h.s.posisi, 1);
      expect(await h.c.goTo(5), isFalse, reason: 'subtes lain');

      await h.c.goTo(2);
      await h.c.next(); // soal terakhir subtes: subtes ditutup
      expect(h.s.subtestIndex, 1);
      expect(h.s.posisi, 3);
      expect(h.s.canGoBack, isFalse);
      expect(await h.c.previous(), isFalse);
      expect(await h.c.goTo(2), isFalse);
      expect(h.s.posisi, 3);
    });

    test('lanjut lebih awal ke subtes berikutnya memberi durasi penuh',
        () async {
      await h.start(SessionMode.simulasi, simPlan());
      h.clock.advance(min1);
      await h.c.goTo(2);
      await h.c.next();
      expect(h.s.remaining, mins(4));
      expect((await h.session()).deadline, t0.add(mins(5)));
    });

    test('subtes terakhir habis: sesi selesai dengan skor', () async {
      await h.start(SessionMode.simulasi, simPlan());
      await h.c.select(h.rightOption());
      await h.c.goTo(2);
      await h.c.next();
      await h.c.next();
      await h.c.next(); // masuk figural
      expect(h.s.subtestIndex, 2);
      expect(h.s.isLastSubtest, isTrue);
      h.clock.advance(mins(3));
      await h.c.tick();

      expect(h.s.finished, isTrue);
      expect(h.s.notice!.sessionEnded, isTrue);
      expect(h.s.remaining, isNull);
      expect(h.s.skor, closeTo(100 / 7, 1e-9));
      final session = await h.session();
      expect(session.selesai, t0.add(mins(3)));
      expect(session.skor, h.s.skor);
      expect(await h.repo.unfinished(), isNull);
      expect(h.activeTimer, isNull, reason: 'penanda waktu berhenti');
      expect((await h.answers(h.s.sessionId)).length, 7);
    });

    test('Berikutnya di soal terakhir subtes terakhir menyelesaikan sesi',
        () async {
      await h.start(SessionMode.simulasi, simPlan());
      for (var i = 0; i < 7; i++) {
        await h.c.select(h.rightOption());
        await h.c.next();
      }
      expect(h.s.finished, isTrue);
      expect(h.s.skor, 100);
      expect(h.s.notice, isNull);
    });

    test(
        'setiap jawaban langsung tersimpan; mengganti pilihan menggantikan '
        'baris', () async {
      await h.start(SessionMode.simulasi, simPlan());
      await h.c.select(h.wrongOption());
      var rows = await h.answers(h.s.sessionId);
      expect(rows[0]!.benar, isFalse);
      await h.c.select(h.rightOption());
      rows = await h.answers(h.s.sessionId);
      expect(rows.length, 1);
      expect(rows[0]!.benar, isTrue);
      expect(rows[0]!.opsiDipilih, h.rightOption());
      expect(h.s.currentAnswer!.benar, isTrue);
      expect(h.s.feedback, isNull, reason: 'pembahasan hanya di akhir');
    });

    test('simulasi tanpa batas waktu di salah satu subtes ditolak', () async {
      await expectLater(
        h.start(SessionMode.simulasi, simPlan(menitLogika: null)),
        throwsArgumentError,
      );
      expect(h.maybe, isNull);
      expect(await h.repo.unfinished(), isNull);
    });

    test('penanda waktu tiap detik memanggil tick', () async {
      await h.start(SessionMode.simulasi, simPlan());
      final timer = h.activeTimer!;
      h.clock.advance(const Duration(seconds: 10));
      timer.fire();
      await h.c.tick(); // menunggu antrean
      expect(h.s.remaining, mins(5) - const Duration(seconds: 10));
    });
  });

  group('pelanjutan setelah proses mati', () {
    test('posisi dan sisa waktu benar dari deadline', () async {
      await h.start(SessionMode.simulasi, simPlan());
      await h.c.goTo(1);
      h.clock.advance(min1);
      await h.c.select(h.wrongOption());
      final id = h.s.sessionId;

      h.kill();
      h.clock.advance(mins(2)); // tertutup 2 menit
      expect(h.maybe, isNull);
      expect(await h.c.resume(), isTrue);
      expect(h.s.sessionId, id);
      expect(h.s.posisi, 1);
      expect(h.s.subtestIndex, 0);
      expect(h.s.remaining, mins(2));
      expect(h.s.answers[1]!.benar, isFalse);
      expect(h.s.question!.seed, 11, reason: 'soal sama dibuat ulang');
      expect(h.activeTimer, isNotNull);
    });

    test('tidak ada sesi yang belum selesai', () async {
      expect(await h.c.resume(), isFalse);
      expect(h.maybe, isNull);
    });

    test(
        'kedaluwarsa saat tertutup: subtes berikutnya mulai saat dibuka '
        'dengan durasi penuh', () async {
      await h.start(SessionMode.simulasi, simPlan());
      await h.c.select(h.rightOption());
      h.kill();
      h.clock.advance(mins(30));
      expect(await h.c.resume(), isTrue);
      expect(h.s.subtestIndex, 1);
      expect(h.s.posisi, 3);
      expect(h.s.remaining, mins(4));
      expect(h.s.notice!.subtest.index, 0);
      expect((await h.session()).deadline, t0.add(mins(34)));
      final rows = await h.answers(h.s.sessionId);
      expect(rows[0]!.benar, isTrue);
      expect(rows[1]!.opsiDipilih, isNull);
      expect(rows[2]!.opsiDipilih, isNull);
    });

    test('subtes terakhir kedaluwarsa saat tertutup: sesi selesai saat dibuka',
        () async {
      await h.start(SessionMode.simulasi, simPlan());
      await h.c.goTo(2);
      await h.c.next();
      await h.c.next();
      await h.c.next();
      expect(h.s.subtestIndex, 2);
      h.kill();
      h.clock.advance(const Duration(days: 2));
      expect(await h.c.resume(), isTrue);
      expect(h.s.finished, isTrue);
      expect(h.s.notice!.sessionEnded, isTrue);
      expect(h.s.skor, 0);
      expect(await h.repo.unfinished(), isNull);
      expect(h.activeTimer, isNull);
    });

    test('rotasi atau rebuild membaca keadaan yang sama tanpa menulis ulang',
        () async {
      await h.start(SessionMode.simulasi, simPlan());
      final before = h.s;
      h.clock.advance(min1);
      // Membaca ulang provider (seperti widget yang dibangun ulang) tidak
      // mengubah sesi; hanya tick yang membaca jam.
      expect(h.s, same(before));
      await h.c.tick();
      expect(h.s.remaining, mins(4));
    });
  });

  group('perubahan jam perangkat', () {
    test(
        'jam dimundurkan saat app berjalan: sisa waktu tidak bertambah, '
        'deadline di database ikut digeser', () async {
      await h.start(SessionMode.simulasi, simPlan());
      h.clock.advance(min1);
      await h.c.tick();
      h.clock.shiftWall(const Duration(hours: -1));
      await h.c.tick();
      expect(h.s.remaining, mins(4));
      h.clock.advance(const Duration(seconds: 30));
      await h.c.tick();
      expect(h.s.remaining, mins(3.5));
      expect((await h.session()).deadline,
          t0.add(mins(5)).subtract(const Duration(hours: 1)));

      // Deadline yang digeser tetap benar setelah proses mati.
      h.kill();
      h.clock.advance(const Duration(seconds: 30));
      await h.c.resume();
      expect(h.s.remaining, mins(3));
    });

    test('jam dimajukan saat app berjalan: waktu tidak hilang', () async {
      await h.start(SessionMode.simulasi, simPlan());
      h.clock.advance(min1);
      await h.c.tick();
      h.clock.shiftWall(const Duration(hours: 2));
      await h.c.tick();
      expect(h.s.subtestIndex, 0);
      expect(h.s.remaining, mins(4));
      expect((await h.session()).deadline,
          t0.add(mins(5)).add(const Duration(hours: 2)));
    });

    test('jam berubah tepat sebelum menjawab: jawaban tetap masuk', () async {
      await h.start(SessionMode.simulasi, simPlan());
      h.clock.advance(min1);
      h.clock.shiftWall(const Duration(hours: 3));
      expect(await h.c.select(h.rightOption()), isTrue);
      expect(h.s.answers[0]!.durasiMs, 60000);
      expect(h.s.remaining, mins(4));
    });

    test('geser kecil di bawah toleransi diterima apa adanya', () async {
      await h.start(SessionMode.simulasi, simPlan());
      h.clock.advance(min1);
      h.clock.shiftWall(const Duration(seconds: 1));
      await h.c.tick();
      expect(h.s.remaining, mins(4) - const Duration(seconds: 1));
    });

    test('jam dimundurkan saat di latar belakang: dikoreksi', () async {
      await h.start(SessionMode.simulasi, simPlan());
      h.clock.advance(min1);
      await h.c.onPaused();
      h.clock.advance(min1);
      h.clock.shiftWall(mins(-30));
      await h.c.onResumed();
      expect(h.s.remaining, mins(3));
    });

    test(
        'jam dimundurkan saat app tertutup: sisa waktu paling banyak durasi '
        'subtes', () async {
      await h.start(SessionMode.simulasi, simPlan());
      h.clock.advance(min1);
      h.kill();
      h.clock.shiftWall(const Duration(hours: -1));
      await h.c.resume();
      expect(h.s.remaining, mins(5));
      expect((await h.session()).deadline, h.clock.now().add(mins(5)));
    });

    test(
        'jam dimajukan saat app tertutup: dianggap waktu berlalu (tidak bisa '
        'dibedakan dari app tertutup lama, A46)', () async {
      await h.start(SessionMode.simulasi, simPlan());
      h.kill();
      h.clock.shiftWall(mins(10));
      await h.c.resume();
      expect(h.s.subtestIndex, 1);
      expect(h.s.remaining, mins(4));
    });

    test('zona waktu tidak berpengaruh: semua waktu UTC', () async {
      await h.start(SessionMode.simulasi, simPlan());
      final s = await h.session();
      expect(s.deadline!.isUtc, isTrue);
      expect(h.s.deadline!.isUtc, isTrue);
    });
  });

  group('jeda dan lanjut (latar belakang, layar mati)', () {
    test('perangkat tidur: waktu tidur ikut dihitung', () async {
      await h.start(SessionMode.simulasi, simPlan());
      await h.c.onPaused();
      expect(h.activeTimer, isNull);
      h.clock.sleep(mins(2));
      await h.c.onResumed();
      expect(h.s.remaining, mins(3));
      expect(h.activeTimer, isNotNull);
    });

    test('latar belakang tanpa tidur: waktu tetap berjalan', () async {
      await h.start(SessionMode.simulasi, simPlan());
      await h.c.onPaused();
      h.clock.advance(mins(2));
      await h.c.onResumed();
      expect(h.s.remaining, mins(3));
    });

    test('tidur melewati deadline: subtes pindah saat kembali', () async {
      await h.start(SessionMode.simulasi, simPlan());
      await h.c.onPaused();
      h.clock.sleep(mins(6));
      await h.c.onResumed();
      expect(h.s.subtestIndex, 1);
      expect(h.s.remaining, mins(4));
      expect(h.s.notice, isNotNull);
    });

    test('tanpa onPaused, lompatan maju tanpa jeda dianggap ubah jam',
        () async {
      await h.start(SessionMode.simulasi, simPlan());
      h.clock.sleep(mins(2));
      await h.c.tick();
      expect(h.s.remaining, mins(5));
    });

    test('waktu di latar belakang tidak masuk durasi jawaban', () async {
      await h.start(SessionMode.simulasi, simPlan());
      h.clock.advance(const Duration(seconds: 10));
      await h.c.onPaused();
      h.clock.advance(mins(2));
      await h.c.onResumed();
      h.clock.advance(const Duration(seconds: 5));
      await h.c.select(h.rightOption());
      expect(h.s.answers[0]!.durasiMs, 15000);
    });

    test('durasi soal dilewati dipotong di deadline', () async {
      await h.start(SessionMode.simulasi, simPlan());
      h.clock.advance(mins(1));
      await h.c.goTo(1);
      h.clock.advance(mins(10));
      await h.c.tick();
      final rows = await h.answers(h.s.sessionId);
      expect(rows[0]!.durasiMs, 60000);
      expect(rows[1]!.durasiMs, 4 * 60000);
      expect(rows[2]!.durasiMs, 0);
    });

    test('waktu melihat soal dijumlah lintas kunjungan', () async {
      await h.start(SessionMode.simulasi, simPlan());
      h.clock.advance(const Duration(seconds: 20));
      await h.c.goTo(1);
      h.clock.advance(const Duration(seconds: 30));
      await h.c.goTo(0);
      h.clock.advance(const Duration(seconds: 5));
      await h.c.select(h.rightOption());
      expect(h.s.answers[0]!.durasiMs, 25000);
    });
  });

  group('mode latihan', () {
    test('tanpa timer: tanpa deadline, waktu lama tidak memindahkan subtes',
        () async {
      await h.start(SessionMode.latihan, practicePlan());
      expect(h.s.deadline, isNull);
      expect(h.s.remaining, isNull);
      expect((await h.session()).deadline, isNull);
      h.clock.advance(const Duration(days: 1));
      await h.c.tick();
      expect(h.s.posisi, 0);
      expect(h.s.finished, isFalse);
    });

    test(
        'kirim aktif setelah memilih; benar atau salah langsung; lanjut '
        'sebelum kirim ditolak', () async {
      await h.start(SessionMode.latihan, practicePlan());
      expect(h.s.canSubmit, isFalse);
      await expectLater(h.c.next(), throwsStateError);
      await h.c.select(h.wrongOption());
      expect(h.s.canSubmit, isTrue);
      expect(await h.repo.byId(h.s.sessionId), isNotNull);
      expect(await h.answers(h.s.sessionId), isEmpty,
          reason: 'pilihan belum dikirim');

      await h.c.submit();
      expect(h.s.feedback!.benar, isFalse);
      expect(h.s.feedback!.correctIndex, h.s.question!.correctIndex);
      expect(h.s.question!.explanation, isNotEmpty);
      expect(h.s.canSubmit, isFalse);
      expect(await h.c.select(h.rightOption()), isFalse,
          reason: 'jawaban terkirim tidak bisa diganti');
      expect((await h.answers(h.s.sessionId))[0]!.benar, isFalse);

      await h.c.next();
      expect(h.s.posisi, 1);
      expect(h.s.feedback, isNull);
      expect(h.s.canGoBack, isFalse);
      expect(await h.c.goTo(0), isFalse);
    });

    test('dibuka ulang setelah kirim: umpan balik tampil lagi', () async {
      await h.start(SessionMode.latihan, practicePlan());
      await h.c.select(h.rightOption());
      await h.c.submit();
      h.kill();
      await h.c.resume();
      expect(h.s.posisi, 0);
      expect(h.s.feedback!.benar, isTrue);
      await h.c.next();
      expect(h.s.posisi, 1);
    });

    test('latihan sampai akhir: skor dari semua soal', () async {
      await h.start(SessionMode.latihan, practicePlan());
      await h.c.select(h.rightOption());
      await h.c.submit();
      await h.c.next();
      await h.c.select(h.wrongOption());
      await h.c.submit();
      await h.c.next();
      expect(h.s.subtestIndex, 1);
      await h.c.select(h.rightOption());
      await h.c.submit();
      await h.c.next();
      expect(h.s.finished, isTrue);
      expect(h.s.skor, closeTo(200 / 3, 1e-9));
    });

    test('timer latihan bisa dimatikan dan tetap mati setelah dibuka ulang',
        () async {
      await h.start(SessionMode.latihan, practicePlan(menit: 2));
      expect(h.s.remaining, mins(2));
      h.clock.advance(min1);
      await h.c.disableTimer();
      expect(h.s.timerEnabled, isFalse);
      expect(h.s.remaining, isNull);
      expect((await h.session()).deadline, isNull);

      h.kill();
      h.clock.advance(const Duration(hours: 1));
      await h.c.resume();
      expect(h.s.timerEnabled, isFalse);
      expect(h.s.posisi, 0);

      // Subtes berikutnya juga tanpa timer.
      await h.c.select(h.rightOption());
      await h.c.submit();
      await h.c.next();
      await h.c.select(h.rightOption());
      await h.c.submit();
      await h.c.next();
      expect(h.s.subtestIndex, 1);
      expect(h.s.deadline, isNull);
    });

    test('timer simulasi tidak bisa dimatikan', () async {
      await h.start(SessionMode.simulasi, simPlan());
      await expectLater(h.c.disableTimer(), throwsStateError);
      expect((await h.session()).deadline, isNotNull);
    });
  });

  group('soal gagal dibuat', () {
    test('questionFailed tanpa pesan exception; soal bisa dilewati', () async {
      await h.dispose();
      h = Harness(builder: (item) {
        if (item.seed == 41) throw StateError('generator rusak');
        return buildFromRegistry(item);
      });
      await h.start(SessionMode.latihan, practicePlan());
      await h.c.select(h.rightOption());
      await h.c.submit();
      await h.c.next();
      expect(h.s.questionFailed, isTrue);
      expect(h.s.question, isNull);
      expect(h.s.canSubmit, isFalse);
      await h.c.next();
      expect(h.s.posisi, 2);
      expect((await h.answers(h.s.sessionId))[1]!.opsiDipilih, isNull);
    });

    test('versi generator berbeda tidak dibuat ulang diam-diam', () {
      final i = item(QuestionType.figMtx, 1, 'figural');
      final old = PlanItem(
        type: i.type,
        seed: i.seed,
        difficulty: i.difficulty,
        genVersi: i.genVersi + 1,
        subtes: i.subtes,
      );
      expect(() => buildFromRegistry(old), throwsA(isA<QuestionUnavailable>()));
    });
  });

  group('penilaian', () {
    test('label memakai median riwayat 30 hari, tanpa sesi berjalan', () async {
      // Sesi lama: NUM-SEQ benar dalam 4, 6, 8 detik (median 6 detik).
      final pid = await h.profile();
      final old = await h.repo.start(NewSession(
        profileId: pid,
        mode: SessionMode.latihan,
        plan: simPlan(),
        mulai: t0.subtract(const Duration(days: 3)),
      ));
      for (final (p, ms) in [(0, 4000), (1, 6000), (2, 8000)]) {
        await h.repo.recordAnswer(AnswerRecord(
          sessionId: old,
          posisi: p,
          tipe: 'NUM-SEQ',
          kategori: 'numerik',
          seed: p,
          kesulitan: Difficulty.easy,
          genVersi: 1,
          opsiDipilih: 0,
          benar: true,
          durasiMs: ms,
          label: SpeedLabel.benarCepat,
        ));
      }
      await h.repo.finish(old, t0.subtract(const Duration(days: 3)));

      await h.start(SessionMode.simulasi, simPlan());
      h.clock.advance(const Duration(seconds: 6));
      await h.c.select(h.rightOption());
      expect(h.s.answers[0]!.label, SpeedLabel.benarCepat);
      await h.c.goTo(1);
      h.clock.advance(const Duration(seconds: 7));
      await h.c.select(h.wrongOption());
      expect(h.s.answers[1]!.label, SpeedLabel.salahLambat);
    });

    test('skor ringkasan sama dengan skor repository', () async {
      await h.start(SessionMode.simulasi, simPlan());
      await h.c.select(h.rightOption());
      await h.c.goTo(1);
      await h.c.select(h.wrongOption());
      final skor = await h.c.finish();
      final summary = Scoring.summarize(
        h.s.plan,
        (await h.answers(h.s.sessionId)).values,
      );
      expect(summary.skor, skor);
      expect(summary.total, 7);
      expect(summary.tidakDijawab, 5);
      expect(summary.kuadran.values.reduce((a, b) => a + b), 7);
      expect(summary.perKategori['numerik']!.benar, 1);
      expect(summary.perKategori['numerik']!.jumlah, 3);
      expect(h.s.finished, isTrue);
      expect(await h.c.finish(), skor, reason: 'selesai dua kali aman');
    });
  });

  group('membuka sesi lewat id (layar sesi)', () {
    test('sesi yang sedang berjalan dipakai apa adanya', () async {
      await h.start(SessionMode.simulasi, simPlan());
      final id = h.s.sessionId;
      await h.c.select(h.rightOption());
      expect(await h.c.open(id), SessionOpen.opened);
      expect(h.s.answers[0], isNotNull, reason: 'tidak dimuat ulang');
    });

    test('proses mati: sesi dimuat dari database dengan posisi dan waktu',
        () async {
      await h.start(SessionMode.simulasi, simPlan());
      final id = h.s.sessionId;
      await h.c.select(h.rightOption());
      await h.c.next();
      h.clock.advance(mins(2));

      h.kill();
      expect(h.maybe, isNull);
      expect(await h.c.open(id), SessionOpen.opened);
      expect(h.s.posisi, 1);
      expect(h.s.remaining, mins(3));
      expect(h.s.answers[0]!.benar, isTrue);
    });

    test('id yang tidak ada: notFound; sesi selesai: finished', () async {
      expect(await h.c.open(404), SessionOpen.notFound);
      await h.start(SessionMode.latihan, practicePlan());
      final id = h.s.sessionId;
      await h.c.finish();
      h.kill();
      expect(await h.c.open(id), SessionOpen.finished);
      expect(h.maybe, isNull, reason: 'sesi selesai tidak dimuat');
    });

    test('membuka sesi lain mengganti sesi yang berjalan', () async {
      await h.start(SessionMode.latihan, practicePlan());
      final first = h.s.sessionId;
      h.c.close();
      await h.start(SessionMode.simulasi, simPlan());
      final second = h.s.sessionId;
      expect(await h.c.open(first), SessionOpen.opened);
      expect(h.s.sessionId, first);
      expect(h.s.sessionId, isNot(second));
    });

    test('close(sessionId) hanya menutup sesi yang cocok', () async {
      await h.start(SessionMode.latihan, practicePlan());
      final id = h.s.sessionId;
      h.c.close(sessionId: id + 1);
      expect(h.maybe, isNotNull, reason: 'layar lama tidak menutup sesi baru');
      h.c.close(sessionId: id);
      expect(h.maybe, isNull);
    });
  });

  group('soal yang gagal dibuat', () {
    test('retryQuestion membuat ulang soal bila generator pulih', () async {
      var failing = true;
      await h.dispose();
      h = Harness(builder: (item) {
        if (failing) throw StateError('gagal');
        return buildFromRegistry(item);
      });
      final flaky = h;
      await flaky.start(SessionMode.latihan, practicePlan());
      expect(flaky.s.questionFailed, isTrue);
      expect(await flaky.c.retryQuestion(), isFalse);
      expect(flaky.s.questionFailed, isTrue);

      failing = false;
      expect(await flaky.c.retryQuestion(), isTrue);
      expect(flaky.s.questionFailed, isFalse);
      expect(flaky.s.question, isNotNull);
      expect(await flaky.c.retryQuestion(), isFalse,
          reason: 'soal sudah ada: tidak ada yang berubah');
    });

    test('soal gagal bisa dilewati tanpa mengirim jawaban', () async {
      await h.dispose();
      h = Harness(builder: (item) => throw StateError('gagal'));
      final broken = h;
      await broken.start(SessionMode.latihan, practicePlan());
      expect(await broken.c.next(), isTrue);
      expect(broken.s.posisi, 1);
      expect(broken.s.answers, isEmpty);
    });
  });
}
