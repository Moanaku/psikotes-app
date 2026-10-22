import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';

/// Rangka layar onboarding: kepala tetap, badan yang bisa digulir, dan bilah
/// aksi di bawah dengan garis `outlineVariant` di atasnya. Perakitan token
/// untuk S01 dan S02, bukan komponen inti (lihat A48).
class OnboardingFrame extends StatelessWidget {
  const OnboardingFrame({
    super.key,
    required this.header,
    required this.children,
    required this.footer,
  });

  final Widget header;

  /// Isi badan; margin horizontal dipasang oleh masing-masing anak agar baris
  /// pilihan bisa penuh sampai tepi layar.
  final List<Widget> children;
  final Widget footer;

  @override
  Widget build(BuildContext context) {
    final c = context.tokens.colors;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            header,
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: AppSpace.s16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: children,
                ),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                color: c.surface,
                border: Border(top: BorderSide(color: c.outlineVariant)),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.s16,
                  AppSpace.s12,
                  AppSpace.s16,
                  AppSpace.s12,
                ),
                child: footer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Margin layar horizontal 16 untuk isi di dalam [OnboardingFrame].
class ScreenPadding extends StatelessWidget {
  const ScreenPadding({super.key, required this.child, this.top = 0});

  final Widget child;
  final double top;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpace.s16,
          top,
          AppSpace.s16,
          0,
        ),
        child: child,
      );
}
