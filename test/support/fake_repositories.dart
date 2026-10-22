import 'dart:async';

import 'package:simulator_psikotes_it/domain/models/codes.dart';
import 'package:simulator_psikotes_it/domain/models/notebook.dart';
import 'package:simulator_psikotes_it/domain/models/profile.dart';
import 'package:simulator_psikotes_it/domain/models/session.dart';
import 'package:simulator_psikotes_it/domain/repositories/repositories.dart';

/// Repository profil di memori tanpa database: aman untuk widget test (tanpa
/// timer dan I/O nyata). Meniru aturan repository Drift: profil pertama
/// otomatis aktif, menyimpan profil aktif menonaktifkan yang lain, dan `save`
/// pada profil yang ada tidak mengubah CV bila `cvTeks` null.
class FakeProfileRepository implements ProfileRepository {
  FakeProfileRepository([Iterable<TestProfile> initial = const []]) {
    for (final p in initial) {
      _items.add(p.id == null ? p.copyWith(id: _next++) : p);
      if (p.id != null && p.id! >= _next) _next = p.id! + 1;
    }
  }

  final List<TestProfile> _items = [];
  final StreamController<void> _changes = StreamController.broadcast(
    sync: true,
  );
  int _next = 1;

  /// Bila diisi, `save` dan `byId` melempar ini (menguji kondisi galat).
  Object? failWith;

  /// Jumlah panggilan `save`.
  int saves = 0;

  /// Bila diisi, `save` menunggu sampai selesai (menguji ketukan ganda).
  Completer<void>? saveGate;

  /// Bila diisi, `watchAll` menahan data pertama sampai selesai (kondisi
  /// memuat).
  Completer<void>? watchGate;

  List<TestProfile> get items => List.unmodifiable(_items);

  @override
  Stream<List<TestProfile>> watchAll() => Stream.multi((c) {
        final gate = watchGate;
        if (gate == null) {
          c.add(items);
        } else {
          gate.future.then((_) => c.add(items));
        }
        final sub = _changes.stream.listen((_) => c.add(items));
        c.onCancel = sub.cancel;
      });

  @override
  Future<TestProfile?> active() async {
    for (final p in _items) {
      if (p.aktif) return p;
    }
    return null;
  }

  @override
  Future<TestProfile?> byId(int id) async {
    if (failWith != null) throw failWith!;
    for (final p in _items) {
      if (p.id == id) return p;
    }
    return null;
  }

  @override
  Future<int> save(TestProfile profile) async {
    if (failWith != null) throw failWith!;
    saves++;
    await saveGate?.future;
    final makeActive = profile.aktif || _items.isEmpty;
    final id = profile.id ?? _next++;
    final index = _items.indexWhere((p) => p.id == id);
    final cv = profile.cvTeks ?? (index >= 0 ? _items[index].cvTeks : null);
    final saved = TestProfile(
      id: id,
      nama: profile.nama,
      role: profile.role,
      formatTes: profile.formatTes,
      tanggalTes: profile.tanggalTes,
      aktif: makeActive,
      blueprint: profile.blueprint,
      cvTeks: cv,
      dibuat: profile.dibuat,
    );
    if (makeActive) {
      for (var i = 0; i < _items.length; i++) {
        if (_items[i].aktif) _items[i] = _items[i].copyWith(aktif: false);
      }
    }
    if (index >= 0) {
      _items[index] = saved;
    } else {
      _items.add(saved);
    }
    _changes.add(null);
    return id;
  }

  @override
  Future<void> setCv(int id, String? cvTeks) async {}

  @override
  Future<void> setActive(int id) async {
    for (var i = 0; i < _items.length; i++) {
      _items[i] = _items[i].copyWith(aktif: _items[i].id == id);
    }
    _changes.add(null);
  }
}

/// Buku kesalahan di memori. [cards] diatur test; `watchDue` hanya memuat
/// kartu aktif yang jatuh tempo, seperti repository Drift.
class FakeMistakeRepository implements MistakeRepository {
  FakeMistakeRepository([Iterable<MistakeCard> initial = const []])
      : cards = [...initial];

  final List<MistakeCard> cards;

  /// Bila diisi, `watchDue` mengeluarkan galat ini (menguji kondisi galat).
  Object? failWith;

  @override
  Stream<List<MistakeCard>> watchDue(DateTime now) {
    if (failWith != null) return Stream.error(failWith!);
    return Stream.value([
      for (final c in cards)
        if (c.status == CardStatus.aktif && !c.jatuhTempo.isAfter(now)) c,
    ]);
  }

  @override
  Future<MistakeCard?> byId(int id) async {
    for (final c in cards) {
      if (c.id == id) return c;
    }
    return null;
  }

  @override
  Future<MistakeCard?> upsertFromAnswer(AnswerRecord answer, DateTime now) =>
      throw UnimplementedError();

  @override
  Future<MistakeCard> applyReview(int cardId, bool correct, DateTime now) =>
      throw UnimplementedError();
}

