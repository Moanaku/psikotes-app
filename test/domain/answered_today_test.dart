import 'package:flutter_test/flutter_test.dart';
import 'package:simulator_psikotes_it/data/db/app_database.dart';
import 'package:simulator_psikotes_it/data/repositories/profile_repository.dart';
import 'package:simulator_psikotes_it/data/repositories/session_repository.dart';
import 'package:simulator_psikotes_it/domain/models/codes.dart';
import 'package:simulator_psikotes_it/domain/models/session.dart';
import 'package:simulator_psikotes_it/domain/services/answered_today.dart';

import '../data/db_helper.dart';
import '../support/fake_clock.dart';

/// Waktu dinding setempat sebagai UTC: hasilnya sama di zona waktu mana pun.
DateTime local(int d, int h, int m) => DateTime(2026, 10, d, h, m).toUtc();

void main() {
  late AppDatabase db;
  late DriftSessionRepository sessions;
  late int profileId;

  setUp(() async {
    db = memoryDb();
    sessions = DriftSessionRepository(db);
    profileId = await DriftProfileRepository(db).save(profile(aktif: true));
  });
  tearDown(() => db.close());

  Future<int> startSession(DateTime mulai, {int? profile}) =>
      sessions.start(NewSession(
        profileId: profile ?? profileId,
        mode: SessionMode.latihan,
        plan: plan(),
        mulai: mulai,
      ));

  Future<void> record(int session, int seed, DateTime? at, {int? pilih = 1}) =>
      sessions.recordAnswer(answer(
        session,
        seed: seed,
        pilih: pilih,
        benar: pilih != null,
        dijawabPada: at,
      ));

  AnsweredToday serviceAt(FakeClock clock) =>
      AnsweredToday(DriftAnswerRepository(db), clock);

  test('jawaban kemarin tidak dihitung, jawaban hari ini dihitung', () async {
    final s = await startSession(local(21, 20, 0));
    await record(s, 1, local(21, 20, 5));
    await record(s, 2, local(22, 9, 0));
    await record(s, 3, local(22, 9, 1));
    expect(await serviceAt(FakeClock(local(22, 12, 0))).count(), 2);
    expect(await serviceAt(FakeClock(local(21, 21, 0))).count(), 1);
  });

  test('batas tengah malam: 23:59 milik hari itu, 00:01 hari berikutnya',
      () async {
    final s = await startSession(local(22, 23, 50));
    await record(s, 1, local(22, 23, 59));
    final clock = FakeClock(local(22, 23, 59));
    final service = serviceAt(clock);
    expect(await service.count(), 1);

    clock.advance(const Duration(minutes: 2)); // 00:01 tanggal 23
    expect(await service.count(), 0, reason: 'hari baru mulai dari nol');
    await record(s, 2, local(23, 0, 1));
    expect(await service.count(), 1);
  });

  test('soal dilewati atau tanpa jawaban tidak dihitung (A63)', () async {
    final s = await startSession(local(22, 8, 0));
    await record(s, 1, local(22, 8, 1));
    await record(s, 2, local(22, 8, 2), pilih: null);
    await record(s, 3, null, pilih: null);
    expect(await serviceAt(FakeClock(local(22, 12, 0))).count(), 1);
  });

  test('menjawab ulang soal yang sama dihitung sekali', () async {
    final s = await startSession(local(22, 8, 0));
    await sessions
        .recordAnswer(answer(s, seed: 1, dijawabPada: local(22, 8, 1)));
    await sessions.recordAnswer(
        answer(s, seed: 1, pilih: 2, dijawabPada: local(22, 8, 5)));
    expect(await serviceAt(FakeClock(local(22, 12, 0))).count(), 1);
  });

  test('sesi belum selesai dan profil lain ikut dihitung', () async {
    final other = await DriftProfileRepository(db).save(profile(nama: 'Lain'));
    final open = await startSession(local(22, 8, 0));
    final done = await startSession(local(22, 9, 0), profile: other);
    await record(open, 1, local(22, 8, 1));
    await record(done, 2, local(22, 9, 1));
    await sessions.finish(done, local(22, 9, 30));
    expect(await serviceAt(FakeClock(local(22, 12, 0))).count(), 2);
  });

  test('sesi dimulai kemarin tetapi dijawab hari ini dihitung hari ini',
      () async {
    final s = await startSession(local(21, 23, 55));
    await record(s, 1, local(21, 23, 58));
    await record(s, 2, local(22, 0, 2));
    expect(await serviceAt(FakeClock(local(22, 10, 0))).count(), 1);
  });

  test('jawaban lama tanpa waktu jatuh ke waktu mulai sesinya', () async {
    final s = await startSession(local(22, 8, 0));
    await record(s, 1, null);
    final old = await startSession(local(20, 8, 0));
    await record(old, 2, null);
    expect(await serviceAt(FakeClock(local(22, 12, 0))).count(), 1);
  });
}
