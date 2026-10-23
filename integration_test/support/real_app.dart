import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:simulator_psikotes_it/app/app.dart';
import 'package:simulator_psikotes_it/app/router.dart';
import 'package:simulator_psikotes_it/core/widgets/app_button.dart';
import 'package:simulator_psikotes_it/core/widgets/app_chip.dart';
import 'package:simulator_psikotes_it/core/widgets/app_text_field.dart';
import 'package:simulator_psikotes_it/core/widgets/option_tile.dart';
import 'package:simulator_psikotes_it/data/db/app_database.dart';
import 'package:simulator_psikotes_it/data/providers.dart';
import 'package:simulator_psikotes_it/domain/models/session_state.dart';
import 'package:simulator_psikotes_it/domain/providers.dart';
import 'package:simulator_psikotes_it/domain/services/secret_store.dart';
import 'package:simulator_psikotes_it/domain/services/session_controller.dart';

import '../../test/support/fake_clock.dart';
import '../../test/support/fake_repositories.dart' show MemoryPhotoStore;
import '../../test/support/manual_ticker.dart';

/// Hari pertama alur integrasi (UTC). Jam palsu dimajukan per hari penuh agar
/// hasilnya sama di zona waktu mana pun.
final DateTime integrationNow = DateTime.utc(2026, 10, 22, 8);

/// App sungguhan: semua layar dan router asli, repository Drift di atas SQLite
/// memori. Hanya jam, penanda waktu, penyimpanan foto, dan penyimpanan rahasia
/// yang diganti, supaya alur berjalan tanpa menunggu waktu nyata.
class RealApp {
  RealApp._(
    this.tester,
    this.db,
    this.container,
    this.clock,
    this.ticker,
    this.secrets,
  );

  final WidgetTester tester;
  final AppDatabase db;
  final ProviderContainer container;
  final FakeClock clock;
  final ManualTicker ticker;
  final MemorySecretStore secrets;

  GoRouter get router => container.read(routerProvider);
  SessionState? get sessionState => container.read(sessionControllerProvider);

  /// Jawaban benar untuk soal yang sedang tampil.
  int get correctIndex => sessionState!.question!.correctIndex;

  /// Memasang app pada [db] (database baru bila kosong) dan ukuran layar HP.
  static Future<RealApp> start(
    WidgetTester tester, {
    AppDatabase? db,
    FakeClock? clock,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 800);
    addTearDown(tester.view.reset);

    final database = db ?? AppDatabase(NativeDatabase.memory());
    final fake = clock ?? FakeClock(integrationNow);
    final manual = ManualTicker();
    final secrets = MemorySecretStore(persistent: true);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        ...dataProviderOverrides,
        capturePhotoStoreProvider.overrideWithValue(MemoryPhotoStore()),
        secretStoreProvider.overrideWithValue(secrets),
        clockProvider.overrideWithValue(fake),
        tickerFactoryProvider.overrideWithValue(manual.factory),
      ],
      child: const PsikotesApp(),
    ));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PsikotesApp)),
    );
    return RealApp._(tester, database, container, fake, manual, secrets);
  }

  /// Melepas pohon widget (menutup aliran Drift) lalu menutup database.
  Future<void> dispose() async {
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await db.close();
  }

  Future<void> tapText(String text, {bool last = false}) async {
    final finder = last ? find.text(text).last : find.text(text);
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> tapButton(String label) async {
    final target = find.widgetWithText(AppButton, label);
    await tester.ensureVisible(target);
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  Future<void> tapChip(String label) async {
    final target = find.widgetWithText(AppChip, label);
    await tester.ensureVisible(target);
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  /// Memilih opsi ke-[i] pada soal yang sedang tampil.
  Future<void> chooseOption(int i) async {
    final option = find.byType(OptionTile).at(i);
    await tester.ensureVisible(option);
    await tester.tap(option);
    await tester.pumpAndSettle();
  }

  /// Opsi yang pasti salah pada soal yang sedang tampil.
  int get wrongIndex => correctIndex == 0 ? 1 : 0;

  /// Satu hari penuh berlalu (jam dinding dan monoton).
  void advanceDays(int days) => clock.advance(Duration(days: days));

  /// Onboarding lewat layar: profil Umum, diagnostik dilewati, tiba di beranda.
  Future<void> createUmumProfile() async {
    await tapText('Umum, tanpa role');
    await tapButton('Lanjut');
    await tapButton('Simpan dan lanjut');
    await tapText('Lewati, nanti saja');
    expect(location, '/');
  }

  /// Lokasi rute sekarang.
  String get location =>
      router.routerDelegate.currentConfiguration.uri.toString();

  /// Menjawab semua soal sesi latihan yang sedang tampil sampai layar hasil;
  /// [correct] menentukan benar atau salah per nomor soal (mulai dari 0).
  Future<void> finishPractice(
    int total, {
    required bool Function(int index) correct,
  }) async {
    for (var i = 0; i < total; i++) {
      final pick = correct(i) ? correctIndex : wrongIndex;
      await chooseOption(pick);
      await tapButton('Kirim jawaban ${letter(pick)}');
      await tapButton(i == total - 1 ? 'Lihat hasil' : 'Berikutnya');
    }
    expect(find.text('Hasil sesi'), findsOneWidget);
  }

  /// Pindah rute seperti tautan dalam.
  Future<void> go(String path) async {
    router.go(path);
    await tester.pumpAndSettle();
  }
}

/// Huruf opsi seperti di tombol "Kirim jawaban B".
String letter(int i) => String.fromCharCode(0x41 + i);

/// Menunggu pekerjaan async asli (isolat, berkas) selesai bila ada.
Future<void> settle(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.runAsync(() => Future<void>.delayed(Duration.zero));
  await tester.pumpAndSettle();
}

/// Isian di dalam [AppTextField] berlabel [label].
Finder fieldLabeled(String label) => find.descendant(
      of: find.ancestor(
        of: find.text(label),
        matching: find.byType(AppTextField),
      ),
      matching: find.byType(TextField),
    );
