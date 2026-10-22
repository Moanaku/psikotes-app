/// PRNG deterministik lintas platform (xorshift32).
///
/// `dart:math Random(seed)` tidak dijamin sama antar versi dan platform.
/// Kelas ini hanya memakai geser, xor, dan dan, dengan penyamaran 32 bit di setiap
/// langkah, sehingga hasilnya identik di VM (int 64 bit) dan web (angka JS).
/// Spesifikasi: docs/02-arsitektur.md, bagian "Determinisme engine".
class Rng {
  /// Seed 0 tidak valid untuk xorshift; diganti konstanta tetap.
  static const int zeroSeedState = 0x6D2B79F5;
  static const int _mask = 0xFFFFFFFF;
  static const int _warmUp = 8;
  static const int _deriveMultiplier = 0x9E3779B1;

  int _state;

  Rng(int seed) : _state = _normalize(seed) {
    for (var i = 0; i < _warmUp; i++) {
      nextUint32();
    }
  }

  /// Seed turunan untuk percobaan ulang pembuatan soal.
  factory Rng.derive(int seed, int attempt) =>
      Rng((seed ^ ((attempt * _deriveMultiplier) & _mask)) & _mask);

  static int _normalize(int seed) {
    final s = seed & _mask;
    return s == 0 ? zeroSeedState : s;
  }

  /// Bilangan bulat 0 sampai 2^32 - 1.
  int nextUint32() {
    var x = _state;
    x ^= (x << 13) & _mask;
    x ^= x >> 17;
    x ^= (x << 5) & _mask;
    _state = x;
    return x;
  }

  /// Bilangan bulat 0 sampai max - 1, tanpa bias modulo (rejection sampling).
  int nextInt(int max) {
    if (max <= 0 || max > _mask) {
      throw RangeError.range(max, 1, _mask, 'max');
    }
    final limit = (0x100000000 ~/ max) * max;
    while (true) {
      final v = nextUint32();
      if (v < limit) return v % max;
    }
  }

  bool nextBool() => nextInt(2) == 1;

  T pick<T>(List<T> items) {
    if (items.isEmpty) throw ArgumentError('items kosong');
    return items[nextInt(items.length)];
  }

  /// Fisher-Yates pada salinan; list asli tidak berubah.
  List<T> shuffle<T>(List<T> items) {
    final out = List<T>.of(items);
    for (var i = out.length - 1; i > 0; i--) {
      final j = nextInt(i + 1);
      final t = out[i];
      out[i] = out[j];
      out[j] = t;
    }
    return out;
  }
}
