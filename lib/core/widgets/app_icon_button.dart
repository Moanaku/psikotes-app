import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// Tombol ikon 48 x 48. `label` wajib: dibaca pembaca layar dan jadi tooltip.
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final c = context.tokens.colors;
    final radius = BorderRadius.circular(AppRadius.md);
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: label,
      excludeSemantics: true,
      onTap: onPressed,
      child: Tooltip(
        message: label,
        excludeFromSemantics: true,
        child: SizedBox(
          width: AppSizes.touchTarget,
          height: AppSizes.touchTarget,
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onPressed,
              borderRadius: radius,
              child: Center(
                child: Icon(
                  icon,
                  size: AppSizes.iconBase,
                  color: onPressed != null ? c.ink : c.inkMuted,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
