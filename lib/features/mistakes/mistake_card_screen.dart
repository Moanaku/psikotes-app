import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/time_format.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_top_bar.dart';
import '../../core/widgets/empty_view.dart';
import '../../core/widgets/error_view.dart';
import '../../core/widgets/note_box.dart';
import '../../core/widgets/skeleton_list.dart';
import '../../domain/models/codes.dart';
import '../../domain/models/notebook.dart';
import '../../domain/models/question_guides.dart';
import '../../domain/providers.dart';
import '../../domain/services/mistake_book.dart';
import '../../domain/services/sm2_scheduler.dart';
import '../onboarding/onboarding_frame.dart';
import '../review/review_screen.dart';
import '../session/session_widgets.dart';
import 'mistake_book_screen.dart';
import 'mistake_provider.dart';

/// Pembahasan satu kartu dari baris S10: soal asal dibuat ulang dari (tipe,
/// seed), lengkap dengan kunci, penjelasan, dan jadwal ulang berikutnya.
class MistakeCardScreen extends ConsumerWidget {
  const MistakeCardScreen({super.key, required this.cardId});

  final int cardId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void back() =>
        context.canPop() ? context.pop() : context.go(Routes.bukuKesalahan);
    final header = AppTopBar(title: 'Kartu kesalahan', onBack: back);
    final toBook = AppButton(
      label: 'Kembali ke buku kesalahan',
      variant: AppButtonVariant.secondary,
      onPressed: back,
    );

    return ref.watch(cardReviewProvider(cardId)).when(
          loading: () => OnboardingFrame(
            header: header,
            footer: toBook,
            children: const [
              SkeletonList(rows: 5, semanticLabel: 'Memuat kartu'),
            ],
          ),
          error: (_, __) => OnboardingFrame(
            header: header,
            footer: toBook,
            children: [
              ErrorView(
                title: 'Kartu tidak bisa dibuka',
                message: 'Data kartu gagal dibaca. Ketuk coba lagi, atau '
                    'kembali ke buku kesalahan.',
                onRetry: () => ref.invalidate(cardReviewProvider(cardId)),
              ),
            ],
          ),
          data: (review) {
            if (review == null) {
              return OnboardingFrame(
                header: header,
                footer: toBook,
                children: [
                  EmptyView(
                    title: 'Kartu tidak ditemukan',
                    message: 'Kartu ini sudah dihapus dari buku kesalahan.',
                    actionLabel: 'Kembali ke buku kesalahan',
                    onAction: back,
                  ),
                ],
              );
            }
            return OnboardingFrame(
              header: header,
              footer: toBook,
              children: _body(context, ref, review),
            );
          },
        );
  }

  List<Widget> _body(BuildContext context, WidgetRef ref, CardReview r) {
    final c = context.tokens.colors;
    final card = r.card;
    final q = r.question;
    final type = r.type;
    return [
      Padding(
        padding: sessionMargin,
        child: Row(
          children: [
            Expanded(
              child: Text(
                '${cardName(card)}, ${sourceName(card.sumber).toLowerCase()}',
                style: AppType.label(c.inkMuted),
              ),
            ),
            const SizedBox(width: AppSpace.s12),
            MasteryDots(count: card.streakBenar.clamp(0, 3)),
          ],
        ),
      ),
      const SizedBox(height: AppSpace.s8),
      if (q == null)
        const Padding(
          padding: sessionMargin,
          child: NoteBox(
            icon: AppIcons.alert,
            text: 'Soal ini belum bisa dibuka dari buku kesalahan. Jadwal '
                'ulangnya tetap berjalan.',
          ),
        )
      else ...[
        QuestionBody(question: q, selected: null, onSelect: null),
        const SizedBox(height: AppSpace.s16),
        Padding(
          padding: sessionMargin,
          child: ReviewAnswerBlock(
            ok: true,
            title: 'Kunci',
            caption: 'Jawaban benar',
            question: q,
            index: q.correctIndex,
          ),
        ),
        const SizedBox(height: AppSpace.s24),
        ReviewSection(title: 'Kenapa', text: q.explanation),
        if (type != null) ...[
          const SizedBox(height: AppSpace.s24),
          ReviewSection(title: 'Pola dan trik', text: questionTypeTrick(type)),
        ],
      ],
      const SizedBox(height: AppSpace.s24),
      Padding(
        padding: sessionMargin,
        child: NoteBox(
          icon: AppIcons.clock,
          text: _schedule(ref, card),
        ),
      ),
    ];
  }

  /// Kalimat jadwal: kapan kartu muncul lagi, atau bahwa ia sudah dikuasai.
  String _schedule(WidgetRef ref, MistakeCard card) {
    final now = ref.read(clockProvider).now();
    final mastered = '${card.streakBenar.clamp(0, Sm2Scheduler.masteredStreak)}'
        ' dari ${Sm2Scheduler.masteredStreak}';
    if (card.status == CardStatus.dikuasai && !card.awaitsRecheck) {
      return 'Dikuasai. Kartu ini tidak muncul lagi.';
    }
    final due = !card.jatuhTempo.isAfter(DueDay.cutoff(now));
    final when = due ? 'hari ini' : formatDay(card.jatuhTempo);
    final prefix = card.awaitsRecheck
        ? 'Dikuasai. Pemeriksaan ulang'
        : 'Dikuasai $mastered kali. Muncul lagi';
    return '$prefix $when.';
  }
}
