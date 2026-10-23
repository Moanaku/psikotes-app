import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:question_engine/question_engine.dart';

import '../../app/routes.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/time_format.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_chip.dart';
import '../../core/widgets/app_top_bar.dart';
import '../../core/widgets/empty_view.dart';
import '../../core/widgets/error_view.dart';
import '../../core/widgets/list_row.dart';
import '../../core/widgets/note_box.dart';
import '../../core/widgets/skeleton_list.dart';
import '../../core/widgets/stat_row.dart';
import '../../core/widgets/status_tag.dart';
import '../../domain/models/catalog.dart';
import '../../domain/models/codes.dart';
import '../../domain/models/notebook.dart';
import '../../domain/providers.dart';
import '../../domain/services/mistake_book.dart';
import '../../domain/services/review_planner.dart';
import '../../domain/services/sm2_scheduler.dart';
import '../session/session_launcher.dart';
import 'mistake_provider.dart';

/// Nama kartu di daftar: nama tipe soal, atau kategori buatan pengguna untuk
/// kartu Capture.
String cardName(MistakeCard card) {
  if (card.sumber == AnswerSource.capture) return card.kategori;
  try {
    return questionTypeName(QuestionType.fromCode(card.tipe));
  } catch (_) {
    return card.tipe;
  }
}

/// S10 Buku kesalahan (F07): kartu yang jatuh tempo, penguasaan, dan jalan
/// masuk ke ulangan.
class MistakeBookScreen extends ConsumerStatefulWidget {
  const MistakeBookScreen({super.key});

  @override
  ConsumerState<MistakeBookScreen> createState() => _MistakeBookScreenState();
}

class _MistakeBookScreenState extends ConsumerState<MistakeBookScreen> {
  bool _starting = false;
  String? _startError;

  void _back() => context.canPop() ? context.pop() : context.go(Routes.beranda);

