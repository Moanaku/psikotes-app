/// Nilai teks yang disimpan di database (docs/03-data-model.md). Setiap enum
/// punya `code` yang sama dengan nilai di kolomnya.
library;

T _byCode<T>(List<T> values, String code, String Function(T) of, String what) {
  for (final v in values) {
    if (of(v) == code) return v;
  }
  throw FormatException('$what tidak dikenal: $code');
}

enum ProfileRole {
  qa('qa'),
  mobile('mobile'),
  ba('ba'),
  umum('umum'),
  lainnya('lainnya');

  const ProfileRole(this.code);
  final String code;
  static ProfileRole fromCode(String c) =>
      _byCode(values, c, (v) => v.code, 'role');
}

enum TestFormat {
  ccat('ccat'),
  bank('bank'),
  kustom('kustom');

  const TestFormat(this.code);
  final String code;
  static TestFormat fromCode(String c) =>
      _byCode(values, c, (v) => v.code, 'format_tes');
}

enum SessionMode {
  latihan('latihan'),
  simulasi('simulasi'),
  diagnostik('diagnostik');

  const SessionMode(this.code);
  final String code;
  static SessionMode fromCode(String c) =>
      _byCode(values, c, (v) => v.code, 'mode');
}

enum AnswerSource {
  engine('engine'),
  capture('capture'),
  bank('bank'),
  pengetahuan('pengetahuan');

  const AnswerSource(this.code);
  final String code;
  static AnswerSource fromCode(String c) =>
      _byCode(values, c, (v) => v.code, 'sumber');
}

enum SpeedLabel {
  benarCepat('benar_cepat'),
  benarLambat('benar_lambat'),
  salahCepat('salah_cepat'),
  salahLambat('salah_lambat');

  const SpeedLabel(this.code);
  final String code;
  static SpeedLabel fromCode(String c) =>
      _byCode(values, c, (v) => v.code, 'label');
}

enum CardStatus {
  aktif('aktif'),
  dikuasai('dikuasai');

  const CardStatus(this.code);
  final String code;
  static CardStatus fromCode(String c) =>
      _byCode(values, c, (v) => v.code, 'status');
}

/// Nilai kolom `tema` di `app_setting`.
enum ThemeSetting {
  terang('terang'),
  gelap('gelap'),
  sistem('sistem');

  const ThemeSetting(this.code);
  final String code;
  static ThemeSetting fromCode(String c) =>
      _byCode(values, c, (v) => v.code, 'tema');
}

/// Kategori soal yang sah di `blueprint_json` dan kolom `kategori`.
const List<String> kCategories = [
  'verbal',
  'numerik',
  'logika',
  'figural',
  'kraepelin',
  'kepribadian',
  'it',
  'pengetahuan',
];
