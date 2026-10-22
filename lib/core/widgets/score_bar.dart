import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// Bilah skor 8 tinggi. Nilai selalu ditulis sebagai teks di sampingnya
/// (`valueLabel`, mis. "72%"). `weakest` menandai kelemahan terbesar:
/// isi `accent` dengan batas `ink`.
class ScoreBar extends StatelessWidget {
  const ScoreBar({
    super.key,
    required this.label,
    required this.value,
    required this.valueLabel,
    this.weakest = false,
  }) : assert(value >= 0 && value <= 1, 'value berada di 0 sampai 1.');

  final String label;

  /// 0 sampai 1.
  final double value;
  final String valueLabel;
  final bool weakest;

  @override
  Widget build(BuildContext context) {
    final c = context.tokens.colors;
    final duration = context.motion;
    final radius = BorderRadius.circular(AppRadius.sm);
    return Semantics(
      label: '$label: $valueLabel${weakest ? ', kelemahan terbesar' : ''}',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppType.body(c.ink)),
          const SizedBox(height: AppSpace.s8),
          Row(
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder: (context, box) => Container(
                    height: AppSizes.barHeight,
                    alignment: Alignment.centerLeft,
                    decoration: BoxDecoration(
                      color: c.surfaceContainerHigh,
                      borderRadius: radius,
                    ),
                    child: AnimatedContainer(
                      duration: duration,
                      curve: AppMotion.curve,
                      width: box.maxWidth * value,
                      height: AppSizes.barHeight,
                      decoration: BoxDecoration(
                        color: weakest ? c.accent : c.ink,
                        borderRadius: radius,
                        border: weakest && value > 0
                            ? Border.all(color: c.ink)
                            : null,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpace.s12),
              Text(
                valueLabel,
                style:
                    AppType.label(c.ink).copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
