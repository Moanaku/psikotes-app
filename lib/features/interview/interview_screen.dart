import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../ai/ai_coach.dart';
import '../../app/routes.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_chip.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/app_top_bar.dart';
import '../../core/widgets/choice_row.dart';
import '../../core/widgets/error_view.dart';
import '../../core/widgets/list_row.dart';
import '../../core/widgets/note_box.dart';
import '../../core/widgets/offline_view.dart';
import '../../core/widgets/skeleton_list.dart';
import '../../core/widgets/status_tag.dart';
import '../../domain/providers.dart';
import 'interview_providers.dart';

const EdgeInsets _margin = EdgeInsets.symmetric(horizontal: AppSpace.s16);

/// S15 Setup wawancara. Tombol memutar dialog contoh tertulis (T29); belum ada
/// AI yang menjawab (A108).
class InterviewScreen extends ConsumerStatefulWidget {
  const InterviewScreen({super.key});

  @override
  ConsumerState<InterviewScreen> createState() => _InterviewScreenState();
}

class _InterviewScreenState extends ConsumerState<InterviewScreen> {
  final _job = TextEditingController();

  @override
  void dispose() {
    _job.dispose();
    super.dispose();
  }

  void _start() {
    unawaited(ref.read(interviewDialogProvider.notifier).start());
    unawaited(context.push(Routes.wawancaraDialogPath(1)));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.tokens.colors;
    final gate = ref.watch(interviewGateProvider);
    final setup = ref.watch(interviewSetupProvider);
    final notifier = ref.read(interviewSetupProvider.notifier);
    final used = ref.watch(interviewSessionsUsedProvider);
    final profile = ref.watch(activeProfileProvider).valueOrNull;
    final hasCv = (profile?.cvTeks ?? '').trim().isNotEmpty;
    const header = AppTopBar(title: 'Wawancara berbasis CV');

    Widget frame(List<Widget> body, {Widget? footer}) => Column(
          children: [
            header,
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: AppSpace.s16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: body,
                ),
              ),
            ),
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
        );

    return gate.when(
      loading: () => frame(const [
        SkeletonList(rows: 4, semanticLabel: 'Memuat pengaturan wawancara'),
      ]),
      error: (_, __) => frame([
        ErrorView(
          title: 'Pengaturan wawancara tidak terbaca',
          message: 'Data di perangkat gagal dibaca. Ketuk coba lagi.',
          onRetry: () => ref.invalidate(interviewGateProvider),
        ),
      ]),
      data: (g) {
        final blocked = g != InterviewGate.ready;
        final form = <Widget>[
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
                  child: Text(
                    'Sisa ${(interviewDailyLimit - used).clamp(0, interviewDailyLimit)}'
                    ' / $interviewDailyLimit hari ini',
                    style: AppType.label(c.inkMuted),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.s8),
          const Padding(
            padding: _margin,
            child: NoteBox(
              text: 'Tampilan contoh. Tombol di bawah memutar dialog tertulis; '
                  'belum ada AI yang menjawab.',
            ),
          ),
          if (g == InterviewGate.noKey) ...[
            const SizedBox(height: AppSpace.s16),
            Padding(
              padding: _margin,
              child: Semantics(
                liveRegion: true,
                child: const NoteBox(
                  icon: AppIcons.key,
                  text: 'Wawancara butuh API key Gemini atau Groq milikmu.',
                ),
              ),
            ),
            const SizedBox(height: AppSpace.s8),
            Padding(
              padding: _margin,
              child: AppButton(
                label: 'Isi key di Pengaturan',
                variant: AppButtonVariant.outline,
                onPressed: () => unawaited(context.push(Routes.pengaturan)),
              ),
            ),
          ],
          if (g == InterviewGate.limitReached) ...[
            const SizedBox(height: AppSpace.s16),
            Padding(
              padding: _margin,
              child: Semantics(
                liveRegion: true,
                child: const NoteBox(
                  icon: AppIcons.alert,
                  text: 'Batas $interviewDailyLimit sesi hari ini sudah '
                      'terpakai. Pakai kartu pertanyaan template atau coba '
                      'lagi besok.',
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSpace.s24),
          Padding(
            padding: _margin,
            child: Text('Pewawancara',
                style:
                    AppType.label(c.ink).copyWith(fontWeight: FontWeight.w600)),
          ),
          for (final p in InterviewPersona.values)
            ChoiceRow(
              title: p.label,
              subtitle: p.focus,
              selected: setup.persona == p,
              onTap: () => notifier.update((s) => s.copyWith(persona: p)),
            ),
          const SizedBox(height: AppSpace.s8),
          ListRow(
            title: 'CV',
            subtitle:
                hasCv ? 'Tersimpan dari profil' : 'Belum ada CV di profil',
            trailing: profile?.id == null
                ? null
                : AppButton(
                    label: 'Ubah',
                    variant: AppButtonVariant.outline,
                    expand: false,
                    onPressed: () => unawaited(
                      context.push(Routes.profilUbah(profile!.id!)),
                    ),
                  ),
          ),
          const SizedBox(height: AppSpace.s16),
          Padding(
            padding: _margin,
            child: AppTextField(
              label: 'Deskripsi lowongan',
              controller: _job,
              hint: 'Tempel deskripsi lowongan yang dilamar',
              minLines: 3,
              maxLines: 6,
              keyboardType: TextInputType.multiline,
              onChanged: (v) => notifier.update((s) => s.copyWith(jobText: v)),
            ),
          ),
          const SizedBox(height: AppSpace.s16),
          Padding(
            padding: _margin,
            child: Text('Bahasa',
                style:
                    AppType.label(c.ink).copyWith(fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: AppSpace.s8),
          Padding(
            padding: _margin,
            child: Wrap(
              spacing: AppSpace.s8,
              runSpacing: AppSpace.s8,
              children: [
                for (final l in InterviewLanguage.values)
                  AppChip(
                    label: l.label,
                    selected: setup.language == l,
                    onTap: () =>
                        notifier.update((s) => s.copyWith(language: l)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.s16),
          Padding(
            padding: _margin,
            child: Text('Mode',
                style:
                    AppType.label(c.ink).copyWith(fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: AppSpace.s8),
          Padding(
            padding: _margin,
            child: Wrap(
              spacing: AppSpace.s8,
              runSpacing: AppSpace.s8,
              children: [
                for (final m in InterviewMode.values)
                  AppChip(
                    label: m.label,
                    selected: setup.mode == m,
                    onTap: () => notifier.update((s) => s.copyWith(mode: m)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.s16),
          const Padding(
            padding: _margin,
            child: NoteBox(
              icon: AppIcons.lock,
              text: 'Saat wawancara AI tersedia, nomor HP, email, dan alamat '
                  'dihapus dari CV sebelum dikirim. Sekarang belum ada yang '
                  'dikirim ke mana pun.',
            ),
          ),
        ];

        if (g == InterviewGate.offline) {
          return frame(
            [
              OfflineView(
                message: 'Wawancara dengan AI tidak bisa dipakai sekarang.',
                stillWorks: 'Wawancara memakai kartu pertanyaan template. '
                    'Psikotes tetap jalan seperti biasa.',
                actionLabel: 'Pakai kartu template',
                onAction: _start,
              ),
              ...form,
            ],
          );
        }
        return frame(
          form,
          footer: AppButton(
            label: blocked ? 'Pakai kartu template' : 'Mulai wawancara',
            onPressed: _start,
          ),
        );
      },
    );
  }
}
