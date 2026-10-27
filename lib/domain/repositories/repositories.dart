/// Antarmuka repository. Domain bergantung pada ini; `data/` mengimplementasikan
/// (docs/02-arsitektur.md). Tanpa `package:flutter`.
library;

import '../models/codes.dart';
import '../models/knowledge.dart';
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

  /// Mengisi atau menghapus (null) teks CV. `save` pada profil yang sudah ada
  /// tidak mengubah CV bila `cvTeks`-nya null.
  Future<void> setCv(int id, String? cvTeks);

  /// Tepat satu profil aktif setelah pemanggilan ini.
  Future<void> setActive(int id);
}

abstract class SessionRepository {
  Future<int> start(NewSession session);

  /// Menjalankan [body] sebagai satu transaksi: bila melempar, semua tulisan
  /// repositori lain di database yang sama di dalamnya dibatalkan. Dipakai
  /// penutupan sesi agar ulangan kartu dan penutupan sesi tidak terpisah (A79).
  Future<T> atomically<T>(Future<T> Function() body);

  /// Menyimpan jawaban; satu baris per (sesi, posisi), jawaban ulang
  /// menggantikan yang lama. Jawaban non-engine wajib punya `refId`.
  Future<int> recordAnswer(AnswerRecord answer);

  /// Menyimpan posisi soal terakhir. [deadline] null membiarkan batas waktu
  /// yang ada; [clearDeadline] menghapusnya (subtes tanpa batas).
  Future<void> updateProgress(
    int sessionId,
    int posisi, {
    DateTime? deadline,
    bool clearDeadline = false,
  });

  /// Menutup sesi dan menghitung skor: jawaban benar dibagi jumlah soal di
  /// rencana (soal yang tak sempat dijawab dihitung salah). Mengembalikan skor.
  Future<double> finish(int sessionId, DateTime now);

  /// Sesi terbaru yang belum selesai, atau null. Dengan [profileId], hanya
  /// sesi profil itu.
  Future<SessionSnapshot?> unfinished({int? profileId});
  Future<SessionRecord?> byId(int id);

  /// Semua sesi yang sudah selesai, dari yang paling lama selesai (statistik).
  Future<List<SessionRecord>> finishedSessions();

  /// Sesi [mode] terbaru milik [profileId] yang sudah selesai, atau null.
  /// Dengan [before], hanya yang selesai sebelum waktu itu.
  Future<SessionRecord?> latestFinished(
    int profileId,
    SessionMode mode, {
    DateTime? before,
  });
}

abstract class AnswerRepository {
  Future<List<AnswerRecord>> forSession(int sessionId);

  /// Jawaban sejak [since], dari yang terbaru.
  Future<List<AnswerRecord>> since(DateTime since);

  /// Jumlah soal yang dijawab (opsi terisi) pada [from] sampai sebelum [to],
  /// dari semua sesi, selesai atau belum, semua profil.
  Future<int> countAnswered(DateTime from, DateTime to);

  /// Semua jawaban dari sesi yang sudah selesai (statistik), urut id.
  Future<List<AnswerRecord>> forFinishedSessions();

  /// Jawaban engine terbaru untuk soal ([tipe], [seed]), atau null bila tidak
  /// ada. Kartu buku kesalahan hanya menyimpan tipe dan seed; kesulitan dan
  /// versi generator soal asalnya dibaca dari sini.
  Future<AnswerRecord?> latestEngineAnswer(String tipe, int seed);
}

abstract class MistakeRepository {
  /// Kartu yang jatuh tempo sampai [now], dari yang paling lama: kartu
  /// `aktif` dan kartu `dikuasai` yang menunggu pemeriksaan ulang 14 hari
  /// (`Sm2Scheduler.isDue`).
  Stream<List<MistakeCard>> watchDue(DateTime now);

  /// Semua kartu, termasuk yang dikuasai, urut `jatuh_tempo` lalu id.
  Stream<List<MistakeCard>> watchAll();
  Future<MistakeCard?> byId(int id);

  /// Jawaban salah membuat atau memperbarui kartu; jawaban benar tidak
  /// mengubah apa pun (mengembalikan null). Soal engine dikenali dari
  /// (tipe, seed); soal lain dari (sumber, tipe, refId), dan `refId` wajib
  /// (ArgumentError bila kosong). Dengan [force], jawaban benar pun menjadi
  /// kartu (sakelar "Masuk buku kesalahan" di S09).
  Future<MistakeCard?> upsertFromAnswer(
    AnswerRecord answer,
    DateTime now, {
    bool force = false,
  });

  /// Kartu untuk soal [answer] (dikenali seperti di [upsertFromAnswer]), atau
  /// null bila soal itu tidak ada di buku kesalahan.
  Future<MistakeCard?> findFor(AnswerRecord answer);

  /// Menghapus kartu (sakelar "Masuk buku kesalahan" dimatikan).
  Future<void> delete(int cardId);

  /// Menerapkan satu ulangan ke kartu lewat `Sm2Scheduler.afterReview` dan
  /// mengembalikan kartu yang sudah diperbarui. Melempar StateError bila kartu
  /// tidak ada.
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

/// Kemajuan bank pengetahuan role (F17, tabel `knowledge_progress`).
abstract class KnowledgeRepository {
  Stream<Map<String, KnowledgeProgress>> watchAll();
  Future<Map<String, KnowledgeProgress>> all();

  /// Menyimpan atau menggantikan kemajuan butir.
  Future<void> save(KnowledgeProgress progress);
}
