import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simulator_psikotes_it/app/routes.dart';
import 'package:simulator_psikotes_it/core/theme/app_tokens.dart';
import 'package:simulator_psikotes_it/core/widgets/app_chip.dart';
import 'package:simulator_psikotes_it/core/widgets/app_text_field.dart';
import 'package:simulator_psikotes_it/domain/models/notebook.dart';
import 'package:simulator_psikotes_it/domain/providers.dart';
import 'package:simulator_psikotes_it/domain/services/capture_service.dart';
import 'package:simulator_psikotes_it/features/capture/capture_screen.dart';
import 'package:simulator_psikotes_it/features/capture/capture_provider.dart';

import '../../core/golden_helper.dart' show expectTouchTargets48;
import '../../support/fake_repositories.dart';
import '../../support/fixtures.dart';
import '../../support/pump_app.dart';

/// Isian di dalam [AppTextField] berlabel [label].
Finder field(String label) => find.descendant(
      of: find.ancestor(
        of: find.text(label),
        matching: find.byType(AppTextField),
      ),
      matching: find.byType(TextField),
    );

final Uint8List pixel = Uint8List.fromList(const [
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x63,
  0xF8,
  0xFF,
  0xFF,
  0x3F,
  0x00,
  0x05,
  0xFE,
  0x02,
  0xFE,
  0xA7,
  0x35,
  0x81,
  0x84,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
]);

Future<AppHarness> open(
  WidgetTester tester, {
  String path = Routes.capture,
  FakeCaptureRepository? captures,
  FakeCompanyLogRepository? logs,
  MemoryPhotoStore? photos,
  PhotoPicker? picker,
  double textScale = 1,
}) async {
  final app = await pumpApp(
    tester,
    profiles: FakeProfileRepository([activeProfile()]),
    captures: captures,
    logs: logs,
    photos: photos,
    textScale: textScale,
    overrides: [
      if (picker != null) photoPickerProvider.overrideWithValue(picker),
    ],
  );
  await app.go(Routes.psikotes);
  unawaited(app.router.push(path));
  await tester.pumpAndSettle();
  return app;
}

Future<void> tapChip(WidgetTester tester, String label) async {
  final chip = find.widgetWithText(AppChip, label);
  await tester.ensureVisible(chip);
  await tester.tap(chip);
  await tester.pump();
}

Future<void> pickKey(WidgetTester tester, int slot) async {
  final radio = find.byKey(ValueKey('kunci-$slot'));
  await tester.ensureVisible(radio);
  await tester.tap(radio);
  await tester.pump();
}

Future<void> fillValid(WidgetTester tester, {bool withKey = true}) async {
  await tapChip(tester, 'Numerik');
  await tester.enterText(field('Teks soal'), 'Berapa 2 + 2?');
  await tester.enterText(field('Opsi A'), '3');
  await tester.enterText(field('Opsi B'), '4');
  await tester.enterText(field('Opsi C'), '5');
  if (withKey) await pickKey(tester, 1);
  await tester.pump();
}

Future<void> save(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Simpan ke bank pribadi'));
  await tester.tap(find.text('Simpan ke bank pribadi'));
  await tester.pumpAndSettle();
}

