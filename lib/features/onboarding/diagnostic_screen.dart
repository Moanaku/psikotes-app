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
import '../../core/widgets/list_row.dart';
import '../../core/widgets/note_box.dart';
import '../../core/widgets/score_bar.dart';
import '../../core/widgets/skeleton_list.dart';
import '../../core/widgets/status_tag.dart';
import '../../domain/models/codes.dart';
import '../../domain/services/profile_templates.dart';
import '../../domain/services/scoring.dart';
import '../session/session_launcher.dart';
import 'diagnostic_provider.dart';
import 'onboarding_frame.dart';

/// S03 Diagnostik (F02): pengantar, progres per subtes, dan hasil nyata
/// sesudah selesai. Diagnostik yang terputus bisa dilanjutkan; hasil lama
/// tetap tersimpan saat diulang.
class DiagnosticScreen extends ConsumerStatefulWidget {
  const DiagnosticScreen({super.key});

  @override
  ConsumerState<DiagnosticScreen> createState() => _DiagnosticScreenState();
}

class _DiagnosticScreenState extends ConsumerState<DiagnosticScreen> {
  bool _starting = false;
  bool _startFailed = false;

  void _toHome() => context.go(Routes.beranda);

  void _back() => context.canPop() ? context.pop() : _toHome();

  Future<void> _openSession(int id) async {
    await context.push(Routes.sesiPath(id));
    // Sesi bisa ditutup di tengah jalan: progres perlu dibaca ulang.
    if (mounted) ref.invalidate(diagnosticProvider);
  }

