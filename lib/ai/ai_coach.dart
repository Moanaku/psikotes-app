/// Antarmuka pewawancara (docs/02-arsitektur.md, "Wawancara"). Dart murni.
///
/// Sekarang hanya [FakeCoach] yang ada: dialog dan laporan contoh yang sudah
/// tertulis, tanpa jaringan dan tanpa model bahasa (T29). Implementasi nyata
/// (template offline, Gemini, Groq) menyusul di T30 dan T31 dan boleh
/// menambah metode; layar wawancara hanya bergantung pada antarmuka ini.
library;

enum InterviewPersona {
  hr('HR', 'Wawancara HR', 'Motivasi, konsistensi, STAR, gaji'),
  teknis(
      'User teknis', 'Wawancara user teknis', 'Keputusan teknis dan trade-off');

  const InterviewPersona(this.label, this.title, this.focus);

  /// Nama di pilihan S15.
  final String label;

  /// Judul S16 dan S17.
  final String title;
  final String focus;
}

enum InterviewLanguage {
  indonesia('Indonesia'),
  english('English'),
  campuran('Campuran');

  const InterviewLanguage(this.label);
  final String label;
}

enum InterviewMode {
  latihan('Latihan'),
  simulasi('Simulasi');

  const InterviewMode(this.label);
  final String label;
}

class InterviewSetup {
  const InterviewSetup({
    this.persona = InterviewPersona.hr,
    this.language = InterviewLanguage.indonesia,
    this.mode = InterviewMode.latihan,
    this.jobText = '',
  });

  final InterviewPersona persona;
  final InterviewLanguage language;
  final InterviewMode mode;

  /// Deskripsi lowongan yang ditempel pengguna.
  final String jobText;

  InterviewSetup copyWith({
    InterviewPersona? persona,
    InterviewLanguage? language,
    InterviewMode? mode,
    String? jobText,
  }) =>
      InterviewSetup(
        persona: persona ?? this.persona,
        language: language ?? this.language,
        mode: mode ?? this.mode,
        jobText: jobText ?? this.jobText,
      );
}

/// Satu giliran bicara.
class InterviewTurn {
  const InterviewTurn({required this.byInterviewer, required this.text});

  final bool byInterviewer;
  final String text;
}

class AspectScore {
  const AspectScore(this.name, this.score);

  final String name;

  /// 1 sampai 5.
  final int score;
}

class ClaimCheck {
  const ClaimCheck({
    required this.claim,
    required this.note,
    required this.strong,
  });

  final String claim;
  final String note;

  /// Kuat atau goyah.
  final bool strong;
}

class InterviewReport {
  const InterviewReport({
    required this.aspects,
    required this.claims,
    required this.cvAdvice,
    required this.weakQuestions,
  });

  final List<AspectScore> aspects;
  final List<ClaimCheck> claims;
  final String cvAdvice;

  /// Jumlah pertanyaan lemah.
  final int weakQuestions;
}

/// Pewawancara tidak menjawab: jaringan, penyedia, atau format jawaban.
class CoachUnavailable implements Exception {
  const CoachUnavailable([this.reason = '']);

  final String reason;

  @override
  String toString() => 'CoachUnavailable: $reason';
}

abstract class AiCoach {
  /// Banyak topik dalam satu wawancara.
  int get topicCount;

  /// Pertanyaan pembuka (topik 1).
  Future<InterviewTurn> openingTurn(InterviewSetup setup);

  /// Giliran pewawancara sesudah jawaban terakhir di [history]. [topic] adalah
  /// topik yang baru dijawab (mulai dari 1). Setelah topik terakhir, jawaban
  /// berupa penutup. Melempar [CoachUnavailable].
  Future<InterviewTurn> nextTurn(
    InterviewSetup setup,
    List<InterviewTurn> history,
    int topic,
  );

  Future<InterviewReport> report(
    InterviewSetup setup,
    List<InterviewTurn> history,
  );
}

/// Dialog dan laporan contoh yang sudah tertulis. Isi jawaban pengguna tidak
/// memengaruhi apa pun; ini bukan model bahasa.
class FakeCoach implements AiCoach {
  FakeCoach({this.delay = Duration.zero});

  /// Jeda sebelum membalas, supaya penanda mengetik sempat terlihat.
  final Duration delay;

  /// Bila diisi, [nextTurn] melempar ini sekali lalu mengosongkannya.
  CoachUnavailable? failNext;

  /// Bila diisi, [report] melempar ini sekali lalu mengosongkannya.
  CoachUnavailable? failReport;

