import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simulator_psikotes_it/app/routes.dart';
import 'package:simulator_psikotes_it/core/theme/app_tokens.dart';
import 'package:simulator_psikotes_it/core/widgets/app_chip.dart';
import 'package:simulator_psikotes_it/core/widgets/app_text_field.dart';
import 'package:simulator_psikotes_it/core/widgets/error_view.dart';
import 'package:simulator_psikotes_it/core/widgets/skeleton_list.dart';
import 'package:simulator_psikotes_it/domain/models/notebook.dart';
import 'package:simulator_psikotes_it/domain/providers.dart';
import 'package:simulator_psikotes_it/features/capture/company_log_screen.dart';

import '../../core/golden_helper.dart' show expectTouchTargets48;
import '../../support/fake_repositories.dart';
import '../../support/fixtures.dart';
import '../../support/pump_app.dart';

Finder field(String label) => find.descendant(
      of: find.ancestor(
        of: find.text(label),
        matching: find.byType(AppTextField),
      ),
      matching: find.byType(TextField),
    );

CompanyTestLog log(
  int id, {
  String nama = 'PT Maju',
  List<String> subtes = const ['verbal', 'figural'],
  List<String> tipeBaru = const ['lipat kertas'],
  String catatan = 'Waktu terasa kurang.',
  DateTime? tanggal,
}) =>
    CompanyTestLog(
      id: id,
      perusahaan: nama,
      tanggal: tanggal ?? DateTime.utc(2026, 10, 1),
      subtes: subtes,
      tipeBaru: tipeBaru,
      catatan: catatan,
    );

Future<AppHarness> open(
  WidgetTester tester, {
  FakeCompanyLogRepository? logs,
  FakeCaptureRepository? captures,
  double textScale = 1,
}) async {
  final app = await pumpApp(
    tester,
    profiles: FakeProfileRepository([activeProfile()]),
    logs: logs,
    captures: captures,
    textScale: textScale,
  );
  await app.go(Routes.psikotes);
  unawaited(app.router.push(Routes.catatanTes));
  await tester.pumpAndSettle();
  return app;
}

