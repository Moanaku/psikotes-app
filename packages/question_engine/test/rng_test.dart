import 'package:question_engine/question_engine.dart';
import 'package:test/test.dart';

/// Nilai emas dihitung dari implementasi Python acuan: python tool/rng_reference.py.
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
    test('attempt besar tetap eksak di web', () {
      expect(take(Rng.derive(100, 0xFFFFFFFF), 3),
          [1896781246, 3566831650, 1445652332]);
      expect(take(Rng.derive(0xDEADBEEF, 19), 3),
          [3985073801, 731808354, 2172997355]);
    });
    test('attempt di luar 32 bit ditolak', () {
      expect(() => Rng.derive(1, -1), throwsRangeError);
      expect(() => Rng.derive(1, 0x100000000), throwsRangeError);
    });
    test('attempt berbeda memberi deret berbeda', () {
      expect(take(Rng.derive(100, 0), 3), isNot(take(Rng.derive(100, 1), 3)));
    });
  });

  group('nilai emas metode turunan', () {
    test('seed negatif dan di atas 32 bit dipotong ke 32 bit', () {
      expect(take(Rng(-1), 3), [2999224306, 1700793103, 3829070063]);
      expect(take(Rng(0x10000000005), 3), [379170181, 1175100977, 2891591223]);
    });
    test('Rng(2024).nextBool x12', () {
      final r = Rng(2024);
      expect([
        for (var i = 0; i < 12; i++) r.nextBool()
      ], [
        true, true, true, true, false, false, //
        true, false, false, true, true, false,
      ]);
    });
    test('Rng(3).nextInt(1000000007) x4', () {
      final r = Rng(3);
      expect([for (var i = 0; i < 4; i++) r.nextInt(1000000007)],
          [57047048, 612810732, 792598780, 843875445]);
    });
    test('Rng(11).pick x8', () {
      final r = Rng(11);
      final letters = 'ABCDEFGH'.split('');
      expect([for (var i = 0; i < 8; i++) r.pick(letters)].join(), 'FCBFHAGA');
    });
    test('Rng(5).shuffle(0..9)', () {
      expect(Rng(5).shuffle([for (var i = 0; i < 10; i++) i]),
          [5, 0, 8, 4, 3, 6, 9, 7, 2, 1]);
    });
    test('Rng(9).shuffle(0..7) dua kali berturut-turut', () {
      final r = Rng(9);
      final src = [for (var i = 0; i < 8; i++) i];
      expect(r.shuffle(src), [1, 0, 5, 2, 6, 3, 4, 7]);
      expect(r.shuffle(src), [1, 3, 0, 4, 7, 5, 2, 6]);
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
