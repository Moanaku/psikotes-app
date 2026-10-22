/// Antarmuka repository. Domain bergantung pada ini; `data/` mengimplementasikan
/// (docs/02-arsitektur.md). Tanpa `package:flutter`.
library;

import '../models/codes.dart';
import '../models/notebook.dart';
import '../models/profile.dart';
import '../models/session.dart';

abstract class ProfileRepository {
  Stream<List<TestProfile>> watchAll();

  /// Profil dengan `aktif = 1`; null bila belum ada profil.
  Future<TestProfile?> active();
  Future<TestProfile?> byId(int id);

  /// Menyimpan (id null = baru). Profil pertama otomatis aktif; menyimpan
  /// profil `aktif` menonaktifkan yang lain. Mengembalikan id.
  Future<int> save(TestProfile profile);

  /// Tepat satu profil aktif setelah pemanggilan ini.
  Future<void> setActive(int id);
}

abstract class SessionRepository {
  Future<int> start(NewSession session);
  Future<int> recordAnswer(AnswerRecord answer);

  /// Menyimpan posisi soal terakhir dan batas waktu subtes yang berjalan.
  Future<void> updateProgress(int sessionId, int posisi, {DateTime? deadline});

  /// Menutup sesi dan menghitung skor: jawaban benar dibagi jumlah soal di
  /// rencana (soal yang tak sempat dijawab dihitung salah). Mengembalikan skor.
  Future<double> finish(int sessionId, DateTime now);

  /// Sesi terbaru yang belum selesai, atau null.
  Future<SessionSnapshot?> unfinished();
  Future<SessionRecord?> byId(int id);
}

abstract class AnswerRepository {
  Future<List<AnswerRecord>> forSession(int sessionId);

  /// Jawaban sejak [since], dari yang terbaru.
  Future<List<AnswerRecord>> since(DateTime since);
}

abstract class MistakeRepository {
  /// Kartu `aktif` yang jatuh tempo sampai [now], dari yang paling lama.
  Stream<List<MistakeCard>> watchDue(DateTime now);
  Future<MistakeCard?> byId(int id);

  /// Jawaban salah membuat atau memperbarui kartu; jawaban benar tidak
  /// mengubah apa pun (mengembalikan null).
  Future<MistakeCard?> upsertFromAnswer(AnswerRecord answer, DateTime now);
  Future<MistakeCard> applyReview(int cardId, bool correct, DateTime now);
}

abstract class CaptureRepository {
  Stream<List<CapturedQuestion>> watchAll();
  Future<CapturedQuestion?> byId(int id);

  /// Menolak soal yang tidak sah (lihat `CapturedQuestion.validate`).
  Future<int> save(CapturedQuestion question);
  Future<void> delete(int id);
}

abstract class CompanyLogRepository {
  Stream<List<CompanyTestLog>> watchAll();
  Future<CompanyTestLog?> byId(int id);
  Future<int> save(CompanyTestLog log);
}

/// Kunci `app_setting`. Key API tidak pernah disimpan di sini.
abstract final class SettingKeys {
  static const String tema = 'tema';
  static const String penyediaAi = 'penyedia_ai';
  static const String batasWawancaraHarian = 'batas_wawancara_harian';
  static const String onboardingSelesai = 'onboarding_selesai';
}

abstract class SettingsRepository {
  Future<String?> get(String key);
  Stream<String?> watch(String key);
  Future<void> set(String key, String value);
  Future<ThemeSetting> theme();
  Future<void> setTheme(ThemeSetting theme);
}
