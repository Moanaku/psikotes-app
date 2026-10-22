import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:question_engine/question_engine.dart';

import '../../app/routes.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_top_bar.dart';
import '../../core/widgets/empty_view.dart';
import '../../core/widgets/error_view.dart';
import '../../core/widgets/list_row.dart';
import '../../core/widgets/note_box.dart';
import '../../core/widgets/segmented_control.dart';
import '../../core/widgets/skeleton_list.dart';
import '../../core/widgets/status_tag.dart';
import '../../domain/models/codes.dart';
import '../../domain/models/profile.dart';
import '../../domain/models/session.dart';
import '../../domain/providers.dart';
import '../../domain/services/profile_templates.dart';
import '../../domain/services/session_plan_builder.dart';
import '../session/session_launcher.dart';
import 'catalog_entries.dart';

enum CatalogMode { latihan, simulasi }

/// Mode terpilih bertahan saat pindah tab.
final catalogModeProvider = StateProvider<CatalogMode>(
  (ref) => CatalogMode.latihan,
);

/// S05 Katalog psikotes (F04): memilih tipe soal untuk latihan, atau memulai
/// simulasi penuh dari profil aktif.
class CatalogScreen extends ConsumerStatefulWidget {
  const CatalogScreen({super.key});

  @override
  ConsumerState<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends ConsumerState<CatalogScreen> {
  bool _starting = false;
  String? _startError;

  Future<void> _launch({
    required TestProfile profile,
    required SessionMode mode,
    required SessionPlanFactory build,
  }) async {
    if (_starting) return;
    setState(() {
      _starting = true;
      _startError = null;
    });
    try {
      final plan = build();
      if (plan == null) {
        setState(() {
          _starting = false;
          _startError = 'Simulasi belum bisa disusun. Subtes di profilmu '
              'belum punya soal. Nyalakan Numerik, Logika, atau Figural di '
              'profil.';
        });
        return;
      }
      final id = await launchSession(
        ref,
        profileId: profile.id!,
        mode: mode,
        plan: plan,
      );
      if (!mounted) return;
      setState(() => _starting = false);
      unawaited(context.push(Routes.sesiPath(id)));
    } catch (_) {
      if (mounted) {
        setState(() {
          _starting = false;
          _startError = 'Sesi belum dimulai. Data di perangkat gagal '
              'ditulis. Ketuk sekali lagi.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(catalogModeProvider);
    final available = ref.watch(availableTypesProvider);
    final profile = ref.watch(activeProfileProvider);
    final active = profile.valueOrNull;
    final clock = ref.watch(clockProvider);

    return Column(
      children: [
        const AppTopBar(title: 'Psikotes'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.s16),
          child: SegmentedControl(
            options: const ['Latihan', 'Simulasi'],
            selectedIndex: mode.index,
            onChanged: (i) => ref.read(catalogModeProvider.notifier).state =
                CatalogMode.values[i],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: AppSpace.s16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_startError != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpace.s16,
                      AppSpace.s16,
                      AppSpace.s16,
                      0,
                    ),
                    child: Semantics(
                      liveRegion: true,
                      child: NoteBox(
                        icon: AppIcons.alert,
                        text: _startError!,
                      ),
                    ),
                  ),
                if (mode == CatalogMode.latihan) ...[
                  for (final g in catalogGroups)
                    _Group(
                      group: g,
                      available: available,
                      onOpen: (type) => active == null || _starting
                          ? null
                          : () => _launch(
                                profile: active,
                                mode: SessionMode.latihan,
                                build: () => SessionPlanBuilder.practice(
                                  type,
                                  now: clock.now(),
                                ),
                              ),
                    ),
                  const _PrivateBank(),
                ] else
                  _SimulationPreview(
                    profile: profile,
                    available: available,
                  ),
              ],
            ),
          ),
        ),
        _SimulationPanel(
          profile: profile,
          starting: _starting,
          onStart: (p) => _launch(
            profile: p,
            mode: SessionMode.simulasi,
            build: () => SessionPlanBuilder.simulation(
              p.blueprint,
              now: clock.now(),
              available: available,
            )?.plan,
          ),
        ),
      ],
    );
  }
}

/// Menyusun rencana sesi; null bila tidak ada yang bisa disusun.
typedef SessionPlanFactory = SessionPlan? Function();

class _Group extends StatelessWidget {
  const _Group({
    required this.group,
    required this.available,
    required this.onOpen,
  });

  final CatalogGroup group;
  final Set<QuestionType> available;

  /// Aksi membuka tipe [QuestionType]; null bila tidak bisa dibuka sekarang.
  final VoidCallback? Function(QuestionType type) onOpen;

  @override
  Widget build(BuildContext context) {
    final c = context.tokens.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpace.s24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.s16),
          child: Semantics(
            header: true,
            child: Text(group.title, style: AppType.title(c.ink)),
          ),
        ),
        const SizedBox(height: AppSpace.s4),
        for (final e in group.entries) _row(e),
      ],
    );
  }

  Widget _row(CatalogEntry e) {
    final why = CatalogAvailability.of(e, available);
    if (why != null) {
      return ListRow(
        title: e.label,
        subtitle: why.reason,
        trailing: StatusTag(label: why.tag),
      );
    }
    return ListRow(title: e.label, onTap: onOpen(e.type!));
  }
}

