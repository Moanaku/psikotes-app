import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/text_scale.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_top_bar.dart';
import '../../core/widgets/empty_view.dart';
import '../../core/widgets/error_view.dart';
import '../../core/widgets/note_box.dart';
import '../../core/widgets/skeleton_list.dart';
import '../../domain/models/codes.dart';
import '../../domain/models/question_guides.dart';
import '../../domain/models/session_state.dart';
import '../../domain/providers.dart';
import '../../domain/services/profile_templates.dart';
import '../../domain/services/session_controller.dart';
import '../capture/capture_photo_view.dart';
import '../onboarding/onboarding_frame.dart';
import 'session_widgets.dart';

enum _Load { loading, ready, notFound, failed }

/// S06 dan S07: satu layar sesi dengan dua tata letak. Mode dengan pembahasan
/// langsung (latihan) memakai S06; simulasi dan diagnostik memakai S07 (A67).
///
/// Layar meneruskan siklus hidup app ke `SessionController.onPaused` dan
/// `onResumed` supaya waktu melihat soal tidak menghitung waktu di latar
/// belakang dan sisa waktu dihitung ulang dari deadline saat kembali. Sesi
/// dibuka lewat id, jadi membuka ulang app lalu `/sesi/:id` melanjutkan dari
/// soal terakhir.
class SessionScreen extends ConsumerStatefulWidget {
  const SessionScreen({super.key, required this.sessionId});

  final int sessionId;

  @override
  ConsumerState<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends ConsumerState<SessionScreen>
    with WidgetsBindingObserver {
  late final SessionController _controller;
  final ScrollController _scroll = ScrollController();
  final GlobalKey _feedbackKey = GlobalKey();

  _Load _load = _Load.loading;
  bool _confirmExit = false;
  bool _hintOpen = false;

  /// Soal tempat konfirmasi menutup subtes diminta; hilang bila soal berganti.
  int? _confirmCloseAt;

  @override
  void initState() {
    super.initState();
    _controller = ref.read(sessionControllerProvider.notifier);
    WidgetsBinding.instance.addObserver(this);
    unawaited(_open());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scroll.dispose();
    final id = widget.sessionId;
    // Mengubah provider saat pohon widget dibongkar dilarang; tunda.
    Future.microtask(() => _controller.close(sessionId: id));
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_load != _Load.ready) return;
    switch (state) {
      case AppLifecycleState.resumed:
        unawaited(_controller.onResumed());
      case AppLifecycleState.inactive:
        // Dialog sistem dan perpindahan singkat tidak menghentikan apa pun.
        break;
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        unawaited(_controller.onPaused());
    }
  }

  Future<void> _open() async {
    setState(() => _load = _Load.loading);
    try {
      final result = await _controller.open(widget.sessionId);
      if (!mounted) return;
      switch (result) {
        case SessionOpen.opened:
          setState(() => _load = _Load.ready);
        case SessionOpen.finished:
          context.go(Routes.hasilPath(widget.sessionId));
        case SessionOpen.notFound:
          setState(() => _load = _Load.notFound);
      }
    } catch (_) {
      if (mounted) setState(() => _load = _Load.failed);
    }
  }

  void _toHome() => context.go(Routes.beranda);

  void _leave() => context.canPop() ? context.pop() : _toHome();

  void _requestExit() => setState(() => _confirmExit = true);

  Future<void> _finishNow() async {
    setState(() => _confirmExit = false);
    await _controller.finish();
  }

