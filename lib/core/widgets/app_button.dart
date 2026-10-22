import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

enum AppButtonVariant { primary, secondary, outline }

/// Tombol teks. Satu aksi utama per layar. Label menyebut objek ("Simpan ke bank pribadi").
/// `onPressed == null` berarti nonaktif. Label panjang turun ke baris berikutnya, tidak terpotong.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final IconData? icon;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final c = context.tokens.colors;
    final enabled = onPressed != null;

    final Color bg;
    final Color fg;
    final BorderSide side;
    switch (variant) {
      case AppButtonVariant.primary:
        bg = enabled ? c.ink : c.surfaceContainerHigh;
        fg = enabled ? c.surfaceContainer : c.inkMuted;
        side = BorderSide.none;
      case AppButtonVariant.secondary:
        bg = c.surfaceContainerHigh;
        fg = enabled ? c.ink : c.inkMuted;
        side = BorderSide.none;
      case AppButtonVariant.outline:
        bg = c.surfaceContainer;
        fg = enabled ? c.ink : c.inkMuted;
        side = BorderSide(color: enabled ? c.outline : c.outlineVariant);
    }

    final style = AppType.body(fg).copyWith(fontWeight: FontWeight.w600);
    final radius = BorderRadius.circular(AppRadius.md);

    return Semantics(
      button: true,
      enabled: enabled,
      container: true,
      label: label,
      excludeSemantics: true,
      onTap: onPressed,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: AppSizes.touchTarget,
          minWidth: expand ? double.infinity : AppSizes.touchTarget,
        ),
        child: Material(
          color: bg,
          shape: RoundedRectangleBorder(borderRadius: radius, side: side),
          child: InkWell(
            onTap: onPressed,
            customBorder: RoundedRectangleBorder(borderRadius: radius),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.s16,
                vertical: AppSpace.s12,
              ),
              child: Row(
                mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: AppSizes.iconInText, color: fg),
                    const SizedBox(width: AppSpace.s8),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      style: style,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
