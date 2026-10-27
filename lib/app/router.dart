import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:question_engine/question_engine.dart' show KrpConfig;

import '../core/widgets/placeholder_screen.dart';
import '../domain/models/knowledge.dart';
import '../domain/providers.dart';
import '../features/capture/capture_screen.dart';
import '../features/capture/company_log_form_screen.dart';
import '../features/capture/company_log_screen.dart';
import '../features/catalog/catalog_screen.dart';
import '../features/home/home_screen.dart';
import '../features/interview/interview_screen.dart';
import '../features/mistakes/mistake_book_screen.dart';
import '../features/mistakes/mistake_card_screen.dart';
import '../features/onboarding/diagnostic_screen.dart';
import '../features/onboarding/profile_screen.dart';
import '../features/onboarding/role_screen.dart';
import '../features/review/result_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/stats/stats_screen.dart';
import '../features/review/review_screen.dart';
import '../features/session/session_screen.dart';
import '../features/knowledge/knowledge_screen.dart';
import '../features/knowledge/knowledge_session_screen.dart';
import '../features/kraepelin/kraepelin_screen.dart';
import '../features/personality/personality_screen.dart';
import 'routes.dart';
import 'tab_shell.dart';

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
      GoRoute(
        path: Routes.onboardingDiagnostik,
        builder: (context, state) => const DiagnosticScreen(),
      ),
      // Empat tab dengan bottom nav (S04, S05, S15, S11).
      ShellRoute(
        builder: (context, state, child) =>
            TabShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(
            path: Routes.beranda,
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: Routes.psikotes,
            builder: (context, state) => const CatalogScreen(),
          ),
          GoRoute(
            path: Routes.pengetahuan,
            builder: (context, state) => KnowledgeScreen(
              initialRole: KnowledgeRole.fromCode(
                state.uri.queryParameters['role'] ?? '',
              ),
            ),
          ),
          GoRoute(
            path: Routes.wawancara,
            builder: (context, state) => const InterviewScreen(),
          ),
          GoRoute(
            path: Routes.statistik,
            builder: (context, state) => const StatsScreen(),
          ),
        ],
      ),
      GoRoute(
        path: Routes.sesi,
        builder: (context, state) => SessionScreen(
          sessionId: int.tryParse(state.pathParameters['id'] ?? '') ?? -1,
        ),
      ),
      GoRoute(
        path: Routes.hasil,
        builder: (context, state) => ResultScreen(
          sessionId: int.tryParse(state.pathParameters['id'] ?? '') ?? -1,
        ),
      ),
      GoRoute(
        path: Routes.pembahasan,
        builder: (context, state) => ReviewScreen(
          sessionId: int.tryParse(state.pathParameters['id'] ?? '') ?? -1,
          number: int.tryParse(state.pathParameters['n'] ?? '') ?? 0,
        ),
      ),
      GoRoute(
        path: Routes.bukuKesalahan,
        builder: (context, state) => const MistakeBookScreen(),
      ),
      GoRoute(
        path: Routes.kartuKesalahan,
        builder: (context, state) => MistakeCardScreen(
          cardId: int.tryParse(state.pathParameters['id'] ?? '') ?? -1,
        ),
      ),
      GoRoute(
        path: Routes.capture,
        builder: (context, state) => CaptureScreen(
          logId: int.tryParse(state.uri.queryParameters['catatan'] ?? ''),
          tipe: state.uri.queryParameters['tipe'],
        ),
      ),
      GoRoute(
        path: Routes.captureUbah,
        builder: (context, state) => CaptureScreen(
          editId: int.tryParse(state.pathParameters['id'] ?? '') ?? -1,
        ),
      ),
      GoRoute(
        path: Routes.catatanTes,
        builder: (context, state) => const CompanyLogScreen(),
      ),
      GoRoute(
        path: Routes.catatanTesBaru,
        builder: (context, state) => const CompanyLogFormScreen(),
      ),
      GoRoute(
        path: Routes.kraepelin,
        builder: (context, state) {
          final q = state.uri.queryParameters;
          final columns = int.tryParse(q['kolom'] ?? '') ?? 0;
          final seconds = int.tryParse(q['detik'] ?? '') ?? 0;
          final config = KrpConfig.timed(
            columns: columns,
            secondsPerColumn: seconds,
          );
          return KraepelinScreen(
            seed: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
            // Isian rute di luar batas tidak dijepit diam-diam: layar
            // menampilkan kondisi pengaturan tidak sah.
            config:
                config.columns == columns && config.secondsPerColumn == seconds
                    ? config
                    : const KrpConfig(columns: 0, secondsPerColumn: 0, rows: 0),
          );
        },
      ),
      GoRoute(
        path: Routes.kepribadian,
        builder: (context, state) => PersonalityScreen(
          seed: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
        ),
      ),
      _r(Routes.wawancaraDialog, 'S16', 'Dialog wawancara'),
      _r(Routes.wawancaraLaporan, 'S17', 'Laporan wawancara'),
      GoRoute(
        path: Routes.pengaturan,
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: Routes.pengetahuanSesi,
        builder: (context, state) => KnowledgeSessionScreen(
          sessionId: int.tryParse(state.pathParameters['id'] ?? '') ?? -1,
        ),
      ),
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
