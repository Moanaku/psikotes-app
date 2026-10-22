import 'dart:async';

import 'package:simulator_psikotes_it/domain/models/codes.dart';
import 'package:simulator_psikotes_it/domain/models/notebook.dart';
import 'package:simulator_psikotes_it/domain/models/profile.dart';
import 'package:simulator_psikotes_it/domain/models/session.dart';
import 'package:simulator_psikotes_it/domain/repositories/repositories.dart';
import 'package:simulator_psikotes_it/domain/services/sm2_scheduler.dart';

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
/// kartu yang jatuh tempo menurut `Sm2Scheduler.isDue`, seperti repository
/// Drift. Kartu dikenali
/// seperti di repository Drift: (tipe, seed) untuk soal engine, (sumber,
/// tipe, refId) untuk lainnya.
class FakeMistakeRepository implements MistakeRepository {
  FakeMistakeRepository([Iterable<MistakeCard> initial = const []])
      : cards = [...initial];

  final List<MistakeCard> cards;
  int _next = 1000;

  /// Bila diisi, `watchDue` dan `watchAll` mengeluarkan galat ini (menguji
  /// kondisi galat).
  Object? failWith;

  /// Bila diisi, `findFor`, `upsertFromAnswer`, `applyReview`, dan `delete`
  /// melempar ini.
  Object? failWritesWith;

  /// Bila diisi, `watchAll` menahan data pertama sampai selesai (kondisi
  /// memuat).
  Completer<void>? gate;

  /// Ulangan yang diterapkan lewat `applyReview`: (id kartu, benar).
  final List<(int, bool)> reviews = [];

  CardSchedule _schedule(MistakeCard c) => CardSchedule(
        jatuhTempo: c.jatuhTempo,
        intervalHari: c.intervalHari,
        streakBenar: c.streakBenar,
        status: c.status,
      );

  @override
  Stream<List<MistakeCard>> watchDue(DateTime now) {
    if (failWith != null) return Stream.error(failWith!);
    final due = [
      for (final c in cards)
        if (Sm2Scheduler.isDue(_schedule(c), now)) c,
    ]..sort((a, b) {
        final byDate = a.jatuhTempo.compareTo(b.jatuhTempo);
        return byDate != 0 ? byDate : a.id.compareTo(b.id);
      });
    return Stream.value(due);
  }

  @override
  Stream<List<MistakeCard>> watchAll() async* {
    await gate?.future;
    if (failWith != null) throw failWith!;
    yield [...cards]..sort((a, b) {
        final byDate = a.jatuhTempo.compareTo(b.jatuhTempo);
        return byDate != 0 ? byDate : a.id.compareTo(b.id);
      });
  }

  @override
  Future<MistakeCard?> byId(int id) async {
    for (final c in cards) {
      if (c.id == id) return c;
    }
    return null;
  }

  bool _same(MistakeCard c, AnswerRecord a) {
    if (c.sumber != a.sumber || c.tipe != a.tipe) return false;
    return a.sumber == AnswerSource.engine
        ? c.seed == a.seed
        : c.refId == a.refId;
  }

  @override
  Future<MistakeCard?> findFor(AnswerRecord answer) async {
    if (failWritesWith != null) throw failWritesWith!;
    for (final c in cards) {
      if (_same(c, answer)) return c;
    }
    return null;
  }

  @override
  Future<MistakeCard?> upsertFromAnswer(
    AnswerRecord answer,
    DateTime now, {
    bool force = false,
  }) async {
    if (failWritesWith != null) throw failWritesWith!;
    if (answer.benar && !force) return null;
    final due = now.add(const Duration(days: 1));
    final i = cards.indexWhere((c) => _same(c, answer));
    final card = MistakeCard(
      id: i >= 0 ? cards[i].id : _next++,
      tipe: answer.tipe,
      kategori: answer.kategori,
      seed: answer.sumber == AnswerSource.engine ? answer.seed : null,
      sumber: answer.sumber,
      refId: answer.refId,
      jatuhTempo: due,
      intervalHari: 1,
      streakBenar: 0,
      status: CardStatus.aktif,
      dibuat: i >= 0 ? cards[i].dibuat : now,
    );
    if (i >= 0) {
      cards[i] = card;
    } else {
      cards.add(card);
    }
    return card;
  }

  @override
  Future<void> delete(int cardId) async {
    if (failWritesWith != null) throw failWritesWith!;
    cards.removeWhere((c) => c.id == cardId);
  }

  @override
  Future<MistakeCard> applyReview(
    int cardId,
    bool correct,
    DateTime now,
  ) async {
    if (failWritesWith != null) throw failWritesWith!;
    final i = cards.indexWhere((c) => c.id == cardId);
    if (i < 0) throw StateError('kartu $cardId tidak ada');
    final c = cards[i];
    final next = Sm2Scheduler.afterReview(_schedule(c), correct, now);
    reviews.add((cardId, correct));
    return cards[i] = MistakeCard(
      id: c.id,
      tipe: c.tipe,
      kategori: c.kategori,
      seed: c.seed,
      sumber: c.sumber,
      refId: c.refId,
      jatuhTempo: next.jatuhTempo,
      intervalHari: next.intervalHari,
      streakBenar: next.streakBenar,
      status: next.status,
      dibuat: c.dibuat,
    );
  }
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
  Future<SessionRecord?> latestFinished(
    int profileId,
    SessionMode mode, {
    DateTime? before,
  }) async {
    SessionRecord? latest;
    for (final s in sessions.values) {
      if (s.selesai == null || s.profileId != profileId || s.mode != mode) {
        continue;
      }
      if (before != null && !s.selesai!.isBefore(before)) continue;
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

  @override
  Future<AnswerRecord?> latestEngineAnswer(String tipe, int seed) async {
    for (final a in [..._log.reversed, ...history]) {
      if (a.sumber == AnswerSource.engine && a.tipe == tipe && a.seed == seed) {
        return a;
      }
    }
    return null;
  }
}