/// "Bank pribadi": soal hasil Capture. Kosong dibedakan dari galat dan memuat.
class _PrivateBank extends ConsumerWidget {
  const _PrivateBank();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.tokens.colors;
    final count = ref.watch(captureCountProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpace.s24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.s16),
          child: Semantics(
            header: true,
            child: Text('Bank pribadi', style: AppType.title(c.ink)),
          ),
        ),
        const SizedBox(height: AppSpace.s4),
        count.when(
          loading: () => const SkeletonList(
            rows: 1,
            semanticLabel: 'Memuat soal Capture',
          ),
          error: (_, __) => ErrorView(
            title: 'Soal Capture tidak bisa dibaca',
            message: 'Data Capture di perangkat gagal dibaca. Ketuk coba '
                'lagi.',
            onRetry: () => ref.invalidate(captureCountProvider),
          ),
          data: (n) => n == 0
              ? EmptyView(
                  title: 'Belum ada soal Capture',
                  message: 'Simpan soal dari tes asli lewat Capture soal.',
                  actionLabel: 'Buka Capture',
                  onAction: () => unawaited(context.push(Routes.capture)),
                )
              : ListRow(
                  title: 'Soal hasil Capture: $n',
                  subtitle: 'Latihan dari bank pribadi tersedia setelah '
                      'Capture selesai dibangun.',
                  trailing: const StatusTag(label: 'Segera'),
                ),
        ),
      ],
    );
  }
}

/// Mode Simulasi: ringkasan subtes profil aktif yang akan dikerjakan.
class _SimulationPreview extends ConsumerWidget {
  const _SimulationPreview({required this.profile, required this.available});

  final AsyncValue<TestProfile?> profile;
  final Set<QuestionType> available;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.tokens.colors;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.s24),
      child: profile.when(
        loading: () => const SkeletonList(
          rows: 4,
          semanticLabel: 'Memuat subtes profil',
        ),
        error: (_, __) => ErrorView(
          title: 'Profil tidak bisa dibaca',
          message: 'Data profil gagal dibaca. Ketuk coba lagi.',
          onRetry: () => ref.invalidate(profilesProvider),
        ),
        data: (p) {
          if (p == null) {
            return const SkeletonList(
              rows: 4,
              semanticLabel: 'Memuat subtes profil',
            );
          }
          final subtests = [
            for (final s in p.blueprint.subtes)
              if (s.aktif) s,
          ];
          final skipped = [
            for (final s in subtests)
              if (!_hasType(s.kategori)) s,
          ];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.s16),
                child: Semantics(
                  header: true,
                  child: Text(
                    'Subtes simulasi',
                    style: AppType.title(c.ink),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.s16,
                  AppSpace.s4,
                  AppSpace.s16,
                  AppSpace.s8,
                ),
                child: Text(
                  'Soal dan menit mengikuti subtes di profil "${p.nama}". '
                  'Waktu berjalan per subtes dan subtes yang sudah lewat '
                  'tidak bisa dibuka lagi.',
                  style: AppType.label(c.inkMuted),
                ),
              ),
              for (final s in subtests)
                ListRow(
                  title: ProfileTemplates.categoryName(s.kategori),
                  subtitle: '${s.jumlah} '
                      '${ProfileTemplates.countUnit(s.kategori)}, '
                      '${s.menit} menit',
                  trailing: _hasType(s.kategori)
                      ? null
                      : const StatusTag(label: 'Belum tersedia'),
                ),
              if (skipped.isNotEmpty)
                const Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppSpace.s16,
                    AppSpace.s12,
                    AppSpace.s16,
                    0,
                  ),
                  child: NoteBox(
                    text: 'Subtes yang belum tersedia dilewati saat simulasi '
                        'dimulai.',
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  bool _hasType(String kategori) => available.any(
        (t) => t.category.code == kategori && GeneratorRegistry.has(t),
      );
}

/// Panel bawah "Simulasi penuh" dengan profil aktif. Disusun dari token
/// seperti bilah aksi onboarding (A48).
class _SimulationPanel extends StatelessWidget {
  const _SimulationPanel({
    required this.profile,
    required this.starting,
    required this.onStart,
  });

  final AsyncValue<TestProfile?> profile;
  final bool starting;
  final void Function(TestProfile profile) onStart;

  @override
  Widget build(BuildContext context) {
    final c = context.tokens.colors;
    final p = profile.valueOrNull;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.outlineVariant)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.s16,
          AppSpace.s12,
          AppSpace.s16,
          AppSpace.s12,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Simulasi penuh',
              style: AppType.body(c.ink).copyWith(fontWeight: FontWeight.w600),
            ),
            if (p != null) Text(p.nama, style: AppType.label(c.inkMuted)),
            const SizedBox(height: AppSpace.s8),
            AppButton(
              label: 'Mulai simulasi',
              onPressed: p == null || starting ? null : () => onStart(p),
            ),
          ],
        ),
      ),
    );
  }
}
