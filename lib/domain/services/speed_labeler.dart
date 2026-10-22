import '../models/codes.dart';
import '../models/session.dart';
import '../repositories/repositories.dart';
import 'scoring.dart';

/// Ambang cepat dan lambat per tipe pada satu saat (docs/03-data-model.md,
/// "Label cepat dan lambat"): median `durasi_ms` jawaban benar tipe itu dalam
/// 30 hari, atau `estimatedSeconds` engine bila belum ada data. Waktu di bawah
/// atau sama dengan ambang berarti cepat.
class SpeedThresholds {
  const SpeedThresholds(this.medians);

  /// Median `durasi_ms` jawaban benar per kode tipe.
  final Map<String, int> medians;

  /// Ambang tipe [tipe] dalam milidetik.
  int targetMs(String tipe, int estimatedSeconds) =>
      Scoring.thresholdMs(medians, tipe, estimatedSeconds);

  SpeedLabel label({
    required String tipe,
    required int estimatedSeconds,
    required bool benar,
    required bool dijawab,
    required int durasiMs,
  }) =>
      Scoring.label(
        benar: benar,
        dijawab: dijawab,
        durasiMs: durasiMs,
        ambangMs: targetMs(tipe, estimatedSeconds),
      );
}

/// Layanan pelabelan cepat atau lambat. Dipakai `SessionController` saat
/// jawaban dicatat dan S09 untuk menampilkan target waktu soal.
class SpeedLabeler {
  const SpeedLabeler(this._answers);

  final AnswerRepository _answers;

  /// Ambang pada waktu [now] dari riwayat 30 hari. Jawaban sesi
  /// [excludeSession] tidak dihitung (A47), dan dengan [onlyBeforeSession]
  /// hanya sesi yang dimulai lebih dulu (id lebih kecil) yang dihitung, yaitu
  /// riwayat yang ada ketika sesi itu berjalan.
  Future<SpeedThresholds> at(
    DateTime now, {
    int? excludeSession,
    int? onlyBeforeSession,
  }) async {
    final history = await _answers.since(now.subtract(Scoring.window));
    return SpeedThresholds(Scoring.correctMedians(history.where((a) =>
        a.sessionId != excludeSession &&
        (onlyBeforeSession == null || a.sessionId < onlyBeforeSession))));
  }

  /// Ambang yang berlaku untuk [session]: riwayat 30 hari sebelum sesi mulai.
  Future<SpeedThresholds> forSession(SessionRecord session) => at(
        session.mulai,
        excludeSession: session.id,
        onlyBeforeSession: session.id,
      );
}