/// Soal Capture di memori; hanya jumlahnya yang dipakai S04 dan S05.
class FakeCaptureRepository implements CaptureRepository {
  FakeCaptureRepository([Iterable<CapturedQuestion> initial = const []])
      : items = [...initial];

  final List<CapturedQuestion> items;

  /// Bila diisi, `watchAll` mengeluarkan galat ini.
  Object? failWith;

  /// Bila diisi, `watchAll` menahan data sampai [Completer] selesai.
  Completer<void>? gate;

  @override
  Stream<List<CapturedQuestion>> watchAll() async* {
    await gate?.future;
    if (failWith != null) throw failWith!;
    yield List.unmodifiable(items);
  }

  @override
  Future<CapturedQuestion?> byId(int id) async => null;

  @override
  Future<int> save(CapturedQuestion question) => throw UnimplementedError();

  @override
  Future<void> delete(int id) => throw UnimplementedError();
}

/// Sesi dan jawaban di memori untuk `SessionController` di widget test.
/// Meniru repository Drift: satu jawaban per (sesi, posisi), skor saat
/// selesai, dan `since` dari yang terbaru.
class FakeSessionRepository implements SessionRepository, AnswerRepository {
  final Map<int, SessionRecord> sessions = {};
  final List<AnswerRecord> _log = [];
  int _next = 1;

  /// Jawaban lama di luar sesi yang tercatat di sini, selalu dikembalikan
  /// `since` (riwayat 30 hari untuk menguji perencana). Dari yang terbaru.
  List<AnswerRecord> history = [];

  /// Bila diisi, `start` melempar ini (menguji kegagalan menulis).
  Object? failStartWith;

  /// Bila diisi, `since` melempar ini (menguji kondisi galat).
  Object? failSinceWith;

  /// Bila diisi, `byId` melempar ini.
  Object? failByIdWith;

  Map<int, AnswerRecord> answersOf(int sessionId) => {
        for (final a in _log)
          if (a.sessionId == sessionId) a.posisi: a,
      };

  @override
  Future<int> start(NewSession s) async {
    if (failStartWith != null) throw failStartWith!;
    final id = _next++;
    sessions[id] = SessionRecord(
      id: id,
      profileId: s.profileId,
      mode: s.mode,
      plan: s.plan,
      mulai: s.mulai,
      deadline: s.deadline,
    );
    return id;
  }

  @override
  Future<int> recordAnswer(AnswerRecord a) async {
    _log.removeWhere((x) => x.sessionId == a.sessionId && x.posisi == a.posisi);
    _log.add(a);
    return _log.length;
  }

  @override
  Future<void> updateProgress(
    int sessionId,
    int posisi, {
    DateTime? deadline,
    bool clearDeadline = false,
  }) async {
    final s = sessions[sessionId]!;
    sessions[sessionId] = SessionRecord(
      id: s.id,
      profileId: s.profileId,
      mode: s.mode,
      plan: s.plan,
      mulai: s.mulai,
      selesai: s.selesai,
      deadline: clearDeadline ? null : (deadline ?? s.deadline),
      posisi: posisi,
      skor: s.skor,
    );
  }

  @override
  Future<double> finish(int sessionId, DateTime now) async {
    final s = sessions[sessionId]!;
    final benar = answersOf(sessionId).values.where((a) => a.benar).length;
    final total = s.plan.items.isEmpty ? 1 : s.plan.items.length;
    final skor = (benar * 100.0 / total).clamp(0.0, 100.0);
    sessions[sessionId] = SessionRecord(
      id: s.id,
      profileId: s.profileId,
      mode: s.mode,
      plan: s.plan,
      mulai: s.mulai,
      selesai: now,
      posisi: s.posisi,
      skor: skor,
    );
    return skor;
  }

  @override
  Future<SessionSnapshot?> unfinished({int? profileId}) async {
    SessionRecord? latest;
    for (final s in sessions.values) {
      if (s.selesai != null) continue;
      if (profileId != null && s.profileId != profileId) continue;
      if (latest == null || s.id > latest.id) latest = s;
    }
    if (latest == null) return null;
    return SessionSnapshot(
      session: latest,
      answers: answersOf(latest.id).values.toList(),
    );
  }

  @override
  Future<SessionRecord?> byId(int id) async {
    if (failByIdWith != null) throw failByIdWith!;
    return sessions[id];
  }

  @override
  Future<SessionRecord?> latestFinished(int profileId, SessionMode mode) async {
    SessionRecord? latest;
    for (final s in sessions.values) {
      if (s.selesai == null || s.profileId != profileId || s.mode != mode) {
        continue;
      }
      if (latest == null || s.selesai!.isAfter(latest.selesai!)) latest = s;
    }
    return latest;
  }

  @override
  Future<List<AnswerRecord>> forSession(int sessionId) async =>
      answersOf(sessionId).values.toList();

  @override
  Future<List<AnswerRecord>> since(DateTime since) async {
    if (failSinceWith != null) throw failSinceWith!;
    final recent = [
      for (final a in _log)
        if (!sessions[a.sessionId]!.mulai.isBefore(since)) a,
    ].reversed;
    return [...recent, ...history];
  }
}
