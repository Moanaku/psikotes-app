import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import '../../domain/services/stats_service.dart';

const List<String> _monthShort = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'Mei',
  'Jun',
  'Jul',
  'Agu',
  'Sep',
  'Okt',
  'Nov',
  'Des',
];

/// Label sumbu: tanggal awal minggu ("20/10") atau bulan ("Okt").
String periodLabel(StatsRange range, DateTime start) =>
    range == StatsRange.mingguan
        ? '${start.day}/${start.month}'
        : _monthShort[start.month - 1];

/// Kalimat untuk pembaca layar dan ringkasan teks: semua nilai grafik.
String trendDescription(StatsSummary s) => [
      for (final p in s.trend)
        '${periodLabel(s.range, p.start)} ${p.skor.round()} persen',
    ].join(', ');

/// Grafik garis skor simulasi per periode (S11). Warna dari token; nilai tiap
/// titik juga tertulis di atasnya dan di ringkasan teks layar. Satu titik
/// digambar sebagai titik tunggal.
class TrendChart extends StatelessWidget {
  const TrendChart({super.key, required this.summary});

  final StatsSummary summary;

  static const double height = AppSpace.s48 * 3;

  @override
  Widget build(BuildContext context) {
    final c = context.tokens.colors;
    final s = summary;
    final spots = [
      for (final p in s.trend) FlSpot(p.index.toDouble(), p.skor),
    ];
    final last = spots.length - 1;
    final label = AppType.caption(c.inkMuted);

    LineChartBarData bar() => LineChartBarData(
          spots: spots,
          isCurved: false,
          color: c.ink,
          barWidth: 2,
          isStrokeCapRound: true,
          isStrokeJoinRound: true,
          dotData: FlDotData(
            getDotPainter: (spot, _, __, index) => FlDotCirclePainter(
              radius: index == last ? AppSpace.s8 - 2 : AppSpace.s4,
              color: index == last ? c.accent : c.surfaceContainer,
              strokeWidth: 2,
              strokeColor: c.ink,
            ),
          ),
        );

    final data = bar();
    final chart = LineChart(
      duration: Duration.zero,
      LineChartData(
        minX: -0.5,
        maxX: s.range.buckets - 0.5,
        minY: 0,
        maxY: 100,
        clipData: const FlClipData.none(),
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: 50,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: c.outlineVariant, strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: AppSpace.s32,
              interval: 50,
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
                if (v != i || i < 0 || i >= s.bucketStarts.length) {
                  return const SizedBox.shrink();
                }
                // Bulan penuh muat semua; 8 minggu di 360 dp ditulis
                // selang-seling agar tidak berdempetan.
                if (s.range == StatsRange.mingguan &&
                    (s.bucketStarts.length - 1 - i).isOdd) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: AppSpace.s4),
                  child: Text(
                    periodLabel(s.range, s.bucketStarts[i]),
                    style: label,
                  ),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          enabled: false,
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => Colors.transparent,
            tooltipPadding: EdgeInsets.zero,
            tooltipMargin: AppSpace.s4,
            getTooltipItems: (touched) => [
              for (final t in touched)
                LineTooltipItem(
                  '${t.y.round()}%',
                  AppType.label(c.ink).copyWith(fontWeight: FontWeight.w700),
                ),
            ],
          ),
        ),
        showingTooltipIndicators: [
          for (var i = 0; i < spots.length; i++)
            ShowingTooltipIndicators([LineBarSpot(data, 0, spots[i])]),
        ],
        lineBarsData: [data],
      ),
    );

    return Semantics(
      label: 'Grafik skor simulasi: ${trendDescription(s)}',
      excludeSemantics: true,
      child: SizedBox(
        height: height,
        child: chart,
      ),
    );
  }
}
