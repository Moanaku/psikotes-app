import 'package:question_engine/question_engine.dart';
import 'package:test/test.dart';

/// Nilai emas dihitung dari implementasi Python acuan (lihat docs/02-arsitektur.md).
/// Test ini harus lolos identik di VM dan di Chrome:
///   dart test -p vm,chrome
void main() {
  List<int> take(Rng r, int n) => [for (var i = 0; i < n; i++) r.nextUint32()];

  group('nilai emas nextUint32', () {
    test('seed 1', () {
      expect(take(Rng(1), 5),
          [2005365029, 2916098932, 2657092299, 1495045943, 3031976842]);
    });
    test('seed 42', () {
      expect(take(Rng(42), 5),
          [3120216979, 1067267639, 2989017562, 3379058227, 3060050788]);
    });
    test('seed 123456789', () {
      expect(take(Rng(123456789), 5),
          [4242376622, 3374601978, 1016977383, 1246752311, 1185147795]);
    });
    test('seed 0 memakai konstanta pengganti', () {
      expect(take(Rng(0), 5),
          [4184948546, 230363598, 2682136559, 1063167422, 2529892618]);
    });
  });

  group('nextInt', () {
    test('Rng(42).nextInt(10) x10', () {
      final r = Rng(42);
      expect([for (var i = 0; i < 10; i++) r.nextInt(10)],
          [9, 9, 2, 7, 8, 2, 1, 1, 0, 0]);
    });
    test('Rng(7).nextInt(6) x12', () {
      final r = Rng(7);
      expect([for (var i = 0; i < 12; i++) r.nextInt(6)],
          [5, 2, 5, 0, 0, 0, 1, 3, 5, 4, 2, 3]);
    });
    test('menolak max tidak valid', () {
      expect(() => Rng(1).nextInt(0), throwsRangeError);
      expect(() => Rng(1).nextInt(-3), throwsRangeError);
    });
  });

  group('derive', () {
    test('derive(100, 3) nilai emas', () {
      expect(take(Rng.derive(100, 3), 3), [965043693, 841572689, 3731522640]);
    });
    test('attempt berbeda memberi deret berbeda', () {
      expect(take(Rng.derive(100, 0), 3), isNot(take(Rng.derive(100, 1), 3)));
    });
  });

  group('sifat umum', () {
    test('seed sama memberi deret sama', () {
      expect(take(Rng(99), 50), take(Rng(99), 50));
    });
    test('shuffle tidak mengubah list asli dan menjaga isi', () {
      final src = [1, 2, 3, 4, 5, 6];
      final out = Rng(5).shuffle(src);
      expect(src, [1, 2, 3, 4, 5, 6]);
      expect([...out]..sort(), src);
    });
    test('pick pada list kosong melempar', () {
      expect(() => Rng(1).pick(<int>[]), throwsArgumentError);
    });
  });
}
