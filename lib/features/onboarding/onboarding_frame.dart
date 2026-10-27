import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/utils/text_scale.dart';

/// Bagian tinggi layar yang paling banyak dipakai bilah aksi.
const double defaultFooterMaxShare = 0.4;

/// Bagian untuk panel konfirmasi (tiga pilihan, catatan, skala huruf besar).
const double confirmFooterMaxShare = 0.6;

/// Rangka layar onboarding: kepala tetap, badan yang bisa digulir, dan bilah
/// aksi di bawah dengan garis `outlineVariant` di atasnya. Bilah aksi tidak
/// lebih tinggi dari 40% layar; bila isinya lebih tinggi (skala huruf besar,
/// panel konfirmasi), bilah itu sendiri yang bisa digulir dan badan layar
/// tetap punya ruang. Perakitan token
/// untuk S01 dan S02, bukan komponen inti (lihat A48).
class OnboardingFrame extends StatelessWidget {
  const OnboardingFrame({
    super.key,
    required this.header,
    required this.children,
    required this.footer,
    this.scrollController,
    this.footerMaxShare = defaultFooterMaxShare,
  });

  final Widget header;

  /// Isi badan; margin horizontal dipasang oleh masing-masing anak agar baris
  /// pilihan bisa penuh sampai tepi layar.
  final List<Widget> children;
  final Widget footer;

  /// Untuk menggulir badan kembali ke atas (layar sesi saat soal berganti).
  final ScrollController? scrollController;

  /// Bagian tinggi layar untuk bilah aksi. Panel konfirmasi menaikkannya agar
  /// ketiga pilihan terlihat tanpa menggulir bilah di skala huruf besar.
  final double footerMaxShare;

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
                controller: scrollController,
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
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * footerMaxShare,
                ),
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(
                    AppSpace.s16,
                    AppSpace.s12,
                    AppSpace.s16,
                    AppSpace.s12,
                  ),
                  children: [footer],
                ),
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

/// Tombol di bilah aksi bawah. Biasanya berdampingan dalam satu baris setinggi
/// tombol tertinggi; di skala huruf besar ([shouldStackButtons]) tombol disusun
/// vertikal selebar penuh dan tingginya menyesuaikan isi, supaya label tidak
/// terpotong. Urutan [buttons] dari kiri ke kanan, aksi utama terakhir; di
/// susunan vertikal aksi utama naik ke atas. [flex] mengatur lebar relatif
/// pada susunan mendatar (bawaan sama lebar).
class FooterButtons extends StatelessWidget {
  const FooterButtons({super.key, required this.buttons, this.flex});

  final List<Widget> buttons;
  final List<int>? flex;

  @override
  Widget build(BuildContext context) {
    if (buttons.length == 1) return buttons.single;
    if (shouldStackButtons(context)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = buttons.length - 1; i >= 0; i--) ...[
            if (i < buttons.length - 1) const SizedBox(height: AppSpace.s8),
            buttons[i],
          ],
        ],
      );
    }
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < buttons.length; i++) ...[
            if (i > 0) const SizedBox(width: AppSpace.s8),
            Expanded(flex: flex?[i] ?? 1, child: buttons[i]),
          ],
        ],
      ),
    );
  }
}