  Future<void> _start(DiagnosticData data) async {
    if (_starting || data.plan == null) return;
    setState(() {
      _starting = true;
      _startFailed = false;
    });
    try {
      final id = await launchSession(
        ref,
        profileId: data.profile.id!,
        mode: SessionMode.diagnostik,
        plan: data.plan!.plan,
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
    final c = context.tokens.colors;
    final data = ref.watch(diagnosticProvider);
    final repeat = data.valueOrNull?.result != null;
    final header = AppTopBar(
      title: 'Diagnostik',
      onBack: _back,
      actions: [
        if (!repeat)
          Padding(
            padding: const EdgeInsets.only(right: AppSpace.s16),
            child:
                Center(child: Text('3 / 3', style: AppType.label(c.inkMuted))),
          ),
      ],
    );
    final skip = AppButton(
      label: 'Lewati, nanti saja',
      variant: AppButtonVariant.secondary,
      onPressed: _toHome,
    );

    return data.when(
      loading: () => OnboardingFrame(
        header: header,
        footer: skip,
        children: const [
          SkeletonList(
            rows: 4,
            withLeading: true,
            semanticLabel: 'Memuat diagnostik',
          ),
        ],
      ),
      error: (_, __) => OnboardingFrame(
        header: header,
        footer: skip,
        children: [
          ErrorView(
            title: 'Diagnostik tidak bisa disiapkan',
            message: 'Data profil atau riwayat gagal dibaca. Ketuk coba lagi, '
                'atau lewati dan mulai dari beranda.',
            onRetry: () => ref.invalidate(diagnosticProvider),
          ),
        ],
      ),
      data: (d) {
        if (d == null) {
          return OnboardingFrame(
            header: header,
            footer: skip,
            children: [
              EmptyView(
                title: 'Belum ada profil aktif',
                message: 'Buat profil tes dulu agar diagnostik bisa disusun.',
                actionLabel: 'Buat profil tes',
                onAction: () => context.go(Routes.onboardingRole),
              ),
            ],
          );
        }
        return OnboardingFrame(
          header: header,
          footer: _Footer(
            data: d,
            starting: _starting,
            onSkip: _toHome,
            onStart: () => _start(d),
            onResume: () => _openSession(d.unfinishedId!),
            onHome: _toHome,
            onEditProfile: () => context.push(Routes.profilUbah(d.profile.id!)),
          ),
          children: [
            ..._body(context, d),
            if (_startFailed)
              ScreenPadding(
                top: AppSpace.s16,
                child: Semantics(
                  liveRegion: true,
                  child: const NoteBox(
                    icon: AppIcons.alert,
                    text: 'Diagnostik belum dimulai. Data di perangkat gagal '
                        'ditulis. Ketuk mulai sekali lagi.',
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  List<Widget> _body(BuildContext context, DiagnosticData d) {
    final c = context.tokens.colors;
    final result = d.result;
    final nothingToDo = !d.canStart && d.rows.isEmpty;
    return [
      ScreenPadding(
        child: Semantics(
          header: true,
          child: Text('Kenali titik awalmu', style: AppType.headline(c.ink)),
        ),
      ),
      const SizedBox(height: AppSpace.s8),
      ScreenPadding(
        child: Text(
          'Maksimal 20 menit. Hasilnya menentukan urutan latihan pertamamu.',
          style: AppType.body(c.inkMuted),
        ),
      ),
      if (nothingToDo)
        const EmptyView(
          title: 'Belum ada subtes yang bisa didiagnosis',
          message: 'Soal untuk subtes di profilmu belum tersedia. Nyalakan '
              'Numerik, Logika, atau Figural di profil.',
        )
      else ...[
        const SizedBox(height: AppSpace.s24),
        ScreenPadding(
          child: Semantics(
            header: true,
            child: Text('Progres', style: AppType.title(c.ink)),
          ),
        ),
        const SizedBox(height: AppSpace.s8),
        for (final row in d.rows) _ProgressRow(row: row),
        const SizedBox(height: AppSpace.s24),
        ScreenPadding(
          child: Semantics(
            header: true,
            child: Text(
              result == null ? 'Setelah selesai' : 'Hasil diagnostik',
              style: AppType.title(c.ink),
            ),
          ),
        ),
        const SizedBox(height: AppSpace.s12),
        ScreenPadding(
          child: result == null
              ? _ResultPreview(rows: d.rows)
              : _ResultBars(result: result),
        ),
        if (result == null) ...[
          const SizedBox(height: AppSpace.s8),
          ListRow(
            leading: AppIcons.home,
            title: 'Ke beranda',
            onTap: _toHome,
          ),
        ],
      ],
    ];
  }
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({required this.row});

  final DiagnosticRow row;

  @override
  Widget build(BuildContext context) {
    final (icon, tag) = switch (row.progress) {
      SubtestProgress.selesai => (
          AppIcons.check,
          const StatusTag(label: 'Selesai', kind: StatusTagKind.strong),
        ),
      SubtestProgress.berjalan => (
          AppIcons.target,
          const StatusTag(label: 'Berjalan', kind: StatusTagKind.attention),
        ),
      SubtestProgress.belum => (
          AppIcons.clock,
          const StatusTag(label: 'Belum'),
        ),
    };
    final parts = [
      if (row.jumlah != null) '${row.jumlah} soal',
      if (row.menit != null) '${row.menit} menit',
    ];
    return ListRow(
      leading: icon,
      title: ProfileTemplates.categoryName(row.kategori),
      subtitle: parts.isEmpty ? null : parts.join(', '),
      trailing: tag,
    );
  }
}

/// Pratinjau struktur hasil sebelum ada angka: bilah kosong. Angka contoh
/// tidak ditampilkan (A5).
class _ResultPreview extends StatelessWidget {
  const _ResultPreview({required this.rows});

  final List<DiagnosticRow> rows;

  @override
  Widget build(BuildContext context) {
    final c = context.tokens.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Akurasi dan median waktu tiap kategori muncul di sini, dengan '
          'kategori terlemah ditandai.',
          style: AppType.label(c.inkMuted),
        ),
        const SizedBox(height: AppSpace.s12),
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpace.s12),
          ScoreBar(
            label: ProfileTemplates.categoryName(rows[i].kategori),
            value: 0,
            valueLabel: 'Belum ada',
          ),
        ],
      ],
    );
  }
}

class _ResultBars extends StatelessWidget {
  const _ResultBars({required this.result});

  final DiagnosticResult result;

  @override
  Widget build(BuildContext context) {
    final cats = result.categories;
    final accuracies = {for (final k in cats) k.akurasi.round()};
    final marked = cats.length > 1 && accuracies.length > 1;
    final weakest = result.weakest;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < cats.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpace.s12),
          ScoreBar(
            label: _label(cats[i]),
            value: (cats[i].akurasi / 100).clamp(0.0, 1.0),
            valueLabel: '${cats[i].akurasi.round()}%',
            weakest: marked && cats[i].kategori == weakest,
          ),
        ],
        if (marked) ...[
          const SizedBox(height: AppSpace.s16),
          StatusTag(
            label: 'Terlemah: ${ProfileTemplates.categoryName(weakest)}',
            kind: StatusTagKind.attention,
          ),
        ],
      ],
    );
  }

  static String _label(CategoryScore s) {
    final name = ProfileTemplates.categoryName(s.kategori);
    final ms = s.medianMs;
    return ms == null ? name : '$name, median ${(ms / 1000).round()} dtk';
  }
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.data,
    required this.starting,
    required this.onSkip,
    required this.onStart,
    required this.onResume,
    required this.onHome,
    required this.onEditProfile,
  });

  final DiagnosticData data;
  final bool starting;
  final VoidCallback onSkip;
  final VoidCallback onStart;
  final VoidCallback onResume;
  final VoidCallback onHome;
  final VoidCallback onEditProfile;

  @override
  Widget build(BuildContext context) {
    final Widget secondary;
    final Widget primary;
    if (!data.canStart && data.unfinishedId == null) {
      secondary = AppButton(
        label: 'Ke beranda',
        variant: AppButtonVariant.secondary,
        onPressed: onHome,
      );
      primary = AppButton(label: 'Ubah profil', onPressed: onEditProfile);
    } else if (data.unfinishedId != null) {
      secondary = AppButton(
        label: 'Lewati, nanti saja',
        variant: AppButtonVariant.secondary,
        onPressed: onSkip,
      );
      primary = AppButton(label: 'Lanjutkan diagnostik', onPressed: onResume);
    } else if (data.result != null) {
      secondary = AppButton(
        label: 'Ulangi diagnostik',
        variant: AppButtonVariant.secondary,
        onPressed: starting ? null : onStart,
      );
      primary = AppButton(label: 'Ke beranda', onPressed: onHome);
    } else {
      secondary = AppButton(
        label: 'Lewati, nanti saja',
        variant: AppButtonVariant.secondary,
        onPressed: onSkip,
      );
      primary = AppButton(
        label: 'Mulai diagnostik',
        onPressed: starting ? null : onStart,
      );
    }
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: 10, child: secondary),
          const SizedBox(width: AppSpace.s8),
          Expanded(flex: 13, child: primary),
        ],
      ),
    );
  }
}
