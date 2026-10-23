import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import '../utils/text_scale.dart';

class StatItem {
  const StatItem({required this.value, required this.label});

  /// Angka sebagai teks, mis. "120" atau "5".
  final String value;
  final String label;
}

/// Dua atau tiga kolom dipisah garis vertikal `outlineVariant`. Angka `headline`,
/// keterangan `label` `inkMuted`; keterangan turun baris bila panjang. Di skala
/// huruf besar (lihat [isLargeText]) kolom tidak muat, jadi barisnya disusun ke
/// bawah: angka di kiri, keterangan di kanan, dipisah garis mendatar.
class StatRow extends StatelessWidget {
  const StatRow({super.key, required this.items});

  final List<StatItem> items;

  @override
  Widget build(BuildContext context) {
    assert(
        items.length == 2 || items.length == 3, 'StatRow dua atau tiga kolom.');
    final c = context.tokens.colors;
    if (isLargeText(context)) return _stacked(c);
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

  Widget _stacked(AppColors c) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0)
              Divider(height: 1, thickness: 1, color: c.outlineVariant),
            MergeSemantics(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpace.s8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(items[i].value, style: AppType.headline(c.ink)),
                    const SizedBox(width: AppSpace.s12),
                    Expanded(
                      child: Text(
                        items[i].label,
                        style: AppType.label(c.inkMuted),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      );
}