  void _onPosisiChanged() {
    if (!mounted) return;
    setState(() {
      _hintOpen = false;
      _confirmCloseAt = null;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _revealFeedback() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _feedbackKey.currentContext;
      if (!mounted || ctx == null) return;
      unawaited(Scrollable.ensureVisible(
        ctx,
        duration: context.motion,
        curve: AppMotion.curve,
      ));
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<SessionState?>(sessionControllerProvider, (prev, next) {
      if (next == null || next.sessionId != widget.sessionId) return;
      if (next.finished) {
        context.go(Routes.hasilPath(next.sessionId));
        return;
      }
      if (prev != null && prev.posisi != next.posisi) _onPosisiChanged();
      if (prev?.feedback == null && next.feedback != null) _revealFeedback();
    });

    final s = ref.watch(sessionControllerProvider);
    if (_load != _Load.ready || s == null || s.sessionId != widget.sessionId) {
      return _StateFrame(
        header: AppTopBar(
          title: 'Sesi',
          onBack: _leave,
          backIcon: AppIcons.close,
          backLabel: 'Tutup sesi',
        ),
        child: switch (_load) {
          _Load.notFound => EmptyView(
              title: 'Sesi tidak ditemukan',
              message: 'Sesi ini sudah dihapus atau tidak pernah ada. Mulai '
                  'sesi baru dari beranda.',
              actionLabel: 'Ke beranda',
              onAction: _toHome,
            ),
          _Load.failed => ErrorView(
              title: 'Sesi tidak bisa dibuka',
              message: 'Data sesi gagal dibaca. Jawabanmu yang sudah tersimpan '
                  'tidak hilang. Ketuk coba lagi, atau kembali ke beranda.',
              onRetry: () => unawaited(_open()),
            ),
          _ => const SkeletonList(
              rows: 4,
              semanticLabel: 'Memuat sesi',
            ),
        },
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _requestExit();
      },
      child: s.rules.immediateFeedback ? _practice(s) : _exam(s),
    );
  }

  // ------------------------------------------------------------ S06 latihan

  Widget _practice(SessionState s) {
    final c = context.tokens.colors;
    final item = s.plan.items[s.posisi];
    final q = s.question;
    final timed = s.deadline != null && s.timerEnabled;
    final fb = s.feedback;
    final last = s.isLastInSubtest && s.isLastSubtest;

    return OnboardingFrame(
      scrollController: _scroll,
      footerMaxShare:
          _confirmExit ? confirmFooterMaxShare : defaultFooterMaxShare,
      header: AppTopBar(
        title: planItemName(item),
        onBack: _requestExit,
        backIcon: AppIcons.close,
        backLabel: 'Tutup sesi',
        actions: [
          if (s.remaining != null && timed) TimerLabel(remaining: s.remaining!),
        ],
      ),
      footer: _confirmExit
          ? _exitPanel(timed: timed)
          : s.questionFailed
              ? AppButton(
                  label: last ? 'Lewati dan lihat hasil' : 'Lewati soal',
                  onPressed: () => unawaited(_controller.next()),
                )
              : fb != null
                  ? AppButton(
                      label: last ? 'Lihat hasil' : 'Berikutnya',
                      onPressed: () => unawaited(_controller.next()),
                    )
                  : _practiceActions(s),
      children: [
        Padding(
          padding: sessionMargin,
          child: Wrap(
            spacing: AppSpace.s12,
            runSpacing: AppSpace.s8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Mode Latihan, soal ${s.posisi + 1} dari '
                '${s.plan.items.length}',
                style: AppType.label(c.inkMuted),
              ),
              if (timed)
                AppButton(
                  label: 'Matikan timer',
                  variant: AppButtonVariant.outline,
                  expand: false,
                  onPressed: () => unawaited(_controller.disableTimer()),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpace.s12),
        NumberStrip(
          count: s.plan.items.length,
          current: s.posisi,
          answered: (i) => s.answers.containsKey(i),
        ),
        const SizedBox(height: AppSpace.s16),
        if (_hintOpen && fb == null)
          Padding(
            padding: sessionMargin.copyWith(bottom: AppSpace.s16),
            child: NoteBox(
              icon: AppIcons.bulb,
              text: planItemHint(item),
            ),
          ),
        if (q == null)
          _QuestionFailed(onRetry: () => unawaited(_controller.retryQuestion()))
        else
          QuestionBody(
            question: q,
            selected: fb != null ? fb.chosen : s.selected,
            onSelect:
                fb != null ? null : (i) => unawaited(_controller.select(i)),
            photo: photoForItem(item),
          ),
        if (q != null && fb != null)
          Padding(
            key: _feedbackKey,
            padding: sessionMargin.copyWith(top: AppSpace.s16),
            child: FeedbackPanel(
              benar: fb.benar,
              skipped: fb.chosen == null,
              correctLetter: q.options[fb.correctIndex].id,
              explanation: q.explanation,
            ),
          ),
      ],
    );
  }

  Widget _practiceActions(SessionState s) {
    final q = s.question;
    final selected = s.selected;
    final letter =
        q != null && selected != null ? ' ${q.options[selected].id}' : '';
    return FooterButtons(
      flex: const [10, 14],
      buttons: [
        AppButton(
          label: _hintOpen ? 'Tutup petunjuk' : 'Buka petunjuk',
          variant: AppButtonVariant.secondary,
          onPressed:
              q == null ? null : () => setState(() => _hintOpen = !_hintOpen),
        ),
        AppButton(
          label: 'Kirim jawaban$letter',
          onPressed: s.canSubmit ? () => unawaited(_controller.submit()) : null,
        ),
      ],
    );
  }

  // ---------------------------------------------------- S07 simulasi, diagnostik

  Widget _exam(SessionState s) {
    final c = context.tokens.colors;
    final q = s.question;
    final timed = s.deadline != null;
    final profiles = ref.watch(profilesProvider).valueOrNull;
    final name = [
      for (final p in profiles ?? const [])
        if (p.id == s.profileId) p.nama,
    ].firstOrNull;
    final title = s.mode == SessionMode.diagnostik ? 'Diagnostik' : 'Simulasi';
    final range = s.subtest;
    final inSubtest = s.posisi - range.start + 1;
    final answeredHere = [
      for (var i = range.start; i < range.end; i++)
        if (s.answers[i]?.opsiDipilih != null) i,
    ];
    final closing = _confirmCloseAt == s.posisi;
    // Di skala huruf besar kepala dipadatkan supaya soal terlihat tanpa
    // menggulir jauh: nama profil dibuang (sudah dikenal di sesi ini) dan
    // keterangan subtes dan soal menjadi satu baris pendek.
    final large = isLargeText(context);

    return OnboardingFrame(
      scrollController: _scroll,
      footerMaxShare:
          _confirmExit ? confirmFooterMaxShare : defaultFooterMaxShare,
      header: AppTopBar(
        title: title,
        onBack: _requestExit,
        backIcon: AppIcons.close,
        backLabel: 'Tutup sesi',
        actions: [
          if (s.remaining != null && timed) TimerLabel(remaining: s.remaining!),
        ],
      ),
      footer: _confirmExit
          ? _exitPanel(timed: timed)
          : closing
              ? _CloseSubtestPanel(
                  s: s,
                  unanswered: range.jumlah - answeredHere.length,
                  onStay: () => setState(() => _confirmCloseAt = null),
                  onClose: () {
                    setState(() => _confirmCloseAt = null);
                    unawaited(_controller.next());
                  },
                )
              : FooterButtons(
                  flex: const [10, 13],
                  buttons: [
                    AppButton(
                      label: 'Sebelumnya',
                      variant: AppButtonVariant.secondary,
                      onPressed: s.canGoBack
                          ? () => unawaited(_controller.previous())
                          : null,
                    ),
                    AppButton(
                      label: 'Berikutnya',
                      onPressed: () {
                        if (s.isLastInSubtest) {
                          setState(() => _confirmCloseAt = s.posisi);
                        } else {
                          unawaited(_controller.next());
                        }
                      },
                    ),
                  ],
                ),
      children: [
        if (name != null && !large)
          Padding(
            padding: sessionMargin,
            child: Text(name, style: AppType.label(c.inkMuted)),
          ),
        if (name != null && !large) const SizedBox(height: AppSpace.s8),
        Padding(
          padding: sessionMargin,
          child: _SubtestSteps(
            subtests: s.subtests,
            current: s.subtestIndex,
            showNames: !large,
          ),
        ),
        SizedBox(height: large ? AppSpace.s8 : AppSpace.s12),
        Padding(
          padding: sessionMargin,
          child: Text(
            large
                ? '${ProfileTemplates.categoryName(range.kategori)}, soal '
                    '$inSubtest dari ${range.jumlah}'
                : 'Subtes ${s.subtestIndex + 1} dari ${s.subtests.length}, '
                    'soal $inSubtest dari ${range.jumlah}',
            style: AppType.label(c.inkMuted),
          ),
        ),
        const SizedBox(height: AppSpace.s4),
        NumberStrip(
          count: range.jumlah,
          current: s.posisi - range.start,
          answered: (i) => s.answers[range.start + i]?.opsiDipilih != null,
          onTap: (i) => unawaited(_controller.goTo(range.start + i)),
        ),
        if (s.notice != null) ...[
          const SizedBox(height: AppSpace.s8),
          Padding(
            padding: sessionMargin,
            child: _TimeUpNotice(
              notice: s.notice!,
              subtests: s.subtests,
              onDismiss: _controller.dismissNotice,
            ),
          ),
        ],
        const SizedBox(height: AppSpace.s16),
        if (q == null)
          _QuestionFailed(onRetry: () => unawaited(_controller.retryQuestion()))
        else
          QuestionBody(
            question: q,
            selected: s.currentAnswer?.opsiDipilih,
            onSelect: (i) => unawaited(_controller.select(i)),
            photo: photoForItem(s.plan.items[s.posisi]),
          ),
        const SizedBox(height: AppSpace.s16),
        Padding(
          padding: sessionMargin,
          child: NoteBox(
            icon: AppIcons.lock,
            text: _ruleNote(s),
          ),
        ),
      ],
    );
  }

  String _ruleNote(SessionState s) {
    final after = s.mode == SessionMode.diagnostik
        ? 'Hasil muncul setelah diagnostik selesai.'
        : 'Pembahasan muncul setelah simulasi selesai.';
    if (s.subtestIndex > 0) {
      final previous = ProfileTemplates.categoryName(
          s.subtests[s.subtestIndex - 1].kategori);
      return 'Tidak bisa kembali ke subtes $previous. $after';
    }
    return 'Setelah subtes ditutup, kamu tidak bisa kembali ke sana. $after';
  }

  Widget _exitPanel({required bool timed}) => ExitPanel(
        timed: timed,
        onStay: () => setState(() => _confirmExit = false),
        onLater: () {
          setState(() => _confirmExit = false);
          _leave();
        },
        onFinish: () => unawaited(_finishNow()),
      );
}

class _StateFrame extends StatelessWidget {
  const _StateFrame({required this.header, required this.child});

  final Widget header;
  final Widget child;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              header,
              Expanded(child: SingleChildScrollView(child: child)),
            ],
          ),
        ),
      );
}

