/// Kerangka sesi (F05): latihan, simulasi, dan diagnostik.
///
/// Waktu sisa selalu dihitung dari `deadline` mutlak yang disimpan di
/// database, bukan dari penghitung yang berkurang, supaya benar setelah app ke
/// latar belakang, layar mati, rotasi, atau proses dimatikan
/// (docs/02-arsitektur.md, Manajemen state). Setiap jawaban dan perpindahan
/// soal langsung ditulis ke database. Perubahan jam perangkat ditangani
/// [WallClockGuard] (A46).
///
/// Layar (T14) wajib meneruskan siklus hidup app: [SessionController.onPaused]
/// saat app ke latar belakang dan [SessionController.onResumed] saat kembali.
library;

import 'dart:async';

import 'package:question_engine/question_engine.dart';
import 'package:riverpod/riverpod.dart';

import '../models/codes.dart';
import '../models/session.dart';
import '../models/session_state.dart';
import '../providers.dart';
import '../repositories/repositories.dart';
import 'clock.dart';
import 'scoring.dart';
import 'speed_labeler.dart';

final sessionControllerProvider =
    NotifierProvider<SessionController, SessionState?>(SessionController.new);

/// Keadaan dalam yang bisa diubah; [SessionState] adalah salinannya.
class _Run {
  _Run({
    required this.sessionId,
    required this.profileId,
    required this.mode,
    required this.plan,
    required this.subtests,
    required this.subtestIndex,
    required this.posisi,
    required this.answers,
    required this.dwell,
    required this.medians,
    required this.deadline,
    required this.timerEnabled,
    required this.lastNow,
    required this.builder,
  }) : rules = SessionRules.of(mode);

  final int sessionId;
  final int profileId;
  final SessionMode mode;
  final SessionRules rules;
  final SessionPlan plan;
  final List<SubtestRange> subtests;
  final Map<int, AnswerRecord> answers;

  /// Waktu melihat tiap soal yang sudah ditutup, tanpa waktu di latar
  /// belakang.
  final Map<int, Duration> dwell;

  /// Median durasi jawaban benar per tipe (30 hari) untuk label kecepatan.
  final Map<String, int> medians;
  final Map<int, Question> questions = {};

  /// Pembuat soal untuk rencana ini: soal engine dari generator, soal Capture
  /// dari isi yang dimuat saat sesi dibuka.
  final QuestionBuilder builder;

  int subtestIndex;
  int posisi;
  DateTime? deadline;

  /// Deadline digeser karena lompatan jam dan belum ditulis ke database.
  bool deadlineDirty = false;
  bool timerEnabled;
  DateTime lastNow;

  /// Saat soal [posisi] mulai dilihat; null saat app di latar belakang.
  DateTime? shownAt;
  int? selected;
  AnswerFeedback? feedback;
  Question? question;
  bool questionFailed = false;
  TimeUpNotice? notice;
  bool finished = false;
  double? skor;

  SubtestRange get subtest => subtests[subtestIndex];
  bool get isLastSubtest => subtestIndex == subtests.length - 1;
}

class SessionController extends Notifier<SessionState?> {
  static const Duration tickInterval = Duration(seconds: 1);

  late SessionRepository _sessions;
  late AnswerRepository _answerHistory;
  late MistakeRepository _mistakes;
  late WallClockGuard _guard;
  late TickerFactory _tickerFactory;
  late QuestionBuilder _buildQuestion;

  CaptureRepository _captureRepo() => ref.read(captureRepositoryProvider);

  _Run? _r;
  Timer? _ticker;
  bool _disposed = false;
  Future<void> _queue = Future.value();

  @override
  SessionState? build() {
    _sessions = ref.watch(sessionRepositoryProvider);
    _answerHistory = ref.watch(answerRepositoryProvider);
    _mistakes = ref.watch(mistakeRepositoryProvider);
    _guard = WallClockGuard(ref.watch(clockProvider));
    _tickerFactory = ref.watch(tickerFactoryProvider);
    _buildQuestion = ref.watch(questionBuilderProvider);
    _disposed = false;
    ref.onDispose(() {
      _disposed = true;
      _stopTicker();
    });
    _r = null;
    return null;
  }

