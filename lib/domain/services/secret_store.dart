/// Penyimpanan rahasia (key API wawancara). Key tidak pernah disimpan di
/// database, tidak ikut backup, tidak masuk log, dan tidak dikirim ke mana pun
/// selain penyedia yang dipilih pengguna (docs/02-arsitektur.md).
abstract class SecretStore {
  /// True bila nilai bertahan setelah app ditutup (Android, terenkripsi);
  /// false bila hanya hidup selama sesi (web: memori).
  bool get persistent;

  Future<String?> read(String name);
  Future<void> write(String name, String value);
  Future<void> delete(String name);
}

/// Penyimpanan di memori: web, dan pengganti di test.
class MemorySecretStore implements SecretStore {
  MemorySecretStore({this.persistent = false});

  final Map<String, String> _values = {};

  @override
  final bool persistent;

  @override
  Future<String?> read(String name) async => _values[name];

  @override
  Future<void> write(String name, String value) async => _values[name] = value;

  @override
  Future<void> delete(String name) async => _values.remove(name);
}

/// Penyedia LLM wawancara (S18). Tidak ada bawaan sampai pemilik memutuskan
/// (Q2); `code` dipakai di `app_setting.penyedia_ai`.
enum AiProvider {
  gemini('gemini', 'Gemini'),
  groq('groq', 'Groq');

  const AiProvider(this.code, this.label);

  final String code;
  final String label;

  /// Nama berkas rahasia untuk key penyedia ini.
  String get secretName => 'api_key_$code';

  static AiProvider? fromCode(String? code) {
    for (final p in values) {
      if (p.code == code) return p;
    }
    return null;
  }
}
