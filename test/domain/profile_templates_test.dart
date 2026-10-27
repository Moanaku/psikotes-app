import 'package:flutter_test/flutter_test.dart';
import 'package:simulator_psikotes_it/domain/models/codes.dart';
import 'package:simulator_psikotes_it/domain/models/profile.dart';
import 'package:simulator_psikotes_it/domain/services/profile_templates.dart';

double sum(Map<String, double> w) => w.values.fold(0, (a, b) => a + b);

List<String> activeOf(List<SubtestSpec> s) => [
      for (final x in s)
        if (x.aktif) x.kategori,
    ];

void main() {
  group('subtes per format', () {
    test('semua format memuat tujuh kategori S02 berurutan', () {
      for (final f in TestFormat.values) {
        expect(
          [for (final s in ProfileTemplates.subtests(f)) s.kategori],
          ProfileTemplates.subtestCategories,
          reason: f.code,
        );
      }
    });

    test('CCAT-style: empat kategori kognitif, 50 soal, 15 menit', () {
      final s = ProfileTemplates.subtests(TestFormat.ccat);
      expect(activeOf(s), ['verbal', 'numerik', 'logika', 'figural']);
      final on = s.where((x) => x.aktif);
      expect(on.fold<int>(0, (a, x) => a + x.jumlah), 50);
      expect(on.fold<int>(0, (a, x) => a + x.menit), 15);
    });

    test('Psikotes Bank-style: lima kategori, 120 soal, 90 sampai 120 menit',
        () {
      final s = ProfileTemplates.subtests(TestFormat.bank);
      expect(activeOf(s),
          ['verbal', 'numerik', 'figural', 'kraepelin', 'kepribadian']);
      final on = s.where((x) => x.aktif);
      expect(
        on
            .where((x) => x.kategori != 'kraepelin')
            .fold<int>(0, (a, x) => a + x.jumlah),
        120,
      );
      final minutes = on.fold<int>(0, (a, x) => a + x.menit);
      expect(minutes, inInclusiveRange(90, 120));
    });

    test('Kustom: empat kategori kognitif, 20 soal dan 8 menit (A4)', () {
      final s = ProfileTemplates.subtests(TestFormat.kustom);
      expect(activeOf(s), ['verbal', 'numerik', 'logika', 'figural']);
      for (final x in s.where((x) => x.aktif)) {
        expect((x.jumlah, x.menit), (20, 8));
      }
    });

    test('subtes nonaktif tetap punya angka awal yang sah', () {
      for (final f in TestFormat.values) {
        for (final s in ProfileTemplates.subtests(f)) {
          expect(s.jumlah, inInclusiveRange(1, 200), reason: s.kategori);
          expect(s.menit, inInclusiveRange(1, 180), reason: s.kategori);
        }
      }
    });
  });

  group('subtes khusus role (A101)', () {
    test('Mobile Dev menyalakan Modul IT di semua format, role lain tidak', () {
      for (final f in TestFormat.values) {
        final mobile = ProfileTemplates.subtests(f, role: ProfileRole.mobile);
        final it = mobile.firstWhere((s) => s.kategori == 'it');
        expect((it.aktif, it.jumlah, it.menit), (true, 10, 10), reason: f.code);
        for (final r in [ProfileRole.qa, ProfileRole.ba, ProfileRole.umum]) {
          expect(
            ProfileTemplates.subtests(f, role: r)
                .firstWhere((s) => s.kategori == 'it')
                .aktif,
            isFalse,
            reason: '${r.code} ${f.code}',
          );
        }
      }
    });

    test('bobot Modul IT naik untuk Mobile Dev dan berjumlah 1,0', () {
      final b = ProfileTemplates.blueprint(ProfileRole.mobile, TestFormat.ccat);
      expect(b.bobot.keys, contains('it'));
      expect(sum(b.bobot), closeTo(1.0, 1e-9));
      // Bobot dasar terkecil CCAT 0,20, dinaikkan 50%: IT setara figural.
      expect(b.bobot['it'], closeTo(b.bobot['figural']!, 1e-4));
    });
  });

  group('bobot', () {
    test('selalu berjumlah 1,0 dan hanya untuk subtes aktif', () {
      for (final r in ProfileTemplates.roles) {
        for (final f in TestFormat.values) {
          final subtests = ProfileTemplates.subtests(f);
          final w = ProfileTemplates.weights(r, f, subtests);
          expect(sum(w), closeTo(1.0, 1e-9), reason: '${r.code} ${f.code}');
          expect(w.keys.toSet(), activeOf(subtests).toSet());
          for (final v in w.values) {
            expect(v, greaterThan(0));
          }
        }
      }
    });

    test('Umum dan Lainnya memakai bobot dasar format tanpa kenaikan', () {
      final s = ProfileTemplates.subtests(TestFormat.ccat);
      for (final r in [ProfileRole.umum, ProfileRole.lainnya]) {
        expect(ProfileTemplates.weights(r, TestFormat.ccat, s), {
          'verbal': 0.3,
          'numerik': 0.3,
          'logika': 0.2,
          'figural': 0.2,
        });
      }
    });

    test('Umum di format Kustom: semua kategori aktif berbobot rata', () {
      final w = ProfileTemplates.weights(
        ProfileRole.umum,
        TestFormat.kustom,
        ProfileTemplates.subtests(TestFormat.kustom),
      );
      expect(w.values, everyElement(0.25));
    });

    test('QA menaikkan logika 50% relatif lalu menormalkan (A2)', () {
      final s = ProfileTemplates.subtests(TestFormat.ccat);
      final base =
          ProfileTemplates.weights(ProfileRole.umum, TestFormat.ccat, s);
      final qa = ProfileTemplates.weights(ProfileRole.qa, TestFormat.ccat, s);
      // 0,30 / 0,30 / 0,20 x 1,5 / 0,20 menjadi 0,30 / 0,30 / 0,30 / 0,20: 1,10.
      expect(qa['logika']!, closeTo(0.30 / 1.10, 1e-3));
      expect(qa['logika']!, greaterThan(base['logika']!));
      expect(qa['verbal']!, lessThan(base['verbal']!));
      expect(qa['logika']! / qa['figural']!, closeTo(1.5, 1e-2));
    });

    test('IT BA menaikkan verbal dan numerik; Mobile Dev menaikkan figural',
        () {
      final s = ProfileTemplates.subtests(TestFormat.ccat);
      final ba = ProfileTemplates.weights(ProfileRole.ba, TestFormat.ccat, s);
      expect(ba['verbal']!, closeTo(0.45 / 1.30, 1e-3));
      expect(ba['numerik']!, closeTo(0.45 / 1.30, 1e-3));
      expect(ba['logika']!, closeTo(0.20 / 1.30, 1e-3));
      final mobile =
          ProfileTemplates.weights(ProfileRole.mobile, TestFormat.ccat, s);
      expect(mobile['figural']!, closeTo(0.30 / 1.10, 1e-3));
    });

    test(
        'QA di Bank-style menaikkan Kraepelin; kategori role yang tidak ada '
        'di daftar S02 tidak berpengaruh', () {
      final s = ProfileTemplates.subtests(TestFormat.bank);
      final qa = ProfileTemplates.weights(ProfileRole.qa, TestFormat.bank, s);
      expect(qa['kraepelin']!, closeTo(0.225 / 1.075, 1e-3));
      // Mobile menaikkan "it", yang tidak ada di daftar S02: hanya figural.
      final mobile =
          ProfileTemplates.weights(ProfileRole.mobile, TestFormat.bank, s);
      expect(mobile['figural']!, closeTo(0.30 / 1.10, 1e-3));
    });

    test('subtes di luar bobot dasar memakai bobot dasar terkecil', () {
      final s = [
        for (final x in ProfileTemplates.subtests(TestFormat.ccat))
          if (x.kategori == 'kraepelin')
            const SubtestSpec(
                kategori: 'kraepelin', aktif: true, jumlah: 10, menit: 10)
          else
            x,
      ];
      final w = ProfileTemplates.weights(ProfileRole.umum, TestFormat.ccat, s);
      expect(w['kraepelin'], closeTo(0.2 / 1.2, 1e-3));
      expect(sum(w), closeTo(1.0, 1e-9));
    });

    test('tanpa subtes aktif: kosong', () {
      final s = [
        for (final x in ProfileTemplates.subtests(TestFormat.ccat))
          SubtestSpec(kategori: x.kategori, aktif: false, jumlah: 1, menit: 1),
      ];
      expect(ProfileTemplates.weights(ProfileRole.qa, TestFormat.ccat, s),
          isEmpty);
    });

    test('blueprint menyimpan subtes nonaktif dan bobot', () {
      final b = ProfileTemplates.blueprint(ProfileRole.qa, TestFormat.ccat);
      expect(b.subtes.length, 7);
      expect(b.subtes.where((s) => !s.aktif).map((s) => s.kategori),
          ['kraepelin', 'kepribadian', 'it']);
      expect(sum(b.bobot), closeTo(1.0, 1e-9));
      // Bisa dibaca ulang oleh ProfileBlueprint.fromJson.
      final again = ProfileBlueprint.fromJson(b.toJson());
      expect(again.bobot, b.bobot);
    });
  });

  group('nama', () {
    test('nama otomatis memakai singkatan role dan nama format', () {
      expect(ProfileTemplates.autoName(ProfileRole.qa, TestFormat.ccat),
          'QA, CCAT-style');
      expect(ProfileTemplates.autoName(ProfileRole.mobile, TestFormat.bank),
          'Mobile Dev, Psikotes Bank-style');
      expect(ProfileTemplates.autoName(ProfileRole.umum, TestFormat.kustom),
          'Umum, Kustom');
    });

    test('satuan jumlah: kolom untuk Kraepelin, item untuk kepribadian', () {
      expect(ProfileTemplates.countUnit('kraepelin'), 'kolom');
      expect(ProfileTemplates.countUnit('kepribadian'), 'item');
      expect(ProfileTemplates.countUnit('verbal'), 'soal');
    });
  });
}
