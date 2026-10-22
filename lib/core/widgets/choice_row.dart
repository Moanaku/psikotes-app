import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// Baris radio untuk pilihan tunggal. Terpilih: latar `accent` sampai tepi layar,
/// titik radio `ink`. Letakkan baris tanpa margin horizontal agar stabilo penuh.
class ChoiceRow extends StatelessWidget {
  const ChoiceRow({
    super.key,
    required this.title,
    this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.tokens.colors;
    final duration = context.motion;
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        child: AnimatedContainer(
          duration: duration,
          curve: AppMotion.curve,
          constraints: const BoxConstraints(
            minHeight: AppSizes.listRowMinHeight,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.s16,
            vertical: AppSpace.s12,
          ),
          decoration: BoxDecoration(
            color: selected ? c.accent : Colors.transparent,
            border: Border(bottom: BorderSide(color: c.outlineVariant)),
          ),
          child: Row(
            children: [
              ExcludeSemantics(
                child: Container(
                  width: AppSizes.radioOuter,
                  height: AppSizes.radioOuter,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected ? c.ink : c.outline,
                      width: 2,
                    ),
                  ),
                  child: selected
                      ? Container(
                          width: AppSizes.radioDot,
                          height: AppSizes.radioDot,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: c.ink,
                          ),
                        )
                      : null,
                ),
              ),
              const SizedBox(width: AppSpace.s16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppType.body(c.ink)
                          .copyWith(fontWeight: FontWeight.w600),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: AppSpace.s4),
                      Text(
                        subtitle!,
                        style: AppType.label(selected ? c.ink : c.inkMuted),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
