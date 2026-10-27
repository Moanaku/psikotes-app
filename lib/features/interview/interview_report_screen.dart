import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_top_bar.dart';
import '../../core/widgets/chat_bubble.dart';
import '../../core/widgets/empty_view.dart';
import '../../core/widgets/error_view.dart';
import '../../core/widgets/list_row.dart';
import '../../core/widgets/note_box.dart';
import '../../core/widgets/score_bar.dart';
import '../../core/widgets/skeleton_list.dart';
import '../../core/widgets/status_tag.dart';
import 'interview_providers.dart';

const EdgeInsets _margin = EdgeInsets.symmetric(horizontal: AppSpace.s16);

/// S17 Laporan wawancara, dari laporan contoh (A108).
class InterviewReportScreen extends ConsumerStatefulWidget {
  const InterviewReportScreen({super.key});

  @override
  ConsumerState<InterviewReportScreen> createState() =>
      _InterviewReportScreenState();
}

class _InterviewReportScreenState extends ConsumerState<InterviewReportScreen> {
  bool _transcript = false;

  void _back() =>
      context.canPop() ? context.pop() : context.go(Routes.wawancara);

  @override
  Widget build(BuildContext context) {
    final c = context.tokens.colors;
    final setup = ref.watch(interviewSetupProvider);
    final dialog = ref.watch(interviewDialogProvider);
    final report = ref.watch(interviewReportProvider);
    final header = AppTopBar(
      title: 'Laporan ${setup.persona.title.toLowerCase()}',
      onBack: _back,
    );

    Widget frame(Widget body, {Widget? footer}) => Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                header,
                Expanded(child: SingleChildScrollView(child: body)),
                if (footer != null)
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: c.surface,
                      border: Border(top: BorderSide(color: c.outlineVariant)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpace.s16),
                      child: footer,
                    ),
                  ),
              ],
            ),
          ),
        );

    return report.when(
      loading: () => frame(const SkeletonList(
        rows: 5,
        semanticLabel: 'Memuat laporan',
      )),
      error: (_, __) => frame(ErrorView(
        title: 'Laporan tidak bisa dibuat',
        message: 'Dialogmu tersimpan. Ketuk coba lagi.',
        onRetry: () => ref.invalidate(interviewReportProvider),
      )),
      data: (r) {
        if (r == null) {
          return frame(EmptyView(
            title: 'Belum ada wawancara',
            message: 'Laporan muncul setelah kamu menyelesaikan satu dialog.',
            actionLabel: 'Ke setup wawancara',
            onAction: () => context.go(Routes.wawancara),
          ));
        }
        final lowest =
            r.aspects.map((a) => a.score).reduce((a, b) => a < b ? a : b);
        return frame(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: _margin,
                child: Row(
                  children: [
                    const StatusTag(
                      label: 'Data contoh',
                      kind: StatusTagKind.attention,
                    ),
                    const SizedBox(width: AppSpace.s8),
                    Expanded(
                      child: Text('Laporan tertulis, bukan hasil AI',
                          style: AppType.label(c.inkMuted)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpace.s16),
              Padding(
                padding: _margin,
                child: Semantics(
                  header: true,
                  child: Text('Skor per aspek (skala 1 sampai 5)',
                      style: AppType.title(c.ink)),
                ),
              ),
              const SizedBox(height: AppSpace.s8),
              for (final a in r.aspects)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpace.s16, 0, AppSpace.s16, AppSpace.s12),
                  child: ScoreBar(
                    label: a.name,
                    value: a.score / 5,
                    valueLabel: '${a.score}/5',
                    weakest: a.score == lowest,
                  ),
                ),
              const SizedBox(height: AppSpace.s12),
              Padding(
                padding: _margin,
                child: Semantics(
                  header: true,
                  child: Text('Peta klaim CV', style: AppType.title(c.ink)),
                ),
              ),
              for (final k in r.claims)
                ListRow(
                  title: k.claim,
                  subtitle: k.note,
                  trailing: k.strong
                      ? const StatusTag(
                          label: 'Kuat', kind: StatusTagKind.strong)
                      : const StatusTag(
                          label: 'Goyah', kind: StatusTagKind.attention),
                ),
              const SizedBox(height: AppSpace.s16),
              Padding(
                padding: _margin,
                child: NoteBox(
                  icon: AppIcons.bulb,
                  text: 'Saran perbaikan CV. ${r.cvAdvice}',
                ),
              ),
              const SizedBox(height: AppSpace.s16),
              Padding(
                padding: _margin,
                child: Text(
                  'Pada laporan nyata, ${r.weakQuestions} pertanyaan lemah '
                  'masuk ke buku kesalahan. Contoh ini belum menambah kartu '
                  'apa pun.',
                  style: AppType.label(c.inkMuted),
                ),
              ),
              if (_transcript) ...[
                const SizedBox(height: AppSpace.s24),
                Padding(
                  padding: _margin,
                  child: Semantics(
                    header: true,
                    child: Text('Transkrip', style: AppType.title(c.ink)),
                  ),
                ),
                const SizedBox(height: AppSpace.s8),
                Padding(
                  padding: _margin,
                  child: Column(
                    children: [
                      for (final t in dialog.turns) ...[
                        ChatBubble(
                            text: t.text, fromInterviewer: t.byInterviewer),
                        const SizedBox(height: AppSpace.s12),
                      ],
                    ],
                  ),
                ),
              ],
              const SizedBox(height: AppSpace.s16),
            ],
          ),
          footer: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppButton(
                label:
                    _transcript ? 'Sembunyikan transkrip' : 'Lihat transkrip',
                variant: AppButtonVariant.secondary,
                onPressed: () => setState(() => _transcript = !_transcript),
              ),
              const SizedBox(height: AppSpace.s8),
              AppButton(
                  label: 'Selesai',
                  onPressed: () => context.go(Routes.beranda)),
            ],
          ),
        );
      },
    );
  }
}