  // ---------------------------------------------------------------- aksi

  /// Memulai sesi baru. Simulasi wajib punya batas waktu di setiap subtes.
  Future<void> start({
    required int profileId,
    required SessionMode mode,
    required SessionPlan plan,
  }) =>
      _serial(() async {
        final subtests = SubtestRange.of(plan);
        if (SessionRules.of(mode).timerRequired &&
            subtests.any((s) => s.duration == null)) {
          throw ArgumentError('setiap subtes ${mode.code} wajib punya batas '
              'waktu');
        }
        _stopTicker();
        _guard.markInterrupted();
        final now = _guard.read().now;
        final firstDuration = subtests.first.duration;
        final deadline = firstDuration == null ? null : now.add(firstDuration);
        final id = await _sessions.start(NewSession(
          profileId: profileId,
          mode: mode,
          plan: plan,
          mulai: now,
          deadline: deadline,
        ));
        final r = _Run(
          sessionId: id,
          profileId: profileId,
          mode: mode,
          plan: plan,
          subtests: subtests,
          subtestIndex: 0,
          posisi: 0,
          answers: {},
          dwell: {},
          medians: await _loadMedians(now, id),
          deadline: deadline,
          timerEnabled: true,
          lastNow: now,
          builder: await questionBuilderFor(plan, _captureRepo, _buildQuestion),
        )..shownAt = now;
        _r = r;
        _loadQuestion(r);
        _emit();
        _startTicker();
      });

  /// Melanjutkan sesi terbaru yang belum selesai, dari posisi terakhir dengan
  /// sisa waktu dari `deadline`. Mengembalikan false bila tidak ada.
  Future<bool> resume({int? profileId}) => _serial(() async {
        final snapshot = await _sessions.unfinished(profileId: profileId);
        if (snapshot == null) return false;
        await _resumeFrom(snapshot);
        return true;
      });

  /// Membuka sesi [sessionId] untuk layar sesi. Sesi yang sudah berjalan di
  /// controller dipakai apa adanya; sesi lain dimuat dari database dan
  /// dilanjutkan seperti [resume].
  Future<SessionOpen> open(int sessionId) => _serial(() async {
        final live = _r;
        if (live != null && live.sessionId == sessionId) {
          return live.finished ? SessionOpen.finished : SessionOpen.opened;
        }
        final session = await _sessions.byId(sessionId);
        if (session == null) return SessionOpen.notFound;
        if (session.selesai != null) return SessionOpen.finished;
        final answers = await _answerHistory.forSession(sessionId);
        await _resumeFrom(SessionSnapshot(session: session, answers: answers));
        return SessionOpen.opened;
      });

  Future<void> _resumeFrom(SessionSnapshot snapshot) async {
    _stopTicker();
    final s = snapshot.session;
    final subtests = SubtestRange.of(s.plan);
    final rules = SessionRules.of(s.mode);
    _guard.markInterrupted();
    final now = _guard.read().now;
    final posisi = s.posisi.clamp(0, s.plan.items.length - 1);
    final k = subtests.indexWhere((x) => x.contains(posisi));
    final duration = subtests[k].duration;

    var deadline = s.deadline;
    var timerEnabled = true;
    var dirty = false;
    if (duration == null) {
      // Subtes tanpa batas: deadline lama tidak berlaku.
      dirty = deadline != null;
      deadline = null;
    } else if (deadline == null) {
      if (rules.timerCanBeDisabled) {
        // Latihan yang timernya dimatikan pengguna.
        timerEnabled = false;
      } else {
        deadline = now.add(duration);
        dirty = true;
      }
    } else if (deadline.difference(now) > duration) {
      // Jam dimundurkan saat app tertutup: sisa waktu tidak boleh lebih
      // dari durasi subtes.
      deadline = now.add(duration);
      dirty = true;
    }

    final r = _Run(
      sessionId: s.id,
      profileId: s.profileId,
      mode: s.mode,
      plan: s.plan,
      subtests: subtests,
      subtestIndex: k,
      posisi: posisi,
      answers: {for (final a in snapshot.answers) a.posisi: a},
      dwell: {
        for (final a in snapshot.answers)
          a.posisi: Duration(milliseconds: a.durasiMs),
      },
      medians: await _loadMedians(now, s.id),
      deadline: deadline,
      timerEnabled: timerEnabled,
      lastNow: now,
      builder: await questionBuilderFor(s.plan, _captureRepo, _buildQuestion),
    )..shownAt = now;
    if (dirty || posisi != s.posisi) {
      await _sessions.updateProgress(r.sessionId, posisi,
          deadline: deadline, clearDeadline: deadline == null);
    }
    _r = r;
    _loadQuestion(r);
    await _settle(r, now);
    _emit();
    if (!r.finished) _startTicker();
  }

