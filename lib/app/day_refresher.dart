import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/providers.dart';

/// Tidak menggambar apa pun. Menyegarkan [dayProvider] saat tengah malam
/// setempat dan saat app kembali dari latar belakang, supaya beranda dan buku
/// kesalahan tidak memakai "hari ini" kemarin (A95).
class DayRefresher extends ConsumerStatefulWidget {
  const DayRefresher({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<DayRefresher> createState() => _DayRefresherState();
}

class _DayRefresherState extends ConsumerState<DayRefresher>
    with WidgetsBindingObserver {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _schedule();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  void _refresh() {
    ref.read(dayProvider.notifier).refresh();
    _schedule();
  }

  /// Timer ke tengah malam setempat berikutnya, dihitung dari jam `Clock`.
  void _schedule() {
    _timer?.cancel();
    final now = ref.read(clockProvider).now().toLocal();
    final midnight = DateTime(now.year, now.month, now.day + 1);
    _timer =
        Timer(midnight.difference(now) + const Duration(seconds: 1), _refresh);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
