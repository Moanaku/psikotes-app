import 'package:flutter_test/flutter_test.dart';
import 'package:question_engine/question_engine.dart';
import 'package:simulator_psikotes_it/domain/models/codes.dart';
import 'package:simulator_psikotes_it/domain/models/session.dart';
import 'package:simulator_psikotes_it/domain/services/speed_labeler.dart';

import '../support/fake_repositories.dart';
import '../support/fixtures.dart';
import '../support/pump_app.dart' show appNow;

/// Satu sesi pada [mulai] dengan jawaban untuk tiap (benar, ms).
Future<int> sessionWith(
  FakeSessionRepository repo,
  DateTime mulai,
  List<(bool, int)> results, {
  QuestionType type = QuestionType.numSeq,
}) async {
  final plan = SessionPlan(items: [
    for (var i = 0; i < results.length; i++) planItem(type, 100 + i, 'numerik'),
  ]);
  final id = await repo.start(NewSession(
    profileId: 1,
    mode: SessionMode.latihan,
    plan: plan,
    mulai: mulai,
  ));
  for (var i = 0; i < results.length; i++) {
    await repo.recordAnswer(answerFor(
      plan.items[i],
      i,
      sessionId: id,
      benar: results[i].$1,
      ms: results[i].$2,
    ));
  }
  return id;
}

void main() {
  late FakeSessionRepository repo;
  late SpeedLabeler labeler;

  setUp(() {
    repo = FakeSessionRepository();
    labeler = SpeedLabeler(repo);
  });

  test('ambang = median durasi jawaban benar tipe itu', () async {
    await sessionWith(repo, appNow.subtract(const Duration(days: 2)), [
      (true, 20000),
      (true, 40000),
      (true, 30000),
      (false, 1000), // salah tidak ikut median
    ]);
    final t = await labeler.at(appNow);
    expect(t.medians['NUM-SEQ'], 30000);
    expect(t.targetMs('NUM-SEQ', 45), 30000);
  });

  test('jumlah genap: rata-rata dua nilai tengah dibulatkan ke bawah',
      () async {
    await sessionWith(repo, appNow.subtract(const Duration(days: 1)), [
      (true, 10000),
      (true, 25001),
    ]);
    expect((await labeler.at(appNow)).medians['NUM-SEQ'], 17500);
  });

  test('belum ada data: estimatedSeconds engine', () async {
    final t = await labeler.at(appNow);
    expect(t.medians, isEmpty);
    expect(t.targetMs('FIG-MTX', 45), 45000);
    // Hanya jawaban salah: tetap belum ada data.
    await sessionWith(repo, appNow, [(false, 5000)]);
    expect((await labeler.at(appNow)).targetMs('NUM-SEQ', 45), 45000);
  });

  test('hanya 30 hari terakhir yang dihitung', () async {
    await sessionWith(
        repo, appNow.subtract(const Duration(days: 31)), [(true, 90000)]);
    await sessionWith(
        repo, appNow.subtract(const Duration(days: 29)), [(true, 20000)]);
    expect((await labeler.at(appNow)).medians['NUM-SEQ'], 20000);
  });

  test('tiap tipe punya ambang sendiri', () async {
    await sessionWith(repo, appNow, [(true, 20000)]);
    await sessionWith(repo, appNow, [(true, 60000)], type: QuestionType.logSyl);
    final t = await labeler.at(appNow);
    expect(t.targetMs('NUM-SEQ', 45), 20000);
    expect(t.targetMs('LOG-SYL', 60), 60000);
    expect(t.targetMs('NUM-ARI', 35), 35000);
  });

  test('sesi yang sedang berjalan tidak dihitung', () async {
    final id = await sessionWith(repo, appNow, [(true, 5000)]);
    expect((await labeler.at(appNow, excludeSession: id)).medians, isEmpty);
  });

  test('forSession: hanya riwayat sebelum sesi itu mulai', () async {
    final early = await sessionWith(
        repo, appNow.subtract(const Duration(days: 3)), [(true, 20000)]);
    final target = await sessionWith(
        repo, appNow.subtract(const Duration(days: 2)), [(true, 50000)]);
    await sessionWith(
        repo, appNow.subtract(const Duration(days: 1)), [(true, 90000)]);
    final session = (await repo.byId(target))!;
    final t = await labeler.forSession(session);
    expect(early, lessThan(target));
    expect(t.medians['NUM-SEQ'], 20000,
        reason: 'sesi sendiri dan sesi sesudahnya tidak ikut');
  });

  group('label', () {
    const t = SpeedThresholds({'NUM-SEQ': 30000});

    SpeedLabel label(bool benar, int ms, {bool dijawab = true}) => t.label(
          tipe: 'NUM-SEQ',
          estimatedSeconds: 45,
          benar: benar,
          dijawab: dijawab,
          durasiMs: ms,
        );

    test('empat label dari ambang; sama dengan ambang berarti cepat', () {
      expect(label(true, 30000), SpeedLabel.benarCepat);
      expect(label(true, 30001), SpeedLabel.benarLambat);
      expect(label(false, 29999), SpeedLabel.salahCepat);
      expect(label(false, 30001), SpeedLabel.salahLambat);
    });

    test('dilewati selalu salah-lambat', () {
      expect(label(false, 1000, dijawab: false), SpeedLabel.salahLambat);
    });

    test('tipe tanpa median memakai estimatedSeconds', () {
      expect(
        t.label(
            tipe: 'FIG-MTX',
            estimatedSeconds: 45,
            benar: true,
            dijawab: true,
            durasiMs: 45000),
        SpeedLabel.benarCepat,
      );
      expect(
        t.label(
            tipe: 'FIG-MTX',
            estimatedSeconds: 45,
            benar: true,
            dijawab: true,
            durasiMs: 45001),
        SpeedLabel.benarLambat,
      );
    });
  });
}