  /// Membuat ulang soal yang gagal dibuat (S06, tombol "Ulangi"). False bila
  /// soalnya tetap tidak bisa dibuat.
  Future<bool> retryQuestion() => _action((r, now) async {
        if (r.question != null) return false;
        r.questions.remove(r.posisi);
        _loadQuestion(r);
        return r.question != null;
      });

  /// Simulasi: memilih opsi langsung menyimpan jawaban (bisa diganti selama
  /// subtes berjalan). Latihan: hanya menandai pilihan sebelum "Kirim".
  /// False bila waktu subtes sudah habis atau soal tidak tersedia.
  Future<bool> select(int option) => _action((r, now) async {
        final q = r.question;
        if (q == null) return false;
        RangeError.checkValidIndex(option, q.options, 'option');
        if (r.rules.immediateFeedback) {
          if (r.feedback != null) return false;
          r.selected = option;
          return true;
        }
        await _record(r, q, option, now);
        return true;
      });

  /// Latihan: menyimpan pilihan dan menampilkan benar atau salah.
  Future<bool> submit() => _action((r, now) async {
        if (!r.rules.immediateFeedback) {
          throw StateError('kirim jawaban hanya di mode ${r.mode.code}');
        }
        final q = r.question;
        final chosen = r.selected;
        if (q == null || chosen == null || r.feedback != null) return false;
        final a = await _record(r, q, chosen, now);
        r.feedback = AnswerFeedback(
          posisi: r.posisi,
          chosen: chosen,
          correctIndex: q.correctIndex,
          benar: a.benar,
        );
        return true;
      });

  /// Soal berikutnya. Di soal terakhir subtes, subtes ditutup (tidak bisa
  /// kembali) dan subtes berikutnya dimulai; di subtes terakhir, sesi
  /// selesai. Latihan: hanya setelah jawaban dikirim, kecuali soalnya gagal
  /// dibuat.
  Future<bool> next() => _action((r, now) async {
        if (r.rules.immediateFeedback &&
            r.feedback == null &&
            !r.questionFailed) {
          throw StateError('kirim jawaban sebelum lanjut');
        }
        _closeView(r, now);
        if (r.posisi < r.subtest.end - 1) {
          await _moveTo(r, r.posisi + 1, now);
        } else {
          await _closeSubtest(r, r.subtest);
          if (r.isLastSubtest) {
            await _finish(r, now);
          } else {
            await _enterSubtest(r, r.subtestIndex + 1, now);
          }
        }
        return true;
      });

  /// Simulasi: soal sebelumnya di subtes yang sama.
  Future<bool> previous() => _action((r, now) => _goTo(r, r.posisi - 1, now));

  /// Simulasi: lompat ke soal lain di subtes yang sama (kisi nomor).
  Future<bool> goTo(int posisi) => _action((r, now) => _goTo(r, posisi, now));

  /// Latihan: mematikan timer untuk sisa sesi.
  Future<void> disableTimer() => _action((r, now) async {
        if (!r.rules.timerCanBeDisabled) {
          throw StateError('timer ${r.mode.code} tidak bisa dimatikan');
        }
        if (!r.timerEnabled) return false;
        await _sessions.updateProgress(r.sessionId, r.posisi,
            clearDeadline: true);
        r.timerEnabled = false;
        r.deadline = null;
        r.deadlineDirty = false;
        return true;
      });

