import 'package:simulator_psikotes_it/domain/services/clock.dart';

/// Jam palsu. [advance] menjalankan kedua jam (waktu nyata berlalu);
/// [shiftWall] hanya mengubah jam dinding (pengguna atau jaringan mengubah
/// jam); [sleep] meniru perangkat tidur: jam dinding jalan, jam monoton
/// berhenti.
class FakeClock implements Clock {
  FakeClock(this._wall);

  DateTime _wall;
  Duration _mono = Duration.zero;

  @override
  DateTime now() => _wall;

  @override
  Duration monotonic() => _mono;

  void advance(Duration d) {
    _wall = _wall.add(d);
    _mono += d;
  }

  void shiftWall(Duration d) => _wall = _wall.add(d);

  void sleep(Duration d) => shiftWall(d);
}
