import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// Kondisi memuat: baris abu `surfaceContainerHigh` berbentuk baris daftar asli
/// (min 56, garis bawah). Bukan spinner di tengah layar. Tanpa animasi karena
/// gerak hanya untuk respons atas aksi pengguna.
class SkeletonList extends StatelessWidget {
  const SkeletonList({
    super.key,
    this.rows = 3,
    this.withLeading = false,
    this.semanticLabel = 'Memuat daftar',
  });

  final int rows;
  final bool withLeading;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.tokens.colors;
    Widget bar(double height, double widthFactor) => FractionallySizedBox(
          widthFactor: widthFactor,
          alignment: Alignment.centerLeft,
          child: Container(
            height: height,
            decoration: BoxDecoration(
              color: c.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
          ),
        );

    return Semantics(
      label: semanticLabel,
      liveRegion: true,
      excludeSemantics: true,
      child: Column(
        children: [
          for (var i = 0; i < rows; i++)
            Container(
              constraints:
                  const BoxConstraints(minHeight: AppSizes.listRowMinHeight),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.s16,
                vertical: AppSpace.s12,
              ),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: c.outlineVariant)),
              ),
              child: Row(
                children: [
                  if (withLeading) ...[
                    Container(
                      width: AppSizes.iconBase,
                      height: AppSizes.iconBase,
                      decoration: BoxDecoration(
                        color: c.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                    ),
                    const SizedBox(width: AppSpace.s16),
                  ],
                  Expanded(
                    // Rata kiri seperti isi baris daftar yang sebenarnya.
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        bar(AppSpace.s16, 0.6),
                        const SizedBox(height: AppSpace.s8),
                        bar(AppSpace.s12, 0.35),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
