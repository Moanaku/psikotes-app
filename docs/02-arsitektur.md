# 02. Arsitektur

## Prinsip

1. Logika soal berada di `question_engine`, paket Dart murni tanpa Flutter, sehingga bisa diuji puluhan ribu kali tanpa UI (ADR-02).
2. Soal tidak disimpan utuh. Cukup `(type, seed, difficulty, versi generator)`; engine membuat ulang soal identik (ADR-03).
3. Psikotes jalan offline sepenuhnya. Hanya modul wawancara yang memanggil layanan luar.
4. UI tidak memegang logika bisnis. Widget membaca state dari Riverpod dan mengirim aksi.
5. Satu sumber token desain (`lib/core/theme/app_tokens.dart`), tidak ada warna atau ukuran hard-coded di widget.

## Lapisan

```
presentation   features/*  (screen, widget, provider)        Flutter
domain         domain/*    (planner, sesi, SM-2, statistik)   Dart murni, bergantung pada engine dan antarmuka repository
data           data/*      (Drift, repository, backup)        SQLite lewat Drift, juga di web
engine         packages/question_engine                       Dart murni, tanpa Flutter dan tanpa I/O
external       ai/*        (AiCoach: Gemini, Groq, template)  hanya wawancara, butuh internet
```

Aturan ketergantungan: panah hanya ke bawah. `engine` tidak mengimpor apa pun dari app. `domain` tidak mengimpor `package:flutter`. `ai` hanya dipakai oleh `features/interview`.

## Struktur folder

```
simulator-psikotes-it/
  CLAUDE.md                     aturan kerja untuk Claude Code
  README.md                     ringkasan proyek dan case study
  pubspec.yaml
  analysis_options.yaml
  assets/
    verbal_bank.json            bank verbal terverifikasi (v1: 300 soal)
    knowledge_bank.json         bank pengetahuan role (v1.1)
    personality_pool.json       pool pernyataan kepribadian (v1.1)
    fonts/                      Instrument Sans (OFL), dibundel agar offline
  lib/
    main.dart
    app/                        app.dart, router.dart, routes.dart
    core/
      theme/                    app_tokens.dart, app_theme.dart
      widgets/                  komponen bersama (lihat 04-sistem-desain.md)
      utils/                    format waktu, ekstensi
    data/
      db/                       app_database.dart, tables.dart, migrations
      repositories/             profile, session, answer, mistake, capture, company_log, settings
      backup/                   backup_service.dart (ekspor dan impor JSON)
    domain/
      models/                   ProfileBlueprint, SessionPlan, ReviewLabel, ...
      services/                 daily_planner.dart, session_controller.dart, sm2_scheduler.dart,
                                scoring.dart, stats_service.dart, weakness_model.dart
    features/
      onboarding/               S01, S02, S03
      home/                     S04
      catalog/                  S05
      session/                  S06, S07 (satu SessionScreen, dua mode)
      review/                   S08, S09
      mistakes/                 S10
      stats/                    S11
      capture/                  S12, S13
      personality/              S14
      knowledge/                S19, S20
      interview/                S15, S16, S17 (v1.3)
      settings/                 S18
    ai/
      ai_coach.dart             antarmuka
      cv_sanitizer.dart         hapus nomor HP, email, alamat
      gemini_coach.dart, groq_coach.dart, template_coach.dart
  packages/
    question_engine/
      lib/src/
        rng.dart                PRNG buatan sendiri (deterministik lintas platform)
        models.dart             Question, Option, Difficulty, QuestionType
        generator.dart          antarmuka QuestionGenerator dan Solver
        generators/             figural/, numeric/, logic/, verbal/, krp/, it/, personality/
        distractors/            pembuat pengecoh bersama
      test/                     unit dan property test
  tool/
    pregenerate/                skrip Python pembuat bank verbal dan bank pengetahuan
  test/                         widget dan golden test
  integration_test/             3 alur utama
  .github/workflows/ci.yml      analyze, test, build web, rilis
  docs/                         paket dokumen ini
```

## Stack

| Kebutuhan | Pilihan | Alasan |
|---|---|---|
| Framework | Flutter (Android dan web) | Satu kode untuk APK dan demo web |
| State | Riverpod | Mudah dites, tanpa BuildContext di logika |
| Navigasi | go_router | Deep link untuk demo web, rute bernama |
| Database | Drift (SQLite, juga di web) | Query bertipe, migrasi jelas |
| Gambar soal | CustomPainter | Gambar dari data, tanpa aset |
| Grafik | fl_chart | Statistik dan tren |
| Tes | flutter_test, glados, golden test | Bukti kualitas generator |
| CI/CD | GitHub Actions, Pages, Releases | Test otomatis, demo web, APK |
| LLM | Gemini atau Groq free tier, key milik sendiri | Rp0, bisa diganti penyedia |

Versi paket di `pubspec.yaml` adalah titik awal. Tugas T01 menjalankan `flutter pub upgrade` dan memperbaiki kalau ada perubahan API.

## Determinisme engine

`dart:math Random(seed)` tidak dijamin menghasilkan deret yang sama antar versi dan antar platform. Karena soal dibuat ulang dari seed, engine memakai PRNG sendiri (`Rng`, xorshift32 dengan penyamaran 32 bit di setiap langkah) yang hanya memakai operasi geser, xor, dan dan. Aturan:

