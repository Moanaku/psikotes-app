import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import 'router.dart';

class PsikotesApp extends StatelessWidget {
  const PsikotesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Simulator Psikotes IT',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      themeMode:
          ThemeMode.light, // T21 mengaktifkan tema gelap dan pengaturan tema.
      routerConfig: appRouter,
    );
  }
}
