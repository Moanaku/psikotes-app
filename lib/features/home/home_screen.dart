import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_icon_button.dart';
import '../../core/widgets/app_top_bar.dart';
import '../../core/widgets/empty_view.dart';
import '../../core/widgets/error_view.dart';
import '../../core/widgets/list_row.dart';
import '../../core/widgets/note_box.dart';
import '../../core/widgets/score_bar.dart';
import '../../core/widgets/skeleton_list.dart';
import '../../core/widgets/status_tag.dart';
import '../../domain/models/catalog.dart';
import '../../domain/models/codes.dart';
import '../../domain/services/daily_planner.dart';
import '../session/session_launcher.dart';
import 'home_provider.dart';

/// S04 Beranda (F03): satu ketukan menuju latihan hari ini.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _starting = false;
  bool _startFailed = false;

  Future<void> _start(HomeData data) async {
    if (_starting) return;
    setState(() {
      _starting = true;
      _startFailed = false;
    });
    try {
      final id = await launchSession(
        ref,
        profileId: data.profile.id!,
        mode: SessionMode.latihan,
        plan: data.plan.session,
      );
      if (!mounted) return;
      setState(() => _starting = false);
      unawaited(context.push(Routes.sesiPath(id)));
    } catch (_) {
      if (mounted) {
        setState(() {
          _starting = false;
          _startFailed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final home = ref.watch(homeProvider);
    final header = AppTopBar(
      title: 'Halo',
      actions: [
        AppIconButton(
          icon: AppIcons.sliders,
          label: 'Pengaturan',
          onPressed: () => context.push(Routes.pengaturan),
        ),
      ],
    );

    return home.when(
      loading: () => _Frame(header: header, children: const [_HomeSkeleton()]),
      error: (_, __) => _Frame(
        header: header,
        children: [
          ErrorView(
            title: 'Rencana latihan tidak bisa disusun',
            message: 'Data profil gagal dibaca. Ketuk coba lagi, atau buka '
                'Pengaturan untuk memeriksa profil.',
            onRetry: () => ref.invalidate(homeProvider),
          ),
        ],
      ),
      // Tanpa profil aktif router sedang mengalihkan ke onboarding.
      data: (data) => data == null
          ? _Frame(header: header, children: const [_HomeSkeleton()])
          : _Frame(
              header: header,
              children: [
                _ProfileRow(data: data),
                const SizedBox(height: AppSpace.s16),
                _TodayPanel(
                  data: data,
                  starting: _starting,
                  onStart: () => _start(data),
                ),
                if (_startFailed)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpace.s16,
                      AppSpace.s8,
                      AppSpace.s16,
                      0,
                    ),
                    child: Semantics(
                      liveRegion: true,
                      child: const NoteBox(
                        icon: AppIcons.alert,
                        text: 'Sesi belum dimulai. Data di perangkat gagal '
                            'ditulis. Ketuk mulai sekali lagi.',
                      ),
                    ),
                  ),
                const SizedBox(height: AppSpace.s24),
                _WeaknessSection(data: data),
                const SizedBox(height: AppSpace.s16),
                _Shortcuts(dueCount: data.dueCount),
              ],
            ),
    );
  }
}

class _Frame extends StatelessWidget {
  const _Frame({required this.header, required this.children});

  final Widget header;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          header,
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: AppSpace.s16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: children,
              ),
            ),
          ),
        ],
      );
}

const EdgeInsets _margin = EdgeInsets.symmetric(horizontal: AppSpace.s16);

/// Baris profil aktif dengan hitung mundur ke tanggal tes.
class _ProfileRow extends StatelessWidget {
  const _ProfileRow({required this.data});

  final HomeData data;

