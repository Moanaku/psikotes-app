import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/widgets/placeholder_screen.dart';
import '../domain/providers.dart';
import '../features/onboarding/profile_screen.dart';
import '../features/onboarding/role_screen.dart';
import 'routes.dart';

/// Rute app. Setiap tugas mengganti PlaceholderScreen dengan layar nyata.
///
/// Guard: selama belum ada profil aktif, semua rute selain `/onboarding/*`
/// dialihkan ke S01 (docs/05-spek-layar.md). Rute onboarding tetap terbuka
/// setelah ada profil karena membuat profil tambahan lewat S01 dan mengubah
/// profil lewat S02.
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(activeProfileProvider, (_, __) => refresh.value++);

  final router = GoRouter(
    initialLocation: Routes.beranda,
    refreshListenable: refresh,
    redirect: (context, state) {
      final noProfile = switch (ref.read(activeProfileProvider)) {
        AsyncData(:final value) => value == null,
        _ => false,
      };
      final inOnboarding =
          state.matchedLocation.startsWith(Routes.onboardingPrefix);
      return noProfile && !inOnboarding ? Routes.onboardingRole : null;
    },
    routes: [
      GoRoute(
        path: Routes.onboardingRole,
        builder: (context, state) => const RoleScreen(),
      ),
      GoRoute(
        path: Routes.onboardingProfil,
        builder: (context, state) => ProfileScreen(
          editId: int.tryParse(state.uri.queryParameters['ubah'] ?? ''),
        ),
      ),
      _r(Routes.onboardingDiagnostik, 'S03', 'Diagnostik'),
      _r(Routes.beranda, 'S04', 'Beranda'),
      _r(Routes.psikotes, 'S05', 'Katalog psikotes'),
      _r(Routes.sesi, 'S06', 'Sesi soal'),
      _r(Routes.hasil, 'S08', 'Hasil sesi'),
      _r(Routes.pembahasan, 'S09', 'Pembahasan soal'),
      _r(Routes.bukuKesalahan, 'S10', 'Buku kesalahan'),
      _r(Routes.statistik, 'S11', 'Statistik'),
      _r(Routes.capture, 'S12', 'Capture soal'),
      _r(Routes.captureUbah, 'S12', 'Capture soal'),
      _r(Routes.catatanTes, 'S13', 'Catatan psikotes'),
      _r(Routes.kepribadian, 'S14', 'Sesi kepribadian'),
      _r(Routes.wawancara, 'S15', 'Setup wawancara'),
      _r(Routes.wawancaraDialog, 'S16', 'Dialog wawancara'),
      _r(Routes.wawancaraLaporan, 'S17', 'Laporan wawancara'),
      _r(Routes.pengaturan, 'S18', 'Pengaturan'),
      _r(Routes.pengetahuan, 'S19', 'Bank pengetahuan role'),
      _r(Routes.pengetahuanSesi, 'S20', 'Sesi kartu pengetahuan'),
    ],
  );
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});

GoRoute _r(String path, String id, String title) => GoRoute(
      path: path,
      builder: (context, state) => PlaceholderScreen(id: id, title: title),
    );
