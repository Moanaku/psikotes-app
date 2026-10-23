import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_top_bar.dart';
import '../../core/widgets/empty_view.dart';
import '../../core/widgets/error_view.dart';
import '../../core/widgets/list_row.dart';
import '../../core/widgets/note_box.dart';
import '../../core/widgets/skeleton_list.dart';
import '../../core/widgets/status_tag.dart';
import '../../domain/models/notebook.dart';
import '../../domain/providers.dart';
import '../../domain/services/company_log_form.dart';
import '../../domain/services/profile_templates.dart';
import '../../domain/services/profile_validation.dart';
import 'capture_provider.dart';

/// S13 Catatan psikotes (F10): tes asli yang pernah dijalani, tag tipe baru,
/// dan saran latihan untuk tipe yang belum punya soal Capture.
class CompanyLogScreen extends ConsumerWidget {
  const CompanyLogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logs = ref.watch(companyLogsProvider);
    final questions = ref.watch(capturedQuestionsProvider).valueOrNull ??
        const <CapturedQuestion>[];
    void back() =>
        context.canPop() ? context.pop() : context.go(Routes.psikotes);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            AppTopBar(title: 'Catatan psikotes', onBack: back),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: AppSpace.s16),
                child: logs.when(
                  loading: () => const SkeletonList(
                    rows: 4,
                    semanticLabel: 'Memuat catatan tes',
                  ),
                  error: (_, __) => ErrorView(
                    title: 'Catatan tes tidak bisa dibuka',
                    message: 'Data catatan gagal dibaca. Ketuk coba lagi. '
                        'Catatanmu tidak hilang.',
                    onRetry: () => ref.invalidate(companyLogsProvider),
                  ),
                  data: (items) => _content(context, items, questions),
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
    List<CompanyTestLog> items,
    List<CapturedQuestion> questions,
  ) {
    final c = context.tokens.colors;
    void add() => unawaited(context.push(Routes.catatanTesBaru));
    if (items.isEmpty) {
      return EmptyView(
        title: 'Belum ada catatan tes',
        message: 'Catat tes yang kamu jalani agar profil tes makin akurat.',
        actionLabel: 'Tambah catatan tes',
        onAction: add,
      );
    }
    final suggestions = NoteSuggestions.pending(items, questions);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.s16),
          child: Text(
            'Catat tes yang kamu jalani agar profil tes makin akurat.',
            style: AppType.body(c.inkMuted),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(AppSpace.s16),
          child: AppButton(
            label: 'Tambah catatan tes',
            icon: AppIcons.plus,
            onPressed: add,
          ),
        ),
        if (NoteSuggestions.hasTags(items)) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.s16,
              AppSpace.s8,
              AppSpace.s16,
              AppSpace.s8,
            ),
            child: Semantics(
              header: true,
              child: Text('Saran dari catatanmu', style: AppType.title(c.ink)),
            ),
          ),
          if (suggestions.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpace.s16),
              child: NoteBox(
                icon: AppIcons.check,
                text: 'Semua tipe baru di catatanmu sudah punya soal Capture.',
              ),
            )
          else ...[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpace.s16),
              child: NoteBox(
                icon: AppIcons.bulb,
                text: 'Tipe ini muncul di tes aslimu tetapi belum ada soal '
                    'latihannya. Simpan satu soal untuk tiap tipe.',
              ),
            ),
            const SizedBox(height: AppSpace.s8),
            for (final s in suggestions)
              ListRow(
                title: 'Tambah soal untuk ${s.tipe}',
                leading: AppIcons.plus,
                onTap: () => unawaited(
                  context.push(Routes.capturePath(
                    logId: s.logId,
                    tipe: s.tipe,
                  )),
                ),
              ),
          ],
        ],
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.s16,
            AppSpace.s24,
            AppSpace.s16,
            AppSpace.s4,
          ),
          child: Semantics(
            header: true,
            child: Text(
              'Tes yang pernah kamu jalani',
              style: AppType.title(c.ink),
            ),
          ),
        ),
        for (final log in items) _LogEntry(log: log),
      ],
    );
  }
}

/// Satu catatan: nama, tanggal, tag subtes, tag tipe baru, catatan, dan aksi
/// "Tambah soal". Baris dengan garis pemisah, bukan kartu.
class _LogEntry extends StatelessWidget {
  const _LogEntry({required this.log});

  final CompanyTestLog log;

  @override
  Widget build(BuildContext context) {
    final c = context.tokens.colors;
    return Semantics(
      container: true,
      child: SizedBox(
        width: double.infinity,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: c.outlineVariant)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.s16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  log.perusahaan,
                  style:
                      AppType.body(c.ink).copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: AppSpace.s4),
                Text(
                  ProfileValidation.formatDate(log.tanggal),
                  style: AppType.label(c.inkMuted),
                ),
                if (log.subtes.isNotEmpty || log.tipeBaru.isNotEmpty) ...[
                  const SizedBox(height: AppSpace.s8),
                  Wrap(
                    spacing: AppSpace.s8,
                    runSpacing: AppSpace.s8,
                    children: [
                      for (final s in log.subtes)
                        StatusTag(label: ProfileTemplates.categoryName(s)),
                      for (final t in log.tipeBaru)
                        StatusTag(
                          label: 'Tipe baru: $t',
                          kind: StatusTagKind.attention,
                        ),
                    ],
                  ),
                ],
                if (log.catatan.isNotEmpty) ...[
                  const SizedBox(height: AppSpace.s8),
                  Text(log.catatan, style: AppType.body(c.ink)),
                ],
                const SizedBox(height: AppSpace.s12),
                AppButton(
                  label: 'Tambah soal',
                  icon: AppIcons.plus,
                  variant: AppButtonVariant.outline,
                  expand: false,
                  onPressed: () => unawaited(
                    context.push(Routes.capturePath(logId: log.id)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
