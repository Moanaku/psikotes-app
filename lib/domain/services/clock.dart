/// Sumber waktu domain. [SystemClock] satu-satunya tempat yang membaca jam
/// sistem; test memakai jam palsu yang bisa dimajukan, dimundurkan, dan
/// "ditidurkan".
library;

/// Dua jam yang dibutuhkan sesi.
abstract interface class Clock {
  /// Jam dinding, UTC. Ikut berjalan saat app tertutup dan perangkat tidur,
  /// tetapi bisa melompat bila pengguna atau jaringan mengubah jam perangkat.
  DateTime now();

  /// Waktu monoton sejak titik awal sembarang di proses ini. Tidak terpengaruh
  /// perubahan jam, tetapi bisa berhenti saat perangkat tidur (Android) dan
  /// mulai lagi dari nol setiap proses baru.
  Duration monotonic();
}

class SystemClock implements Clock {
  SystemClock() : _stopwatch = Stopwatch()..start();

  final Stopwatch _stopwatch;

  @override
  DateTime now() => DateTime.now().toUtc();

  @override
  Duration monotonic() => _stopwatch.elapsed;
}

/// Satu bacaan dari [WallClockGuard].
class ClockReading {
  const ClockReading(this.now, this.jump);

  /// Jam dinding saat dibaca.
  final DateTime now;

  /// Lompatan jam dinding yang terdeteksi sejak bacaan sebelumnya (positif =
  /// maju). Batas waktu yang disimpan dalam kerangka jam dinding harus digeser
  /// sebesar ini agar sisa waktu tidak berubah.
  final Duration jump;
}

/// Mendeteksi perubahan jam perangkat dengan membandingkan selisih jam dinding
/// dan jam monoton antara dua bacaan (docs/11-asumsi-dan-pertanyaan.md, A46).
///
/// - Jam dinding mundur lebih dari [tolerance] selalu lompatan: waktu nyata
///   tidak pernah mundur.
/// - Jam dinding maju lebih cepat dari jam monoton dianggap lompatan hanya bila
///   app berjalan terus sejak bacaan sebelumnya. Setelah [markInterrupted]
///   (app ke latar belakang, layar mati, proses baru), selisih itu bisa berarti
///   perangkat tidur, jadi diterima sebagai waktu yang berlalu.
class WallClockGuard {
  WallClockGuard(this._clock, {this.tolerance = const Duration(seconds: 2)});

  final Clock _clock;
  final Duration tolerance;

  DateTime? _wall;
  Duration? _mono;
  bool _interrupted = true;

  /// Bacaan berikutnya boleh menerima jam dinding yang maju lebih cepat.
  void markInterrupted() => _interrupted = true;

  ClockReading read() {
    final wall = _clock.now();
    final mono = _clock.monotonic();
    var jump = Duration.zero;
    final lastWall = _wall;
    final lastMono = _mono;
    if (lastWall != null && lastMono != null) {
      var monoDelta = mono - lastMono;
      if (monoDelta.isNegative) monoDelta = Duration.zero;
      final skew = wall.difference(lastWall) - monoDelta;
      if (skew < -tolerance || (skew > tolerance && !_interrupted)) {
        jump = skew;
      }
    }
    _wall = wall;
    _mono = mono;
    _interrupted = false;
    return ClockReading(wall, jump);
  }
}
