import 'dart:async';

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
import '../../core/widgets/quadrant_grid.dart';
import '../../core/widgets/score_bar.dart';
import '../../core/widgets/skeleton_list.dart';
import '../../core/widgets/status_tag.dart';
import '../../domain/models/codes.dart';
import '../../domain/services/profile_templates.dart';
import '../../domain/services/scoring.dart';
import '../onboarding/onboarding_frame.dart';
import 'review_provider.dart';

String modeName(SessionMode mode) => switch (mode) {
      SessionMode.latihan => 'Latihan',
      SessionMode.simulasi => 'Simulasi',
      SessionMode.diagnostik => 'Diagnostik',
    };

/// S08 Hasil sesi (F06): skor, akurasi dan median per kategori, kecepatan
/// lawan ketepatan, dan jumlah soal salah yang masuk buku kesalahan.
class ResultScreen extends ConsumerWidget {
  const ResultScreen({super.key, required this.sessionId});

  final int sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void toHome() => context.go(Routes.beranda);
    final header = AppTopBar(
      title: 'Hasil sesi',
      onBack: () => context.canPop() ? context.pop() : toHome(),
    );
    final skip = AppButton(
      label: 'Beranda',
      variant: AppButtonVariant.secondary,
      onPressed: toHome,
    );

    return ref.watch(sessionReviewProvider(sessionId)).when(
          loading: () => OnboardingFrame(
            header: header,
            footer: skip,
            children: const [
              SkeletonList(rows: 5, semanticLabel: 'Memuat hasil sesi'),
            ],
          ),
          error: (_, __) => OnboardingFrame(
            header: header,
            footer: skip,
            children: [
              ErrorView(
                title: 'Hasil sesi tidak bisa dibuka',
                message: 'Data sesi gagal dibaca. Ketuk coba lagi, atau '
                    'kembali ke beranda. Jawabanmu tidak hilang.',
                onRetry: () => ref.invalidate(sessionReviewProvider(sessionId)),
              ),
            ],
          ),
          data: (review) {
            if (review == null) {
              return OnboardingFrame(
                header: header,
                footer: skip,
                children: [
                  EmptyView(
                    title: 'Hasil sesi tidak ditemukan',
                    message: 'Sesi ini sudah dihapus atau tidak pernah ada.',
                    actionLabel: 'Ke beranda',
                    onAction: toHome,
                  ),
                ],
              );
            }
            if (!review.finished) {
              return OnboardingFrame(
                header: header,
                footer: skip,
                children: [
                  EmptyView(
                    title: 'Sesi belum selesai',
                    message: 'Hasilnya muncul setelah sesi selesai.',
                    actionLabel: 'Lanjutkan sesi',
                    onAction: () =>
                        unawaited(context.push(Routes.sesiPath(sessionId))),
                  ),
                ],
              );
            }
            return OnboardingFrame(
              header: header,
              footer: FooterButtons(
                flex: const [10, 13],
                buttons: [
                  skip,
                  AppButton(
                    label: 'Lihat pembahasan',
                    onPressed: () => unawaited(context.push(
                      Routes.pembahasanPath(sessionId, review.firstWrong + 1),
                    )),
                  ),
                ],
              ),
              children: _body(context, review),
            );
          },
        );
  }

  List<Widget> _body(BuildContext context, SessionReview r) {
    final c = context.tokens.colors;
    final s = r.summary;
    final cats = s.perKategori.values.toList();
    final marked =
        cats.length > 1 && {for (final k in cats) k.akurasi.round()}.length > 1;
    var weakest = cats.first;
    for (final k in cats) {
      if (k.akurasi < weakest.akurasi) weakest = k;
    }
    final previous = r.previousScore;
    final since = previous == null
        ? 'Belum ada sesi ${modeName(r.session.mode).toLowerCase()} '
            'sebelumnya, durasi ${formatClock(r.duration)}'
        : 'Sesi lalu ${previous.round()}%, durasi ${formatClock(r.duration)}';
    final wrong = r.wrongCount;

    QuadrantCell cell(String title, SpeedLabel l, bool ok, [String? note]) =>
        QuadrantCell(
          title: title,
          count: s.kuadran[l] ?? 0,
          correct: ok,
          note: note,
        );

    return [
      ScreenPadding(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Semantics(
              label: 'Skor ${s.skor.round()} persen',
              excludeSemantics: true,
              child: Text('${s.skor.round()}%', style: AppType.display(c.ink)),
            ),
            const SizedBox(width: AppSpace.s16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r.profile?.nama ?? 'Profil dihapus',
                    style: AppType.body(c.ink)
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: AppSpace.s4),
                  Wrap(
                    spacing: AppSpace.s8,
                    runSpacing: AppSpace.s4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      StatusTag(label: modeName(r.session.mode)),
                      Text(since, style: AppType.label(c.inkMuted)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: AppSpace.s24),
      ScreenPadding(
        child: Semantics(
          header: true,
          child: Text('Per kategori', style: AppType.title(c.ink)),
        ),
      ),
      const SizedBox(height: AppSpace.s12),
      ScreenPadding(
        child: Column(
          children: [
            for (var i = 0; i < cats.length; i++) ...[
              if (i > 0) const SizedBox(height: AppSpace.s12),
              ScoreBar(
                label: _label(cats[i]),
                value: (cats[i].akurasi / 100).clamp(0.0, 1.0),
                valueLabel: '${cats[i].akurasi.round()}%',
                weakest: marked && cats[i].kategori == weakest.kategori,
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: AppSpace.s24),
      ScreenPadding(
        child: Semantics(
          header: true,
          child: Text('Kecepatan vs ketepatan', style: AppType.title(c.ink)),
        ),
      ),
      const SizedBox(height: AppSpace.s12),
      ScreenPadding(
        child: QuadrantGrid(cells: [
          cell('Benar dan cepat', SpeedLabel.benarCepat, true),
          cell('Benar tapi lambat', SpeedLabel.benarLambat, true),
          cell('Salah dan cepat', SpeedLabel.salahCepat, false, 'Terburu-buru'),
          cell('Salah dan lambat', SpeedLabel.salahLambat, false,
              'Belum paham pola'),
        ]),
      ),
      const SizedBox(height: AppSpace.s16),
      ScreenPadding(
        child: NoteBox(
          icon: AppIcons.book,
          text: wrong > 0
              ? '$wrong soal salah masuk buku kesalahan dan dijadwalkan ulang '
                  'besok.'
              : 'Tidak ada soal salah. Buku kesalahan tidak berubah.',
        ),
      ),
      if (s.tidakDijawab > 0)
        ScreenPadding(
          top: AppSpace.s8,
          child: Text(
            'Tidak dijawab: ${s.tidakDijawab} soal. Dihitung salah pada skor, '
            'tidak masuk buku kesalahan.',
            style: AppType.label(c.inkMuted),
          ),
        ),
    ];
  }

  static String _label(CategoryScore k) {
    final name = ProfileTemplates.categoryName(k.kategori);
    final ms = k.medianMs;
    return ms == null ? name : '$name, median ${secondsOf(ms)} dtk';
  }
}
