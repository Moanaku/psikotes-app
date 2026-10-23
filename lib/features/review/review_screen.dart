import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:question_engine/question_engine.dart';

import '../../app/routes.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/text_scale.dart';
import '../../core/utils/time_format.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_top_bar.dart';
import '../../core/widgets/empty_view.dart';
import '../../core/widgets/error_view.dart';
import '../../core/widgets/figure_view.dart';
import '../../core/widgets/list_row.dart';
import '../../core/widgets/note_box.dart';
import '../../core/widgets/skeleton_list.dart';
import '../../core/widgets/status_tag.dart';
import '../../domain/models/codes.dart';
import '../../domain/models/question_guides.dart';
import '../../domain/providers.dart';
import '../../domain/services/profile_templates.dart';
import '../capture/capture_photo_view.dart';
import '../onboarding/onboarding_frame.dart';
import '../session/session_widgets.dart';
import 'review_provider.dart';

/// S09 Pembahasan soal (F06): jawabanmu, kunci, penjelasan, pola dan trik,
/// waktu, dan sakelar "Masuk buku kesalahan". [number] dimulai dari 1.
class ReviewScreen extends ConsumerStatefulWidget {
  const ReviewScreen(
      {super.key, required this.sessionId, required this.number});

  final int sessionId;
  final int number;

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  final ScrollController _scroll = ScrollController();
  bool _toggleFailed = false;
  bool _toggling = false;

