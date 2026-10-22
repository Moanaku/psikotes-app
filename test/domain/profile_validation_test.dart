import 'package:flutter_test/flutter_test.dart';
import 'package:simulator_psikotes_it/domain/models/codes.dart';
import 'package:simulator_psikotes_it/domain/services/profile_templates.dart';
import 'package:simulator_psikotes_it/domain/services/profile_validation.dart';

final today = DateTime.utc(2026, 10, 22);

List<SubtestInput> inputs([TestFormat f = TestFormat.ccat]) => [
      for (final s in ProfileTemplates.subtests(f)) SubtestInput.fromSpec(s),
    ];

ProfileErrors check(List<SubtestInput> s, {String tanggal = ''}) =>
    ProfileValidation.validate(subtests: s, tanggal: tanggal, today: today);

List<SubtestInput> change(
  List<SubtestInput> list,
  String kategori,
  SubtestInput Function(SubtestInput) f,
) =>
    [
      for (final s in list)
        if (s.kategori == kategori) f(s) else s,
    ];

void main() {
  test('template awal semua format sah', () {
    for (final f in TestFormat.values) {
      expect(check(inputs(f)).isValid, isTrue, reason: f.code);
    }
  });

  group('subtes', () {
    test('tanpa subtes aktif tidak sah', () {
      final none = [for (final s in inputs()) s.copyWith(aktif: false)];
      final e = check(none);
      expect(e.noSubtest, isTrue);
      expect(e.isValid, isFalse);
    });

    test('satu subtes aktif cukup', () {
      final one = [
        for (final s in inputs()) s.copyWith(aktif: s.kategori == 'verbal'),
      ];
      expect(check(one).isValid, isTrue);
    });

    test('jumlah soal: 1 dan 200 sah, 0 dan 201 di luar batas', () {
      for (final (v, ok) in [
        ('1', true),
        ('200', true),
        ('0', false),
        ('201', false),
      ]) {
        final e =
            check(change(inputs(), 'verbal', (s) => s.copyWith(jumlah: v)));
        expect(e.jumlah.containsKey('verbal'), !ok, reason: v);
        if (!ok) expect(e.jumlah['verbal'], NumberError.outOfRange);
      }
    });

    test('menit: 1 dan 180 sah, 0 dan 181 di luar batas', () {
      for (final (v, ok) in [
        ('1', true),
        ('180', true),
        ('0', false),
        ('181', false),
      ]) {
        final e =
            check(change(inputs(), 'numerik', (s) => s.copyWith(menit: v)));
        expect(e.menit.containsKey('numerik'), !ok, reason: v);
      }
    });

    test('kosong atau bukan angka: invalid', () {
      for (final v in ['', ' ', 'abc', '1,5']) {
        final e =
            check(change(inputs(), 'logika', (s) => s.copyWith(jumlah: v)));
        expect(e.jumlah['logika'], NumberError.invalid, reason: '"$v"');
      }
    });

    test('angka negatif di luar batas', () {
      final e =
          check(change(inputs(), 'logika', (s) => s.copyWith(jumlah: '-3')));
      expect(e.jumlah['logika'], NumberError.outOfRange);
    });

    test('subtes nonaktif tidak diperiksa', () {
      final e = check(change(
        inputs(),
        'kraepelin',
        (s) => s.copyWith(aktif: false, jumlah: '', menit: 'x'),
      ));
      expect(e.isValid, isTrue);
    });
  });

  group('tanggal tes', () {
    test('kosong boleh', () => expect(check(inputs()).tanggal, isNull));

    test('hari ini dan sesudahnya sah, kemarin tidak', () {
      expect(check(inputs(), tanggal: '22/10/2026').tanggal, isNull);
      expect(check(inputs(), tanggal: '03/11/2026').tanggal, isNull);
      expect(check(inputs(), tanggal: '21/10/2026').tanggal, DateError.past);
      expect(check(inputs(), tanggal: '01/01/2020').tanggal, DateError.past);
    });

    test('bukan tanggal kalender: invalid', () {
      for (final t in [
        '31/02/2027',
        '00/10/2026',
        '10/13/2026',
        '3/11',
        '2026-11-03',
        'besok',
        '3/11/26',
      ]) {
        expect(check(inputs(), tanggal: t).tanggal, DateError.invalid,
            reason: t);
      }
    });

    test('29 Februari hanya di tahun kabisat', () {
      expect(check(inputs(), tanggal: '29/02/2028').tanggal, isNull);
      expect(check(inputs(), tanggal: '29/02/2027').tanggal, DateError.invalid);
    });

    test('spasi dan satu digit diterima', () {
      expect(ProfileValidation.parseDate(' 3 / 11 / 2026 '),
          DateTime.utc(2026, 11, 3));
    });

    test('"hari ini" mengikuti tanggal kalender, bukan jam', () {
      final late = DateTime(2026, 10, 22, 23, 30);
      final e = ProfileValidation.validate(
        subtests: inputs(),
        tanggal: '22/10/2026',
        today: ProfileValidation.dateOnly(late),
      );
      expect(e.tanggal, isNull);
    });

    test('format tanggal bolak-balik', () {
      expect(
          ProfileValidation.formatDate(DateTime.utc(2026, 1, 5)), '05/01/2026');
      expect(
          ProfileValidation.parseDate(
              ProfileValidation.formatDate(DateTime.utc(2027, 12, 31))),
          DateTime.utc(2027, 12, 31));
    });
  });

  test('toBlueprint: isian nonaktif yang rusak diganti angka awal', () {
    final list = change(
      inputs(),
      'kraepelin',
      (s) => s.copyWith(aktif: false, jumlah: '', menit: 'x'),
    );
    final b =
        ProfileValidation.toBlueprint(ProfileRole.qa, TestFormat.ccat, list);
    final k = b.subtes.firstWhere((s) => s.kategori == 'kraepelin');
    expect((k.aktif, k.jumlah, k.menit), (false, 10, 10));
  });
}
