import 'dart:async';

import 'package:simulator_psikotes_it/domain/providers.dart';

/// Penanda waktu yang hanya berdetak saat [fire] dipanggil, supaya widget test
/// tidak menunggu `Timer.periodic` sungguhan.
class ManualTimer implements Timer {
  ManualTimer(this._onTick);

  final void Function() _onTick;
  bool _active = true;
  int _ticks = 0;

  void fire() {
    if (!_active) return;
    _ticks++;
    _onTick();
  }

  @override
  void cancel() => _active = false;

  @override
  bool get isActive => _active;

  @override
  int get tick => _ticks;
}

/// Pabrik penanda waktu yang mencatat semua penanda yang dibuat.
class ManualTicker {
  final List<ManualTimer> timers = [];

  ManualTimer? get active {
    for (final t in timers.reversed) {
      if (t.isActive) return t;
    }
    return null;
  }

  TickerFactory get factory => (interval, onTick) {
        final t = ManualTimer(onTick);
        timers.add(t);
        return t;
      };
}