  @override
  Widget build(BuildContext context) {
    final c = context.tokens.colors;
    final days = data.daysUntilTest;
    Widget? trailing;
    Widget? below;
    if (days != null && days > 0) {
      trailing = Semantics(
        label: '$days hari lagi',
        excludeSemantics: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('$days', style: AppType.headline(c.ink)),
            Text('hari lagi', style: AppType.label(c.inkMuted)),
          ],
        ),
      );
    } else if (days == 0) {
      trailing = Text('Hari ini', style: AppType.title(c.ink));
    } else {
      final past = days != null;
      below = Padding(
        padding: const EdgeInsets.only(top: AppSpace.s12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                past ? 'Tanggal tes sudah lewat' : 'Tanggal tes belum diisi',
                style: AppType.label(c.inkMuted),
              ),
            ),
            const SizedBox(width: AppSpace.s8),
            Flexible(
              child: AppButton(
                label: past ? 'Ubah tanggal tes' : 'Isi tanggal tes',
                variant: AppButtonVariant.outline,
                expand: false,
                onPressed: () =>
                    context.push(Routes.profilUbah(data.profile.id!)),
              ),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: _margin,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: c.outlineVariant)),
        ),
        child: Padding(
          padding: const EdgeInsets.only(bottom: AppSpace.s12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Profil aktif', style: AppType.label(c.inkMuted)),
                        const SizedBox(height: AppSpace.s4),
                        Semantics(
                          header: true,
                          child: Text(
                            data.profile.nama,
                            style: AppType.title(c.ink),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: AppSpace.s12),
                    trailing,
                  ],
                ],
              ),
              if (below != null) below,
            ],
          ),
        ),
      ),
    );
  }
}

/// Panel "Latihan hari ini": satu-satunya panel berbingkai di beranda karena
/// itu aksi utamanya (docs/04-sistem-desain.md). Disusun dari token; bukan
/// komponen inti (A57).
class _TodayPanel extends StatelessWidget {
  const _TodayPanel({
    required this.data,
    required this.starting,
    required this.onStart,
  });

  final HomeData data;
  final bool starting;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final c = context.tokens.colors;
    final plan = data.plan;
    final empty = plan.session.items.isEmpty;
    return Padding(
      padding: _margin,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: c.surfaceContainer,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        position: DecorationPosition.background,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: c.outline),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.s16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(
                          'Latihan hari ini',
                          style: AppType.title(c.ink),
                        ),
                      ),
                    ),
                    if (!empty) ...[
                      const SizedBox(width: AppSpace.s8),
                      Text(
                        'Sekitar ${plan.estimatedMinutes} menit',
                        style: AppType.label(c.inkMuted),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: AppSpace.s8),
                if (empty)
                  Text(
                    'Soal untuk subtes di profilmu belum tersedia. Nyalakan '
                    'Numerik, Logika, atau Figural di profil.',
                    style: AppType.body(c.inkMuted),
                  )
                else
                  for (final b in plan.blocks) _BlockRow(block: b, plan: plan),
                const SizedBox(height: AppSpace.s12),
                if (empty)
                  AppButton(
                    label: 'Ubah profil',
                    variant: AppButtonVariant.outline,
                    onPressed: () =>
                        context.push(Routes.profilUbah(data.profile.id!)),
                  )
                else
                  AppButton(
                    label: 'Mulai latihan hari ini',
                    onPressed: starting ? null : onStart,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BlockRow extends StatelessWidget {
  const _BlockRow({required this.block, required this.plan});

  final PlanBlock block;
  final DailyPlan plan;

  @override
  Widget build(BuildContext context) {
    final c = context.tokens.colors;
    final (icon, text) = switch (block.kind) {
      PlanBlockKind.weakest => (
          AppIcons.target,
          '${block.type == null ? 'Tipe' : questionTypeName(block.type!)}, '
              'kategori terlemah',
        ),
      PlanBlockKind.due => (
          AppIcons.book,
          'Kartu buku kesalahan jatuh tempo',
        ),
      PlanBlockKind.mixed => (
          AppIcons.layers,
          'Campuran sesuai bobot profil',
        ),
    };
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AppSpace.s48),
      child: Row(
        children: [
          ExcludeSemantics(
            child: Icon(icon, size: AppSizes.iconBase, color: c.ink),
          ),
          const SizedBox(width: AppSpace.s12),
          Expanded(child: Text(text, style: AppType.body(c.ink))),
          const SizedBox(width: AppSpace.s8),
          Text('${block.count} soal', style: AppType.label(c.inkMuted)),
        ],
      ),
    );
  }
}

