import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// Kontrol segmen: latar `surfaceContainerHigh`, isi 4, tombol 40, radius 8.
/// Terpilih: latar `accent`. Total tinggi 48.
class SegmentedControl extends StatelessWidget {
  const SegmentedControl({
    super.key,
    required this.options,
    required this.selectedIndex,
    required this.onChanged,
  }) : assert(options.length >= 2, 'Minimal dua segmen.');

  final List<String> options;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.tokens.colors;
    final duration = context.motion;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < options.length; i++)
              Expanded(
                child: Semantics(
                  button: true,
                  selected: i == selectedIndex,
                  child: InkWell(
                    onTap: () => onChanged(i),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    // Area sentuh penuh 48; isian 4 ada di dalam.
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpace.s4),
                      child: AnimatedContainer(
                        duration: duration,
                        curve: AppMotion.curve,
                        constraints: const BoxConstraints(
                          minHeight: AppSizes.segmentHeight,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpace.s8,
                          vertical: AppSpace.s8,
                        ),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: i == selectedIndex
                              ? c.accent
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        child: Text(
                          options[i],
                          textAlign: TextAlign.center,
                          style: AppType.label(
                                  i == selectedIndex ? c.onAccent : c.ink)
                              .copyWith(
                            fontWeight: i == selectedIndex
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
