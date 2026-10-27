import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_chip.dart';
import '../../core/widgets/app_top_bar.dart';
import '../../core/widgets/empty_view.dart';
import '../../core/widgets/error_view.dart';
import '../../core/widgets/note_box.dart';
import '../../core/widgets/score_bar.dart';
import '../../core/widgets/skeleton_list.dart';
import '../../core/theme/app_icons.dart';
import '../../domain/models/codes.dart';
import '../../domain/models/knowledge.dart';
import '../../domain/providers.dart';
import '../../domain/services/knowledge_bank.dart';
import '../../domain/services/knowledge_service.dart';
import '../../domain/services/mistake_book.dart';
import 'knowledge_providers.dart';

const EdgeInsets _margin = EdgeInsets.symmetric(horizontal: AppSpace.s16);

/// Role profil aktif sebagai role bank; role lain memakai Umum.
KnowledgeRole roleOfProfile(ProfileRole role) =>
    KnowledgeRole.fromCode(role.code) ?? KnowledgeRole.umum;

/// S19 Bank pengetahuan role (F17): memilih role, topik, dan level, lalu
/// memulai sesi kartu (S20).
class KnowledgeScreen extends ConsumerStatefulWidget {
  const KnowledgeScreen({super.key, this.initialRole});

  /// Role yang dipilih dari katalog; null memakai role profil aktif.
  final KnowledgeRole? initialRole;

  @override
  ConsumerState<KnowledgeScreen> createState() => _KnowledgeScreenState();
}

class _KnowledgeScreenState extends ConsumerState<KnowledgeScreen> {
  KnowledgeRole? _role;
  String? _topik;
  bool _starting = false;
  String? _note;

