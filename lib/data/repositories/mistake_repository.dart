import 'package:drift/drift.dart';

import '../../domain/models/codes.dart';
import '../../domain/models/notebook.dart';
import '../../domain/models/session.dart';
import '../../domain/repositories/repositories.dart';
import '../../domain/services/sm2_scheduler.dart';
import '../db/app_database.dart';

DateTime _utc(int ms) => DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);

MistakeCard _card(MistakeCardRow r) => MistakeCard(
      id: r.id,
      tipe: r.tipe,
      kategori: r.kategori,
      seed: r.seed,
      sumber: AnswerSource.fromCode(r.sumber),
      refId: r.refId,
      jatuhTempo: _utc(r.jatuhTempo),
      intervalHari: r.intervalHari,
      streakBenar: r.streakBenar,
      status: CardStatus.fromCode(r.status),
      dibuat: _utc(r.dibuat),
    );

class DriftMistakeRepository implements MistakeRepository {
  DriftMistakeRepository(this._db);

  final AppDatabase _db;

  @override
  Stream<List<MistakeCard>> watchDue(DateTime now) {
    final q = _db.select(_db.mistakeCardTable)
      ..where((t) =>
          t.status.equals(CardStatus.aktif.code) &
          t.jatuhTempo.isSmallerOrEqualValue(now.millisecondsSinceEpoch))
      ..orderBy([
        (t) => OrderingTerm.asc(t.jatuhTempo),
        (t) => OrderingTerm.asc(t.id)
      ]);
    return q.watch().map((rows) => rows.map(_card).toList());
  }

  @override
  Future<MistakeCard?> byId(int id) async {
    final row = await (_db.select(_db.mistakeCardTable)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _card(row);
  }

  /// Kartu soal engine dikenali dari (tipe, seed); soal lain (Capture, bank,
  /// pengetahuan) dari (sumber, tipe, ref_id). Butir bank ber-ID teks memakai
  /// tipenya (`VRB-SYN`) dan nomornya sebagai ref_id.
  Expression<bool> _sameQuestion($MistakeCardTableTable t, AnswerRecord a) {
    final bySource = t.sumber.equals(a.sumber.code) & t.tipe.equals(a.tipe);
    if (a.sumber == AnswerSource.engine) {
      return bySource & t.seed.equals(a.seed);
    }
    return bySource & t.refId.equals(a.refId!);
  }

  @override
  Future<MistakeCard?> findFor(AnswerRecord a) async {
    if (a.sumber != AnswerSource.engine && a.refId == null) return null;
    final row = await (_db.select(_db.mistakeCardTable)
          ..where((t) => _sameQuestion(t, a))
          ..limit(1))
        .getSingleOrNull();
    return row == null ? null : _card(row);
  }

  @override
  Future<void> delete(int cardId) =>
      (_db.delete(_db.mistakeCardTable)..where((t) => t.id.equals(cardId)))
          .go();

  @override
  Future<MistakeCard?> upsertFromAnswer(
    AnswerRecord a,
    DateTime now, {
    bool force = false,
  }) async {
    if (a.benar && !force) return null;
    if (a.sumber != AnswerSource.engine && a.refId == null) {
      throw ArgumentError('jawaban ${a.sumber.code} wajib punya refId');
    }
    return _db.transaction(() async {
      final s = Sm2Scheduler.afterWrong(now);
      final existing = await (_db.select(_db.mistakeCardTable)
            ..where((t) => _sameQuestion(t, a))
            ..limit(1))
          .getSingleOrNull();
      final fields = MistakeCardTableCompanion(
        jatuhTempo: Value(s.jatuhTempo.millisecondsSinceEpoch),
        intervalHari: Value(s.intervalHari),
        streakBenar: Value(s.streakBenar),
        status: Value(s.status.code),
      );
      late int id;
      if (existing == null) {
        id = await _db.into(_db.mistakeCardTable).insert(
              MistakeCardTableCompanion.insert(
                tipe: a.tipe,
                kategori: a.kategori,
                seed: Value(a.seed),
                sumber: a.sumber.code,
                refId: Value(a.refId),
                jatuhTempo: s.jatuhTempo.millisecondsSinceEpoch,
                intervalHari: s.intervalHari,
                streakBenar: s.streakBenar,
                status: s.status.code,
                dibuat: now.millisecondsSinceEpoch,
              ),
            );
      } else {
        id = existing.id;
        await (_db.update(_db.mistakeCardTable)..where((t) => t.id.equals(id)))
            .write(fields);
      }
      return (await byId(id))!;
    });
  }

  @override
  Future<MistakeCard> applyReview(int cardId, bool correct, DateTime now) =>
      _db.transaction(() async {
        final card = await byId(cardId);
        if (card == null) throw StateError('kartu $cardId tidak ada');
        final next = Sm2Scheduler.afterReview(
          CardSchedule(
            jatuhTempo: card.jatuhTempo,
            intervalHari: card.intervalHari,
            streakBenar: card.streakBenar,
            status: card.status,
          ),
          correct,
          now,
        );
        await (_db.update(_db.mistakeCardTable)
              ..where((t) => t.id.equals(cardId)))
            .write(MistakeCardTableCompanion(
          jatuhTempo: Value(next.jatuhTempo.millisecondsSinceEpoch),
          intervalHari: Value(next.intervalHari),
          streakBenar: Value(next.streakBenar),
          status: Value(next.status.code),
        ));
        return (await byId(cardId))!;
      });
}
