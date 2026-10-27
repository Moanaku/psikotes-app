import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/widgets/app_bottom_nav.dart';
import 'routes.dart';

/// Kerangka empat tab: Beranda, Psikotes, Wawancara, Statistik. Layar di
/// dalamnya tidak memasang `Scaffold` sendiri; bottom nav tetap di bawah.
/// Sesi (S06, S07) berada di luar kerangka ini dan layar penuh.
class TabShell extends StatelessWidget {
  const TabShell({super.key, required this.location, required this.child});

  /// Rute sekarang, untuk menentukan tab aktif.
  final String location;
  final Widget child;

  static const List<String> tabRoutes = [
    Routes.beranda,
    Routes.psikotes,
    Routes.wawancara,
    Routes.statistik,
  ];

  static int indexOf(String location) {
    // Bank pengetahuan (S19) dibuka dari katalog, jadi tab Psikotes aktif.
    if (location.startsWith(Routes.pengetahuan)) return 1;
    final i = tabRoutes.indexWhere(
      (r) => r == Routes.beranda ? location == r : location.startsWith(r),
    );
    return i < 0 ? 0 : i;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(bottom: false, child: child),
      bottomNavigationBar: AppBottomNav(
        currentIndex: indexOf(location),
        onSelected: (i) => context.go(tabRoutes[i]),
      ),
    );
  }
}
