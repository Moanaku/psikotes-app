import 'package:flutter/material.dart';
import 'package:question_engine/question_engine.dart';

import '../../core/theme/app_icons.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/time_format.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/figure_view.dart';
import '../../core/widgets/note_box.dart';
import '../../core/widgets/number_bubble.dart';
import '../../core/widgets/option_tile.dart';
import '../onboarding/onboarding_frame.dart';

/// Margin layar horizontal 16 untuk isi layar sesi.
const EdgeInsets sessionMargin = EdgeInsets.symmetric(
  horizontal: AppSpace.s16,
);

/// Stem soal (teks dan gambar) lalu opsi. Opsi bergambar disusun dua kolom
/// karena huruf opsi memakai satu kolom sendiri di `OptionTile` (A69); opsi
/// teks satu kolom. [onSelect] null menonaktifkan opsi (jawaban sudah
/// dikirim).
class QuestionBody extends StatelessWidget {
  const QuestionBody({
    super.key,
    required this.question,
    required this.selected,
    required this.onSelect,
    this.photo,
  });

  final Question question;
  final int? selected;
  final ValueChanged<int>? onSelect;

  /// Foto soal Capture; tampil di bawah teks soal.
  final Widget? photo;

  @override
  Widget build(BuildContext context) {
    final c = context.tokens.colors;
    final text = question.stem.text;
    final figure = question.stem.figure;
    final short = text != null && text.length <= 70 && !text.contains('\n');
    return Padding(
      padding: sessionMargin,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (text != null)
            Semantics(
              container: true,
              child: Text(
                text,
                style: short ? AppType.title(c.ink) : AppType.body(c.ink),
              ),
            ),
          if (figure != null) ...[
            if (text != null) const SizedBox(height: AppSpace.s12),
            DecoratedBox(
              decoration: BoxDecoration(
                color: c.surfaceContainer,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: c.outlineVariant),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpace.s16),
                child:
                    Center(child: FigureView(figure: figure, maxExtent: 320)),
              ),
            ),
          ],
          if (photo != null) ...[
            const SizedBox(height: AppSpace.s12),
            photo!,
          ],
          const SizedBox(height: AppSpace.s16),
          _Options(
            question: question,
            selected: selected,
            onSelect: onSelect,
          ),
        ],
      ),
    );
  }
}

class _Options extends StatelessWidget {
  const _Options({
    required this.question,
    required this.selected,
    required this.onSelect,
  });

  final Question question;
  final int? selected;
  final ValueChanged<int>? onSelect;

  Widget _tile(int i) {
    final o = question.options[i];
    final fig = o.content.figure;
    final text = o.content.text;
    final Widget? child = fig == null
        ? null
        : text == null
            ? FigureView(figure: fig, maxExtent: 120)
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(text),
                  const SizedBox(height: AppSpace.s8),
                  FigureView(figure: fig, maxExtent: 120),
                ],
              );
    return OptionTile(
      letter: o.id,
      label: fig == null ? text : null,
      semanticLabel: fig == null ? null : describeFigure(fig),
      selected: selected == i,
      onTap: onSelect == null ? null : () => onSelect!(i),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final n = question.options.length;
    final twoColumns = question.options.any((o) => o.content.figure != null);
    return Semantics(
      container: true,
      label: 'Pilihan jawaban',
      child: twoColumns
          ? LayoutBuilder(
              builder: (context, box) {
                // Lebar tetap dua kolom: gambar opsi sama besar, jadi tinggi
                // barisnya sama tanpa mengukur isi.
                final width = (box.maxWidth - AppSpace.s8) / 2;
                return Wrap(
                  spacing: AppSpace.s8,
                  runSpacing: AppSpace.s8,
                  children: [
                    for (var i = 0; i < n; i++)
                      SizedBox(width: width, child: _tile(i)),
                  ],
                );
              },
            )
          : Column(
              children: [
                for (var i = 0; i < n; i++) ...[
                  if (i > 0) const SizedBox(height: AppSpace.s8),
                  _tile(i),
                ],
              ],
            ),
    );
  }
}

/// Deretan nomor soal satu baris yang digulir mendatar, di latihan dan
/// simulasi. Tiap nomor mendapat sel 48 x 48 (target sentuh yang sama di semua
/// mode); nomor sekarang digulir ke tengah saat berganti. Bisa diketuk hanya
/// bila [onTap] ada (simulasi); latihan tidak boleh melompat antar soal.
class NumberStrip extends StatefulWidget {
  const NumberStrip({
    super.key,
    required this.count,
    required this.current,
    required this.answered,
    this.onTap,
  });

  final int count;
  final int current;
  final bool Function(int index) answered;
  final ValueChanged<int>? onTap;

  @override
  State<NumberStrip> createState() => _NumberStripState();
}

