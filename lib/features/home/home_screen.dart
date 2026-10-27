import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/text_scale.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_icon_button.dart';
import '../../core/widgets/app_top_bar.dart';
import '../../core/widgets/empty_view.dart';
import '../../core/widgets/error_view.dart';
import '../../core/widgets/list_row.dart';
import '../../core/widgets/note_box.dart';
import '../../core/widgets/score_bar.dart';
import '../../core/widgets/skeleton_list.dart';
import '../../domain/models/catalog.dart';
import '../../domain/models/codes.dart';
import '../../domain/services/daily_planner.dart';
import '../../domain/services/profile_templates.dart';
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

  /// Membuka sesi, lalu menghitung ulang beranda saat kembali: sesi bisa
  /// ditutup di tengah jalan ("Lanjutkan nanti").
  Future<void> _openSession(int id) async {
    await context.push(Routes.sesiPath(id));
    if (mounted) ref.invalidate(homeProvider);
  }

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
      unawaited(_openSession(id));
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
                if (data.resume != null)
                  _ResumeRow(
                    resume: data.resume!,
                    onTap: () =>
                        unawaited(_openSession(data.resume!.sessionId)),
                  ),
                const SizedBox(height: AppSpace.s16),
                _TodayPanel(
                  data: data,
                  starting: _starting,
                  onStart: () => _start(data),
                ),
                _AnsweredTodayLine(count: data.answeredToday),
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
    final large = isLargeText(context);
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
        child: _DateHint(
          text: past ? 'Tanggal tes sudah lewat' : 'Tanggal tes belum diisi',
          button: AppButton(
            label: past ? 'Ubah tanggal tes' : 'Isi tanggal tes',
            variant: AppButtonVariant.outline,
            expand: !large,
            onPressed: () => context.push(Routes.profilUbah(data.profile.id!)),
          ),
          stacked: large,
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
                  if (trailing != null && !large) ...[
                    const SizedBox(width: AppSpace.s12),
                    trailing,
                  ],
                ],
              ),
              if (trailing != null && large) ...[
                const SizedBox(height: AppSpace.s8),
                trailing,
              ],
              if (below != null) below,
            ],
          ),
        ),
      ),
    );
  }
}

/// Sesi yang terputus: satu baris di bawah profil, bukan panel (A70).
class _ResumeRow extends StatelessWidget {
  const _ResumeRow({required this.resume, required this.onTap});

  final ResumeInfo resume;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final what = switch (resume.mode) {
      SessionMode.latihan => 'latihan',
      SessionMode.simulasi => 'simulasi',
      SessionMode.diagnostik => 'diagnostik',
    };
    return ListRow(
      leading: AppIcons.clock,
      title: 'Lanjutkan $what',
      subtitle: 'Soal ${resume.position} dari ${resume.total}',
      onTap: onTap,
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
                _PanelTitle(
                  title: 'Latihan hari ini',
                  note: empty ? null : 'Sekitar ${plan.estimatedMinutes} menit',
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

/// Satu baris di bawah panel latihan: berapa soal sudah dijawab hari ini.
class _AnsweredTodayLine extends StatelessWidget {
  const _AnsweredTodayLine({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final c = context.tokens.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.s16,
        AppSpace.s8,
        AppSpace.s16,
        0,
      ),
      child: Text(
        count == 0
            ? 'Belum ada soal dikerjakan hari ini.'
            : 'Sudah dikerjakan hari ini: $count soal',
        style: AppType.label(c.inkMuted),
      ),
    );
  }
}

/// Judul panel dengan keterangan di kanannya; di skala huruf besar keterangan
/// turun ke bawah judul.
class _PanelTitle extends StatelessWidget {
  const _PanelTitle({required this.title, this.note});

  final String title;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final c = context.tokens.colors;
    final heading = Semantics(
      header: true,
      child: Text(title, style: AppType.title(c.ink)),
    );
    final noteText =
        note == null ? null : Text(note!, style: AppType.label(c.inkMuted));
    if (isLargeText(context)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          heading,
          if (noteText != null) ...[
            const SizedBox(height: AppSpace.s4),
            noteText,
          ],
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Expanded(child: heading),
        if (noteText != null) ...[
          const SizedBox(width: AppSpace.s8),
          noteText,
        ],
      ],
    );
  }
}

/// Keterangan tanggal tes dan tombolnya. Berdampingan di skala normal; di
/// skala huruf besar tombol turun dan selebar penuh, tinggi menyesuaikan.
class _DateHint extends StatelessWidget {
  const _DateHint({
    required this.text,
    required this.button,
    required this.stacked,
  });

  final String text;
  final Widget button;
  final bool stacked;

  @override
  Widget build(BuildContext context) {
    final c = context.tokens.colors;
    final label = Text(text, style: AppType.label(c.inkMuted));
    if (stacked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [label, const SizedBox(height: AppSpace.s8), button],
      );
    }
    return Row(
      children: [
        Expanded(child: label),
        const SizedBox(width: AppSpace.s8),
        Flexible(child: button),
      ],
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
      PlanBlockKind.simulation => (
          AppIcons.clock,
          'Simulasi subtes ${ProfileTemplates.categoryName(block.kategori ?? '')}, '
              '${block.minutes} menit',
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
        ListRow(
          leading: AppIcons.bulb,
          title: 'Pengetahuan role',
          subtitle: 'Kartu dasar sampai lanjut',
          onTap: () => context.push(Routes.pengetahuan),
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
