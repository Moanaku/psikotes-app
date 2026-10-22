import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simulator_psikotes_it/core/widgets/app_chip.dart';
import 'package:simulator_psikotes_it/core/widgets/choice_row.dart';
import 'package:simulator_psikotes_it/core/widgets/skeleton_list.dart';
import 'package:simulator_psikotes_it/domain/models/codes.dart';
import 'package:simulator_psikotes_it/domain/models/profile.dart';
import 'package:simulator_psikotes_it/domain/services/profile_templates.dart';

import '../../support/fake_clock.dart';
import '../../support/fake_repositories.dart';
import '../../support/pump_app.dart';

Future<AppHarness> openS02(
  WidgetTester tester, {
  FakeProfileRepository? profiles,
  double textScale = 1,
}) async {
  final app = await pumpApp(tester, profiles: profiles, textScale: textScale);
  await app.go('/onboarding/profil');
  return app;
}

Future<void> type(WidgetTester tester, String key, String text) async {
  final f = fieldIn(key);
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.enterText(f, text);
  await tester.pump();
}

Future<void> tapChip(WidgetTester tester, String label) async {
  final f = find.widgetWithText(AppChip, label);
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

bool chipSelected(WidgetTester tester, String label) =>
    tester.widget<AppChip>(find.widgetWithText(AppChip, label)).selected;

String textOf(WidgetTester tester, String key) =>
    tester.widget<TextField>(fieldIn(key)).controller!.text;

TestProfile existing({
  int id = 7,
  bool aktif = true,
  String nama = 'Mobile Dev, CCAT',
}) =>
    TestProfile(
      id: id,
      nama: nama,
      role: ProfileRole.mobile,
      formatTes: TestFormat.kustom,
      tanggalTes: DateTime.utc(2026, 12, 5),
      aktif: aktif,
      blueprint: ProfileTemplates.blueprint(
        ProfileRole.mobile,
        TestFormat.kustom,
        subtests: const [
          SubtestSpec(kategori: 'verbal', aktif: true, jumlah: 12, menit: 6),
          SubtestSpec(kategori: 'numerik', aktif: false, jumlah: 20, menit: 8),
          SubtestSpec(kategori: 'logika', aktif: false, jumlah: 20, menit: 8),
          SubtestSpec(kategori: 'figural', aktif: true, jumlah: 30, menit: 12),
          SubtestSpec(
              kategori: 'kraepelin', aktif: false, jumlah: 10, menit: 10),
          SubtestSpec(
              kategori: 'kepribadian', aktif: false, jumlah: 30, menit: 10),
        ],
      ),
      cvTeks: 'ringkasan CV',
      dibuat: DateTime.utc(2026, 9, 1),
    );

void main() {
  group('tampilan awal', () {
    testWidgets('format CCAT-style dan empat subtes aktif', (tester) async {
      await openS02(tester);
      expect(find.text('Profil tes target'), findsOneWidget);
      expect(find.text('2 / 3'), findsOneWidget);
      expect(chipSelected(tester, 'CCAT-style'), isTrue);
      expect(chipSelected(tester, 'Psikotes Bank-style'), isFalse);
      expect(chipSelected(tester, 'Verbal'), isTrue);
      expect(chipSelected(tester, 'Figural'), isTrue);
      expect(chipSelected(tester, 'Kraepelin / Pauli'), isFalse);
      expect(textOf(tester, 'jumlah-verbal'), '15');
      expect(textOf(tester, 'menit-verbal'), '4');
      expect(find.text('Simpan dan lanjut'), findsOneWidget);
      expect(find.text('Tempel CV'), findsNothing);
      expect(find.text('CV untuk wawancara'), findsOneWidget);
    });

    testWidgets('memilih format mengisi subtes dari template', (tester) async {
      await openS02(tester);
      await tapChip(tester, 'Psikotes Bank-style');
      expect(chipSelected(tester, 'Psikotes Bank-style'), isTrue);
      expect(chipSelected(tester, 'Kraepelin / Pauli'), isTrue);
      expect(chipSelected(tester, 'Logika'), isFalse);
      expect(textOf(tester, 'jumlah-verbal'), '30');
      expect(textOf(tester, 'menit-verbal'), '25');
      // Satuan Kraepelin adalah kolom, kepribadian item.
      expect(find.text('Jumlah kolom'), findsOneWidget);
      expect(find.text('Jumlah item'), findsOneWidget);

      await tapChip(tester, 'Kustom');
      expect(textOf(tester, 'jumlah-verbal'), '20');
      expect(textOf(tester, 'menit-verbal'), '8');
      expect(find.text('Jumlah kolom'), findsNothing);
    });

    testWidgets('menyalakan subtes tanpa angka mengisi angka awal',
        (tester) async {
      await openS02(tester);
      await tapChip(tester, 'Kraepelin / Pauli');
      expect(textOf(tester, 'jumlah-kraepelin'), '10');
      expect(textOf(tester, 'menit-kraepelin'), '10');
      await tapChip(tester, 'Kraepelin / Pauli');
      expect(fieldIn('jumlah-kraepelin'), findsNothing);
    });

    testWidgets('mematikan lalu menyalakan subtes menjaga angka yang diubah',
        (tester) async {
      await openS02(tester);
      await type(tester, 'jumlah-verbal', '33');
      await tapChip(tester, 'Verbal');
      await tapChip(tester, 'Verbal');
      expect(textOf(tester, 'jumlah-verbal'), '33');
    });

    testWidgets('isian jumlah dan menit hanya menerima angka', (tester) async {
      await openS02(tester);
      await type(tester, 'jumlah-verbal', 'a1b2c3d4');
      expect(textOf(tester, 'jumlah-verbal'), '123');
      await type(tester, 'tanggal', 'x3/1y1/2026999');
      // Batas panjang 10 karakter memotong sisanya.
      expect(textOf(tester, 'tanggal'), '3/11/20269');
    });
  });

  group('validasi', () {
    testWidgets('tanpa subtes aktif: pesan, dan tidak ada yang tersimpan',
        (tester) async {
      final repo = FakeProfileRepository();
      await openS02(tester, profiles: repo);
      for (final k in ['Verbal', 'Numerik', 'Logika', 'Figural']) {
        await tapChip(tester, k);
      }
      expect(
        find.text('Pilih minimal satu subtes agar latihan bisa disusun.'),
        findsNothing,
        reason: 'galat baru tampil setelah mencoba menyimpan',
      );
      await tester.tap(find.text('Simpan dan lanjut'));
      await tester.pumpAndSettle();
      expect(
        find.text('Pilih minimal satu subtes agar latihan bisa disusun.'),
        findsOneWidget,
      );
      expect(repo.saves, 0);
      expect(find.text('Profil tes target'), findsOneWidget);
    });

    testWidgets('jumlah soal di luar batas dan menit kosong', (tester) async {
      final repo = FakeProfileRepository();
      await openS02(tester, profiles: repo);
      await type(tester, 'jumlah-verbal', '201');
      await type(tester, 'menit-numerik', '');
      await tester.tap(find.text('Simpan dan lanjut'));
      await tester.pumpAndSettle();
      expect(find.text('Isi 1 sampai 200 soal.'), findsOneWidget);
      expect(find.text('Isi menit.'), findsOneWidget);
      expect(repo.saves, 0);

      // Galat hilang begitu isian benar.
      await type(tester, 'jumlah-verbal', '200');
      await type(tester, 'menit-numerik', '181');
      expect(find.text('Isi 1 sampai 200 soal.'), findsNothing);
      expect(find.text('Isi 1 sampai 180 menit.'), findsOneWidget);
    });

    testWidgets('satuan galat mengikuti subtes (kolom)', (tester) async {
      await openS02(tester);
      await tapChip(tester, 'Kraepelin / Pauli');
      await type(tester, 'jumlah-kraepelin', '');
      await tester.tap(find.text('Simpan dan lanjut'));
      await tester.pumpAndSettle();
      expect(find.text('Isi jumlah kolom.'), findsOneWidget);
    });

    testWidgets('tanggal tes di masa lalu dan tanggal yang tidak ada',
        (tester) async {
      final repo = FakeProfileRepository();
      await openS02(tester, profiles: repo);
      await type(tester, 'tanggal', '21/10/2026');
      await tester.tap(find.text('Simpan dan lanjut'));
      await tester.pumpAndSettle();
      expect(
        find.text('Tanggal tes sudah lewat. Isi hari ini atau sesudahnya, '
            'atau kosongkan.'),
        findsOneWidget,
      );
      await type(tester, 'tanggal', '31/02/2027');
      expect(
        find.text('Tulis tanggal sebagai hh/bb/tttt, mis. 03/11/2026.'),
        findsOneWidget,
      );
      expect(repo.saves, 0);

      await type(tester, 'tanggal', '22/10/2026');
      await tester.tap(find.text('Simpan dan lanjut'));
      await tester.pumpAndSettle();
      expect(repo.saves, 1, reason: 'hari ini sah');
    });

    testWidgets('"hari ini" mengikuti jam palsu, bukan jam sistem',
        (tester) async {
      final repo = FakeProfileRepository();
      final clock = FakeClock(DateTime.utc(2030, 1, 15, 8));
      final app = await pumpApp(tester, profiles: repo, clock: clock);
      await app.go('/onboarding/profil');
      await type(tester, 'tanggal', '14/01/2030');
      await tester.tap(find.text('Simpan dan lanjut'));
      await tester.pumpAndSettle();
      expect(repo.saves, 0);
      await type(tester, 'tanggal', '15/01/2030');
      await tester.tap(find.text('Simpan dan lanjut'));
      await tester.pumpAndSettle();
      expect(repo.saves, 1);
    });
  });

  group('menyimpan', () {
    testWidgets('profil baru: aktif, nama otomatis, blueprint, lalu S03',
        (tester) async {
      final repo = FakeProfileRepository();
      final app = await pumpApp(tester, profiles: repo);
      await tester.tap(find.text('Mobile / App Developer'));
      await tester.tap(find.text('Lanjut'));
      await tester.pumpAndSettle();
      await type(tester, 'jumlah-verbal', '25');
      await type(tester, 'tanggal', '03/11/2026');
      await tester.tap(find.text('Simpan dan lanjut'));
      await tester.pumpAndSettle();

      expect(app.location, '/onboarding/diagnostik');
      expect(repo.items.length, 1);
      final p = repo.items.single;
      expect(p.aktif, isTrue);
      expect(p.nama, 'Mobile Dev, CCAT-style');
      expect(p.role, ProfileRole.mobile);
      expect(p.formatTes, TestFormat.ccat);
      expect(p.tanggalTes, DateTime.utc(2026, 11, 3));
      expect(p.cvTeks, isNull);
      expect(p.dibuat, appNow);
      final verbal =
          p.blueprint.subtes.firstWhere((s) => s.kategori == 'verbal');
      expect((verbal.aktif, verbal.jumlah, verbal.menit), (true, 25, 4));
      expect(p.blueprint.subtes.length, 6);
      expect(p.blueprint.bobot.values.fold<double>(0, (a, b) => a + b),
          closeTo(1.0, 1e-9));
      expect(p.blueprint.bobot.keys.toSet(),
          {'verbal', 'numerik', 'logika', 'figural'});
    });

    testWidgets('nama yang diisi dipakai apa adanya (dipangkas)',
        (tester) async {
      final repo = FakeProfileRepository();
      await openS02(tester, profiles: repo);
      await type(tester, 'nama', '  Tes bank Maret  ');
      await tester.tap(find.text('Simpan dan lanjut'));
      await tester.pumpAndSettle();
      expect(repo.items.single.nama, 'Tes bank Maret');
    });

    testWidgets('nama otomatis tampil sebagai petunjuk dan mengikuti pilihan',
        (tester) async {
      await openS02(tester);
      expect(find.text('QA, CCAT-style'), findsOneWidget);
      await tapChip(tester, 'Psikotes Bank-style');
      expect(find.text('QA, Psikotes Bank-style'), findsOneWidget);
    });

    testWidgets('profil baru berikutnya menjadi aktif dan menonaktifkan lama',
        (tester) async {
      final repo = FakeProfileRepository([existing()]);
      final app = await pumpApp(tester, profiles: repo);
      expect(app.location, '/');
      await app.go('/onboarding/role');
      await tester.tap(find.text('Lanjut'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Simpan dan lanjut'));
      await tester.pumpAndSettle();
      expect(repo.items.length, 2);
      expect(repo.items.where((p) => p.aktif).length, 1);
      expect(repo.items.last.aktif, isTrue);
    });

    testWidgets('sesudah tersimpan draf kembali ke awal', (tester) async {
      final repo = FakeProfileRepository();
      final app = await pumpApp(tester, profiles: repo);
      await tester.tap(find.text('Umum, tanpa role'));
      await tester.tap(find.text('Lanjut'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Simpan dan lanjut'));
      await tester.pumpAndSettle();
      await app.go('/onboarding/role');
      final qa = find.widgetWithText(ChoiceRow, 'QA Engineer');
      expect(qa, findsOneWidget);
    });

    testWidgets('gagal menulis: pesan tanpa teks exception, bisa diulang',
        (tester) async {
      final repo = FakeProfileRepository()..failWith = StateError('disk penuh');
      await openS02(tester, profiles: repo);
      await tester.tap(find.text('Simpan dan lanjut'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Profil belum tersimpan'), findsOneWidget);
      expect(find.textContaining('disk penuh'), findsNothing);
      expect(find.textContaining('StateError'), findsNothing);
      expect(find.text('Profil tes target'), findsOneWidget);

      repo.failWith = null;
      await tester.tap(find.text('Simpan dan lanjut'));
      await tester.pumpAndSettle();
      expect(repo.items.length, 1);
      expect(find.textContaining('Profil belum tersimpan'), findsNothing);
    });

    testWidgets(
        'mengetuk simpan lagi saat masih menulis tidak menulis dua kali',
        (tester) async {
      final repo = FakeProfileRepository()..saveGate = Completer<void>();
      await openS02(tester, profiles: repo);
      await tester.tap(find.text('Simpan dan lanjut'));
      await tester.pump();
      await tester.tap(find.text('Simpan dan lanjut'), warnIfMissed: false);
      await tester.pump();
      expect(repo.saves, 1);
      repo.saveGate!.complete();
      await tester.pumpAndSettle();
      expect(repo.saves, 1);
      expect(repo.items.length, 1);
    });
  });

  group('mode ubah profil', () {
    testWidgets('memuat profil ke formulir; tombol Simpan profil',
        (tester) async {
      final repo = FakeProfileRepository([existing()]);
      final app = await pumpApp(tester, profiles: repo);
      await app.go('/onboarding/profil?ubah=7');
      expect(find.text('Ubah profil'), findsOneWidget);
      expect(find.text('2 / 3'), findsNothing);
      expect(find.text('Simpan profil'), findsOneWidget);
      expect(find.text('Simpan dan lanjut'), findsNothing);
      expect(chipSelected(tester, 'Kustom'), isTrue);
      expect(chipSelected(tester, 'Verbal'), isTrue);
      expect(chipSelected(tester, 'Numerik'), isFalse);
      expect(textOf(tester, 'jumlah-verbal'), '12');
      expect(textOf(tester, 'menit-figural'), '12');
      expect(textOf(tester, 'tanggal'), '05/12/2026');
      expect(textOf(tester, 'nama'), 'Mobile Dev, CCAT');
    });

    testWidgets(
        'menyimpan memperbarui profil yang sama tanpa mengubah aktif, '
        'CV, dan waktu dibuat', (tester) async {
      final repo = FakeProfileRepository([
        existing(id: 3, aktif: false, nama: 'Lama'),
        existing(id: 7),
      ]);
      final app = await pumpApp(tester, profiles: repo);
      await app.go('/onboarding/profil?ubah=3');
      await type(tester, 'nama', 'Diubah');
      await type(tester, 'jumlah-verbal', '40');
      await tester.tap(find.text('Simpan profil'));
      await tester.pumpAndSettle();

      expect(repo.items.length, 2);
      final p = repo.items.firstWhere((x) => x.id == 3);
      expect(p.nama, 'Diubah');
      expect(p.aktif, isFalse, reason: 'profil aktif lain tidak diganti');
      expect(repo.items.firstWhere((x) => x.id == 7).aktif, isTrue);
      expect(p.cvTeks, 'ringkasan CV');
      expect(p.dibuat, DateTime.utc(2026, 9, 1));
      expect(
          p.blueprint.subtes.firstWhere((s) => s.kategori == 'verbal').jumlah,
          40);
      // Subtes nonaktif tetap tersimpan dengan angkanya.
      expect(p.blueprint.subtes.length, 6);
      expect(app.location, isNot('/onboarding/diagnostik'));
    });

    testWidgets('profil tidak ada: kondisi kosong dengan jalan keluar',
        (tester) async {
      final app = await pumpApp(
        tester,
        profiles: FakeProfileRepository([existing()]),
      );
      await app.go('/onboarding/profil?ubah=99');
      expect(find.text('Profil tidak ditemukan'), findsOneWidget);
      expect(find.text('Kembali'), findsWidgets);
    });

    testWidgets('memuat: skeleton, bukan spinner', (tester) async {
      final repo = SlowProfileRepository([existing()]);
      final app = await pumpApp(tester, profiles: repo);
      app.router.go('/onboarding/profil?ubah=7');
      await tester.pump();
      await tester.pump();
      expect(find.byType(SkeletonList), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      repo.release();
      await tester.pumpAndSettle();
      expect(find.byType(SkeletonList), findsNothing);
      expect(textOf(tester, 'nama'), 'Mobile Dev, CCAT');
    });

    testWidgets('galat membaca: pesan untuk pengguna dan Coba lagi',
        (tester) async {
      final repo = FakeProfileRepository([existing()]);
      final app = await pumpApp(tester, profiles: repo);
      repo.failWith = StateError('SQLITE_IOERR');
      await app.go('/onboarding/profil?ubah=7');
      expect(find.text('Profil tidak bisa dibuka'), findsOneWidget);
      expect(find.textContaining('SQLITE'), findsNothing);
      expect(find.text('Coba lagi'), findsOneWidget);

      repo.failWith = null;
      await tester.tap(find.text('Coba lagi'));
      await tester.pumpAndSettle();
      expect(find.text('Profil tidak bisa dibuka'), findsNothing);
      expect(textOf(tester, 'nama'), 'Mobile Dev, CCAT');
    });

    testWidgets('membuka S02 baru sesudah mode ubah tidak membawa profil lama',
        (tester) async {
      final repo = FakeProfileRepository([existing()]);
      final app = await pumpApp(tester, profiles: repo);
      await app.go('/onboarding/profil?ubah=7');
      await app.go('/onboarding/role');
      await tester.tap(find.text('Lanjut'));
      await tester.pumpAndSettle();
      expect(find.text('Profil tes target'), findsOneWidget);
      expect(chipSelected(tester, 'CCAT-style'), isTrue);
      expect(textOf(tester, 'nama'), '');
      expect(textOf(tester, 'jumlah-verbal'), '15');
    });
  });

  group('aksesibilitas dan tata letak', () {
    for (final scale in [1.3, 2.0]) {
      testWidgets('tanpa meluap di 360 dp dengan skala teks $scale',
          (tester) async {
        final repo = FakeProfileRepository();
        await openS02(tester, profiles: repo, textScale: scale);
        await tapChip(tester, 'Psikotes Bank-style');
        // Galat terpanjang tampil bersamaan.
        await type(tester, 'tanggal', '21/10/2026');
        await type(tester, 'jumlah-kraepelin', '');
        await tester.tap(find.text('Simpan dan lanjut'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final button = find.widgetWithText(InkWell, 'Simpan dan lanjut');
        expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
      });
    }

    testWidgets('semua area ketuk minimal 48 x 48', (tester) async {
      await openS02(tester);
      for (final i in tester.widgetList<InkWell>(find.byType(InkWell))) {
        if (i.onTap == null) continue;
        final size = tester.getSize(find.byWidget(i));
        expect(size.height, greaterThanOrEqualTo(48), reason: '$i');
        expect(size.width, greaterThanOrEqualTo(48), reason: '$i');
      }
    });

    testWidgets('tombol kembali berlabel dan membuka S01', (tester) async {
      final app = await openS02(tester);
      expect(find.byTooltip('Kembali ke pilihan role'), findsOneWidget);
      await tester.tap(find.byTooltip('Kembali ke pilihan role'));
      await tester.pumpAndSettle();
      expect(app.location, '/onboarding/role');
    });

    testWidgets('setiap isian punya label yang dibaca pembaca layar',
        (tester) async {
      final handle = tester.ensureSemantics();
      await openS02(tester);
      for (final label in [
        'Jumlah soal',
        'Menit',
        'Tanggal tes (opsional)',
        'Nama profil',
      ]) {
        expect(find.bySemanticsLabel(label), findsWidgets, reason: label);
      }
      handle.dispose();
    });
  });
}

/// Repository yang menahan `byId` sampai [release] dipanggil.
class SlowProfileRepository extends FakeProfileRepository {
  SlowProfileRepository(super.initial);

  final Completer<void> _gate = Completer<void>();

  void release() => _gate.complete();

  @override
  Future<TestProfile?> byId(int id) async {
    await _gate.future;
    return super.byId(id);
  }
}