  /// Membaca jam, memperbarui sisa waktu, dan memindahkan subtes bila
  /// waktunya habis. Dipanggil penanda waktu tiap detik.
  Future<void> tick() => _serial(() async {
        final r = _r;
        if (r == null || r.finished) return;
        await _settle(r, _now(r));
        _emit();
      });

  /// App ke latar belakang atau layar mati. Waktu subtes tetap berjalan
  /// (deadline mutlak); waktu melihat soal berhenti.
  Future<void> onPaused() {
    _stopTicker();
    return _serial(() async {
      final r = _r;
      if (r == null) return;
      _closeView(r, _now(r));
      _guard.markInterrupted();
    });
  }

  /// App kembali ke depan: sisa waktu dihitung ulang dari deadline, termasuk
  /// waktu saat perangkat tidur.
  Future<void> onResumed() => _serial(() async {
        final r = _r;
        if (r == null) return;
        _guard.markInterrupted();
        final now = _now(r);
        if (!r.finished) {
          r.shownAt ??= now;
          await _settle(r, now);
        }
        _emit();
        if (!r.finished) _startTicker();
      });

  /// Mengakhiri sesi sekarang. Soal yang belum dijawab dicatat dilewati.
  Future<double> finish() => _serial(() async {
        final r = _active();
        if (!r.finished) {
          final now = _now(r);
          await _settle(r, now);
          if (!r.finished) {
            _closeView(r, now);
            await _finish(r, now);
          }
        }
        _emit();
        return r.skor!;
      });

  void dismissNotice() {
    final r = _r;
    if (r == null || r.notice == null) return;
    r.notice = null;
    _emit();
  }

  /// Meninggalkan layar sesi. Sesi yang belum selesai tetap tersimpan dan
  /// bisa dilanjutkan dengan [resume]. Dengan [sessionId], hanya menutup bila
  /// itu sesi yang sedang berjalan (layar lama tidak menutup sesi baru).
  void close({int? sessionId}) {
    final r = _r;
    if (sessionId != null && r != null && r.sessionId != sessionId) return;
    _stopTicker();
    _r = null;
    _emit();
  }

  // ------------------------------------------------------------- internal

