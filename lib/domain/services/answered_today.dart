import '../repositories/repositories.dart';
import 'clock.dart';

/// Berapa soal yang dijawab pada hari kalender zona waktu perangkat (A105).
/// Satu soal dihitung sekali, dari semua sesi dan profil, selesai atau belum.
/// Soal yang dilewati atau habis waktunya tidak dihitung (A63).
class AnsweredToday {
  const AnsweredToday(this._answers, this._clock);

  final AnswerRepository _answers;
  final Clock _clock;

  Future<int> count() {
    final now = _clock.now().toLocal();
    final from = DateTime(now.year, now.month, now.day);
    final to = DateTime(now.year, now.month, now.day + 1);
    return _answers.countAnswered(from.toUtc(), to.toUtc());
  }
}
