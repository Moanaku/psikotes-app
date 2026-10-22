import 'package:question_engine/question_engine.dart';
import 'package:test/test.dart';

void main() {
  group('Fraction', () {
    test('disederhanakan dan penyebut positif', () {
      final f = Fraction(6, -8);
      expect(f.num, -3);
      expect(f.den, 4);
      expect(Fraction(0, 5).toString(), '0');
    });

    test('operasi eksak tanpa galat desimal', () {
      // 0,1 + 0,2 = 0,3 persis (double memberi 0.30000000000000004).
      final sum = Fraction(1, 10) + Fraction(2, 10);
      expect(sum.equals(Fraction(3, 10)), isTrue);
      expect((Fraction(1, 3) * Fraction(3)).equals(Fraction.one), isTrue);
      expect((Fraction(7) / Fraction(2)).toString(), '7/2');
      expect((Fraction(1, 2) - Fraction(3, 4)).toString(), '-1/4');
    });

    test('pembanding', () {
      expect(Fraction(1, 3) < Fraction(1, 2), isTrue);
      expect(Fraction(2, 4).compareTo(Fraction(1, 2)), 0);
      expect(Fraction(-1, 2) < Fraction.zero, isTrue);
    });

    test('bagi nol dan melampaui batas', () {
      expect(() => Fraction(1, 0), throwsArgumentError);
      expect(() => Fraction.one / Fraction.zero, throwsArgumentError);
      expect(
          () => Fraction(Fraction.limit + 1), throwsA(isA<FractionOverflow>()));
      expect(() => Fraction(Fraction.limit) * Fraction(Fraction.limit),
          throwsA(isA<FractionOverflow>()));
    });

    test('pembulatan setengah ke atas dan pemotongan', () {
      expect(Fraction(5, 2).roundHalfUp(), 3);
      expect(Fraction(7, 3).roundHalfUp(), 2);
      expect(Fraction(7, 3).truncate(), 2);
      expect(Fraction(9, 2).roundHalfUp(), 5);
    });

    test('teks desimal dengan koma dan titik ribuan', () {
      expect(Fraction(3, 4).toDecimal(), '0,75');
      expect(Fraction(25, 2).toDecimal(), '12,5');
      expect(Fraction(7).toDecimal(), '7');
      expect(Fraction(1000).toDecimal(), '1.000');
      expect(Fraction(1234567, 100).toDecimal(), '12.345,67');
      expect(Fraction(-5, 2).toDecimal(), '-2,5');
      expect(Fraction(1, 3).toDecimal(), isNull);
      expect(Fraction(1, 8).toDecimal(maxPlaces: 2), isNull);
      expect(Fraction(1, 8).toDecimal(maxPlaces: 3), '0,125');
    });

    test('parse desimal dan angka tampilan', () {
      expect(Fraction.parseDecimal('12,5')!.equals(Fraction(25, 2)), isTrue);
      expect(Fraction.parseDecimal('3')!.equals(Fraction(3)), isTrue);
      expect(Fraction.parseDecimal('-3'), isNull);
      expect(Fraction.parseDecimal('abc'), isNull);
      expect(parseDisplayNumber('45.000')!.equals(Fraction(45000)), isTrue);
      expect(
          parseDisplayNumber('1.234.567')!.equals(Fraction(1234567)), isTrue);
      expect(parseDisplayNumber('12.345,67')!.equals(Fraction(1234567, 100)),
          isTrue);
      expect(parseDisplayNumber('0,75')!.equals(Fraction(3, 4)), isTrue);
    });

    test('teks desimal dan parse saling berlawanan', () {
      for (final f in [
        Fraction(0),
        Fraction(7),
        Fraction(1, 2),
        Fraction(999, 100),
        Fraction(100000),
        Fraction(123456, 100),
      ]) {
        expect(parseDisplayNumber(f.toDecimal()!)!.equals(f), isTrue,
            reason: '$f -> ${f.toDecimal()}');
      }
    });
  });
}
