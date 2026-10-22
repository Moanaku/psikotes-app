import 'package:flutter/material.dart';

import '../theme/app_icons.dart';
import '../theme/app_tokens.dart';

/// Info tambahan: ikon di kiri, teks `label`, latar `surfaceContainer`,
/// batas `outline` 1, radius 8. Tanpa garis tebal di sisi.
class NoteBox extends StatelessWidget {
  const NoteBox({super.key, required this.text, this.icon = AppIcons.note});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final c = context.tokens.colors;
    final radius = BorderRadius.circular(AppRadius.md);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpace.s12),
      decoration:
          BoxDecoration(color: c.surfaceContainer, borderRadius: radius),
      foregroundDecoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(color: c.outline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: Icon(icon, size: AppSizes.iconInText, color: c.ink),
          ),
          const SizedBox(width: AppSpace.s8),
          Expanded(child: Text(text, style: AppType.label(c.ink))),
        ],
      ),
    );
  }
}
