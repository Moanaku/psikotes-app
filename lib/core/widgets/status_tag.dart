import 'package:flutter/material.dart';

import '../theme/app_icons.dart';
import '../theme/app_tokens.dart';

enum StatusTagKind { neutral, attention, strong }

/// Tag status, tinggi 24, radius 4. Netral: batas `outline`. Perlu perhatian:
/// latar `accent`. Kuat: `okContainer` dengan ikon centang (warna tidak berdiri sendiri).
class StatusTag extends StatelessWidget {
  const StatusTag({
    super.key,
    required this.label,
    this.kind = StatusTagKind.neutral,
  });

  final String label;
  final StatusTagKind kind;

  @override
  Widget build(BuildContext context) {
    final c = context.tokens.colors;
    final Color bg;
    final Color fg;
    final Color? border;
    switch (kind) {
      case StatusTagKind.neutral:
        bg = Colors.transparent;
        fg = c.ink;
        border = c.outline;
      case StatusTagKind.attention:
        bg = c.accent;
        fg = c.onAccent;
        border = null;
      case StatusTagKind.strong:
        bg = c.okContainer;
        fg = c.ok;
        border = null;
    }
    final radius = BorderRadius.circular(AppRadius.sm);
    return DecoratedBox(
      decoration: BoxDecoration(color: bg, borderRadius: radius),
      position: DecorationPosition.background,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          border: border == null ? null : Border.all(color: border),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSizes.tagHeight),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.s8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (kind == StatusTagKind.strong) ...[
                  ExcludeSemantics(
                    child: Icon(AppIcons.check,
                        size: AppSizes.iconInTag, color: fg),
                  ),
                  const SizedBox(width: AppSpace.s4),
                ],
                Flexible(
                  child: Text(
                    label,
                    style:
                        AppType.label(fg).copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