  static const List<String> _hr = [
    'Di CV kamu tertulis pernah magang sebagai Flutter developer. Kontribusi apa '
        'yang paling kamu banggakan di sana?',
    'Halaman apa saja yang kamu buat, dan bug seperti apa? Seberapa besar '
        'dampaknya untuk pengguna atau tim?',
    'Ceritakan satu situasi ketika kamu berbeda pendapat dengan rekan tim. Apa '
        'yang kamu lakukan dan bagaimana akhirnya?',
    'Kenapa kamu tertarik melamar ke posisi ini, dan apa yang membuatmu cocok '
        'dibanding pelamar lain?',
    'Sebutkan satu kegagalan di proyek yang pernah kamu kerjakan. Apa yang kamu '
        'pelajari darinya?',
    'Bagaimana kamu membagi waktu ketika dua tugas punya tenggat yang sama?',
    'Terakhir, apa yang ingin kamu pelajari dalam enam bulan pertama bekerja?',
  ];

  static const List<String> _teknis = [
    'Di CV kamu tertulis memakai Flutter untuk aplikasi pemesanan. Mengapa kamu '
        'memilih Flutter dibanding menulis dua aplikasi native?',
    'Bagaimana kamu mengelola state di aplikasi itu, dan apa yang kamu lakukan '
        'ketika state mulai sulit dilacak?',
    'Jelaskan bagaimana aplikasimu bekerja saat jaringan putus di tengah '
        'pemesanan.',
    'Bagaimana kamu menguji alur pemesanan sebelum rilis? Apa yang paling '
        'sering lolos dari pengujianmu?',
    'Kalau waktu muat sebuah halaman terasa lambat, langkah apa yang kamu ambil '
        'pertama kali?',
    'Pernah memilih solusi cepat yang kamu tahu bukan yang terbaik? Apa '
        'pertimbangannya?',
    'Terakhir, bagian mana dari kode yang menurutmu paling perlu dirapikan di '
        'proyek terakhirmu, dan mengapa?',
  ];

  static const String _closing = 'Terima kasih, itu pertanyaan terakhir. Ketuk '
      'Akhiri atau Lihat laporan untuk melihat ringkasan penilaian contoh.';

  List<String> _script(InterviewSetup setup) =>
      setup.persona == InterviewPersona.hr ? _hr : _teknis;

  @override
  int get topicCount => _hr.length;

  Future<void> _wait() async {
    if (delay > Duration.zero) await Future<void>.delayed(delay);
  }

  @override
  Future<InterviewTurn> openingTurn(InterviewSetup setup) async {
    await _wait();
    return InterviewTurn(byInterviewer: true, text: _script(setup).first);
  }

  @override
  Future<InterviewTurn> nextTurn(
    InterviewSetup setup,
    List<InterviewTurn> history,
    int topic,
  ) async {
    await _wait();
    final failure = failNext;
    if (failure != null) {
      failNext = null;
      throw failure;
    }
    final script = _script(setup);
    return InterviewTurn(
      byInterviewer: true,
      text: topic >= script.length ? _closing : script[topic],
    );
  }

  @override
  Future<InterviewReport> report(
    InterviewSetup setup,
    List<InterviewTurn> history,
  ) async {
    await _wait();
    final failure = failReport;
    if (failure != null) {
      failReport = null;
      throw failure;
    }
    final hr = setup.persona == InterviewPersona.hr;
    return InterviewReport(
      aspects: hr
          ? const [
              AspectScore('Struktur STAR', 2),
              AspectScore('Kespesifikan', 2),
              AspectScore('Relevansi', 4),
              AspectScore('Kejelasan', 3),
            ]
          : const [
              AspectScore('Struktur STAR', 3),
              AspectScore('Kespesifikan', 2),
              AspectScore('Relevansi', 4),
              AspectScore('Kejelasan', 4),
            ],
      claims: const [
        ClaimCheck(
          claim: 'Magang Flutter developer',
          note: 'Kontribusi pribadi dan dampak belum terukur.',
          strong: false,
        ),
        ClaimCheck(
          claim: 'Program Android Bangkit',
          note: 'Jawaban runtut, ada hasil proyek.',
          strong: true,
        ),
        ClaimCheck(
          claim: 'Skill testing',
          note: 'Disebut di CV, tetapi tidak ada contoh kasus.',
          strong: false,
        ),
      ],
      cvAdvice: 'Tambahkan satu angka dampak di poin magang, atau ganti klaim '
          'testing dengan contoh test yang pernah kamu tulis.',
      weakQuestions: 2,
    );
  }
}
