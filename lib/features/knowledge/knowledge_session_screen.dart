import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/app_top_bar.dart';
import '../../core/widgets/empty_view.dart';
import '../../core/widgets/list_row.dart';
import '../../core/widgets/note_box.dart';
import '../../core/widgets/score_bar.dart';
import '../../core/widgets/status_tag.dart';
import '../../domain/models/knowledge.dart';
import '../../domain/providers.dart';
import '../../domain/services/knowledge_service.dart';
import '../onboarding/onboarding_frame.dart';
import 'knowledge_providers.dart';

const EdgeInsets _margin = EdgeInsets.symmetric(horizontal: AppSpace.s16);

/// S20 Sesi kartu (F17): menjawab, membuka jawaban model, lalu menilai diri.
/// Jawaban tertulis hanya hidup di layar ini dan tidak disimpan (A107);
/// penilaian tiap kartu langsung tersimpan.
class KnowledgeSessionScreen extends ConsumerStatefulWidget {
  const KnowledgeSessionScreen({super.key, required this.sessionId});

  final int sessionId;

  @override
  ConsumerState<KnowledgeSessionScreen> createState() =>
      _KnowledgeSessionScreenState();
}

class _KnowledgeSessionScreenState
    extends ConsumerState<KnowledgeSessionScreen> {
  final _scroll = ScrollController();
  final _answer = TextEditingController();
  final Map<String, bool> _results = {};
  final Set<int> _checked = {};
  var _index = 0;
  var _revealed = false;
  var _saving = false;
  var _saveFailed = false;

  @override
  void dispose() {
    _scroll.dispose();
    _answer.dispose();
    super.dispose();
  }

  void _leave() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.pengetahuan);
    }
  }

  Future<void> _judge(KnowledgeItem item, {required bool paham}) async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _saveFailed = false;
    });
    try {
      await ref.read(knowledgeServiceProvider).judge(item, paham: paham);
      if (!mounted) return;
      setState(() {
        _saving = false;
        _results[item.id] = paham;
        _index++;
        _revealed = false;
        _checked.clear();
        _answer.clear();
      });
      if (_scroll.hasClients) _scroll.jumpTo(0);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _saveFailed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final plan = ref.watch(
      knowledgeSessionsProvider.select((s) => s[widget.sessionId]),
    );
    if (plan == null) {
      return Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              AppTopBar(
                title: 'Sesi kartu',
                onBack: _leave,
                backIcon: AppIcons.close,
                backLabel: 'Tutup sesi kartu',
              ),
              EmptyView(
                title: 'Sesi kartu tidak ditemukan',
                message: 'Sesi hanya ada selama app terbuka. Kemajuanmu '
                    'tetap tersimpan. Mulai sesi baru dari bank pengetahuan.',
                actionLabel: 'Ke bank pengetahuan',
                onAction: () => context.go(Routes.pengetahuan),
              ),
            ],
          ),
        ),
      );
    }
    final header = AppTopBar(
      title: '${plan.role.label}, level ${plan.level.label}',
      onBack: _leave,
      backIcon: AppIcons.close,
      backLabel: 'Tutup sesi kartu',
    );
    if (_index >= plan.items.length) return _summary(plan, header);
    return _card(plan, header, plan.items[_index]);
  }

  Widget _card(KnowledgeSessionPlan plan, Widget header, KnowledgeItem item) {
    final c = context.tokens.colors;
    final lanjut = item.level == KnowledgeLevel.lanjut;
    final total = item.poinKunci.length;
    final needed = KeyPointScoring.needed(total);
    final canPaham = _revealed &&
        (!lanjut || KeyPointScoring.passes(_checked.length, total));
    return OnboardingFrame(
      scrollController: _scroll,
      header: header,
      footer: FooterButtons(
        flex: const [1, 1],
        buttons: [
          AppButton(
            label: 'Belum paham',
            variant: AppButtonVariant.secondary,
            onPressed:
                !_revealed || _saving ? null : () => _judge(item, paham: false),
          ),
          AppButton(
            label: 'Sudah paham',
            onPressed:
                !canPaham || _saving ? null : () => _judge(item, paham: true),
          ),
        ],
      ),
      children: [
        const SizedBox(height: AppSpace.s8),
        Padding(
          padding: _margin,
          child: ScoreBar(
            label: 'Kartu ${_index + 1} dari ${plan.items.length}',
            value: _index / plan.items.length,
            valueLabel: '$_index dinilai',
          ),
        ),
        const SizedBox(height: AppSpace.s16),
        Padding(
          padding: _margin,
          child: Wrap(
            spacing: AppSpace.s8,
            runSpacing: AppSpace.s8,
            children: [
              StatusTag(label: item.topikLabel),
              if (item.needsVerification)
                const StatusTag(
                  label: 'Perlu verifikasi',
                  kind: StatusTagKind.attention,
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpace.s12),
        Padding(
          padding: _margin,
          child: Semantics(
            header: true,
            child: Text(item.pertanyaan, style: AppType.title(c.ink)),
          ),
        ),
        const SizedBox(height: AppSpace.s16),
        Padding(
          padding: _margin,
          child: AppTextField(
            label: 'Jawabanmu (boleh dikosongkan)',
            controller: _answer,
            minLines: 3,
            maxLines: 6,
            keyboardType: TextInputType.multiline,
            enabled: !_revealed,
          ),
        ),
        const SizedBox(height: AppSpace.s16),
        if (!_revealed)
          Padding(
            padding: _margin,
            child: AppButton(
              label: 'Buka jawaban',
              variant: AppButtonVariant.outline,
              onPressed: () => setState(() => _revealed = true),
            ),
          )
        else ...[
          _Section(title: 'Jawaban model', body: item.jawabanModel),
          const SizedBox(height: AppSpace.s24),
          Padding(
            padding: _margin,
            child: Semantics(
              header: true,
              child: Text('Poin kunci', style: AppType.title(c.ink)),
            ),
          ),
          if (lanjut) ...[
            const SizedBox(height: AppSpace.s4),
            Padding(
              padding: _margin,
              child: Text(
                'Centang poin yang sudah ada di jawabanmu. Paling sedikit '
                '$needed dari $total untuk menandai paham.',
                style: AppType.label(c.inkMuted),
              ),
            ),
            const SizedBox(height: AppSpace.s8),
            for (var i = 0; i < total; i++)
              Semantics(
                checked: _checked.contains(i),
                child: ListRow(
                  title: item.poinKunci[i],
                  trailing: _checked.contains(i)
                      ? const StatusTag(
                          label: 'Ada',
                          kind: StatusTagKind.strong,
                        )
                      : const StatusTag(label: 'Belum'),
                  onTap: () => setState(() {
                    if (!_checked.add(i)) _checked.remove(i);
                  }),
                ),
              ),
          ] else ...[
            const SizedBox(height: AppSpace.s8),
            for (final p in item.poinKunci) _Bullet(text: p),
          ],
          const SizedBox(height: AppSpace.s16),
          Padding(
            padding: _margin,
            child: Text(
              item.sumber == null
                  ? 'Belum ada sumber. Periksa sendiri sebelum dipercaya.'
                  : 'Sumber: ${item.sumber}',
              style: AppType.label(c.inkMuted),
            ),
          ),
        ],
        if (_saveFailed)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.s16,
              AppSpace.s16,
              AppSpace.s16,
              0,
            ),
            child: Semantics(
              liveRegion: true,
              child: const NoteBox(
                icon: AppIcons.alert,
                text: 'Penilaian belum tersimpan. Data di perangkat gagal '
                    'ditulis. Ketuk sekali lagi.',
              ),
            ),
          ),
      ],
    );
  }

  Widget _summary(KnowledgeSessionPlan plan, Widget header) {
    final c = context.tokens.colors;
    final paham = _results.values.where((v) => v).length;
    final belum = _results.length - paham;
    return OnboardingFrame(
      header: header,
      footer: FooterButtons(
        flex: const [1, 1],
        buttons: [
          AppButton(
            label: 'Buku kesalahan',
            variant: AppButtonVariant.secondary,
            onPressed: () => unawaited(context.push(Routes.bukuKesalahan)),
          ),
          AppButton(label: 'Ke bank pengetahuan', onPressed: _leave),
        ],
      ),
      children: [
        const SizedBox(height: AppSpace.s16),
        Padding(
          padding: _margin,
          child: Semantics(
            header: true,
            child: Text('Sesi selesai', style: AppType.title(c.ink)),
          ),
        ),
        const SizedBox(height: AppSpace.s8),
        Padding(
          padding: _margin,
          child: Text(
            '${_results.length} kartu dinilai.',
            style: AppType.body(c.ink),
          ),
        ),
        ListRow(
          leading: AppIcons.check,
          title: 'Sudah paham',
          subtitle: '$paham kartu',
          divider: true,
        ),
        ListRow(
          leading: AppIcons.book,
          title: 'Belum paham',
          subtitle:
              belum == 0 ? 'Tidak ada' : '$belum kartu masuk ke buku kesalahan',
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final c = context.tokens.colors;
    return Padding(
      padding: _margin,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(title, style: AppType.title(c.ink)),
          ),
          const SizedBox(height: AppSpace.s8),
          Text(body, style: AppType.body(c.ink)),
        ],
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.tokens.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.s16,
        0,
        AppSpace.s16,
        AppSpace.s8,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('•', style: AppType.body(c.ink)),
          const SizedBox(width: AppSpace.s8),
          Expanded(child: Text(text, style: AppType.body(c.ink))),
        ],
      ),
    );
  }
}
