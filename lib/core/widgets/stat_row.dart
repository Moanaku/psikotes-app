import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

class StatItem {
  const StatItem({required this.value, required this.label});

  /// Angka sebagai teks, mis. "120" atau "5".
  final String value;
  final String label;
}

/// Dua atau tiga kolom dipisah garis vertikal `outlineVariant`. Angka `headline`,
/// keterangan `label` `inkMuted`; keterangan turun baris bila panjang.
class StatRow extends StatelessWidget {
  const StatRow({super.key, required this.items});

  final List<StatItem> items;

  @override
  Widget build(BuildContext context) {
    assert(
        items.length == 2 || items.length == 3, 'StatRow dua atau tiga kolom.');
    final c = context.tokens.colors;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) VerticalDivider(width: 1, color: c.outlineVariant),
            Expanded(
              child: MergeSemantics(
                child: Padding(
                  padding: EdgeInsets.only(
                    left: i == 0 ? 0 : AppSpace.s12,
                    right: AppSpace.s12,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(items[i].value, style: AppType.headline(c.ink)),
                      const SizedBox(height: AppSpace.s4),
                      Text(items[i].label, style: AppType.label(c.inkMuted)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