- Semua keacakan di engine datang dari `Rng`. Dilarang memakai `Random`, `DateTime.now()`, atau `hashCode` di dalam generator.
- Seed turunan untuk percobaan ulang: `Rng.derive(seed, attempt)`.
- Ada test lintas platform: deret nilai `Rng` untuk seed tetap dibandingkan dengan nilai emas, dijalankan di VM dan di Chrome (`dart test -p vm,chrome`).

## Antarmuka inti

### Engine

```dart
enum Difficulty { easy, medium, hard }

abstract class QuestionGenerator {
  QuestionType get type;
  /// Naik setiap kali perilaku generator berubah, agar soal lama bisa dibuat ulang identik.
  int get version;
  /// Murni dan deterministik. Melempar GenerationFailure hanya jika semua 20 percobaan gagal.
  Question generate(int seed, Difficulty difficulty);
}

abstract class QuestionSolver {
  /// Mengembalikan indeks semua opsi yang valid menurut aturan soal.
  List<int> validOptions(Question question);
}
```

Pembuatan satu soal: `for attempt in 0..19 { rng = Rng.derive(seed, attempt); q = build(rng); if solver.validOptions(q) == [q.correctIndex] and no duplicate options -> return q }`.

### Repository (domain bergantung pada ini, data mengimplementasikan)

```dart
abstract class ProfileRepository { Stream<List<TestProfile>> watchAll(); Future<TestProfile?> active(); Future<int> save(TestProfile p); Future<void> setActive(int id); }
abstract class SessionRepository { Future<int> start(SessionPlan plan); Future<void> recordAnswer(AnswerRecord a); Future<void> finish(int sessionId); Future<SessionSnapshot?> unfinished(); }
abstract class MistakeRepository { Stream<List<MistakeCard>> watchDue(DateTime now); Future<void> upsertFromAnswer(AnswerRecord a); Future<void> applyReview(int cardId, bool correct, DateTime now); }
```

### Wawancara (v1.3)

```dart
abstract class AiCoach {
  Future<CvExtraction> extractCv(String cvText, String jobText);
  Future<InterviewPlan> planInterview(CvExtraction cv, Persona persona, AppLanguage lang);
  Future<TurnAssessment> assess(InterviewPlan plan, Turn turn);
  Future<String> nextTurn(InterviewPlan plan, List<Turn> history, TurnAssessment last);
  Future<InterviewReport> report(InterviewPlan plan, List<Turn> history);
}
```

Implementasi: `GeminiCoach`, `GroqCoach`, `TemplateCoach` (offline, kartu pertanyaan). Semua teks CV melewati `CvSanitizer` sebelum meninggalkan perangkat.

Alur satu wawancara:
1. Sanitasi CV (regex nomor HP, email, alamat).
2. Panggilan 1, ekstraksi: CV dan lowongan menjadi JSON berisi klaim, skill, celah, kecocokan.
3. Panggilan 2, rencana: 6-8 topik sesuai persona; tiap topik punya klaim yang digali.
4. Tiap putaran: penilai mengembalikan JSON (spesifik, ada angka, peran pribadi, hasil, relevan; skor 1-5; keputusan gali, lanjut, atau tutup), lalu pewawancara menulis pertanyaan berikutnya.
5. Panggilan akhir: laporan per aspek, peta klaim CV kuat dan goyah, saran perbaikan CV.

Batas default 3 sesi wawancara per hari. Key disimpan dengan `flutter_secure_storage` di Android; di web hanya di memori sesi browser.

## Navigasi

Rute dan aturan ada di `lib/app/routes.dart`; daftar lengkap di `05-spek-layar.md`. Bottom nav empat tab: Beranda, Psikotes, Wawancara, Statistik. Layar lain dibuka di atas tab dengan tombol kembali. Sesi (S06, S07) selalu layar penuh tanpa bottom nav.

Pengalihan awal: jika belum ada profil aktif, `/` mengarah ke `/onboarding/role`.

## Manajemen state

- Satu `ProviderScope` di akar.
- Repository diekspos sebagai provider; layar tidak menyentuh Drift langsung.
- `SessionController` (Notifier) memegang sesi berjalan: daftar soal, indeks, jawaban, sisa waktu. Setiap jawaban langsung ditulis ke database agar sesi bisa dilanjutkan.
- Waktu sisa dihitung dari `deadline` mutlak yang disimpan, bukan dari penghitung yang berkurang, supaya benar setelah app ditutup paksa.
- Domain tidak membaca jam sistem langsung: semua waktu lewat `Clock` (`clockProvider`; `SystemClock` di app, jam palsu di test). `WallClockGuard` mendeteksi perubahan jam perangkat dan `SessionController` menggeser deadline sebesar lompatannya (ADR-14, A46). Layar sesi meneruskan siklus hidup app ke `onPaused` dan `onResumed`.
- Provider repository dideklarasikan di `lib/domain/providers.dart` dengan tipe antarmuka dan diisi `dataProviderOverrides` dari `lib/data/providers.dart` di `ProviderScope` akar dan di test (A47).

## Penanganan galat dan kondisi

Setiap layar data punya empat kondisi: kosong, memuat, galat, dan offline (untuk wawancara). Teks galat menyebut apa yang terjadi dan apa yang harus dilakukan, tanpa meminta maaf. Contoh ada di `05-spek-layar.md`.

## Keamanan dan privasi

- Semua data lokal. Tidak ada telemetri.
- Soal Capture dan foto tidak masuk repo; `.gitignore` menutup folder data lokal.
- Key LLM tidak pernah masuk log atau ekspor backup.
- Teks CV yang dikirim ke LLM sudah disanitasi; versi mentah tidak disimpan di `cv_profile`.