  KnowledgeRole _currentRole() {
    final chosen = _role ?? widget.initialRole;
    if (chosen != null) return chosen;
    final profile = ref.watch(activeProfileProvider).valueOrNull;
    return profile == null ? KnowledgeRole.qa : roleOfProfile(profile.role);
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.psikotes);
    }
  }

  Future<void> _start(
    KnowledgeBank bank,
    Map<String, KnowledgeProgress> progress,
    KnowledgeRole role,
    KnowledgeLevel level,
  ) async {
    if (_starting) return;
    setState(() {
      _starting = true;
      _note = null;
    });
    try {
      final now = ref.read(clockProvider).now();
      final due = await ref
          .read(mistakeRepositoryProvider)
          .watchDue(DueDay.cutoff(now))
          .first;
      final items = KnowledgeSelector.pick(
        bank,
        role: role,
        level: level,
        topik: _topik,
        progress: progress,
        dueIds: KnowledgeService.dueIds(bank, due),
      );
      if (!mounted) return;
      if (items.isEmpty) {
        setState(() {
          _starting = false;
          _note = role == KnowledgeRole.umum
              ? 'Semua kartu level ${level.label} sudah kamu kuasai.'
              : 'Belum ada kartu untuk pilihan ini. Pilih level atau topik '
                  'lain.';
        });
        return;
      }
      final id = ref
          .read(knowledgeSessionsProvider.notifier)
          .start(role: role, level: level, items: items);
      setState(() => _starting = false);
      unawaited(context.push(Routes.pengetahuanSesiPath(id)));
    } catch (_) {
      if (mounted) {
        setState(() {
          _starting = false;
          _note = 'Sesi belum dimulai. Data di perangkat gagal dibaca. Ketuk '
              'sekali lagi.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bank = ref.watch(knowledgeBankProvider);
    final progress = ref.watch(knowledgeProgressProvider);
    final header = AppTopBar(title: 'Pengetahuan role', onBack: _back);

    Widget frame(Widget child) => Column(
          children: [
            header,
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: AppSpace.s16),
                child: child,
              ),
            ),
          ],
        );

    Widget failed() => frame(ErrorView(
          title: 'Bank pengetahuan tidak terbaca',
          message: 'Berkas bank di app rusak atau tidak ada. Ketuk coba lagi, '
              'atau buka ulang app.',
          onRetry: () {
            ref.invalidate(knowledgeBankProvider);
            ref.invalidate(knowledgeProgressProvider);
          },
        ));

    return bank.when(
      loading: () => frame(const SkeletonList(
        rows: 5,
        semanticLabel: 'Memuat bank pengetahuan',
      )),
      error: (_, __) => failed(),
      data: (state) {
        final loaded = state.bank;
        if (loaded == null) return failed();
        if (loaded.isEmpty) {
          return frame(const EmptyView(
            title: 'Belum ada kartu pengetahuan',
            message: 'Isi bank sedang disiapkan. Kartu muncul di sini setelah '
                'bank terpasang di app.',
          ));
        }
        return progress.when(
          loading: () => frame(const SkeletonList(
            rows: 5,
            semanticLabel: 'Memuat kemajuan',
          )),
          error: (_, __) => frame(ErrorView(
            title: 'Kemajuanmu tidak terbaca',
            message: 'Data di perangkat gagal dibaca. Ketuk coba lagi. '
                'Kemajuanmu tidak hilang.',
            onRetry: () => ref.invalidate(knowledgeProgressProvider),
          )),
          data: (done) => frame(_content(loaded, done)),
        );
      },
    );
  }

  Widget _content(KnowledgeBank bank, Map<String, KnowledgeProgress> done) {
    final c = context.tokens.colors;
    final role = _currentRole();
    final topics = <String>{
      for (final l in KnowledgeLevel.values) ...bank.topics(role, l),
    }.toList()
      ..sort();
    final tallies = {
      for (final l in KnowledgeLevel.values)
        l: KnowledgeSelector.tally(
          bank,
          role: role,
          level: l,
          topik: _topik,
          progress: done,
        ),
    };
    final nothingInRole = topics.isEmpty;
    final nothingForTopic =
        !nothingInRole && tallies.values.every((t) => t.total == 0);
    // Level pertama yang belum selesai; bila semua selesai, yang pertama ada.
    final next = KnowledgeLevel.values.firstWhere(
      (l) => tallies[l]!.total > 0 && tallies[l]!.mastered < tallies[l]!.total,
      orElse: () => KnowledgeLevel.values.firstWhere(
        (l) => tallies[l]!.total > 0,
        orElse: () => KnowledgeLevel.dasar,
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: _margin,
          child: Wrap(
            spacing: AppSpace.s8,
            runSpacing: AppSpace.s8,
            children: [
              for (final r in KnowledgeRole.values)
                AppChip(
                  label: r.label,
                  selected: r == role,
                  onTap: () => setState(() {
                    _role = r;
                    _topik = null;
                    _note = null;
                  }),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpace.s16),
        Padding(
          padding: _margin,
          child: Text(
            role == KnowledgeRole.umum
                ? 'Pertanyaan dari semua role, tanpa butir yang sudah kamu '
                    'kuasai. Jawab dengan kata-katamu, lalu bandingkan dengan '
                    'jawaban model.'
                : 'Pertanyaan seputar ${role.label} dari dasar sampai lanjut. '
                    'Jawab dengan kata-katamu, lalu bandingkan dengan '
                    'jawaban model.',
            style: AppType.body(c.inkMuted),
          ),
        ),
        if (nothingInRole)
          const EmptyView(
            title: 'Belum ada kartu untuk role ini',
            message: 'Bank untuk role ini sedang disiapkan. Pilih role lain.',
          )
        else ...[
          const SizedBox(height: AppSpace.s24),
          Padding(
            padding: _margin,
            child: Semantics(
              header: true,
              child: Text('Topik', style: AppType.title(c.ink)),
            ),
          ),
          const SizedBox(height: AppSpace.s8),
          Padding(
            padding: _margin,
            child: Wrap(
              spacing: AppSpace.s8,
              runSpacing: AppSpace.s8,
              children: [
                AppChip(
                  label: 'Semua topik',
                  selected: _topik == null,
                  onTap: () => setState(() {
                    _topik = null;
                    _note = null;
                  }),
                ),
                for (final t in topics)
                  AppChip(
                    label: KnowledgeItem.topicLabel(t),
                    selected: _topik == t,
                    onTap: () => setState(() {
                      _topik = t;
                      _note = null;
                    }),
                  ),
              ],
            ),
          ),
          if (nothingForTopic)
            EmptyView(
              title: 'Belum ada kartu untuk topik ini',
              message: 'Belum ada kartu untuk topik ini. Pilih topik lain.',
              actionLabel: 'Tampilkan semua topik',
              onAction: () => setState(() => _topik = null),
            )
          else ...[
            const SizedBox(height: AppSpace.s24),
            Padding(
              padding: _margin,
              child: Semantics(
                header: true,
                child: Text('Level', style: AppType.title(c.ink)),
              ),
            ),
            const SizedBox(height: AppSpace.s4),
            for (final l in KnowledgeLevel.values)
              _LevelRow(
                level: l,
                total: tallies[l]!.total,
                mastered: tallies[l]!.mastered,
                onTap: tallies[l]!.total == 0 || _starting
                    ? null
                    : () => _start(bank, done, role, l),
              ),
            if (_note != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.s16,
                  AppSpace.s12,
                  AppSpace.s16,
                  0,
                ),
                child: Semantics(
                  liveRegion: true,
                  child: NoteBox(icon: AppIcons.alert, text: _note!),
                ),
              ),
            const SizedBox(height: AppSpace.s16),
            Padding(
              padding: _margin,
              child: AppButton(
                label: 'Latihan ${KnowledgeSelector.sessionSize} kartu',
                onPressed:
                    _starting ? null : () => _start(bank, done, role, next),
              ),
            ),
          ],
        ],
      ],
    );
  }
}

/// Baris level: nama, bilah, dan "n dari N". Ketuk memulai sesi level itu.
class _LevelRow extends StatelessWidget {
  const _LevelRow({
    required this.level,
    required this.total,
    required this.mastered,
    required this.onTap,
  });

  final KnowledgeLevel level;
  final int total;
  final int mastered;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.tokens.colors;
    final bar = ScoreBar(
      label: level.label,
      value: total == 0 ? 0 : mastered / total,
      valueLabel: '$mastered dari $total',
    );
    final content = DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.outlineVariant)),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppSpace.s48),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.s16,
            vertical: AppSpace.s12,
          ),
          child: Row(
            children: [
              Expanded(child: bar),
              if (onTap != null) ...[
                const SizedBox(width: AppSpace.s12),
                Icon(AppIcons.next, size: AppSizes.iconBase, color: c.inkMuted),
              ],
            ],
          ),
        ),
      ),
    );
    if (onTap == null) return content;
    return Semantics(
      button: true,
      hint: 'Mulai sesi kartu level ${level.label}',
      child: InkWell(onTap: onTap, child: content),
    );
  }
}
