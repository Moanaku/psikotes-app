import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// Opsi soal. Batas `outline` 1, latar `surfaceContainer`, radius 8.
/// Terpilih: latar `accent`, batas `ink` 2, huruf opsi berlatar `ink`.
/// Isi berupa teks (`label`) atau widget (`child`, mis. gambar figural).
class OptionTile extends StatelessWidget {
  const OptionTile({
    super.key,
    required this.letter,
    this.label,
    this.child,
    this.semanticLabel,
    required this.selected,
    required this.onTap,
  }) : assert(label != null || child != null, 'Isi label atau child.');

  final String letter;
  final String? label;
  final Widget? child;

  /// Wajib bila `child` berupa gambar; dibaca setelah "Opsi [huruf]".
  final String? semanticLabel;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.tokens.colors;
    final duration = context.motion;
    final radius = BorderRadius.circular(AppRadius.md);
    return Semantics(
      button: true,
      selected: selected,
      label:
          'Opsi $letter${(semanticLabel ?? label) == null ? '' : ', ${semanticLabel ?? label}'}',
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: AnimatedContainer(
          duration: duration,
          curve: AppMotion.curve,
          constraints:
              const BoxConstraints(minHeight: AppSizes.listRowMinHeight),
          padding: const EdgeInsets.all(AppSpace.s12),
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
          child: Row(
            children: [
              AnimatedContainer(
                duration: duration,
                curve: AppMotion.curve,
                width: AppSizes.optionLetter,
                height: AppSizes.optionLetter,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? c.ink : c.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(
                  letter,
                  style: AppType.label(selected ? c.surfaceContainer : c.ink)
                      .copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: AppSpace.s12),
              Expanded(
                child: child ??
                    Text(
                      label!,
                      style:
                          AppType.body(selected ? c.onAccent : c.ink).copyWith(
                        fontWeight: selected ? FontWeight.w600 : null,
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
