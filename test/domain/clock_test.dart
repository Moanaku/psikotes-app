import 'package:flutter_test/flutter_test.dart';
import 'package:simulator_psikotes_it/domain/services/clock.dart';

import '../data/db_helper.dart' show t0;
import 'session_harness.dart';

void main() {
  late FakeClock clock;
  late WallClockGuard guard;

  setUp(() {
    clock = FakeClock(t0);
    guard = WallClockGuard(clock);
  });

  test('bacaan pertama tidak pernah lompatan', () {
    clock.shiftWall(const Duration(hours: 5));
    final r = guard.read();
    expect(r.jump, Duration.zero);
    expect(r.now, t0.add(const Duration(hours: 5)));
  });

  test('waktu berjalan normal bukan lompatan', () {
    guard.read();
    clock.advance(const Duration(minutes: 3));
    expect(guard.read().jump, Duration.zero);
  });

  test('jam mundur selalu lompatan, juga setelah jeda', () {
    guard.read();
    clock.advance(const Duration(seconds: 10));
    clock.shiftWall(const Duration(minutes: -20));
    expect(guard.read().jump, const Duration(minutes: -20));

    guard.markInterrupted();
    clock.shiftWall(const Duration(minutes: -5));
    expect(guard.read().jump, const Duration(minutes: -5));
  });

  test('jam maju tanpa jeda lompatan; setelah jeda diterima sebagai tidur', () {
    guard.read();
    clock.shiftWall(const Duration(minutes: 7));
    expect(guard.read().jump, const Duration(minutes: 7));

    guard.markInterrupted();
    clock.sleep(const Duration(minutes: 7));
    expect(guard.read().jump, Duration.zero);

    // Tanda jeda hanya berlaku untuk satu bacaan.
    clock.shiftWall(const Duration(minutes: 7));
    expect(guard.read().jump, const Duration(minutes: 7));
  });

  test('selisih di dalam toleransi bukan lompatan', () {
    guard.read();
    clock.advance(const Duration(seconds: 1));
    clock.shiftWall(const Duration(seconds: 2));
    expect(guard.read().jump, Duration.zero);
    clock.shiftWall(const Duration(seconds: -2));
    expect(guard.read().jump, Duration.zero);
    clock.shiftWall(const Duration(milliseconds: -2001));
    expect(guard.read().jump, const Duration(milliseconds: -2001));
  });

  test('SystemClock memberi waktu UTC dan monoton tidak mundur', () {
    final c = SystemClock();
    expect(c.now().isUtc, isTrue);
    final a = c.monotonic();
    final b = c.monotonic();
    expect(b >= a, isTrue);
  });
}
