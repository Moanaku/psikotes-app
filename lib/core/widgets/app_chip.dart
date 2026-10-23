import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// Chip pilihan (filter, format tes). Tampilan 44 tinggi, area sentuh 48.
/// Terpilih: latar `accent`, batas `ink` 2, teks tebal.
class AppChip extends StatelessWidget {
  const AppChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.tokens.colors;
    final duration = context.motion;
    const radius = BorderRadius.all(Radius.circular(AppRadius.full));
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSizes.touchTarget),
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
            child: AnimatedContainer(
              duration: duration,
              curve: AppMotion.curve,
              constraints: const BoxConstraints(minHeight: AppSizes.chipHeight),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.s16,
                vertical: AppSpace.s8,
              ),
              decoration: BoxDecoration(
                color: selected ? c.accent : c.surfaceContainer,
                borderRadius: radius,
              ),
              foregroundDecoration: BoxDecoration(
                borderRadius: radius,
                border: Border.all(
                  color: selected ? c.ink : c.outline,
                  width: selected ? 2 : 1,
                ),
              ),
              child: Center(
                widthFactor: 1,
                heightFactor: 1,
                child: Text(
                  label,
                  style: AppType.label(selected ? c.onAccent : c.ink).copyWith(
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