class _QuestionFailed extends StatelessWidget {
  const _QuestionFailed({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => ErrorView(
        title: 'Soal tidak bisa dibuat',
        message: 'Coba tipe lain atau ulangi sesi.',
        retryLabel: 'Ulangi',
        onRetry: onRetry,
      );
}

/// Langkah subtes: batang pendek tiap subtes dengan namanya. Selesai: `ink`
/// dan centang; sekarang: `accent` berbatas `ink`; belum: `outlineVariant`.
class _SubtestSteps extends StatelessWidget {
  const _SubtestSteps({
    required this.subtests,
    required this.current,
    required this.showNames,
  });

  final List<SubtestRange> subtests;
  final int current;

  /// Nama di bawah batang. Dimatikan di skala huruf besar: lebar satu langkah
  /// tidak cukup dan nama subtes sekarang sudah tertulis di baris keterangan.
  final bool showNames;

  @override
  Widget build(BuildContext context) {
    final c = context.tokens.colors;
    return Semantics(
      container: true,
      label: 'Subtes',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final r in subtests) ...[
            if (r.index > 0) const SizedBox(width: AppSpace.s8),
            Expanded(
              child: Semantics(
                label: '${ProfileTemplates.categoryName(r.kategori)}, '
                    '${r.index < current ? 'selesai' : r.index == current ? 'sekarang' : 'belum'}',
                excludeSemantics: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: r.index < current
                            ? c.ink
                            : r.index == current
                                ? c.accent
                                : c.outlineVariant,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        border: r.index == current
                            ? Border.all(color: c.ink)
                            : null,
                      ),
                      child: const SizedBox(
                        height: AppSpace.s4,
                        width: double.infinity,
                      ),
                    ),
                    if (showNames) ...[
                      const SizedBox(height: AppSpace.s8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (r.index < current) ...[
                            Padding(
                              padding: const EdgeInsets.only(top: AppSpace.s4),
                              child: Icon(
                                AppIcons.check,
                                size: AppSizes.iconInTag,
                                color: c.ink,
                              ),
                            ),
                            const SizedBox(width: AppSpace.s4),
                          ],
                          // Satu baris yang mengecil bila perlu: nama subtes tidak
                          // pernah dipatahkan di tengah kata.
                          Expanded(
                            child: ClampedChromeText(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: AlignmentDirectional.centerStart,
                                child: Text(
                                  ProfileTemplates.categoryName(r.kategori),
                                  maxLines: 1,
                                  softWrap: false,
                                  style: AppType.label(
                                    r.index > current ? c.inkMuted : c.ink,
                                  ).copyWith(
                                    fontWeight: r.index == current
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TimeUpNotice extends StatelessWidget {
  const _TimeUpNotice({
    required this.notice,
    required this.subtests,
    required this.onDismiss,
  });

  final TimeUpNotice notice;
  final List<SubtestRange> subtests;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final done = ProfileTemplates.categoryName(notice.subtest.kategori);
    final next = notice.subtest.index + 1 < subtests.length
        ? ProfileTemplates.categoryName(
            subtests[notice.subtest.index + 1].kategori)
        : null;
    final text = notice.sessionEnded || next == null
        ? 'Waktu subtes $done habis. Sesi selesai.'
        : 'Waktu subtes $done habis. Lanjut ke subtes $next.';
    return Semantics(
      liveRegion: true,
      container: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          NoteBox(icon: AppIcons.clock, text: text),
          const SizedBox(height: AppSpace.s8),
          AppButton(
            label: 'Tutup pesan',
            variant: AppButtonVariant.outline,
            expand: false,
            onPressed: onDismiss,
          ),
        ],
      ),
    );
  }
}

/// Konfirmasi menutup subtes (S07): setelah ditutup tidak bisa kembali.
class _CloseSubtestPanel extends StatelessWidget {
  const _CloseSubtestPanel({
    required this.s,
    required this.unanswered,
    required this.onStay,
    required this.onClose,
  });

  final SessionState s;
  final int unanswered;
  final VoidCallback onStay;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final name = ProfileTemplates.categoryName(s.subtest.kategori);
    final last = s.isLastSubtest;
    final diagnostic = s.mode == SessionMode.diagnostik;
    final what = last
        ? (diagnostic ? 'Selesaikan diagnostik' : 'Selesaikan simulasi')
        : 'Tutup subtes $name';
    final rest =
        last ? 'Hasil muncul setelah ini.' : 'Kamu tidak bisa kembali ke sana.';
    final count = unanswered > 0 ? ' $unanswered soal belum dijawab.' : '';
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          liveRegion: true,
          child: NoteBox(
            icon: AppIcons.alert,
            text: '$what? $rest$count',
          ),
        ),
        const SizedBox(height: AppSpace.s12),
        FooterButtons(
          buttons: [
            AppButton(
              label: 'Tetap di subtes',
              variant: AppButtonVariant.secondary,
              onPressed: onStay,
            ),
            AppButton(label: what, onPressed: onClose),
          ],
        ),
      ],
    );
  }
}