  Future<void> _repeat() async {
    final profile = ref.read(activeProfileProvider).valueOrNull;
    if (profile == null || _starting) return;
    setState(() {
      _starting = true;
      _startError = null;
    });
    try {
      final now = ref.read(clockProvider).now();
      final due = await ref
          .read(mistakeRepositoryProvider)
          .watchDue(DueDay.cutoff(now))
          .first;
      final answers = ref.read(answerRepositoryProvider);
      final difficulties = <int, Difficulty>{};
      for (final c in due.take(ReviewPlanner.maxCards)) {
        final seed = c.seed;
        if (c.sumber != AnswerSource.engine || seed == null) continue;
        final origin = await answers.latestEngineAnswer(c.tipe, seed);
        if (origin != null) difficulties[c.id] = origin.kesulitan;
      }
      final review = ReviewPlanner.build(
        due,
        now: now,
        available: ref.read(availableTypesProvider),
        avoid: await recentSeenKeys(ref),
        difficulty: (c) => difficulties[c.id] ?? Difficulty.medium,
      );
      if (!mounted) return;
      if (review.plan.items.isEmpty) {
        setState(() {
          _starting = false;
          _startError = 'Kartu yang jatuh tempo belum bisa diulang di sini. '
              'Soal bank dan pengetahuan belum bisa dikerjakan dari buku '
              'kesalahan.';
        });
        return;
      }
      final id = await launchSession(
        ref,
        profileId: profile.id!,
        mode: SessionMode.latihan,
        plan: review.plan,
      );
      if (!mounted) return;
      setState(() => _starting = false);
      unawaited(context.push(Routes.sesiPath(id)));
    } catch (_) {
      if (mounted) {
        setState(() {
          _starting = false;
          _startError = 'Ulangan belum dimulai. Data di perangkat gagal '
              'dibaca. Ketuk sekali lagi.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final book = ref.watch(mistakeBookProvider);
    final filter = ref.watch(mistakeFilterProvider);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            AppTopBar(title: 'Buku kesalahan', onBack: _back),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: AppSpace.s16),
                child: book.when(
                  loading: () => const SkeletonList(
                    rows: 6,
                    semanticLabel: 'Memuat buku kesalahan',
                  ),
                  error: (_, __) => ErrorView(
                    title: 'Buku kesalahan tidak bisa dibuka',
                    message: 'Data kartu gagal dibaca. Ketuk coba lagi. '
                        'Kartumu tidak hilang.',
                    onRetry: () => ref.invalidate(mistakeCardsProvider),
                  ),
                  data: (view) => _content(context, view, filter),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _content(
    BuildContext context,
    MistakeBookView view,
    MistakeFilter filter,
  ) {
    final c = context.tokens.colors;
    if (view.totalCards == 0) {
      return EmptyView(
        title: 'Buku kesalahan masih kosong',
        message: 'Soal yang salah akan masuk ke sini dan muncul lagi '
            'beberapa hari kemudian.',
        actionLabel: 'Mulai latihan',
        onAction: () => context.go(Routes.psikotes),
      );
    }
    final next = view.nextDue;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.s16),
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.symmetric(
                horizontal: BorderSide(color: c.outlineVariant),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpace.s12),
              child: StatRow(items: [
                StatItem(
                  value: '${view.dueCount}',
                  label: 'jatuh tempo hari ini',
                ),
                StatItem(
                  value: '${view.masteredCount}',
                  label: 'sudah dikuasai',
                ),
              ]),
            ),
          ),
        ),
        const SizedBox(height: AppSpace.s16),
        if (view.dueCount > 0)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.s16),
            child: AppButton(
              label: 'Ulangi yang jatuh tempo',
              onPressed: _starting ? null : () => unawaited(_repeat()),
            ),
          )
        else
          EmptyView(
            title: 'Tidak ada kartu jatuh tempo hari ini',
            message: next == null
                ? 'Semua kartu sudah dikuasai. Kartu baru muncul bila ada '
                    'soal yang salah.'
                : 'Kartu berikutnya muncul ${formatDay(next)}.',
          ),
        if (_startError != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.s16,
              AppSpace.s12,
              AppSpace.s16,
              0,
            ),
            child: Semantics(
              liveRegion: true,
              child: NoteBox(icon: AppIcons.alert, text: _startError!),
            ),
          ),
        const SizedBox(height: AppSpace.s8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.s16),
          child: Semantics(
            container: true,
            label: 'Filter sumber',
            child: Wrap(
              spacing: AppSpace.s8,
              children: [
                for (final f in MistakeFilter.values)
                  AppChip(
                    label: f.label,
                    selected: f == filter,
                    onTap: () =>
                        ref.read(mistakeFilterProvider.notifier).state = f,
                  ),
              ],
            ),
          ),
        ),
        if (view.rows.isEmpty)
          filter != MistakeFilter.semua
              ? EmptyView(
                  title: 'Tidak ada kartu ${filter.label} yang jatuh tempo.',
                  message: 'Kartu dari sumber lain tetap ada di Semua.',
                  actionLabel: 'Tampilkan semua',
                  onAction: () => ref
                      .read(mistakeFilterProvider.notifier)
                      .state = MistakeFilter.semua,
                )
              : const SizedBox.shrink()
        else
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: c.outlineVariant)),
            ),
            child: Column(
              children: [
                for (final row in view.rows) _CardRow(row: row),
              ],
            ),
          ),
      ],
    );
  }
}

class _CardRow extends StatelessWidget {
  const _CardRow({required this.row});

  final MistakeRow row;

  String get _dueLabel =>
      row.daysUntil == 1 ? 'Besok' : '${row.daysUntil} hari lagi';

  @override
  Widget build(BuildContext context) {
    final c = context.tokens.colors;
    final card = row.card;
    final source = sourceName(card.sumber);
    return Semantics(
      container: true,
      child: ListRow(
        title: cardName(card),
        subtitle: row.recheck ? '$source, pemeriksaan ulang' : source,
        onTap: () => unawaited(
          context.push(Routes.kartuKesalahanPath(card.id)),
        ),
        trailing: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (row.due)
              const StatusTag(label: 'Hari ini', kind: StatusTagKind.attention)
            else
              Text(
                _dueLabel,
                style:
                    AppType.label(c.ink).copyWith(fontWeight: FontWeight.w600),
              ),
            const SizedBox(height: AppSpace.s8),
            MasteryDots(count: row.mastery),
          ],
        ),
      ),
    );
  }
}

/// Tiga titik penguasaan: terisi `ink` untuk tiap jawaban benar berturut-turut.
/// Perakitan token (A81); jumlahnya juga dibaca pembaca layar.
class MasteryDots extends StatelessWidget {
  const MasteryDots({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final c = context.tokens.colors;
    const total = Sm2Scheduler.masteredStreak;
    return Semantics(
      label: 'Dikuasai $count dari $total kali',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < total; i++) ...[
            if (i > 0) const SizedBox(width: AppSpace.s4),
            Container(
              width: AppSpace.s12,
              height: AppSpace.s12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < count ? c.ink : Colors.transparent,
                border: Border.all(color: i < count ? c.ink : c.outline),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
