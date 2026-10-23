import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simulator_psikotes_it/app/routes.dart';
import 'package:simulator_psikotes_it/core/theme/app_tokens.dart';
import 'package:simulator_psikotes_it/core/widgets/app_chip.dart';
import 'package:simulator_psikotes_it/core/widgets/app_text_field.dart';
import 'package:simulator_psikotes_it/core/widgets/error_view.dart';
import 'package:simulator_psikotes_it/core/widgets/segmented_control.dart';
import 'package:simulator_psikotes_it/core/widgets/skeleton_list.dart';
import 'package:simulator_psikotes_it/domain/models/codes.dart';
import 'package:simulator_psikotes_it/domain/providers.dart';
import 'package:simulator_psikotes_it/domain/repositories/repositories.dart';
import 'package:simulator_psikotes_it/domain/services/backup.dart';
import 'package:simulator_psikotes_it/domain/services/secret_store.dart';
import 'package:simulator_psikotes_it/features/onboarding/onboarding_draft.dart';
import 'package:simulator_psikotes_it/features/settings/settings_provider.dart';
import 'package:simulator_psikotes_it/features/settings/settings_screen.dart';

import '../../core/golden_helper.dart' show expectTouchTargets48;
import '../../support/fake_repositories.dart';
import '../../support/fake_settings.dart';
import '../../support/fixtures.dart';
import '../../support/pump_app.dart';

class Rig {
  Rig({
    FakeProfileRepository? profiles,
    FakeSettingsRepository? settings,
    SecretStore? secrets,
    this.pick,
  })  : profiles = profiles ??
            FakeProfileRepository([
              activeProfile(),
              activeProfile(
                  id: 2, nama: 'Mobile Dev, Bank-style', aktif: false),
            ]),
        settings = settings ?? FakeSettingsRepository(),
        secrets = secrets ?? MemorySecretStore(persistent: true);

  final FakeProfileRepository profiles;
  final FakeSettingsRepository settings;
  final SecretStore secrets;
  final FakeBackupService backup = FakeBackupService();
  final FakeBackupSharer sharer = FakeBackupSharer();

  /// Teks berkas yang "dipilih" pengguna; null berarti dibatalkan.
  String? pick;
  Object? pickFailWith;

  List<Override> get overrides => [
        settingsRepositoryProvider.overrideWithValue(settings),
        secretStoreProvider.overrideWithValue(secrets),
        backupServiceProvider.overrideWithValue(backup),
        backupSharerProvider.overrideWithValue(sharer),
        backupFilePickerProvider.overrideWithValue(() async {
          if (pickFailWith != null) throw pickFailWith!;
          return pick;
        }),
      ];
}

BackupSummary summary({
  int profiles = 2,
  int added = 2,
  int updated = 0,
}) =>
    BackupSummary(
      versi: 1,
      diekspor: DateTime.utc(2026, 10, 20, 9),
      tabel: {
        'test_profile': BackupTableCount(
          total: profiles,
          added: added,
          updated: updated,
        ),
        'session': const BackupTableCount(total: 4, added: 4, updated: 0),
        'answer': const BackupTableCount(total: 0, added: 0, updated: 0),
      },
    );

Future<AppHarness> open(
  WidgetTester tester,
  Rig rig, {
  double textScale = 1,
}) async {
  final app = await pumpApp(
    tester,
    profiles: rig.profiles,
    textScale: textScale,
    overrides: rig.overrides,
  );
  unawaited(app.router.push(Routes.pengaturan));
  await tester.pumpAndSettle();
  return app;
}

Future<void> tapText(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text));
  await tester.tap(find.text(text));
  await tester.pumpAndSettle();
}

Finder keyField(String label) => find.descendant(
      of: find.ancestor(
        of: find.text(label),
        matching: find.byType(AppTextField),
      ),
      matching: find.byType(TextField),
    );