class _NumberStripState extends State<NumberStrip> {
  static const double _step = AppSizes.touchTarget;
  final ScrollController _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _center());
  }

  @override
  void didUpdateWidget(NumberStrip old) {
    super.didUpdateWidget(old);
    if (old.current != widget.current) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _center());
    }
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

  Widget _bubble(int i) {
    final tap = widget.onTap;
    final bubble = NumberBubble(
      number: i + 1,
      state: i == widget.current
          ? NumberBubbleState.current
          : widget.answered(i)
              ? NumberBubbleState.answered
              : NumberBubbleState.unanswered,
      onTap: tap == null ? null : () => tap(i),
    );
    // Sel 48 juga untuk nomor yang tidak bisa diketuk, supaya jarak dan tinggi
    // deretan sama di semua mode.
    return SizedBox(
      width: _step,
      height: _step,
      child: tap == null ? Center(child: bubble) : bubble,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Nomor soal, sekarang soal ${widget.current + 1} dari '
          '${widget.count}',
      child: SizedBox(
        height: AppSizes.touchTarget,
        child: ListView.builder(
          controller: _controller,
          scrollDirection: Axis.horizontal,
          padding: sessionMargin,
          itemCount: widget.count,
          itemExtent: _step,
          itemBuilder: (context, i) => _bubble(i),
        ),
      ),
    );
  }
}

/// Sisa waktu "mm:ss" dengan ikon jam. Dibaca sebagai kalimat, bukan angka.
class TimerLabel extends StatelessWidget {
  const TimerLabel({super.key, required this.remaining});

  final Duration remaining;

  @override
  Widget build(BuildContext context) {
    final c = context.tokens.colors;
    return Semantics(
      label: 'Sisa waktu ${spokenDuration(remaining)}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.only(right: AppSpace.s16),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(AppIcons.clock, size: AppSizes.iconInText, color: c.ink),
            const SizedBox(width: AppSpace.s4),
            Text(
              formatClock(remaining),
              style: AppType.body(c.ink).copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

/// Benar atau salah beserta pembahasan singkat setelah mengirim jawaban di
/// mode Latihan. Ikon dan teks selalu menyertai warna. Perakitan token, bukan
/// komponen inti (A69).
class FeedbackPanel extends StatelessWidget {
  const FeedbackPanel({
    super.key,
    required this.benar,
    required this.correctLetter,
    required this.explanation,
    this.skipped = false,
  });

  final bool benar;
  final String correctLetter;
  final String explanation;
  final bool skipped;

  @override
  Widget build(BuildContext context) {
    final c = context.tokens.colors;
    final fg = benar ? c.ok : c.bad;
    final title = benar
        ? 'Benar'
        : skipped
            ? 'Dilewati. Kunci: $correctLetter'
            : 'Salah. Kunci: $correctLetter';
    return Semantics(
      liveRegion: true,
      container: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: benar ? c.okContainer : c.badContainer,
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
                    child: Icon(
                      benar ? AppIcons.check : AppIcons.close,
                      size: AppSizes.iconBase,
                      color: fg,
                    ),
                  ),
                  const SizedBox(width: AppSpace.s8),
                  Expanded(
                    child: Text(
                      title,
                      style: AppType.body(fg)
                          .copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.s8),
              Text(
                'Pembahasan',
                style: AppType.label(c.ink).copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpace.s4),
              Text(explanation, style: AppType.label(c.ink)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Konfirmasi keluar dari sesi, menggantikan bilah aksi bawah. Jawaban sudah
/// tersimpan per soal, jadi pilihannya hanya melanjutkan nanti, mengakhiri,
/// atau tetap mengerjakan. Waktu subtes tidak berhenti (deadline mutlak).
class ExitPanel extends StatelessWidget {
  const ExitPanel({
    super.key,
    required this.timed,
    required this.onLater,
    required this.onFinish,
    required this.onStay,
  });

  final bool timed;
  final VoidCallback onLater;
  final VoidCallback onFinish;
  final VoidCallback onStay;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        NoteBox(
          icon: timed ? AppIcons.clock : AppIcons.check,
          text: timed
              ? 'Jawabanmu sudah tersimpan. Waktu subtes tetap berjalan '
                  'selama kamu keluar.'
              : 'Jawabanmu sudah tersimpan. Kamu bisa melanjutkan sesi ini '
                  'nanti dari beranda.',
        ),
        const SizedBox(height: AppSpace.s12),
        AppButton(label: 'Tetap mengerjakan', onPressed: onStay),
        const SizedBox(height: AppSpace.s8),
        FooterButtons(
          buttons: [
            AppButton(
              label: 'Lanjutkan nanti',
              variant: AppButtonVariant.secondary,
              onPressed: onLater,
            ),
            AppButton(
              label: 'Akhiri sesi',
              variant: AppButtonVariant.outline,
              onPressed: onFinish,
            ),
          ],
        ),
      ],
    );
  }
}
