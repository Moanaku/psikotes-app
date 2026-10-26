import 'package:flutter/material.dart';

import '../theme/app_icons.dart';
import '../theme/app_tokens.dart';
import '../utils/text_scale.dart';

/// Empat tab tetap: Beranda, Psikotes, Wawancara, Statistik.
/// Tab aktif: ikon di dalam pil `accent` 56 x 32, label `ink` tebal. Skala
/// huruf label dibatasi 1,3 supaya nama tab tidak terpotong.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.currentIndex,
    required this.onSelected,
  });

  static const _tabs = [
    (AppIcons.home, 'Beranda'),
    (AppIcons.grid, 'Psikotes'),
    (AppIcons.chat, 'Wawancara'),
    (AppIcons.chart, 'Statistik'),
  ];

  final int currentIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final c = context.tokens.colors;
    final duration = context.motion;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < _tabs.length; i++)
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: i == currentIndex,
                    child: InkWell(
                      onTap: () => onSelected(i),
                      child: Padding(
                        padding:
                            const EdgeInsets.symmetric(vertical: AppSpace.s8),
                        child: Column(
                          children: [
                            AnimatedContainer(
                              duration: duration,
                              curve: AppMotion.curve,
                              width: AppSizes.navPillWidth,
                              height: AppSizes.navPillHeight,
                              decoration: BoxDecoration(
                                color: i == currentIndex
                                    ? c.accent
                                    : Colors.transparent,
                                borderRadius:
                                    BorderRadius.circular(AppRadius.full),
                              ),
                              child: ExcludeSemantics(
                                child: Icon(
                                  _tabs[i].$1,
                                  size: AppSizes.iconBase,
                                  color: i == currentIndex
                                      ? c.onAccent
                                      : c.inkMuted,
                                ),
                              ),
                            ),
                            const SizedBox(height: AppSpace.s4),
                            ClampedChromeText(
                              child: Text(
                                _tabs[i].$2,
                                textAlign: TextAlign.center,
                                style: AppType.caption(
                                  i == currentIndex ? c.ink : c.inkMuted,
                                ).copyWith(
                                  fontWeight: i == currentIndex
                                      ? FontWeight.w700
                                      : FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