void main() {
  group('tampilan', () {
    testWidgets('lima bagian, profil aktif, dan disclaimer', (tester) async {
      await open(tester, Rig());
      for (final t in [
        'Profil tes',
        'Data',
        'Wawancara AI',
        'Tampilan',
        'Tentang latihan ini',
      ]) {
        await tester.ensureVisible(find.text(t));
        expect(find.text(t), findsOneWidget);
      }
      expect(find.text('QA, CCAT-style'), findsOneWidget);
      expect(find.text('Profil aktif. Ketuk untuk mengubah.'), findsOneWidget);
      expect(find.text('Aktif'), findsOneWidget);
      expect(find.textContaining('bukan penilaian resmi'), findsOneWidget);
      expect(find.textContaining('edukatif, bukan diagnosis'), findsOneWidget);
    });

    testWidgets('catatan data menyebut yang tidak ikut backup', (tester) async {
      await open(tester, Rig());
      expect(
        find.textContaining('Foto Capture, teks CV, dan API key tidak ikut'),
        findsOneWidget,
      );
      expect(find.textContaining('soal Capture'), findsWidgets);
    });
  });

  group('kondisi', () {
    testWidgets('memuat: skeleton, bukan spinner', (tester) async {
      final settings = FakeSettingsRepository()..gate = Completer<void>();
      final rig = Rig(settings: settings);
      final app = await pumpApp(
        tester,
        profiles: rig.profiles,
        overrides: rig.overrides,
      );
      unawaited(app.router.push(Routes.pengaturan));
      await tester.pump();
      await tester.pump();
      expect(find.byType(SkeletonList), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      settings.gate!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(SkeletonList), findsNothing);
      expect(find.text('Tentang latihan ini'), findsOneWidget);
    });

    testWidgets('galat: sebab, tanpa teks exception, Coba lagi pulih',
        (tester) async {
      final settings = FakeSettingsRepository()..failWith = StateError('rusak');
      await open(tester, Rig(settings: settings));
      expect(find.byType(ErrorView), findsOneWidget);
      expect(find.text('Pengaturan tidak bisa dibuka'), findsOneWidget);
      expect(find.textContaining('rusak'), findsNothing);
      settings.failWith = null;
      await tester.tap(find.text('Coba lagi'));
      await tester.pumpAndSettle();
      expect(find.text('Tampilan'), findsOneWidget);
    });

    testWidgets('profil kosong dibedakan dari galat dan dari memuat',
        (tester) async {
      final rig = Rig(profiles: FakeProfileRepository());
      await pumpScreen(
        tester,
        const SettingsScreen(),
        overrides: [
          profileRepositoryProvider.overrideWithValue(rig.profiles),
          ...rig.overrides,
        ],
      );
      expect(find.text('Belum ada profil tes'), findsOneWidget);
      expect(find.text('Buat profil tes'), findsOneWidget);
      expect(find.byType(ErrorView), findsNothing);
      expect(find.byType(SkeletonList), findsNothing);
      expect(find.text('Data'), findsOneWidget,
          reason: 'bagian lain tetap bisa dipakai');
    });
  });

  group('profil', () {
    testWidgets('profil aktif membuka S02 mode ubah', (tester) async {
      final app = await open(tester, Rig());
      await tester.tap(find.text('QA, CCAT-style'));
      await tester.pumpAndSettle();
      expect(app.location, Routes.profilUbah(1));
    });

    testWidgets('profil lain dijadikan aktif lewat ketukan', (tester) async {
      final rig = Rig();
      await open(tester, rig);
      expect(find.text('Ketuk untuk menjadikan aktif.'), findsOneWidget);
      await tester.tap(find.text('Mobile Dev, Bank-style'));
      await tester.pumpAndSettle();
      expect(rig.profiles.items.where((p) => p.aktif).single.id, 2);
      expect(find.text('Profil aktif. Ketuk untuk mengubah.'), findsOneWidget);
    });

    testWidgets('Tambah profil mengosongkan draf lalu membuka S01',
        (tester) async {
      final rig = Rig();
      final app = await open(tester, rig);
      final container = app.container;
      container.read(onboardingDraftProvider.notifier).state = container
          .read(onboardingDraftProvider)
          .copyWith(role: ProfileRole.ba);
      await tapText(tester, 'Tambah profil tes');
      expect(app.location, Routes.onboardingRole);
      expect(container.read(onboardingDraftProvider).role,
          OnboardingDraft.initial().role);
    });

    testWidgets(
        'wizard profil tambahan: tombol kembali dan Back sistem '
        'menuju Pengaturan, bukan keluar app', (tester) async {
      final app = await open(tester, Rig());
      await tapText(tester, 'Tambah profil tes');
      expect(app.location, Routes.onboardingRole);
      expect(find.byTooltip('Kembali ke pengaturan'), findsOneWidget);

      // Tombol kembali di langkah 1.
      await tester.tap(find.byTooltip('Kembali ke pengaturan'));
      await tester.pumpAndSettle();
      expect(app.location, Routes.pengaturan);

      // Back sistem di langkah 1.
      await tapText(tester, 'Tambah profil tes');
      expect(await tester.binding.handlePopRoute(), isTrue,
          reason: 'Back ditangani app, tidak keluar');
      await tester.pumpAndSettle();
      expect(app.location, Routes.pengaturan);

      // Langkah 2 kembali ke langkah 1, lalu Back sistem ke Pengaturan.
      await tapText(tester, 'Tambah profil tes');
      await tapText(tester, 'Lanjut');
      expect(app.location, Routes.onboardingProfil);
      await tester.tap(find.byTooltip('Kembali ke pilihan role'));
      await tester.pumpAndSettle();
      expect(app.location, Routes.onboardingRole);
      expect(await tester.binding.handlePopRoute(), isTrue);
      await tester.pumpAndSettle();
      expect(app.location, Routes.pengaturan);
    });

    testWidgets('Ulangi diagnostik membuka S03', (tester) async {
      final app = await open(tester, Rig());
      await tapText(tester, 'Ulangi diagnostik');
      expect(app.location, Routes.onboardingDiagnostik);
    });
  });

  group('ekspor backup', () {
    testWidgets('membagikan berkas JSON bernama tanggal', (tester) async {
      final rig = Rig();
      await open(tester, rig);
      await tapText(tester, 'Ekspor backup');
      expect(rig.backup.exports, [appNow]);
      final shared = rig.sharer.shared.single;
      expect(shared.fileName, 'simulator-psikotes-backup-2026-10-22.json');
      expect(shared.content, rig.backup.exportText);
      expect(find.textContaining('Backup dibagikan'), findsOneWidget);
    });

    testWidgets('gagal: pesan tanpa exception, bisa dicoba lagi',
        (tester) async {
      final rig = Rig();
      rig.sharer.failWith = StateError('tidak ada aplikasi');
      await open(tester, rig);
      await tapText(tester, 'Ekspor backup');
      expect(find.textContaining('Backup belum dibagikan'), findsOneWidget);
      expect(find.textContaining('tidak ada aplikasi'), findsNothing);
      rig.sharer.failWith = null;
      await tapText(tester, 'Ekspor backup');
      expect(rig.sharer.shared, hasLength(1));
      expect(find.textContaining('Backup dibagikan'), findsOneWidget);
    });
  });

  group('impor backup', () {
    testWidgets('ringkasan lebih dulu, baru digabungkan setelah dikonfirmasi',
        (tester) async {
      final rig = Rig(pick: '{"isi":"backup"}');
      rig.backup.summary = summary(added: 1, updated: 1);
      await open(tester, rig);
      await tapText(tester, 'Impor backup');

      expect(rig.backup.previews, ['{"isi":"backup"}']);
      expect(rig.backup.imports, isEmpty, reason: 'belum menulis apa pun');
      expect(find.text('Isi backup'), findsOneWidget);
      expect(find.text('Dibuat 20 Oktober 2026.'), findsOneWidget);
      expect(find.text('Profil tes'), findsWidgets);
      expect(find.text('1 baru, 1 diperbarui'), findsOneWidget);
      expect(find.text('Sesi'), findsOneWidget);
      expect(find.text('4 baru'), findsOneWidget);
      expect(find.text('Jawaban'), findsNothing, reason: 'tabel kosong');

      await tapText(tester, 'Gabungkan ke data ini');
      expect(rig.backup.imports, ['{"isi":"backup"}']);
      expect(find.text('Isi backup'), findsNothing);
      expect(
          find.textContaining('Backup digabungkan: 5 baris baru, 1 diperbarui'),
          findsOneWidget);
    });

    testWidgets('nomor bentrok dilaporkan jujur di ringkasan dan hasil',
        (tester) async {
      final rig = Rig(pick: '{"isi":"backup"}');
      rig.backup.summary = BackupSummary(
        versi: 1,
        diekspor: DateTime.utc(2026, 10, 20, 9),
        tabel: const {
          'test_profile': BackupTableCount(total: 2, added: 2, renumbered: 1),
          'session': BackupTableCount(total: 4, added: 3, renumbered: 3),
        },
      );
      await open(tester, rig);
      await tapText(tester, 'Impor backup');
      expect(
          find.text('2 baru (1 diberi nomor baru), 0 sudah ada'
              .replaceAll(', 0 sudah ada', '')),
          findsOneWidget);
      expect(find.text('3 baru (3 diberi nomor baru), 1 sudah ada'),
          findsOneWidget);

      await tapText(tester, 'Gabungkan ke data ini');
      expect(
        find.textContaining('Backup digabungkan: 5 baris baru. 4 baris diberi '
            'nomor baru karena bentrok dengan data di perangkat ini.'),
        findsOneWidget,
      );
    });

    testWidgets('Batal membuang ringkasan tanpa menulis', (tester) async {
      final rig = Rig(pick: '{}');
      rig.backup.summary = summary();
      await open(tester, rig);
      await tapText(tester, 'Impor backup');
      await tapText(tester, 'Batal');
      expect(find.text('Isi backup'), findsNothing);
      expect(rig.backup.imports, isEmpty);
    });

    testWidgets('berkas salah: pesan dari spek, tidak ada penulisan',
        (tester) async {
      final rig = Rig(pick: 'bukan backup');
      rig.backup.previewFailWith =
          const BackupException(BackupProblem.unreadable);
      await open(tester, rig);
      await tapText(tester, 'Impor backup');
      expect(
        find.text('Backup tidak bisa dibaca. Berkasnya bukan hasil ekspor '
            'dari app ini. Pilih berkas lain.'),
        findsOneWidget,
      );
      expect(rig.backup.imports, isEmpty);
    });

    testWidgets('versi lebih baru ditolak dengan pesan yang jelas',
        (tester) async {
      final rig = Rig(pick: '{}');
      rig.backup.previewFailWith =
          const BackupException(BackupProblem.newer, version: 2);
      await open(tester, rig);
      await tapText(tester, 'Impor backup');
      expect(
          find.textContaining('Backup dibuat oleh versi app yang lebih baru'),
          findsOneWidget);
      expect(
          find.textContaining('Perbarui app lalu coba lagi.'), findsOneWidget);
      expect(find.text('Isi backup'), findsNothing);
    });

    testWidgets('penggabungan gagal: data tidak berubah, bisa dicoba lagi',
        (tester) async {
      final rig = Rig(pick: '{}');
      rig.backup.summary = summary();
      rig.backup.importFailWith = const BackupException(BackupProblem.failed);
      await open(tester, rig);
      await tapText(tester, 'Impor backup');
      await tapText(tester, 'Gabungkan ke data ini');
      expect(find.textContaining('Backup belum digabungkan'), findsOneWidget);
      expect(find.textContaining('Data di perangkat tidak berubah'),
          findsOneWidget);
    });

    testWidgets('dibatalkan di pemilih berkas: tidak ada pesan',
        (tester) async {
      final rig = Rig(pick: null);
      await open(tester, rig);
      await tapText(tester, 'Impor backup');
      expect(rig.backup.previews, isEmpty);
      expect(find.byType(ErrorView), findsNothing);
      expect(find.textContaining('Backup'), findsWidgets);
      expect(find.textContaining('tidak bisa dibaca'), findsNothing);
    });

    testWidgets('pemilih berkas gagal dibuka: pesan jelas', (tester) async {
      final rig = Rig(pick: '{}')..pickFailWith = const BackupPickFailure();
      await open(tester, rig);
      await tapText(tester, 'Impor backup');
      expect(find.text('Pemilih berkas tidak bisa dibuka. Coba lagi.'),
          findsOneWidget);
    });

    testWidgets('backup kosong: tanpa tombol gabungkan', (tester) async {
      final rig = Rig(pick: '{}');
      rig.backup.summary = const BackupSummary(
        versi: 1,
        diekspor: null,
        tabel: {},
      );
      await open(tester, rig);
      await tapText(tester, 'Impor backup');
      expect(find.text('Backup ini tidak berisi data. Pilih berkas lain.'),
          findsOneWidget);
      expect(find.text('Gabungkan ke data ini'), findsNothing);
    });
  });

  group('wawancara AI', () {
    testWidgets('penyedia belum dipilih: tanpa isian key', (tester) async {
      await open(tester, Rig());
      expect(find.widgetWithText(AppChip, 'Gemini'), findsOneWidget);
      expect(find.widgetWithText(AppChip, 'Groq'), findsOneWidget);
      expect(
        tester.widgetList<AppChip>(find.byType(AppChip)).where(
            (c) => (c.label == 'Gemini' || c.label == 'Groq') && c.selected),
        isEmpty,
      );
      expect(find.byType(AppTextField), findsNothing);
    });

    testWidgets('memilih penyedia menyimpan pilihan dan membuka isian key',
        (tester) async {
      final rig = Rig();
      await open(tester, rig);
      await tester.ensureVisible(find.widgetWithText(AppChip, 'Groq'));
      await tester.tap(find.widgetWithText(AppChip, 'Groq'));
      await tester.pumpAndSettle();
      expect(rig.settings.values[SettingKeys.penyediaAi], 'groq');
      expect(find.text('API key Groq'), findsOneWidget);
      expect(find.text('Simpan key Groq'), findsOneWidget);
    });

    testWidgets('key disimpan di penyimpanan rahasia, bukan di pengaturan',
        (tester) async {
      final rig = Rig(
        settings: FakeSettingsRepository({SettingKeys.penyediaAi: 'gemini'}),
      );
      await open(tester, rig);
      expect(
        tester.widget<TextField>(keyField('API key Gemini')).obscureText,
        isTrue,
        reason: 'key disamarkan saat diketik',
      );
      await tester.enterText(keyField('API key Gemini'), '  AIzaRAHASIA-123 ');
      await tapText(tester, 'Simpan key Gemini');

      expect(await rig.secrets.read('api_key_gemini'), 'AIzaRAHASIA-123');
      expect(rig.settings.values.values.any((v) => v.contains('RAHASIA')),
          isFalse);
      expect(find.text('Key Gemini tersimpan.'), findsOneWidget);
      expect(find.textContaining('RAHASIA'), findsNothing,
          reason: 'isi key tidak ditampilkan lagi');
      expect(find.text('Tersimpan'), findsOneWidget);
      expect(find.text('Hapus key Gemini'), findsOneWidget);
    });

    testWidgets('key kosong ditolak dengan pesan', (tester) async {
      final rig = Rig(
        settings: FakeSettingsRepository({SettingKeys.penyediaAi: 'gemini'}),
      );
      await open(tester, rig);
      await tapText(tester, 'Simpan key Gemini');
      expect(find.text('Tempel key dari Gemini dulu, lalu simpan.'),
          findsOneWidget);
      expect(await rig.secrets.read('api_key_gemini'), isNull);
    });

    testWidgets('hapus key', (tester) async {
      final secrets = MemorySecretStore(persistent: true);
      await secrets.write('api_key_groq', 'gsk_rahasia');
      final rig = Rig(
        settings: FakeSettingsRepository({SettingKeys.penyediaAi: 'groq'}),
        secrets: secrets,
      );
      await open(tester, rig);
      expect(find.text('Key Groq sudah ada.'), findsOneWidget);
      await tapText(tester, 'Hapus key Groq');
      expect(await secrets.read('api_key_groq'), isNull);
      expect(find.text('Key Groq dihapus.'), findsOneWidget);
      expect(find.text('API key Groq'), findsOneWidget);
    });

    testWidgets('catatan privasi Android: terenkripsi di perangkat',
        (tester) async {
      await open(tester, Rig(secrets: MemorySecretStore(persistent: true)));
      expect(
        find.text('Disimpan terenkripsi di perangkat, tidak pernah ke server '
            'kami.'),
        findsOneWidget,
      );
    });

    testWidgets('catatan privasi web: hanya selama tab terbuka',
        (tester) async {
      await open(tester, Rig(secrets: MemorySecretStore()));
      expect(find.text('Key hanya disimpan selama tab ini terbuka.'),
          findsOneWidget);
      expect(find.textContaining('terenkripsi'), findsNothing);
    });

    testWidgets(
        'batas sesi per hari: bawaan 3, tersimpan, dibatasi 1 sampai 10',
        (tester) async {
      final rig = Rig();
      await open(tester, rig);
      expect(find.text('3'), findsOneWidget);
      await tester.ensureVisible(find.byTooltip('Tambah batas sesi per hari'));
      await tester.tap(find.byTooltip('Tambah batas sesi per hari'));
      await tester.pumpAndSettle();
      expect(rig.settings.values[SettingKeys.batasWawancaraHarian], '4');
      expect(find.text('4'), findsOneWidget);
      for (var i = 0; i < 5; i++) {
        await tester.tap(find.byTooltip('Kurangi batas sesi per hari').first);
        await tester.pumpAndSettle();
      }
      expect(rig.settings.values[SettingKeys.batasWawancaraHarian], '1');
      final minus = tester.widget<InkWell>(find
          .descendant(
            of: find.byTooltip('Kurangi batas sesi per hari'),
            matching: find.byType(InkWell),
          )
          .first);
      expect(minus.onTap, isNull, reason: 'tidak bisa kurang dari 1');
    });

    testWidgets('batas tersimpan di luar rentang dikembalikan ke rentang',
        (tester) async {
      await open(
        tester,
        Rig(
          settings: FakeSettingsRepository(
            {SettingKeys.batasWawancaraHarian: '99'},
          ),
        ),
      );
      expect(find.text('10'), findsOneWidget);
    });
  });

  group('tampilan tema', () {
    testWidgets('bawaan terang tanpa catatan; gelap dan sistem tersimpan',
        (tester) async {
      final rig = Rig();
      await open(tester, rig);
      final control = tester.widget<SegmentedControl>(
        find.byType(SegmentedControl),
      );
      expect(control.options, ['Terang', 'Gelap', 'Sistem']);
      expect(control.selectedIndex, 0);
      expect(find.textContaining('Tema gelap tersedia di v1.1'), findsNothing);

      await tapText(tester, 'Gelap');
      expect(rig.settings.values[SettingKeys.tema], 'gelap');
      expect(
          find.textContaining('Tema gelap tersedia di v1.1'), findsOneWidget);
      expect(
        tester
            .widget<SegmentedControl>(find.byType(SegmentedControl))
            .selectedIndex,
        1,
      );

      await tapText(tester, 'Sistem');
      expect(rig.settings.values[SettingKeys.tema], 'sistem');

      await tapText(tester, 'Terang');
      expect(rig.settings.values[SettingKeys.tema], 'terang');
      expect(find.textContaining('Tema gelap tersedia di v1.1'), findsNothing);
    });

    testWidgets('app tetap terang walau gelap dipilih (T21 belum ada)',
        (tester) async {
      final rig = Rig(
        settings: FakeSettingsRepository({SettingKeys.tema: 'gelap'}),
      );
      await open(tester, rig);
      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.themeMode, ThemeMode.light);
    });
  });

  group('keterbacaan', () {
    for (final scale in [1.3, 2.0]) {
      testWidgets('teks terpanjang di 360 dp, skala $scale tanpa luapan',
          (tester) async {
        final rig = Rig(
          pick: '{}',
          profiles: FakeProfileRepository([
            activeProfile(
              nama: 'Profil dengan nama yang sangat panjang untuk Mobile '
                  'Developer, Psikotes Bank-style kustom',
            ),
          ]),
          settings: FakeSettingsRepository({SettingKeys.penyediaAi: 'gemini'}),
        );
        rig.backup.summary = summary();
        await open(tester, rig, textScale: scale);
        await tapText(tester, 'Impor backup');
        expect(tester.takeException(), isNull);
        expect(find.text('Isi backup'), findsOneWidget);
      });
    }

    testWidgets('target sentuh minimal 48 dp', (tester) async {
      await open(
        tester,
        Rig(settings: FakeSettingsRepository({SettingKeys.penyediaAi: 'groq'})),
      );
      expectTouchTargets48(tester);
    });

    testWidgets('ikon tanpa teks punya label: kembali dan stepper',
        (tester) async {
      final handle = tester.ensureSemantics();
      await open(tester, Rig());
      expect(find.bySemanticsLabel('Kembali'), findsOneWidget);
      await tester.ensureVisible(find.byTooltip('Tambah batas sesi per hari'));
      expect(
          find.bySemanticsLabel('Tambah batas sesi per hari'), findsOneWidget);
      expect(
          find.bySemanticsLabel('Kurangi batas sesi per hari'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('tema gelap memakai token gelap tanpa luapan', (tester) async {
      final rig = Rig();
      await pumpScreen(
        tester,
        const SettingsScreen(),
        brightness: Brightness.dark,
        overrides: [
          profileRepositoryProvider.overrideWithValue(rig.profiles),
          ...rig.overrides,
        ],
      );
      expect(tester.takeException(), isNull);
      expect(
        tester.widget<Text>(find.text('Profil tes')).style?.color,
        AppColors.dark.ink,
      );
    });
  });
}
