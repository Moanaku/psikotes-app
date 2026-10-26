import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import 'day_refresher.dart';
import 'router.dart';

class PsikotesApp extends ConsumerWidget {
  const PsikotesApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Simulator Psikotes IT',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      themeMode:
          ThemeMode.light, // T21 mengaktifkan tema gelap dan pengaturan tema.
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) =>
          DayRefresher(child: child ?? const SizedBox.shrink()),
    );
  }
}
