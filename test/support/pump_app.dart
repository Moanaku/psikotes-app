import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:simulator_psikotes_it/app/app.dart';
import 'package:simulator_psikotes_it/app/router.dart';
import 'package:simulator_psikotes_it/core/theme/app_theme.dart';
import 'package:simulator_psikotes_it/domain/providers.dart';

import 'fake_clock.dart';
import 'fake_repositories.dart';

final DateTime appNow = DateTime.utc(2026, 10, 22, 8);

class AppHarness {
  AppHarness(
    this.tester,
    this.container,
    this.profiles,
    this.clock,
    this.mistakes,
    this.captures,
    this.sessions,
  );

  final WidgetTester tester;
  final ProviderContainer container;
  final FakeProfileRepository profiles;
  final FakeClock clock;
  final FakeMistakeRepository mistakes;
  final FakeCaptureRepository captures;
  final FakeSessionRepository sessions;

  GoRouter get router => container.read(routerProvider);

  /// Lokasi sekarang, termasuk halaman yang dibuka lewat `push`.
  String get location {
    final config = router.routerDelegate.currentConfiguration;
    final last = config.last;
    return last is ImperativeRouteMatch
        ? last.matches.uri.toString()
        : config.uri.toString();
  }

  /// Pindah rute seperti tautan dalam (deep link).
  Future<void> go(String path) async {
    router.go(path);
    await tester.pumpAndSettle();
  }
}

/// Memasang seluruh app dengan repository di memori. Ukuran layar dan skala
/// teks bisa diatur; keduanya dikembalikan di akhir test.
Future<AppHarness> pumpApp(
  WidgetTester tester, {
  FakeProfileRepository? profiles,
  FakeMistakeRepository? mistakes,
  FakeCaptureRepository? captures,
  FakeSessionRepository? sessions,
  FakeClock? clock,
  double width = 360,
  double height = 800,
  double textScale = 1,
  List<Override> overrides = const [],
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, height);
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

  final repo = profiles ?? FakeProfileRepository();
  final fake = clock ?? FakeClock(appNow);
  final mistakeRepo = mistakes ?? FakeMistakeRepository();
  final captureRepo = captures ?? FakeCaptureRepository();
  final sessionRepo = sessions ?? FakeSessionRepository();
  await tester.pumpWidget(ProviderScope(
    overrides: [
      profileRepositoryProvider.overrideWithValue(repo),
      mistakeRepositoryProvider.overrideWithValue(mistakeRepo),
      captureRepositoryProvider.overrideWithValue(captureRepo),
      sessionRepositoryProvider.overrideWithValue(sessionRepo),
      answerRepositoryProvider.overrideWithValue(sessionRepo),
      clockProvider.overrideWithValue(fake),
      ...overrides,
    ],
    child: const PsikotesApp(),
  ));
  await tester.pumpAndSettle();
  final container = ProviderScope.containerOf(
    tester.element(find.byType(PsikotesApp)),
  );
  return AppHarness(
    tester,
    container,
    repo,
    fake,
    mistakeRepo,
    captureRepo,
    sessionRepo,
  );
}

/// Kolom isian di dalam [AppTextField] bertanda [key].
Finder fieldIn(String key) => find.descendant(
      of: find.byKey(ValueKey(key)),
      matching: find.byType(TextField),
    );

/// Memasang satu layar langsung (tanpa router) pada tema terang atau gelap,
/// untuk golden dan pemeriksaan tema gelap. Navigasi lewat `context.go` tidak
/// tersedia di sini; pakai [pumpApp] untuk alur.
Future<void> pumpScreen(
  WidgetTester tester,
  Widget screen, {
  Brightness brightness = Brightness.light,
  double width = 360,
  double height = 800,
  double textScale = 1,
  List<Override> overrides = const [],
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, height);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      clockProvider.overrideWithValue(FakeClock(appNow)),
      ...overrides,
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: brightness == Brightness.dark ? AppTheme.dark() : AppTheme.light(),
      builder: (context, app) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: app!,
      ),
      home: screen,
    ),
  ));
  await tester.pumpAndSettle();
}