  Future<T> _serial<T>(Future<T> Function() op) {
    final result = _queue.then((_) => op());
    _queue = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  /// Menjalankan aksi pengguna setelah waktu diselesaikan. Bila subtes
  /// berpindah karena waktunya habis, aksi untuk subtes lama dibatalkan.
  Future<bool> _action(Future<bool> Function(_Run r, DateTime now) op) =>
      _serial(() async {
        final r = _active();
        final subtest = r.subtestIndex;
        final now = _now(r);
        await _settle(r, now);
        if (r.finished || r.subtestIndex != subtest) {
          _emit();
          return false;
        }
        final changed = await op(r, now);
        _emit();
        return changed;
      });

  _Run _active() {
    final r = _r;
    if (r == null) throw StateError('belum ada sesi berjalan');
    return r;
  }

  /// Bacaan jam. Lompatan jam menggeser deadline dan awal melihat soal,
  /// sehingga sisa waktu tidak berubah karena jam perangkat diubah.
  DateTime _now(_Run r) {
    final reading = _guard.read();
    if (reading.jump != Duration.zero) {
      final deadline = r.deadline;
      if (deadline != null) {
        r.deadline = deadline.add(reading.jump);
        r.deadlineDirty = true;
      }
      final shown = r.shownAt;
      if (shown != null) r.shownAt = shown.add(reading.jump);
    }
    r.lastNow = reading.now;
    return reading.now;
  }

  /// Menyimpan deadline yang digeser, lalu menutup subtes yang waktunya habis.
  /// Subtes berikutnya dimulai saat ini dengan durasi penuh, juga bila waktu
  /// habis saat app tertutup (A46).
  Future<void> _settle(_Run r, DateTime now) async {
    if (r.finished) return;
    if (r.deadlineDirty) {
      r.deadlineDirty = false;
      await _sessions.updateProgress(r.sessionId, r.posisi,
          deadline: r.deadline);
    }
    final deadline = r.deadline;
    if (deadline == null || now.isBefore(deadline)) return;
    final expired = r.subtest;
    _closeView(r, deadline.isBefore(now) ? deadline : now);
    await _closeSubtest(r, expired);
    if (r.isLastSubtest) {
      await _finish(r, now);
    } else {
      await _enterSubtest(r, r.subtestIndex + 1, now);
    }
    r.notice = TimeUpNotice(subtest: expired, sessionEnded: r.finished);
  }

  Future<bool> _goTo(_Run r, int posisi, DateTime now) async {
    if (!r.rules.freeNavigation) return false;
    if (!r.subtest.contains(posisi) || posisi == r.posisi) return false;
    _closeView(r, now);
    await _moveTo(r, posisi, now);
    return true;
  }

  Future<void> _moveTo(_Run r, int posisi, DateTime now) async {
    await _sessions.updateProgress(r.sessionId, posisi);
    r.posisi = posisi;
    r.selected = null;
    r.feedback = null;
    r.shownAt = now;
    _loadQuestion(r);
  }

  Future<void> _enterSubtest(_Run r, int k, DateTime now) async {
    final s = r.subtests[k];
    final duration = s.duration;
    final deadline =
        duration != null && r.timerEnabled ? now.add(duration) : null;
    await _sessions.updateProgress(r.sessionId, s.start,
        deadline: deadline, clearDeadline: deadline == null);
    r.subtestIndex = k;
    r.posisi = s.start;
    r.deadline = deadline;
    r.deadlineDirty = false;
    r.selected = null;
    r.feedback = null;
    r.shownAt = now;
    _loadQuestion(r);
  }

  /// Soal subtes yang belum dijawab dicatat dilewati.
  Future<void> _closeSubtest(_Run r, SubtestRange s) async {
    for (var p = s.start; p < s.end; p++) {
      if (!r.answers.containsKey(p)) await _recordSkipped(r, p);
    }
  }

  Future<void> _finish(_Run r, DateTime now) async {
    for (var p = 0; p < r.plan.items.length; p++) {
      if (!r.answers.containsKey(p)) await _recordSkipped(r, p);
    }
    // Setiap soal yang tidak benar, termasuk yang dilewati, menjadi kartu
    // buku kesalahan (jatuh tempo besok). Soal ulangan (PlanItem.cardId)
    // menjadwal ulang kartunya lewat SM-2, benar atau salah, dan tidak
    // membuat kartu baru untuk seed barunya. Semua kartu dan penutupan sesi
    // ditulis dalam satu transaksi: bila gagal di tengah, tidak ada kartu yang
    // berubah dan sesi tetap terbuka, jadi penutupan bisa diulang tanpa
    // menerapkan ulangan dua kali (A79).
    r.skor = await _sessions.atomically(() async {
      for (final a in r.answers.values) {
        final cardId = r.plan.items[a.posisi].cardId;
        if (cardId != null && await _mistakes.byId(cardId) != null) {
          await _mistakes.applyReview(cardId, a.benar, now);
          continue;
        }
        if (a.benar) continue;
        if (a.sumber != AnswerSource.engine && a.refId == null) continue;
        await _mistakes.upsertFromAnswer(a, now);
      }
      return _sessions.finish(r.sessionId, now);
    });
    r.finished = true;
    r.deadline = null;
    r.selected = null;
    r.shownAt = null;
    _stopTicker();
  }

  Future<AnswerRecord> _record(
    _Run r,
    Question q,
    int chosen,
    DateTime now,
  ) async {
    final item = r.plan.items[r.posisi];
    final durasiMs = _dwellAt(r, r.posisi, now).inMilliseconds;
    final benar = Scoring.isCorrect(q, chosen);
    final a = AnswerRecord(
      sessionId: r.sessionId,
      posisi: r.posisi,
      tipe: item.tipeCode,
      kategori: item.kategoriCode,
      seed: item.seed,
      kesulitan: item.difficulty,
      genVersi: item.genVersi,
      sumber: item.source,
      refId: item.refId,
      opsiDipilih: chosen,
      benar: benar,
      durasiMs: durasiMs,
      label: Scoring.label(
        benar: benar,
        dijawab: true,
        durasiMs: durasiMs,
        ambangMs:
            Scoring.thresholdMs(r.medians, item.tipeCode, q.estimatedSeconds),
      ),
    );
    await _sessions.recordAnswer(a);
    r.answers[r.posisi] = a;
    return a;
  }

  Future<void> _recordSkipped(_Run r, int posisi) async {
    final item = r.plan.items[posisi];
    final durasiMs = (r.dwell[posisi] ?? Duration.zero).inMilliseconds;
    final a = AnswerRecord(
      sessionId: r.sessionId,
      posisi: posisi,
      tipe: item.tipeCode,
      kategori: item.kategoriCode,
      seed: item.seed,
      kesulitan: item.difficulty,
      genVersi: item.genVersi,
      sumber: item.source,
      refId: item.refId,
      benar: false,
      durasiMs: durasiMs,
      label: Scoring.label(
          benar: false, dijawab: false, durasiMs: durasiMs, ambangMs: 0),
    );
    await _sessions.recordAnswer(a);
    r.answers[posisi] = a;
  }

  Duration _dwellAt(_Run r, int posisi, DateTime now) {
    var d = r.dwell[posisi] ?? Duration.zero;
    final shown = r.shownAt;
    if (posisi == r.posisi && shown != null && now.isAfter(shown)) {
      d += now.difference(shown);
    }
    return d;
  }

  void _closeView(_Run r, DateTime at) {
    r.dwell[r.posisi] = _dwellAt(r, r.posisi, at);
    r.shownAt = null;
  }

  void _loadQuestion(_Run r) {
    final item = r.plan.items[r.posisi];
    Question? q = r.questions[r.posisi];
    if (q == null) {
      try {
        q = r.builder(item);
        r.questions[r.posisi] = q;
      } catch (_) {
        // Semua percobaan generator gagal, tipe belum terdaftar, atau versi
        // generator berbeda: layar menampilkan teks galat S06.
        q = null;
      }
    }
    r.question = q;
    r.questionFailed = q == null;
    if (r.rules.immediateFeedback) {
      final a = r.answers[r.posisi];
      r.feedback = a != null && q != null
          ? AnswerFeedback(
              posisi: r.posisi,
              chosen: a.opsiDipilih,
              correctIndex: q.correctIndex,
              benar: a.benar,
            )
          : null;
    }
  }

  Future<Map<String, int>> _loadMedians(DateTime now, int sessionId) async =>
      (await SpeedLabeler(_answerHistory).at(now, excludeSession: sessionId))
          .medians;

  void _startTicker() {
    _stopTicker();
    if (_disposed) return;
    _ticker = _tickerFactory(tickInterval, () => unawaited(tick()));
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  void _emit() {
    if (_disposed) return;
    final r = _r;
    if (r == null) {
      state = null;
      return;
    }
    final deadline = r.deadline;
    Duration? remaining;
    if (deadline != null) {
      remaining = deadline.difference(r.lastNow);
      if (remaining.isNegative) remaining = Duration.zero;
    }
    state = SessionState(
      sessionId: r.sessionId,
      profileId: r.profileId,
      mode: r.mode,
      plan: r.plan,
      subtests: r.subtests,
      subtestIndex: r.subtestIndex,
      posisi: r.posisi,
      answers: Map.unmodifiable(r.answers),
      timerEnabled: r.timerEnabled,
      finished: r.finished,
      selected: r.selected,
      feedback: r.feedback,
      deadline: deadline,
      remaining: remaining,
      question: r.question,
      questionFailed: r.questionFailed,
      notice: r.notice,
      skor: r.skor,
    );
  }
}