void main() {
  group('kondisi', () {
    testWidgets('kosong: teks spek dan tombol Tambah catatan tes',
        (tester) async {
      await open(tester);
      expect(find.text('Belum ada catatan tes'), findsOneWidget);
      expect(
        find.text('Catat tes yang kamu jalani agar profil tes makin akurat.'),
        findsOneWidget,
      );
      expect(find.text('Tambah catatan tes'), findsOneWidget);
      expect(find.text('Saran dari catatanmu'), findsNothing);
    });

    testWidgets('memuat: skeleton berbentuk baris, bukan spinner',
        (tester) async {
      final gate = Completer<void>();
      final logs = FakeCompanyLogRepository()..gate = gate;
      final app = await pumpApp(
        tester,
        profiles: FakeProfileRepository([activeProfile()]),
        logs: logs,
      );
      unawaited(app.router.push(Routes.catatanTes));
      await tester.pump();
      await tester.pump();
      expect(find.byType(SkeletonList), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      gate.complete();
      await tester.pumpAndSettle();
      expect(find.byType(SkeletonList), findsNothing);
    });

    testWidgets('galat: sebab, tanpa teks exception, Coba lagi pulih',
        (tester) async {
      final logs = FakeCompanyLogRepository([log(1)])
        ..failWith = StateError('rusak');
      await open(tester, logs: logs);
      expect(find.byType(ErrorView), findsOneWidget);
      expect(find.text('Catatan tes tidak bisa dibuka'), findsOneWidget);
      expect(find.textContaining('rusak'), findsNothing);
      logs.failWith = null;
      await tester.tap(find.text('Coba lagi'));
      await tester.pumpAndSettle();
      expect(find.text('PT Maju'), findsOneWidget);
    });
  });

  group('daftar dan saran', () {
    testWidgets('catatan menampilkan tag subtes, tag Tipe baru, dan catatan',
        (tester) async {
      await open(tester, logs: FakeCompanyLogRepository([log(1)]));
      expect(find.text('PT Maju'), findsOneWidget);
      expect(find.text('01/10/2026'), findsOneWidget);
      expect(find.text('Verbal'), findsOneWidget);
      expect(find.text('Figural'), findsOneWidget);
      expect(find.text('Tipe baru: lipat kertas'), findsOneWidget);
      expect(find.text('Waktu terasa kurang.'), findsOneWidget);
      expect(find.text('Tambah soal'), findsOneWidget);
    });

    testWidgets('tipe baru tanpa soal Capture menjadi saran', (tester) async {
      await open(tester, logs: FakeCompanyLogRepository([log(1)]));
      expect(find.text('Saran dari catatanmu'), findsOneWidget);
      expect(find.text('Tambah soal untuk lipat kertas'), findsOneWidget);
    });

    testWidgets('saran hilang setelah ada soal Capture dengan tipe itu',
        (tester) async {
      await open(
        tester,
        logs: FakeCompanyLogRepository([log(1)]),
        captures: FakeCaptureRepository([
          CapturedQuestion(
            id: 1,
            teks: 'T',
            opsi: const ['a', 'b'],
            kunci: 0,
            kategori: 'Lipat Kertas',
            dibuat: appNow,
          ),
        ]),
      );
      expect(find.text('Tambah soal untuk lipat kertas'), findsNothing);
      expect(
        find.text('Semua tipe baru di catatanmu sudah punya soal Capture.'),
        findsOneWidget,
      );
    });

    testWidgets('catatan tanpa tag: tidak ada kotak saran', (tester) async {
      await open(
        tester,
        logs: FakeCompanyLogRepository([log(1, tipeBaru: const [])]),
      );
      expect(find.text('Saran dari catatanmu'), findsNothing);
    });

    testWidgets('Tambah soal dari catatan membuka S12 terhubung ke catatan',
        (tester) async {
      final app = await open(tester, logs: FakeCompanyLogRepository([log(7)]));
      await tester.tap(find.text('Tambah soal'));
      await tester.pumpAndSettle();
      expect(app.location, '${Routes.capture}?catatan=7');
      expect(
        tester
            .widget<AppChip>(find.widgetWithText(AppChip, 'PT Maju'))
            .selected,
        isTrue,
      );
    });

    testWidgets('saran membuka S12 dengan nama tipe baru terisi',
        (tester) async {
      final app = await open(tester, logs: FakeCompanyLogRepository([log(7)]));
      await tester.tap(find.text('Tambah soal untuk lipat kertas'));
      await tester.pumpAndSettle();
      expect(app.location, startsWith(Routes.capture));
      expect(
        tester.widget<TextField>(field('Nama tipe baru')).controller!.text,
        'lipat kertas',
      );
    });
  });

  group('formulir catatan tes', () {
    Future<void> openForm(WidgetTester tester, AppHarness app) async {
      await tester.tap(find.text('Tambah catatan tes').first);
      await tester.pumpAndSettle();
      expect(app.location, Routes.catatanTesBaru);
    }

    testWidgets('validasi: nama dan tanggal wajib, pesan menyebut perbaikannya',
        (tester) async {
      final logs = FakeCompanyLogRepository();
      final app = await open(tester, logs: logs);
      await openForm(tester, app);
      await tester.enterText(field('Tanggal tes'), '31/02/2026');
      await tester.tap(find.text('Simpan catatan tes'));
      await tester.pumpAndSettle();
      expect(find.text('Isi nama perusahaan agar catatan mudah dicari.'),
          findsOneWidget);
      expect(
        find.text('Tulis tanggal tes sebagai hh/bb/tttt, misalnya '
            '22/10/2026.'),
        findsOneWidget,
      );
      expect(logs.items, isEmpty);
    });

    testWidgets('tanggal terisi hari ini; simpan lalu kembali ke daftar',
        (tester) async {
      final logs = FakeCompanyLogRepository();
      final app = await open(tester, logs: logs);
      await openForm(tester, app);
      expect(
        tester.widget<TextField>(field('Tanggal tes')).controller!.text,
        '22/10/2026',
      );
      await tester.enterText(field('Nama perusahaan'), 'PT Baru');
      await tester.tap(find.widgetWithText(AppChip, 'Numerik'));
      await tester.pump();
      await tester.enterText(
          field('Tipe baru yang keluar'), 'Lipat kertas, rotasi kubus');
      await tester.enterText(field('Catatan (opsional)'), 'Sulit.');
      await tester.tap(find.text('Simpan catatan tes'));
      await tester.pumpAndSettle();

      final saved = logs.items.single;
      expect(saved.perusahaan, 'PT Baru');
      expect(saved.tanggal, DateTime.utc(2026, 10, 22));
      expect(saved.subtes, ['numerik']);
      expect(saved.tipeBaru, ['Lipat kertas', 'rotasi kubus']);
      expect(saved.catatan, 'Sulit.');
      expect(app.location, Routes.catatanTes);
      expect(find.text('PT Baru'), findsOneWidget);
      expect(find.text('Tambah soal untuk rotasi kubus'), findsOneWidget);
    });

    testWidgets('gagal menulis: pesan tanpa exception, bisa dicoba lagi',
        (tester) async {
      final logs = FakeCompanyLogRepository()
        ..saveFailWith = StateError('disk penuh');
      final app = await open(tester, logs: logs);
      await openForm(tester, app);
      await tester.enterText(field('Nama perusahaan'), 'PT Baru');
      await tester.tap(find.text('Simpan catatan tes'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Catatan belum tersimpan'), findsOneWidget);
      expect(find.textContaining('disk penuh'), findsNothing);
      expect(app.location, Routes.catatanTesBaru);

      logs.saveFailWith = null;
      await tester.tap(find.text('Simpan catatan tes'));
      await tester.pumpAndSettle();
      expect(logs.items, hasLength(1));
      expect(app.location, Routes.catatanTes);
    });
  });

  group('keterbacaan', () {
    for (final scale in [1.3, 2.0]) {
      testWidgets('teks terpanjang di 360 dp, skala $scale tanpa luapan',
          (tester) async {
        await open(
          tester,
          logs: FakeCompanyLogRepository([
            log(
              1,
              nama: 'PT Perusahaan Teknologi Informasi Nusantara Sejahtera',
              subtes: const ['verbal', 'numerik', 'logika', 'figural'],
              tipeBaru: const [
                'lipat kertas dengan lubang bertingkat',
                'rotasi kubus tiga dimensi',
              ],
              catatan: 'Waktu terasa sangat kurang dan urutan subtes berubah '
                  'dari yang diberitahukan sebelumnya oleh panitia tes.',
            ),
          ]),
          textScale: scale,
        );
        expect(tester.takeException(), isNull);
        expect(find.textContaining('PT Perusahaan Teknologi'), findsOneWidget);
      });
    }

    testWidgets('target sentuh minimal 48 dp', (tester) async {
      await open(tester, logs: FakeCompanyLogRepository([log(1)]));
      expectTouchTargets48(tester);
    });

    testWidgets('tema gelap memakai token gelap', (tester) async {
      await pumpScreen(
        tester,
        const CompanyLogScreen(),
        brightness: Brightness.dark,
        overrides: [
          companyLogRepositoryProvider
              .overrideWithValue(FakeCompanyLogRepository([log(1)])),
          captureRepositoryProvider.overrideWithValue(FakeCaptureRepository()),
        ],
      );
      expect(tester.takeException(), isNull);
      expect(
        tester.widget<Text>(find.text('Saran dari catatanmu')).style?.color,
        AppColors.dark.ink,
      );
    });
  });
}
