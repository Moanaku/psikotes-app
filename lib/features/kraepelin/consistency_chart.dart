import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:question_engine/question_engine.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/utils/text_scale.dart';

/// Kalimat untuk pembaca layar: isian tiap kolom.
String consistencyDescription(KrpScore score) => [
      for (var i = 0; i < score.columns.length; i++)
        'kolom ${i + 1} ${score.columns[i].filled} isian',
    ].join(', ');

/// Grafik konsistensi Kraepelin (T23): isian per kolom sebagai garis. Warna
/// dari token, sama dengan grafik S11; nilai tiap kolom juga ditulis di
/// daftar teks layar. Label sumbu dibatasi skala 1,3 (A97).
class ConsistencyChart extends StatelessWidget {
  const ConsistencyChart({super.key, required this.score});

  final KrpScore score;

  static const double height = AppSpace.s48 * 3;

  @override
  Widget build(BuildContext context) {
    final c = context.tokens.colors;
    final label = AppType.caption(c.inkMuted);
    final n = score.columns.length;
    final top = score.maxFilled == 0 ? 1 : score.maxFilled;
    // Label kolom selang bila kolom banyak, supaya tidak berdempetan.
    final every = n <= 10 ? 1 : (n / 10).ceil();
    final chart = LineChart(
      duration: Duration.zero,
      LineChartData(
        minX: 0.5,
        maxX: n + 0.5,
        minY: 0,
        maxY: top.toDouble(),
        clipData: const FlClipData.none(),
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: top.toDouble(),
          getDrawingHorizontalLine: (_) =>
              FlLine(color: c.outlineVariant, strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: AppSpace.s48,
              interval: top.toDouble(),
              getTitlesWidget: (v, meta) => Padding(
                padding: const EdgeInsets.only(right: AppSpace.s4),
                child: Text(
                  v.round().toString(),
                  textAlign: TextAlign.right,
                  style: label,
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: AppSpace.s24,
              interval: 1,
              getTitlesWidget: (v, meta) {
                final i = v.round();
                if (v != i || i < 1 || i > n || (i - 1) % every != 0) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: AppSpace.s4),
                  child: Text('$i', style: label),
                );
              },
            ),
          ),
        ),
        lineTouchData: const LineTouchData(enabled: false),
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (var i = 0; i < n; i++)
                FlSpot(i + 1.0, score.columns[i].filled.toDouble()),
            ],
            color: c.ink,
            barWidth: 2,
            isStrokeCapRound: true,
            isStrokeJoinRound: true,
            dotData: FlDotData(
              getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                radius: AppSpace.s4,
                color: c.surfaceContainer,
                strokeWidth: 2,
                strokeColor: c.ink,
              ),
            ),
          ),
        ],
      ),
    );
    return Semantics(
      label: 'Grafik isian per kolom: ${consistencyDescription(score)}',
      excludeSemantics: true,
      child: SizedBox(
        height: height,
        child: ClampedChromeText(child: chart),
      ),
    );
  }
}
