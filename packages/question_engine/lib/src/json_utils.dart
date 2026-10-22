/// Pembaca JSON ketat untuk model engine. Struktur salah melempar
/// [FormatException]; aturan isi diperiksa terpisah oleh `validate()`.
library;

Map<String, Object?> asJsonMap(Object? json, String what) {
  if (json is Map<String, Object?>) return json;
  if (json is Map) {
    final out = <String, Object?>{};
    for (final e in json.entries) {
      final key = e.key;
      if (key is! String) {
        throw FormatException('kunci $what bukan string: $key');
      }
      out[key] = e.value;
    }
    return out;
  }
  throw FormatException('$what bukan objek JSON');
}

List<Object?> asJsonList(Object? json, String what) {
  if (json is List) return json;
  throw FormatException('$what bukan array JSON');
}

Object? _require(Map<String, Object?> m, String key) {
  if (!m.containsKey(key)) throw FormatException('kunci "$key" tidak ada');
  return m[key];
}

String readString(Map<String, Object?> m, String key) {
  final v = _require(m, key);
  if (v is String) return v;
  throw FormatException('"$key" bukan string');
}

String? readOptionalString(Map<String, Object?> m, String key) {
  final v = m[key];
  if (v == null || v is String) return v as String?;
  throw FormatException('"$key" bukan string');
}

int readInt(Map<String, Object?> m, String key) {
  final v = _require(m, key);
  if (v is int) return v;
  throw FormatException('"$key" bukan bilangan bulat');
}

List<Object?> readList(Map<String, Object?> m, String key) =>
    asJsonList(_require(m, key), '"$key"');

T enumByCode<T>(List<T> values, String code, String Function(T) codeOf) {
  for (final v in values) {
    if (codeOf(v) == code) return v;
  }
  throw FormatException('kode tidak dikenal: $code');
}
