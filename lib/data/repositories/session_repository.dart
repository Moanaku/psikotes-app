import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:question_engine/question_engine.dart';

import '../../domain/models/codes.dart';
import '../../domain/models/session.dart';
import '../../domain/repositories/repositories.dart';
import '../db/app_database.dart';

DateTime _utc(int ms) => DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);

AnswerRecord _answer(AnswerRow r) => AnswerRecord(
      id: r.id,
      sessionId: r.sessionId,
      posisi: r.posisi,
      tipe: r.tipe,
      kategori: r.kategori,
      seed: r.seed,
      kesulitan: Difficulty.fromCode(r.kesulitan),
      genVersi: r.genVersi,
      sumber: AnswerSource.fromCode(r.sumber),
      refId: r.refId,
      opsiDipilih: r.opsiDipilih,
      benar: r.benar,
      durasiMs: r.durasiMs,
      label: SpeedLabel.fromCode(r.label),
    );

SessionRecord _session(SessionRow r) => SessionRecord(
      id: r.id,
      profileId: r.profileId,
      mode: SessionMode.fromCode(r.mode),
      plan: SessionPlan.fromJson(
        (jsonDecode(r.rencanaJson) as Map).cast<String, Object?>(),
      ),
      mulai: _utc(r.mulai),
      selesai: r.selesai == null ? null : _utc(r.selesai!),
      deadline: r.deadline == null ? null : _utc(r.deadline!),
      posisi: r.posisi,
      skor: r.skor,
    );

class DriftSessionRepository implements SessionRepository {
  DriftSessionRepository(this._db);

  final AppDatabase _db;

  @override
  Future<int> start(NewSession s) => _db.into(_db.sessionTable).insert(
        SessionTableCompanion.insert(
          profileId: s.profileId,
          mode: s.mode.code,
          rencanaJson: jsonEncode(s.plan.toJson()),
          mulai: s.mulai.millisecondsSinceEpoch,
          deadline: Value(s.deadline?.millisecondsSinceEpoch),
        ),
      );

  @override
  Future<int> recordAnswer(AnswerRecord a) async {
    if (a.sumber != AnswerSource.engine && a.refId == null) {
      throw ArgumentError('jawaban ${a.sumber.code} wajib punya refId');
    }
    final row = AnswerTableCompanion.insert(
      sessionId: a.sessionId,
      posisi: a.posisi,
      tipe: a.tipe,
      kategori: a.kategori,
      seed: a.seed,
      kesulitan: a.kesulitan.code,
      genVersi: a.genVersi,
      sumber: a.sumber.code,
      refId: Value(a.refId),
      opsiDipilih: Value(a.opsiDipilih),
      benar: a.benar,
      durasiMs: a.durasiMs,
      label: a.label.code,
    );
    return _db.into(_db.answerTable).insert(
          row,
          onConflict: DoUpdate(
            (_) => row,
            target: [_db.answerTable.sessionId, _db.answerTable.posisi],
          ),
        );
  }

  @override
  Future<void> updateProgress(
    int sessionId,
    int posisi, {
    DateTime? deadline,
    bool clearDeadline = false,
  }) async {
    final n = await (_db.update(_db.sessionTable)
          ..where((t) => t.id.equals(sessionId)))
        .write(SessionTableCompanion(
      posisi: Value(posisi),
      deadline: deadline != null
          ? Value(deadline.millisecondsSinceEpoch)
          : clearDeadline
              ? const Value(null)
              : const Value.absent(),
    ));
    if (n == 0) throw StateError('sesi $sessionId tidak ada');
  }

  @override
  Future<double> finish(int sessionId, DateTime now) =>
      _db.transaction(() async {
        final session = await byId(sessionId);
        if (session == null) throw StateError('sesi $sessionId tidak ada');
        final correct = await (_db.selectOnly(_db.answerTable)
              ..addColumns([_db.answerTable.id.count()])
              ..where(_db.answerTable.sessionId.equals(sessionId) &
                  _db.answerTable.benar.equals(true)))
            .map((r) => r.read(_db.answerTable.id.count()) ?? 0)
            .getSingle();
        final total =
            session.plan.items.isEmpty ? 1 : session.plan.items.length;
        final skor = (correct * 100.0 / total).clamp(0.0, 100.0);
        await (_db.update(_db.sessionTable)
              ..where((t) => t.id.equals(sessionId)))
            .write(SessionTableCompanion(
          selesai: Value(now.millisecondsSinceEpoch),
          skor: Value(skor),
        ));
        return skor;
      });

  @override
  Future<SessionSnapshot?> unfinished({int? profileId}) async {
    final row = await (_db.select(_db.sessionTable)
          ..where((t) =>
              t.selesai.isNull() &
              (profileId == null
                  ? const Constant(true)
                  : t.profileId.equals(profileId)))
          ..orderBy([
            (t) => OrderingTerm.desc(t.mulai),
            (t) => OrderingTerm.desc(t.id)
          ])
          ..limit(1))
        .getSingleOrNull();
    if (row == null) return null;
    final answers = await (_db.select(_db.answerTable)
          ..where((t) => t.sessionId.equals(row.id))
          ..orderBy([(t) => OrderingTerm.asc(t.id)]))
        .get();
    return SessionSnapshot(
      session: _session(row),
      answers: answers.map(_answer).toList(),
    );
  }

  @override
  Future<SessionRecord?> latestFinished(int profileId, SessionMode mode) async {
    final row = await (_db.select(_db.sessionTable)
          ..where((t) =>
              t.selesai.isNotNull() &
              t.profileId.equals(profileId) &
              t.mode.equals(mode.code))
          ..orderBy([
            (t) => OrderingTerm.desc(t.selesai),
            (t) => OrderingTerm.desc(t.id)
          ])
          ..limit(1))
        .getSingleOrNull();
    return row == null ? null : _session(row);
  }

  @override
  Future<SessionRecord?> byId(int id) async {
    final row = await (_db.select(_db.sessionTable)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _session(row);
  }
}

class DriftAnswerRepository implements AnswerRepository {
  DriftAnswerRepository(this._db);

  final AppDatabase _db;

  @override
  Future<List<AnswerRecord>> forSession(int sessionId) async {
    final rows = await (_db.select(_db.answerTable)
          ..where((t) => t.sessionId.equals(sessionId))
          ..orderBy([(t) => OrderingTerm.asc(t.id)]))
        .get();
    return rows.map(_answer).toList();
  }

  @override
  Future<List<AnswerRecord>> since(DateTime since) async {
    final query = _db.select(_db.answerTable).join([
      innerJoin(
        _db.sessionTable,
        _db.sessionTable.id.equalsExp(_db.answerTable.sessionId),
      ),
    ])
      ..where(_db.sessionTable.mulai
          .isBiggerOrEqualValue(since.millisecondsSinceEpoch))
      ..orderBy([OrderingTerm.desc(_db.answerTable.id)]);
    final rows = await query.get();
    return rows.map((r) => _answer(r.readTable(_db.answerTable))).toList();
  }
}