void main() {
  group('tampilan', () {
    testWidgets('catatan privasi, kategori, opsi A sampai D, dan tombol simpan',
        (tester) async {
      final handle = tester.ensureSemantics();
      await open(tester);
      expect(
        find.text('Disimpan hanya di HP ini dan tidak ikut ke repo. Jangan '
            'bagikan soal asli perusahaan.'),
        findsOneWidget,
      );
      for (final k in ['Verbal', 'Numerik', 'Logika', 'Figural', 'Tipe baru']) {
        expect(find.widgetWithText(AppChip, k), findsOneWidget);
      }
      for (final l in ['A', 'B', 'C', 'D']) {
        expect(find.text('Opsi $l'), findsOneWidget);
        expect(find.bySemanticsLabel('Jadikan opsi $l sebagai kunci'),
            findsOneWidget);
      }
      expect(find.text('Simpan ke bank pribadi'), findsOneWidget);
      expect(find.text('Hapus soal ini'), findsNothing,
          reason: 'hanya di mode ubah');
      handle.dispose();
    });

    testWidgets('tambah opsi sampai enam lalu tombolnya hilang',
        (tester) async {
      await open(tester);
      for (final l in ['E', 'F']) {
        await tester.ensureVisible(find.text('Tambah opsi'));
        await tester.tap(find.text('Tambah opsi'));
        await tester.pump();
        expect(find.text('Opsi $l'), findsOneWidget);
      }
      expect(find.text('Tambah opsi'), findsNothing);
    });

    testWidgets('Tipe baru membuka isian nama tipe', (tester) async {
      await open(tester);
      expect(find.text('Nama tipe baru'), findsNothing);
      await tapChip(tester, 'Tipe baru');
      expect(find.text('Nama tipe baru'), findsOneWidget);
    });
  });

  group('validasi', () {
    testWidgets('formulir kosong: galat dekat bagiannya, tidak menyimpan',
        (tester) async {
      final repo = FakeCaptureRepository();
      final app = await open(tester, captures: repo);
      await save(tester);
      expect(
          find.text('Isi teks soal atau tambahkan foto soal.'), findsOneWidget);
      expect(find.text('Isi minimal 2 opsi jawaban.'), findsOneWidget);
      expect(
        find.text('Kunci jawaban belum dipilih. Pilih lingkaran di kiri opsi '
            'yang benar.'),
        findsOneWidget,
      );
      expect(find.text('Pilih kategori soal, atau isi nama tipe baru.'),
          findsOneWidget);
      expect(repo.items, isEmpty);
      expect(app.location, startsWith(Routes.capture));
    });

    testWidgets('hanya kunci yang belum dipilih', (tester) async {
      final repo = FakeCaptureRepository();
      await open(tester, captures: repo);
      await fillValid(tester, withKey: false);
      await save(tester);
      expect(
          find.textContaining('Kunci jawaban belum dipilih'), findsOneWidget);
      expect(
          find.text('Isi teks soal atau tambahkan foto soal.'), findsNothing);
      expect(repo.items, isEmpty);
    });

    testWidgets('kunci pada opsi kosong ditolak', (tester) async {
      final repo = FakeCaptureRepository();
      await open(tester, captures: repo);
      await fillValid(tester, withKey: false);
      await pickKey(tester, 3);
      await save(tester);
      expect(find.textContaining('menunjuk opsi yang masih kosong'),
          findsOneWidget);
      expect(repo.items, isEmpty);
    });

    testWidgets('galat hilang begitu isian diperbaiki', (tester) async {
      await open(tester);
      await save(tester);
      expect(
          find.text('Isi teks soal atau tambahkan foto soal.'), findsOneWidget);
      await tester.enterText(field('Teks soal'), 'Soal');
      await tester.pump();
      expect(
          find.text('Isi teks soal atau tambahkan foto soal.'), findsNothing);
    });

    testWidgets('tipe baru tanpa nama ditolak', (tester) async {
      await open(tester);
      await tapChip(tester, 'Tipe baru');
      await save(tester);
      expect(find.text('Pilih kategori soal, atau isi nama tipe baru.'),
          findsOneWidget);
    });
  });

  group('simpan', () {
    testWidgets('soal tersimpan, opsi kosong dibuang, kembali ke S05',
        (tester) async {
      final repo = FakeCaptureRepository();
      final app = await open(tester, captures: repo);
      await fillValid(tester);
      await tester.enterText(field('Pembahasan (opsional)'), 'Dua tambah dua.');
      await save(tester);

      final q = repo.items.single;
      expect(q.teks, 'Berapa 2 + 2?');
      expect(q.opsi, ['3', '4', '5']);
      expect(q.kunci, 1);
      expect(q.kategori, 'numerik');
      expect(q.pembahasan, 'Dua tambah dua.');
      expect(q.dibuat, appNow);
      expect(app.location, Routes.psikotes);
    });

    testWidgets('tipe baru disimpan sebagai kategori', (tester) async {
      final repo = FakeCaptureRepository();
      await open(tester, captures: repo);
      await fillValid(tester);
      await tapChip(tester, 'Tipe baru');
      await tester.enterText(field('Nama tipe baru'), 'lipat kertas');
      await save(tester);
      expect(repo.items.single.kategori, 'lipat kertas');
    });

    testWidgets('gagal menulis: pesan tanpa exception, bisa dicoba lagi',
        (tester) async {
      final repo = FakeCaptureRepository()
        ..saveFailWith = StateError('disk penuh');
      final app = await open(tester, captures: repo);
      await fillValid(tester);
      await save(tester);
      expect(find.textContaining('Soal belum tersimpan'), findsOneWidget);
      expect(find.textContaining('disk penuh'), findsNothing);
      expect(app.location, startsWith(Routes.capture));

      repo.saveFailWith = null;
      await save(tester);
      expect(repo.items, hasLength(1));
      expect(app.location, Routes.psikotes);
    });

    testWidgets('dibuka dari catatan tes: soal terhubung ke catatan',
        (tester) async {
      final repo = FakeCaptureRepository();
      final logs = FakeCompanyLogRepository([
        CompanyTestLog(
          id: 5,
          perusahaan: 'PT Maju',
          tanggal: DateTime.utc(2026, 10, 1),
        ),
      ]);
      await open(
        tester,
        path: Routes.capturePath(logId: 5, tipe: 'lipat kertas'),
        captures: repo,
        logs: logs,
      );
      expect(
        tester
            .widget<AppChip>(find.widgetWithText(AppChip, 'PT Maju'))
            .selected,
        isTrue,
      );
      expect(
        tester
            .widget<AppChip>(find.widgetWithText(AppChip, 'Tipe baru'))
            .selected,
        isTrue,
      );
      expect(
        tester.widget<TextField>(field('Nama tipe baru')).controller!.text,
        'lipat kertas',
      );
      await fillValid(tester);
      await tapChip(tester, 'Tipe baru');
      await save(tester);
      expect(repo.items.single.companyLogId, 5);
      expect(repo.items.single.kategori, 'lipat kertas');
    });

    testWidgets('chip catatan bisa dilepas lagi', (tester) async {
      final repo = FakeCaptureRepository();
      final logs = FakeCompanyLogRepository([
        CompanyTestLog(
          id: 5,
          perusahaan: 'PT Maju',
          tanggal: DateTime.utc(2026, 10, 1),
        ),
      ]);
      await open(tester, captures: repo, logs: logs);
      await tester.ensureVisible(find.widgetWithText(AppChip, 'PT Maju'));
      await tapChip(tester, 'PT Maju');
      await tapChip(tester, 'PT Maju');
      await fillValid(tester);
      await save(tester);
      expect(repo.items.single.companyLogId, isNull);
    });
  });

  group('foto', () {
    testWidgets('foto dari galeri tampil dan tersimpan lokal', (tester) async {
      final repo = FakeCaptureRepository();
      final photos = MemoryPhotoStore();
      PhotoSource? asked;
      await open(
        tester,
        captures: repo,
        photos: photos,
        picker: (source) async {
          asked = source;
          return pixel;
        },
      );
      await tester.ensureVisible(find.text('Pilih dari galeri'));
      await tester.tap(find.text('Pilih dari galeri'));
      await tester.pumpAndSettle();
      expect(asked, PhotoSource.gallery);
      expect(find.byType(Image), findsOneWidget);
      expect(find.text('Hapus foto'), findsOneWidget);

      await fillValid(tester);
      await save(tester);
      final q = repo.items.single;
      expect(q.fotoPath, isNotNull);
      expect(photos.files[q.fotoPath], pixel);
    });

    testWidgets('soal hanya foto: teks tidak wajib', (tester) async {
      final repo = FakeCaptureRepository();
      await open(
        tester,
        captures: repo,
        picker: (source) async => pixel,
      );
      await tester.ensureVisible(find.text('Ambil foto soal'));
      await tester.tap(find.text('Ambil foto soal'));
      await tester.pumpAndSettle();
      await fillValid(tester);
      await tester.enterText(field('Teks soal'), '');
      await save(tester);
      expect(repo.items.single.teks, '');
      expect(repo.items.single.hasPhoto, isTrue);
    });

    testWidgets('kamera gagal dibuka: pesan jelas tanpa exception',
        (tester) async {
      await open(
        tester,
        picker: (source) async => throw const PhotoPickFailure(),
      );
      await tester.ensureVisible(find.text('Ambil foto soal'));
      await tester.tap(find.text('Ambil foto soal'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Kamera atau galeri tidak bisa dibuka'),
          findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('pengguna membatalkan pemilih: tidak ada perubahan',
        (tester) async {
      await open(tester, picker: (source) async => null);
      await tester.ensureVisible(find.text('Pilih dari galeri'));
      await tester.tap(find.text('Pilih dari galeri'));
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsNothing);
      expect(find.text('Hapus foto'), findsNothing);
    });

    testWidgets('penyimpanan penuh: soal tidak tersimpan, pesan di dekat foto',
        (tester) async {
      final repo = FakeCaptureRepository();
      final photos = MemoryPhotoStore()
        ..failWith = const PhotoStoreException(PhotoStoreProblem.storageFull);
      await open(
        tester,
        captures: repo,
        photos: photos,
        picker: (source) async => pixel,
      );
      await tester.ensureVisible(find.text('Pilih dari galeri'));
      await tester.tap(find.text('Pilih dari galeri'));
      await tester.pumpAndSettle();
      await fillValid(tester);
      await save(tester);
      expect(find.textContaining('Penyimpanan penuh'), findsOneWidget);
      expect(repo.items, isEmpty);
    });

    testWidgets('hapus foto membuang pratinjau', (tester) async {
      await open(tester, picker: (source) async => pixel);
      await tester.ensureVisible(find.text('Pilih dari galeri'));
      await tester.tap(find.text('Pilih dari galeri'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hapus foto'));
      await tester.pump();
      expect(find.byType(Image), findsNothing);
    });
  });

  group('mode ubah', () {
    CapturedQuestion saved({String? foto}) => CapturedQuestion(
          id: 3,
          teks: 'Soal lama',
          opsi: const ['a', 'b', 'c'],
          kunci: 2,
          pembahasan: 'Karena c.',
          kategori: 'lipat kertas',
          fotoPath: foto,
          dibuat: DateTime.utc(2026, 9, 1),
        );

    testWidgets('mengisi formulir dari soal tersimpan', (tester) async {
      await open(
        tester,
        path: Routes.captureUbahPath(3),
        captures: FakeCaptureRepository([saved()]),
      );
      expect(find.text('Ubah soal Capture'), findsOneWidget);
      expect(tester.widget<TextField>(field('Teks soal')).controller!.text,
          'Soal lama');
      expect(tester.widget<TextField>(field('Opsi C')).controller!.text, 'c');
      expect(tester.widget<TextField>(field('Nama tipe baru')).controller!.text,
          'lipat kertas');
      expect(find.text('Hapus soal ini'), findsOneWidget);
    });

    testWidgets('simpan memperbarui soal yang sama', (tester) async {
      final repo = FakeCaptureRepository([saved()]);
      final app = await open(
        tester,
        path: Routes.captureUbahPath(3),
        captures: repo,
      );
      await tester.enterText(field('Teks soal'), 'Soal baru');
      await save(tester);
      expect(repo.items, hasLength(1));
      expect(repo.items.single.id, 3);
      expect(repo.items.single.teks, 'Soal baru');
      expect(repo.items.single.dibuat, DateTime.utc(2026, 9, 1));
      expect(app.location, Routes.psikotes);
    });

    testWidgets('hapus meminta konfirmasi lebih dulu', (tester) async {
      final repo = FakeCaptureRepository([saved()]);
      final app = await open(
        tester,
        path: Routes.captureUbahPath(3),
        captures: repo,
      );
      await tester.ensureVisible(find.text('Hapus soal ini'));
      await tester.tap(find.text('Hapus soal ini'));
      await tester.pump();
      expect(find.textContaining('kartu buku kesalahannya dihapus'),
          findsOneWidget);
      expect(repo.deleted, isEmpty);

      await tester.tap(find.text('Batal'));
      await tester.pump();
      expect(find.text('Simpan ke bank pribadi'), findsOneWidget);

      await tester.ensureVisible(find.text('Hapus soal ini'));
      await tester.tap(find.text('Hapus soal ini'));
      await tester.pump();
      await tester.tap(find.text('Hapus soal'));
      await tester.pumpAndSettle();
      expect(repo.deleted, [3]);
      expect(app.location, Routes.psikotes);
    });

    testWidgets('soal yang sudah dihapus: kondisi kosong, bukan crash',
        (tester) async {
      await open(tester, path: Routes.captureUbahPath(99));
      expect(find.text('Soal Capture tidak ditemukan'), findsOneWidget);
      expect(find.text('Kembali ke bank pribadi'), findsWidgets);
    });

    testWidgets('galat membaca: sebab dan Coba lagi pulih', (tester) async {
      final repo = FakeCaptureRepository([saved()])
        ..byIdFailWith = StateError('rusak');
      await open(
        tester,
        path: Routes.captureUbahPath(3),
        captures: repo,
      );
      expect(find.text('Soal Capture tidak bisa dibuka'), findsOneWidget);
      expect(find.textContaining('rusak'), findsNothing);
      repo.byIdFailWith = null;
      await tester.tap(find.text('Coba lagi'));
      await tester.pumpAndSettle();
      expect(find.text('Ubah soal Capture'), findsOneWidget);
      expect(tester.widget<TextField>(field('Teks soal')).controller!.text,
          'Soal lama');
    });

    testWidgets('foto yang berkasnya hilang: catatan, soal tetap bisa diubah',
        (tester) async {
      await open(
        tester,
        path: Routes.captureUbahPath(3),
        captures: FakeCaptureRepository([saved(foto: 'hilang.jpg')]),
      );
      expect(find.textContaining('Foto soal tidak ada di perangkat ini'),
          findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('foto tersimpan tampil di formulir', (tester) async {
      final photos = MemoryPhotoStore()..files['ada.jpg'] = pixel;
      await open(
        tester,
        path: Routes.captureUbahPath(3),
        captures: FakeCaptureRepository([saved(foto: 'ada.jpg')]),
        photos: photos,
      );
      expect(find.byType(Image), findsOneWidget);
    });
  });

  group('keterbacaan', () {
    for (final scale in [1.3, 2.0]) {
      testWidgets('teks terpanjang di 360 dp, skala $scale tanpa luapan',
          (tester) async {
        await open(tester, textScale: scale);
        await tester.enterText(
          field('Teks soal'),
          'Kertas persegi dilipat dua kali menjadi seperempat bagian lalu '
          'dilubangi di tengah, berapa jumlah lubang saat dibuka kembali?',
        );
        await tapChip(tester, 'Tipe baru');
        await tester.enterText(
          field('Nama tipe baru'),
          'Rotasi kubus tiga dimensi dengan pewarnaan berbeda',
        );
        await save(tester);
        expect(tester.takeException(), isNull);
        expect(find.text('Simpan ke bank pribadi'), findsOneWidget);
      });
    }

    testWidgets('target sentuh minimal 48 dp', (tester) async {
      await open(tester);
      await save(tester);
      expectTouchTargets48(tester);
    });

    testWidgets('ikon bertombol punya label: kembali dan lingkaran kunci',
        (tester) async {
      final handle = tester.ensureSemantics();
      await open(tester);
      expect(find.bySemanticsLabel('Kembali'), findsOneWidget);
      expect(find.bySemanticsLabel('Jadikan opsi A sebagai kunci'),
          findsOneWidget);
      handle.dispose();
    });

    testWidgets('tema gelap memakai token gelap tanpa luapan', (tester) async {
      await pumpScreen(
        tester,
        const CaptureScreen(),
        brightness: Brightness.dark,
        overrides: [
          captureRepositoryProvider.overrideWithValue(FakeCaptureRepository()),
          companyLogRepositoryProvider
              .overrideWithValue(FakeCompanyLogRepository()),
          capturePhotoStoreProvider.overrideWithValue(MemoryPhotoStore()),
        ],
      );
      expect(tester.takeException(), isNull);
      expect(
        tester.widget<Text>(find.text('Kategori soal')).style?.color,
        AppColors.dark.ink,
      );
    });
  });
}
