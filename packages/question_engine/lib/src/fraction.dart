/// Pecahan eksak untuk aritmetika soal numerik (NUM-ARI, NUM-WORD, NUM-SEQ).
///
/// Tanpa `double`: hasil yang sama di VM dan web. Pembilang dan penyebut
/// dibatasi [limit] agar perkalian dan penjumlahan tetap eksak pada bilangan
/// bulat web (2^53); melampaui batas melempar [FractionOverflow].
///
/// Tidak menimpa `==` dan `hashCode` (engine dilarang memakai `hashCode`);
/// bandingkan dengan [equals] atau [compareTo].
library;

final class FractionOverflow implements Exception {
  const FractionOverflow(this.detail);

  final String detail;

  @override
  String toString() => 'FractionOverflow($detail)';
}

final class Fraction implements Comparable<Fraction> {
  /// Batas mutlak pembilang dan penyebut: 2^25.
  static const int limit = 33554432;

  static const Fraction zero = Fraction._(0, 1);
  static const Fraction one = Fraction._(1, 1);

  const Fraction._(this.num, this.den);

  /// [num]/[den] disederhanakan; penyebut selalu positif.
  factory Fraction(int num, [int den = 1]) {
    if (den == 0) throw ArgumentError.value(den, 'den', 'penyebut nol');
    var n = num;
    var d = den;
    if (d < 0) {
      n = -n;
      d = -d;
    }
    final g = _gcd(n.abs(), d);
    n ~/= g;
    d ~/= g;
    if (n.abs() > limit || d > limit) {
      throw FractionOverflow('$n/$d');
    }
    return Fraction._(n, d);
  }

  final int num;
  final int den;

  /// Dari teks desimal dengan koma atau titik, misalnya "12,5". Null bila
  /// bukan bilangan tak negatif.
  static Fraction? parseDecimal(String text) {
    final m = RegExp(r'^(\d+)(?:[.,](\d{1,6}))?$').firstMatch(text.trim());
    if (m == null) return null;
    final frac = m.group(2) ?? '';
    var scale = 1;
    for (var i = 0; i < frac.length; i++) {
      scale *= 10;
    }
    try {
      return Fraction(int.parse(m.group(1)! + frac), scale);
    } on FractionOverflow {
      return null;
    }
  }

  static int _gcd(int a, int b) {
    while (b != 0) {
      final t = a % b;
      a = b;
      b = t;
    }
    return a == 0 ? 1 : a;
  }

  bool get isInteger => den == 1;
  bool get isNegative => num < 0;
  bool get isZero => num == 0;

  Fraction operator +(Fraction o) =>
      Fraction(num * o.den + o.num * den, den * o.den);

  Fraction operator -(Fraction o) =>
      Fraction(num * o.den - o.num * den, den * o.den);

  Fraction operator *(Fraction o) => Fraction(num * o.num, den * o.den);

  Fraction operator /(Fraction o) {
    if (o.num == 0) throw ArgumentError('bagi nol');
    return Fraction(num * o.den, den * o.num);
  }

  Fraction operator -() => Fraction._(-num, den);

  bool equals(Fraction o) => num == o.num && den == o.den;

  @override
  int compareTo(Fraction o) => (num * o.den).compareTo(o.num * den);

  bool operator <(Fraction o) => compareTo(o) < 0;
  bool operator >(Fraction o) => compareTo(o) > 0;
  bool operator <=(Fraction o) => compareTo(o) <= 0;
  bool operator >=(Fraction o) => compareTo(o) >= 0;

  /// Pembulatan ke bilangan bulat terdekat, setengah ke atas (untuk nilai
  /// tak negatif).
  int roundHalfUp() => (num * 2 + den) ~/ (den * 2);

  /// Pembuangan pecahan (menuju nol).
  int truncate() => num ~/ den;

  /// Teks desimal dengan koma bila penyebut hanya berfaktor 2 dan 5 dan butuh
  /// paling banyak [maxPlaces] angka di belakang koma; selain itu null.
  /// Bilangan 1000 ke atas diberi titik ribuan: "45.000".
  String? toDecimal({int maxPlaces = 2}) {
    var scale = 1;
    var places = 0;
    while (scale % den != 0) {
      if (places == maxPlaces) return null;
      scale *= 10;
      places++;
    }
    final scaled = (num.abs() * (scale ~/ den));
    final digits = scaled.toString().padLeft(places + 1, '0');
    var whole = digits.substring(0, digits.length - places);
    final frac = digits.substring(digits.length - places);
    if (whole.length >= 4) {
      final out = StringBuffer();
      for (var i = 0; i < whole.length; i++) {
        if (i > 0 && (whole.length - i) % 3 == 0) out.write('.');
        out.write(whole[i]);
      }
      whole = out.toString();
    }
    return '${num < 0 ? '-' : ''}$whole${places > 0 ? ',$frac' : ''}';
  }

  @override
  String toString() => den == 1 ? '$num' : '$num/$den';
}

/// Bilangan dari teks tampilan: titik ribuan dibuang, koma menjadi desimal.
/// Null bila bukan bilangan tak negatif.
Fraction? parseDisplayNumber(String text) {
  final cleaned =
      text.trim().replaceAll(RegExp(r'(?<=\d)\.(?=\d{3}(\D|$))'), '');
  return Fraction.parseDecimal(cleaned);
}
