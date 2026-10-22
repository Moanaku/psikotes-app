import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_top_bar.dart';
import '../../core/widgets/empty_view.dart';
import '../../core/widgets/error_view.dart';
import '../../core/widgets/note_box.dart';
import '../../core/widgets/score_bar.dart';
import '../../core/widgets/segmented_control.dart';
import '../../core/widgets/skeleton_list.dart';
import '../../core/widgets/stat_row.dart';
import '../../domain/providers.dart';
import '../../domain/services/profile_templates.dart';
import '../../domain/services/stats_service.dart';
import '../../core/utils/time_format.dart';
import 'stats_provider.dart';
import 'trend_chart.dart';

/// S11 Statistik (F08): tren skor simulasi, akurasi dan median per kategori,
/// dan ekspor CSV. Tampil di dalam kerangka tab (bottom nav).
class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key});

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen> {
  bool _exporting = false;
  String? _exportError;

  Future<void> _export() async {
    if (_exporting) return;
    setState(() {
      _exporting = true;
      _exportError = null;
    });
    try {
      final data = await ref.refresh(statsDataProvider.future);
      final now = ref.read(clockProvider).now().toLocal();
      final day = '${now.year.toString().padLeft(4, '0')}-'
          '${now.month.toString().padLeft(2, '0')}-'
          '${now.day.toString().padLeft(2, '0')}';
      await ref.read(csvSharerProvider).share(
            fileName: 'statistik-psikotes-$day.csv',
            content: StatsService.csv(
              sessions: data.sessions,
              answers: data.answers,
            ),
          );
      if (mounted) setState(() => _exporting = false);
    } catch (_) {
      if (mounted) {
        setState(() {
          _exporting = false;
          _exportError = 'Berkas CSV belum dibagikan. Data di perangkat gagal '
              'dibaca atau lembar bagikan tidak terbuka. Ketuk sekali lagi.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final stats = ref.watch(statsProvider);
    final range = ref.watch(statsRangeProvider);
    final showControls = stats.valueOrNull?.hasSessions ?? false;
    return Column(
      children: [
        const AppTopBar(title: 'Statistik'),
        if (showControls)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.s16),
            child: SegmentedControl(
              options: [for (final r in StatsRange.values) r.label],
              selectedIndex: range.index,
              onChanged: (i) => ref.read(statsRangeProvider.notifier).state =
                  StatsRange.values[i],
            ),
          ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: AppSpace.s16),
            child: stats.when(
              loading: () => const _StatsSkeleton(),
              error: (_, __) => ErrorView(
                title: 'Statistik tidak bisa dibuka',
                message: 'Data sesi gagal dibaca. Ketuk coba lagi. '
                    'Riwayat latihanmu tidak hilang.',
                onRetry: () => ref.invalidate(statsDataProvider),
              ),
              data: (s) => s.hasSessions
                  ? _content(context, s)
                  : EmptyView(
                      title: 'Belum ada sesi',
                      message: 'Statistik muncul setelah sesi pertama selesai.',
                      actionLabel: 'Mulai latihan',
                      onAction: () => context.go(Routes.psikotes),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _content(BuildContext context, StatsSummary s) {
    final c = context.tokens.colors;
    final weekly = s.range == StatsRange.mingguan;
    final unit = weekly ? 'minggu' : 'bulan';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpace.s8),
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border.symmetric(
                horizontal: BorderSide(color: c.outlineVariant),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpace.s12),
              child: StatRow(items: [
                StatItem(value: '${s.minutes}', label: 'menit $unit ini'),
                StatItem(value: '${s.sessionsDone}', label: 'sesi selesai'),
                StatItem(value: '${s.streakDays}', label: 'hari beruntun'),
              ]),
            ),
          ),
          const SizedBox(height: AppSpace.s24),
          Semantics(
            header: true,
            child: Text('Skor simulasi per $unit', style: AppType.title(c.ink)),
          ),
          const SizedBox(height: AppSpace.s12),
          ..._trend(context, s),
          const SizedBox(height: AppSpace.s24),
          Semantics(
            header: true,
            child: Text('Per kategori', style: AppType.title(c.ink)),
          ),
          const SizedBox(height: AppSpace.s12),
          ..._categories(s),
          const SizedBox(height: AppSpace.s24),
          AppButton(
            label: 'Ekspor CSV untuk laporan hasil',
            icon: AppIcons.download,
            variant: AppButtonVariant.outline,
            onPressed: _exporting ? null : () => unawaited(_export()),
          ),
          if (_exportError != null) ...[
            const SizedBox(height: AppSpace.s12),
            Semantics(
              liveRegion: true,
              child: NoteBox(icon: AppIcons.alert, text: _exportError!),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _trend(BuildContext context, StatsSummary s) {
    final c = context.tokens.colors;
    final unit = s.range == StatsRange.mingguan ? 'minggu' : 'bulan';
    if (s.trend.isEmpty) {
      return [
        const NoteBox(
          icon: AppIcons.chart,
          text: 'Belum ada simulasi di rentang ini. Kerjakan simulasi dari '
              'tab Psikotes.',
        ),
      ];
    }
    final last = s.trend.last;
    final String summary;
    if (s.trend.length >= 2) {
      final diff = (last.skor - s.trend[s.trend.length - 2].skor).round();
      summary = 'Terakhir ${last.skor.round()}%, '
          '${diff == 0 ? 'sama dengan' : diff > 0 ? 'naik $diff poin dari' : 'turun ${-diff} poin dari'}'
          ' $unit sebelumnya.';
    } else {
      summary = 'Terakhir ${last.skor.round()}%.';
    }
    return [
      TrendChart(summary: s),
      const SizedBox(height: AppSpace.s8),
      Text(summary, style: AppType.label(c.ink)),
      if (s.trend.length < 2) ...[
        const SizedBox(height: AppSpace.s8),
        Text(
          s.simulations < 2
              ? 'Butuh minimal dua simulasi untuk melihat tren.'
              : 'Butuh simulasi di minimal dua $unit untuk melihat tren.',
          style: AppType.label(c.inkMuted),
        ),
      ],
    ];
  }

  List<Widget> _categories(StatsSummary s) {
    final cats = s.categories;
    if (cats.isEmpty) return const [];
    final marked =
        cats.length > 1 && {for (final k in cats) k.akurasi.round()}.length > 1;
    var weakest = cats.first;
    for (final k in cats) {
      if (k.akurasi < weakest.akurasi) weakest = k;
    }
    return [
      for (var i = 0; i < cats.length; i++) ...[
        if (i > 0) const SizedBox(height: AppSpace.s12),
        ScoreBar(
          label: _label(cats[i]),
          value: (cats[i].akurasi / 100).clamp(0.0, 1.0),
          valueLabel: '${cats[i].akurasi.round()}%',
          weakest: marked && cats[i].kategori == weakest.kategori,
        ),
      ],
    ];
  }

  static String _label(CategoryStat k) {
    final name = ProfileTemplates.categoryName(k.kategori);
    final ms = k.medianMs;
    return ms == null ? name : '$name, median ${secondsOf(ms)} dtk';
  }
}

/// Skeleton S11: tiga angka, grafik, dan empat baris kategori.
class _StatsSkeleton extends StatelessWidget {
  const _StatsSkeleton();

  @override
  Widget build(BuildContext context) {
    final c = context.tokens.colors;
    Widget block(double height) => Container(
          height: height,
          decoration: BoxDecoration(
            color: c.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
        );
    return Semantics(
      label: 'Memuat statistik',
      liveRegion: true,
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.s16,
              AppSpace.s16,
              AppSpace.s16,
              0,
            ),
            child: Row(
              children: [
                for (var i = 0; i < 3; i++) ...[
                  if (i > 0) const SizedBox(width: AppSpace.s12),
                  Expanded(child: block(AppSpace.s48)),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.s16,
              AppSpace.s24,
              AppSpace.s16,
              AppSpace.s24,
            ),
            child: block(TrendChart.height),
          ),
          const SkeletonList(rows: 4, semanticLabel: 'Memuat kategori'),
        ],
      ),
    );
  }
}