  @override
  void didUpdateWidget(ReviewScreen old) {
    super.didUpdateWidget(old);
    if (old.number != widget.number) {
      _toggleFailed = false;
      if (_scroll.hasClients) _scroll.jumpTo(0);
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _goTo(int n) =>
      context.pushReplacement(Routes.pembahasanPath(widget.sessionId, n));

  void _back() => context.canPop()
      ? context.pop()
      : context.go(Routes.hasilPath(widget.sessionId));

  Future<void> _toggle(SessionReview review, int index, bool inBook) async {
    final answer = review.answers[index];
    if (answer == null || _toggling) return;
    setState(() {
      _toggling = true;
      _toggleFailed = false;
    });
    try {
      final repo = ref.read(mistakeRepositoryProvider);
      if (inBook) {
        final card = await repo.findFor(answer);
        if (card != null) await repo.delete(card.id);
      } else {
        await repo.upsertFromAnswer(
          answer,
          ref.read(clockProvider).now(),
          force: true,
        );
      }
      ref.invalidate(reviewCardProvider((widget.sessionId, index)));
      if (mounted) setState(() => _toggling = false);
    } catch (_) {
      if (mounted) {
        setState(() {
          _toggling = false;
          _toggleFailed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.sessionId;
    final reviewAsync = ref.watch(sessionReviewProvider(id));
    final header = AppTopBar(
      title: 'Pembahasan',
      onBack: _back,
      actions: [
        if (reviewAsync.valueOrNull != null && !isLargeText(context))
          Padding(
            padding: const EdgeInsets.only(right: AppSpace.s16),
            child: Center(
              child: Text(
                'Soal ${widget.number} dari ${reviewAsync.value!.total}',
                style: AppType.label(context.tokens.colors.inkMuted),
              ),
            ),
          ),
      ],
    );
    final toResult = AppButton(
      label: 'Kembali ke hasil',
      variant: AppButtonVariant.secondary,
      onPressed: _back,
    );

    return reviewAsync.when(
      loading: () => OnboardingFrame(
        header: header,
        footer: toResult,
        children: const [
          SkeletonList(rows: 5, semanticLabel: 'Memuat pembahasan'),
        ],
      ),
      error: (_, __) => OnboardingFrame(
        header: header,
        footer: toResult,
        children: [
          ErrorView(
            title: 'Pembahasan tidak bisa dibuka',
            message: 'Data sesi gagal dibaca. Ketuk coba lagi, atau kembali '
                'ke hasil.',
            onRetry: () => ref.invalidate(sessionReviewProvider(id)),
          ),
        ],
      ),
      data: (review) {
        final index = widget.number - 1;
        if (review == null || index < 0 || index >= review.total) {
          return OnboardingFrame(
            header: header,
            footer: toResult,
            children: [
              EmptyView(
                title: 'Soal tidak ditemukan',
                message: 'Nomor soal ini tidak ada di sesi tersebut.',
                actionLabel: 'Kembali ke hasil',
                onAction: _back,
              ),
            ],
          );
        }
        return OnboardingFrame(
          scrollController: _scroll,
          header: header,
          footer: FooterButtons(
            buttons: [
              AppButton(
                label: 'Sebelumnya',
                variant: AppButtonVariant.secondary,
                onPressed: index > 0 ? () => _goTo(widget.number - 1) : null,
              ),
              AppButton(
                label: 'Berikutnya',
                onPressed: index < review.total - 1
                    ? () => _goTo(widget.number + 1)
                    : null,
              ),
            ],
          ),
          children: _body(context, review, index),
        );
      },
    );
  }

  List<Widget> _body(BuildContext context, SessionReview review, int index) {
    final c = context.tokens.colors;
    final item = review.session.plan.items[index];
    final answer = review.answers[index];
    final q = review.questionAt(index);
    final skipped = answer == null || answer.opsiDipilih == null;
    final benar = answer?.benar ?? false;
    final card = ref.watch(reviewCardProvider((widget.sessionId, index)));
    final inBook = card.valueOrNull != null;
    final targetMs = review.thresholds.targetMs(
      item.tipeCode,
      q?.estimatedSeconds ?? 60,
    );

    return [
      _ReviewStrip(
        review: review,
        current: index,
        onTap: (i) => _goTo(i + 1),
      ),
      if (isLargeText(context)) ...[
        // Penghitung soal tidak muat di bilah atas pada skala huruf besar.
        const SizedBox(height: AppSpace.s8),
        Padding(
          padding: sessionMargin,
          child: Text(
            'Soal ${widget.number} dari ${review.total}',
            style: AppType.label(c.inkMuted),
          ),
        ),
      ],
      const SizedBox(height: AppSpace.s16),
      Padding(
        padding: sessionMargin,
        child: Text(
          item.isCapture
              ? 'Capture, ${item.kategoriCode}'
              : '${ProfileTemplates.categoryName(item.kategoriCode)}, '
                  '${planItemName(item).toLowerCase()}',
          style: AppType.label(c.inkMuted),
        ),
      ),
      const SizedBox(height: AppSpace.s8),
      if (q == null)
        Padding(
          padding: sessionMargin,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const NoteBox(
                icon: AppIcons.alert,
                text: 'Soal ini tidak bisa dibuat ulang. Hasil dan waktumu '
                    'tetap tersimpan.',
              ),
              const SizedBox(height: AppSpace.s12),
              Text(
                skipped
                    ? 'Soal ini dilewati.'
                    : benar
                        ? 'Jawabanmu benar.'
                        : 'Jawabanmu salah.',
                style: AppType.body(c.ink),
              ),
            ],
          ),
        )
      else ...[
        QuestionBody(
          question: q,
          selected: answer?.opsiDipilih,
          onSelect: null,
          photo: photoForItem(item),
        ),
        const SizedBox(height: AppSpace.s16),
        Padding(
          padding: sessionMargin,
          child: _SideBySide(
            stacked: isLargeText(context),
            children: [
              ReviewAnswerBlock(
                ok: benar,
                title: benar
                    ? 'Benar'
                    : skipped
                        ? 'Dilewati'
                        : 'Salah',
                caption: 'Jawabanmu',
                question: q,
                index: answer?.opsiDipilih,
              ),
              ReviewAnswerBlock(
                ok: true,
                title: 'Kunci',
                caption: 'Jawaban benar',
                question: q,
                index: q.correctIndex,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpace.s24),
        ReviewSection(title: 'Kenapa', text: q.explanation),
        const SizedBox(height: AppSpace.s24),
        ReviewSection(title: 'Pola dan trik', text: planItemTrick(item)),
      ],
      const SizedBox(height: AppSpace.s16),
      Padding(
        padding: sessionMargin,
        child: SizedBox(
          width: double.infinity,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: c.outlineVariant)),
            ),
            child: Padding(
              padding: const EdgeInsets.only(top: AppSpace.s12),
              child: Wrap(
                spacing: AppSpace.s12,
                runSpacing: AppSpace.s8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ExcludeSemantics(
                        child: Icon(AppIcons.clock,
                            size: AppSizes.iconInText, color: c.ink),
                      ),
                      const SizedBox(width: AppSpace.s8),
                      Flexible(
                        child: Text(
                          answer == null || skipped
                              ? 'Tidak dijawab, target ${secondsOf(targetMs)} dtk'
                              : 'Waktumu ${secondsOf(answer.durasiMs)} dtk, target '
                                  '${secondsOf(targetMs)} dtk',
                          style: AppType.body(c.ink),
                        ),
                      ),
                    ],
                  ),
                  if (answer != null)
                    StatusTag(label: _speedName(answer.label)),
                ],
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: AppSpace.s8),
      if (answer != null)
        Semantics(
          toggled: inBook,
          container: true,
          label: 'Masuk buku kesalahan, ${inBook ? 'ya' : 'tidak'}',
          excludeSemantics: true,
          onTap: card.isLoading || _toggling
              ? null
              : () => unawaited(_toggle(review, index, inBook)),
          child: ListRow(
            leading: AppIcons.book,
            title: 'Masuk buku kesalahan',
            subtitle: inBook
                ? 'Muncul lagi sesuai jadwal ulang'
                : 'Ketuk untuk menambahkan',
            trailing: StatusTag(
              label: inBook ? 'Ya' : 'Tidak',
              kind: inBook ? StatusTagKind.strong : StatusTagKind.neutral,
            ),
            onTap: card.isLoading || _toggling
                ? null
                : () => unawaited(_toggle(review, index, inBook)),
          ),
        ),
      if (_toggleFailed)
        Padding(
          padding: sessionMargin.copyWith(top: AppSpace.s8),
          child: Semantics(
            liveRegion: true,
            child: const NoteBox(
              icon: AppIcons.alert,
              text: 'Buku kesalahan belum berubah. Data di perangkat gagal '
                  'ditulis. Ketuk sekali lagi.',
            ),
          ),
        ),
    ];
  }

  static String _speedName(SpeedLabel l) => switch (l) {
        SpeedLabel.benarCepat => 'Benar, cepat',
        SpeedLabel.benarLambat => 'Benar, lambat',
        SpeedLabel.salahCepat => 'Salah, cepat',
        SpeedLabel.salahLambat => 'Salah, lambat',
      };
}

/// Dua blok berdampingan sama lebar; di skala huruf besar disusun ke bawah.
class _SideBySide extends StatelessWidget {
  const _SideBySide({required this.children, required this.stacked});

  final List<Widget> children;
  final bool stacked;

  @override
  Widget build(BuildContext context) {
    if (stacked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: AppSpace.s8),
            children[i],
          ],
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(width: AppSpace.s8),
          Expanded(child: children[i]),
        ],
      ],
    );
  }
}