/// "Kelemahan saat ini": tiga tipe terlemah, atau kondisi kosong.
class _WeaknessSection extends StatelessWidget {
  const _WeaknessSection({required this.data});

  final HomeData data;

  @override
  Widget build(BuildContext context) {
    final c = context.tokens.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: _margin,
          child: Semantics(
            header: true,
            child: Text('Kelemahan saat ini', style: AppType.title(c.ink)),
          ),
        ),
        const SizedBox(height: AppSpace.s8),
        if (data.weaknesses.isEmpty)
          EmptyView(
            title: 'Belum ada data kelemahan',
            message: 'Kerjakan diagnostik agar latihan hari ini bisa disusun.',
            actionLabel: 'Mulai diagnostik',
            onAction: () => context.push(Routes.onboardingDiagnostik),
          )
        else
          Padding(
            padding: _margin,
            child: Column(
              children: [
                for (var i = 0; i < data.weaknesses.length; i++) ...[
                  if (i > 0) const SizedBox(height: AppSpace.s12),
                  ScoreBar(
                    label: questionTypeName(data.weaknesses[i].type),
                    value: data.weaknesses[i].accuracy.clamp(0.0, 1.0),
                    valueLabel:
                        '${(data.weaknesses[i].accuracy * 100).round()}%',
                    weakest: i == 0,
                  ),
                ],
              ],
            ),
          ),
        if (data.weaknesses.isNotEmpty) ...[
          const SizedBox(height: AppSpace.s8),
          ListRow(
            title: 'Lihat semua di Statistik',
            onTap: () => context.go(Routes.statistik),
          ),
        ],
      ],
    );
  }
}

/// Pintasan: baris dengan garis pemisah, bukan kartu berjajar.
class _Shortcuts extends StatelessWidget {
  const _Shortcuts({required this.dueCount});

  final int dueCount;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListRow(
          leading: AppIcons.grid,
          title: 'Katalog psikotes',
          subtitle: 'Pilih tipe soal',
          onTap: () => context.go(Routes.psikotes),
        ),
        const ListRow(
          leading: AppIcons.bulb,
          title: 'Pengetahuan role',
          subtitle: 'Tersedia di v1.1',
          trailing: StatusTag(label: 'v1.1'),
        ),
        ListRow(
          leading: AppIcons.camera,
          title: 'Capture soal',
          subtitle: 'Dari tes asli',
          onTap: () => context.push(Routes.capture),
        ),
        ListRow(
          leading: AppIcons.book,
          title: 'Buku kesalahan',
          subtitle: dueCount > 0
              ? '$dueCount jatuh tempo'
              : 'Tidak ada kartu jatuh tempo',
          onTap: () => context.push(Routes.bukuKesalahan),
        ),
      ],
    );
  }
}

/// Kondisi memuat: skeleton berbentuk baris profil, panel, dan tiga baris
/// kelemahan.
class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();

  @override
  Widget build(BuildContext context) {
    final c = context.tokens.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SkeletonList(rows: 1, semanticLabel: 'Memuat profil aktif'),
        const SizedBox(height: AppSpace.s16),
        Padding(
          padding: _margin,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: c.outlineVariant),
            ),
            child: const SkeletonList(
              rows: 3,
              withLeading: true,
              semanticLabel: 'Memuat latihan hari ini',
            ),
          ),
        ),
        const SizedBox(height: AppSpace.s24),
        const SkeletonList(rows: 3, semanticLabel: 'Memuat kelemahan'),
      ],
    );
  }
}
