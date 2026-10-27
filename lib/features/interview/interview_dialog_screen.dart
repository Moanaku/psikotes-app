import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../ai/ai_coach.dart';
import '../../app/routes.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/text_scale.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_icon_button.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/app_top_bar.dart';
import '../../core/widgets/chat_bubble.dart';
import '../../core/widgets/note_box.dart';
import '../../core/widgets/score_bar.dart';
import '../../core/widgets/status_tag.dart';
import 'interview_providers.dart';

const EdgeInsets _margin = EdgeInsets.symmetric(horizontal: AppSpace.s16);

/// S16 Dialog wawancara. Memutar dialog contoh tertulis (A108).
class InterviewDialogScreen extends ConsumerStatefulWidget {
  const InterviewDialogScreen({super.key});

  @override
  ConsumerState<InterviewDialogScreen> createState() =>
      _InterviewDialogScreenState();
}

class _InterviewDialogScreenState extends ConsumerState<InterviewDialogScreen> {
  final _answer = TextEditingController();
  final _scroll = ScrollController();

  @override
  void dispose() {
    _answer.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _toBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  void _send() {
    final text = _answer.text;
    if (text.trim().isEmpty) return;
    _answer.clear();
    unawaited(ref.read(interviewDialogProvider.notifier).send(text));
  }

  void _finish() => unawaited(context.push(Routes.wawancaraLaporanPath(1)));

  @override
  Widget build(BuildContext context) {
    final c = context.tokens.colors;
    final s = ref.watch(interviewDialogProvider);
    final setup = ref.watch(interviewSetupProvider);
    final total = ref.read(aiCoachProvider).topicCount;
    ref.listen(interviewDialogProvider, (_, __) => _toBottom());
    final large = isLargeText(context);
    final canSend = !s.typing && !s.finished && s.turns.isNotEmpty;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            AppTopBar(
              title: setup.persona.title,
              onBack: () => context.canPop()
                  ? context.pop()
                  : context.go(Routes.wawancara),
              actions: large
                  ? const []
                  : [
                      AppButton(
                        label: 'Akhiri',
                        variant: AppButtonVariant.outline,
                        expand: false,
                        onPressed: _finish,
                      ),
                    ],
            ),
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
                    child: Text('Dialog tertulis, bukan AI',
                        style: AppType.label(c.inkMuted)),
                  ),
                ],
              ),
            ),
            if (large) ...[
              const SizedBox(height: AppSpace.s8),
              Padding(
                padding: _margin,
                child: AppButton(
                  label: 'Akhiri',
                  variant: AppButtonVariant.outline,
                  onPressed: _finish,
                ),
              ),
            ],
            const SizedBox(height: AppSpace.s8),
            Padding(
              padding: _margin,
              child: ScoreBar(
                label: 'Topik ${s.topic} dari $total, mode ${setup.mode.label}',
                value: (s.topic / total).clamp(0.0, 1.0),
                valueLabel: '${s.topic}/$total',
              ),
            ),
            const SizedBox(height: AppSpace.s12),
            Expanded(
              child: ListView(
                controller: _scroll,
                padding: _margin,
                children: [
                  for (final t in s.turns) ...[
                    ChatBubble(text: t.text, fromInterviewer: t.byInterviewer),
                    const SizedBox(height: AppSpace.s12),
                  ],
                  if (setup.mode == InterviewMode.latihan &&
                      !s.finished &&
                      s.turns.isNotEmpty) ...[
                    const NoteBox(
                      icon: AppIcons.bulb,
                      text: 'Petunjuk (hanya di mode Latihan): sebutkan '
                          'peranmu sendiri, angka atau hasil, dan susun '
                          'dengan pola STAR.',
                    ),
                    const SizedBox(height: AppSpace.s12),
                  ],
                  if (s.typing) ...[
                    const ChatBubble.typing(),
                    const SizedBox(height: AppSpace.s12),
                  ],
                  if (s.failed) ...[
                    Semantics(
                      liveRegion: true,
                      child: const NoteBox(
                        icon: AppIcons.alert,
                        text: 'Pewawancara tidak menjawab. Jawabanmu '
                            'tersimpan. Coba kirim lagi.',
                      ),
                    ),
                    const SizedBox(height: AppSpace.s8),
                    AppButton(
                      label: 'Kirim ulang',
                      variant: AppButtonVariant.outline,
                      expand: false,
                      onPressed: () => unawaited(
                        ref.read(interviewDialogProvider.notifier).retry(),
                      ),
                    ),
                    const SizedBox(height: AppSpace.s12),
                  ],
                  if (s.finished)
                    AppButton(label: 'Lihat laporan', onPressed: _finish),
                ],
              ),
            ),
            if (!s.finished)
              DecoratedBox(
                decoration: BoxDecoration(
                  color: c.surfaceContainer,
                  border: Border(top: BorderSide(color: c.outlineVariant)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpace.s16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: AppTextField(
                          label: 'Jawabanmu',
                          controller: _answer,
                          maxLines: 4,
                          keyboardType: TextInputType.multiline,
                          enabled: canSend || s.turns.isEmpty,
                        ),
                      ),
                      const AppIconButton(
                        icon: AppIcons.mic,
                        label: 'Jawab dengan suara, tersedia di v1.3',
                        onPressed: null,
                      ),
                      AppIconButton(
                        icon: AppIcons.send,
                        label: 'Kirim jawaban',
                        onPressed: canSend ? _send : null,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
