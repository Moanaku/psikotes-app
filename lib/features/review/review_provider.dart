import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:question_engine/question_engine.dart';

import '../../domain/models/notebook.dart';
import '../../domain/models/profile.dart';
import '../../domain/models/session.dart';
import '../../domain/providers.dart';
import '../../domain/services/scoring.dart';
import '../../domain/services/speed_labeler.dart';

/// Data hasil dan pembahasan satu sesi (S08, S09). Soal dibuat ulang dari
/// `(tipe, seed, kesulitan, gen_versi)`; soal yang tidak bisa dibuat ulang
/// menghasilkan null dan ditangani layar tanpa crash.
class SessionReview {
  SessionReview({
    required this.session,
    required this.profile,
    required this.answers,
    required this.summary,
    required this.thresholds,
    required this.previousScore,
    required QuestionBuilder builder,
  }) : _builder = builder;

  final SessionRecord session;
  final TestProfile? profile;

  /// Jawaban menurut posisi; posisi tanpa baris (sesi tidak selesai) kosong.
  final Map<int, AnswerRecord> answers;
  final SessionSummary summary;
  final SpeedThresholds thresholds;

  /// Skor sesi sebelumnya (mode dan profil sama), atau null.
  final double? previousScore;
  final QuestionBuilder _builder;
  final Map<int, Question?> _questions = {};

  bool get finished => session.selesai != null;
  int get total => session.plan.items.length;

  /// Waktu mengerjakan: jumlah waktu melihat tiap soal, tanpa waktu di latar
  /// belakang atau saat app tertutup.
  Duration get duration =>
      Duration(milliseconds: answers.values.fold(0, (a, b) => a + b.durasiMs));

  /// Posisi soal salah pertama; 0 bila semua benar.
  int get firstWrong {
    for (var i = 0; i < total; i++) {
      final a = answers[i];
      if (a == null || !a.benar) return i;
    }
    return 0;
  }

  int get wrongCount => total - summary.benar;

  /// Soal di [index] dibuat ulang; null bila tidak bisa (generator gagal, tipe
  /// belum terdaftar, atau `gen_versi` berbeda).
  Question? questionAt(int index) => _questions.putIfAbsent(index, () {
        try {
          return _builder(session.plan.items[index]);
        } catch (_) {
          return null;
        }
      });
}

/// Hasil sesi [id]; null bila sesi tidak ada.
final sessionReviewProvider =
    FutureProvider.autoDispose.family<SessionReview?, int>((ref, id) async {
  final session = await ref.watch(sessionRepositoryProvider).byId(id);
  if (session == null) return null;
  final answers = await ref.watch(answerRepositoryProvider).forSession(id);
  final profiles = await ref.watch(profilesProvider.future);
  TestProfile? profile;
  for (final p in profiles) {
    if (p.id == session.profileId) profile = p;
  }
  final thresholds = await SpeedLabeler(ref.watch(answerRepositoryProvider))
      .forSession(session);
  final previous = session.selesai == null
      ? null
      : await ref.watch(sessionRepositoryProvider).latestFinished(
            session.profileId,
            session.mode,
            before: session.selesai,
          );
  return SessionReview(
    session: session,
    profile: profile,
    answers: {for (final a in answers) a.posisi: a},
    summary: Scoring.summarize(session.plan, answers),
    thresholds: thresholds,
    previousScore: previous?.skor,
    builder: ref.watch(questionBuilderProvider),
  );
});

/// Kartu buku kesalahan untuk jawaban [posisi] di sesi [sessionId], atau null.
final reviewCardProvider = FutureProvider.autoDispose
    .family<MistakeCard?, (int, int)>((ref, key) async {
  final review = await ref.watch(sessionReviewProvider(key.$1).future);
  final answer = review?.answers[key.$2];
  if (answer == null) return null;
  return ref.watch(mistakeRepositoryProvider).findFor(answer);
});
