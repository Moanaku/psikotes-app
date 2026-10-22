import 'package:flutter/material.dart';

import '../theme/app_icons.dart';
import '../theme/app_tokens.dart';

/// Baris daftar: min 56, garis bawah `outlineVariant`, bukan kartu.
/// Chevron muncul bila `onTap` ada dan `trailing` kosong.
class ListRow extends StatelessWidget {
  const ListRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.divider = true,
  });

  final String title;
  final String? subtitle;
  final IconData? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final c = context.tokens.colors;
    final end = trailing ??
        (onTap != null
            ? Icon(AppIcons.next, size: AppSizes.iconBase, color: c.inkMuted)
            : null);

    final content = DecoratedBox(
      decoration: BoxDecoration(
        border: divider
            ? Border(bottom: BorderSide(color: c.outlineVariant))
            : null,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppSizes.listRowMinHeight),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.s16,
            vertical: AppSpace.s12,
          ),
          child: Row(
            children: [
              if (leading != null) ...[
                ExcludeSemantics(
                  child: Icon(leading, size: AppSizes.iconBase, color: c.ink),
                ),
                const SizedBox(width: AppSpace.s16),
              ],
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
                      Text(subtitle!, style: AppType.label(c.inkMuted)),
                    ],
                  ],
                ),
              ),
              if (end != null) ...[
                const SizedBox(width: AppSpace.s12),
                end,
              ],
            ],
          ),
        ),
      ),
    );

    if (onTap == null) return content;
    return Semantics(
      button: true,
      child: InkWell(onTap: onTap, child: content),
    );
  }
}