/// Judul seksi dan isinya di S09 dan pembahasan kartu buku kesalahan.
class ReviewSection extends StatelessWidget {
  const ReviewSection({super.key, required this.title, required this.text});

  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.tokens.colors;
    return Padding(
      padding: sessionMargin,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
              header: true, child: Text(title, style: AppType.title(c.ink))),
          const SizedBox(height: AppSpace.s8),
          Text(text, style: AppType.body(c.ink)),
        ],
      ),
    );
  }
}

/// Blok "Jawabanmu" atau "Kunci": ikon dan teks bersama warna, isi opsi
/// berupa teks atau gambar kecil. Perakitan token (A76).
class ReviewAnswerBlock extends StatelessWidget {
  const ReviewAnswerBlock({
    super.key,
    required this.ok,
    required this.title,
    required this.caption,
    required this.question,
    required this.index,
  });

  final bool ok;
  final String title;
  final String caption;
  final Question question;
  final int? index;

  @override
  Widget build(BuildContext context) {
    final c = context.tokens.colors;
    final fg = ok ? c.ok : c.bad;
    final o = index == null ? null : question.options[index!];
    final fig = o?.content.figure;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: ok ? c.okContainer : c.badContainer,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.s12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ExcludeSemantics(
                  child: Icon(ok ? AppIcons.check : AppIcons.close,
                      size: AppSizes.iconInText, color: fg),
                ),
                const SizedBox(width: AppSpace.s4),
                Expanded(
                  child: Text(
                    title,
                    style:
                        AppType.label(fg).copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.s4),
            Text(caption, style: AppType.label(c.ink)),
            const SizedBox(height: AppSpace.s4),
            if (o == null)
              Text('Tidak dijawab', style: AppType.body(c.ink))
            else if (fig != null)
              Row(
                children: [
                  Text(o.id, style: AppType.title(c.ink)),
                  const SizedBox(width: AppSpace.s8),
                  Flexible(
                    child: FigureView(
                      figure: fig,
                      maxExtent: 72,
                      semanticLabel: 'Opsi ${o.id}, ${describeFigure(fig)}',
                    ),
                  ),
                ],
              )
            else
              Text(
                '${o.id}. ${o.content.text}',
                style: AppType.title(c.ink),
              ),
          ],
        ),
      ),
    );
  }
}

/// Deretan nomor soal dengan hasilnya: benar `okContainer`, salah
/// `badContainer` dan bergaris putus, sekarang berkontur tebal. Ikon tidak
/// dipakai; teks "Soal n, benar" dibaca pembaca layar. Perakitan token (A76).
class _ReviewStrip extends StatefulWidget {
  const _ReviewStrip({
    required this.review,
    required this.current,
    required this.onTap,
  });

  final SessionReview review;
  final int current;
  final ValueChanged<int> onTap;

  @override
  State<_ReviewStrip> createState() => _ReviewStripState();
}

class _ReviewStripState extends State<_ReviewStrip> {
  static const double _step = AppSizes.touchTarget;
  final ScrollController _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _center());
  }

  void _center() {
    if (!mounted || !_controller.hasClients) return;
    final p = _controller.position;
    final target = widget.current * _step - (p.viewportDimension - _step) / 2;
    _controller.jumpTo(target.clamp(0.0, p.maxScrollExtent));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _bubble(int i) => _ReviewBubble(
        number: i + 1,
        ok: widget.review.answers[i]?.benar ?? false,
        current: i == widget.current,
        onTap: () => widget.onTap(i),
      );

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppSizes.touchTarget,
      child: ListView.builder(
        controller: _controller,
        scrollDirection: Axis.horizontal,
        padding: sessionMargin,
        itemCount: widget.review.total,
        itemBuilder: (context, i) => _bubble(i),
      ),
    );
  }
}

class _ReviewBubble extends StatelessWidget {
  const _ReviewBubble({
    required this.number,
    required this.ok,
    required this.current,
    required this.onTap,
  });

  final int number;
  final bool ok;
  final bool current;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.tokens.colors;
    final stroke = current ? 2.0 : 1.0;
    final text = '$number';
    return Semantics(
      button: true,
      selected: current,
      label: 'Soal $number, ${ok ? 'benar' : 'salah'}',
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: AppSizes.touchTarget,
          height: AppSizes.touchTarget,
          child: Center(
            child: CustomPaint(
              foregroundPainter: _BubbleBorder(
                color: current
                    ? c.ink
                    : ok
                        ? c.ok
                        : c.bad,
                width: stroke,
                dashed: !ok && !current,
              ),
              child: Container(
                width: AppSizes.bubble,
                height: AppSizes.bubble,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: ok ? c.okContainer : c.badContainer,
                ),
                child: Text(text, style: AppType.caption(c.ink)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BubbleBorder extends CustomPainter {
  const _BubbleBorder({
    required this.color,
    required this.width,
    required this.dashed,
  });

  final Color color;
  final double width;
  final bool dashed;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width;
    final rect = (Offset.zero & size).deflate(width / 2);
    if (!dashed) {
      canvas.drawOval(rect, paint);
      return;
    }
    final path = Path()..addOval(rect);
    for (final m in path.computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        canvas.drawPath(m.extractPath(d, math.min(d + 4, m.length)), paint);
        d += 7;
      }
    }
  }

  @override
  bool shouldRepaint(_BubbleBorder old) =>
      old.color != color || old.width != width || old.dashed != dashed;
}
