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
import '../../core/widgets/note_box.dart';
import '../../core/widgets/option_tile.dart';
import '../../core/widgets/score_bar.dart';
import '../../core/widgets/skeleton_list.dart';
import '../../domain/providers.dart';
import '../../domain/services/personality.dart';
import '../../domain/services/profile_templates.dart';
import '../../domain/services/session_plan_builder.dart';
import '../onboarding/onboarding_frame.dart';
import 'personality_providers.dart';

const String _title = 'Papi-style';

const String _disclaimer = 'Tidak ada jawaban benar atau salah. Hasilnya '
    'edukatif, bukan diagnosis.';

/// S14 Sesi kepribadian (F12). Soal ditentukan [seed]: pasangan pernyataan
/// dari dua sifat berbeda. Pilihan hanya disimpan di layar ini (A103).
class PersonalityScreen extends ConsumerStatefulWidget {
  const PersonalityScreen({super.key, required this.seed});

  final int seed;

  @override
  ConsumerState<PersonalityScreen> createState() => _PersonalityScreenState();
}

class _PersonalityScreenState extends ConsumerState<PersonalityScreen> {
  final _scroll = ScrollController();
  final Map<int, int> _choices = {};
  var _index = 0;
  var _review = false;
  var _confirmExit = false;
  PersonalityPool? _builtFor;
  List<PersonalityItem> _items = const [];

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  List<PersonalityItem> _itemsOf(PersonalityPool pool) {
    if (!identical(pool, _builtFor)) {
      _builtFor = pool;
      _items = PersonalityPairs.build(pool, widget.seed);
    }
    return _items;
  }

  void _toTop() {
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _leave() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.psikotes);
    }
  }

  void _restart() {
    var seed = SessionPlanBuilder.seedBase(ref.read(clockProvider).now());
    if (seed == widget.seed) seed++;
    context.pushReplacement(Routes.kepribadianPath(seed));
  }

  /// Keluar langsung bila belum ada pilihan atau sudah di review.
  void _requestExit() {
    if (_choices.isEmpty || _review) {
      _leave();
    } else {
      setState(() => _confirmExit = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pool = ref.watch(personalityPoolProvider);
    final header = AppTopBar(
      title: _title,
      onBack: _requestExit,
      backIcon: AppIcons.close,
      backLabel: 'Tutup sesi kepribadian',
    );
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _requestExit();
      },
      child: pool.when(
        loading: () => _Frame(
          header: header,
          child: const SkeletonList(
            rows: 3,
            semanticLabel: 'Memuat pernyataan',
          ),
        ),
        error: (_, __) => _Frame(
          header: header,
          child: ErrorView(
            title: 'Pernyataan tidak terbaca',
            message: 'Berkas pernyataan di app rusak atau tidak ada. Coba '
                'lagi, atau buka ulang app.',
            onRetry: () => ref.invalidate(personalityPoolProvider),
          ),
        ),
        data: (pool) {
          final items = _itemsOf(pool);
          if (items.isEmpty) {
            return _Frame(
              header: header,
              child: EmptyView(
                title: 'Belum ada pernyataan',
                message: 'Pool kepribadian di app ini kosong.',
                actionLabel: 'Kembali ke katalog',
                onAction: _leave,
              ),
            );
          }
          return _review
              ? _reviewView(header, pool, items)
              : _question(header, items);
        },
      ),
    );
  }

  Widget _question(Widget header, List<PersonalityItem> items) {
    final c = context.tokens.colors;
    final item = items[_index];
    final picked = _choices[_index];
    final last = _index == items.length - 1;
    const margin = EdgeInsets.symmetric(horizontal: AppSpace.s16);
    return OnboardingFrame(
      scrollController: _scroll,
      header: header,
      footerMaxShare:
          _confirmExit ? confirmFooterMaxShare : defaultFooterMaxShare,
      footer: _confirmExit
          ? _exitPanel()
          : FooterButtons(
              flex: const [10, 13],
              buttons: [
                AppButton(
                  label: 'Sebelumnya',
                  variant: AppButtonVariant.secondary,
                  onPressed: _index == 0
                      ? null
                      : () {
                          setState(() => _index--);
                          _toTop();
                        },
                ),
                AppButton(
                  label: last ? 'Lihat profil' : 'Berikutnya',
                  onPressed: picked == null
                      ? null
                      : () {
                          setState(() {
                            if (last) {
                              _review = true;
                            } else {
                              _index++;
                            }
                          });
                          _toTop();
                        },
                ),
              ],
            ),
      children: [
        const SizedBox(height: AppSpace.s8),
        Padding(
          padding: margin,
          child: ScoreBar(
            label: 'Soal ${_index + 1} dari ${items.length}',
            value: _choices.length / items.length,
            valueLabel: '${_choices.length} dijawab',
          ),
        ),
        const SizedBox(height: AppSpace.s24),
        Padding(
          padding: margin,
          child: Semantics(
            header: true,
            child: Text(
              'Pilih yang paling menggambarkan dirimu.',
              // Body, bukan judul: "menggambarkan" dalam 20 sp tidak muat
              // satu baris di 360 dp skala 2,0.
              style: AppType.body(c.ink).copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(height: AppSpace.s16),
        for (var i = 0; i < 2; i++) ...[
          if (i > 0) const SizedBox(height: AppSpace.s12),
          Padding(
            padding: margin,
            child: OptionTile(
              letter: i == 0 ? 'A' : 'B',
              label: item.option(i).teks,
              selected: picked == i,
              onTap: () => setState(() {
                _choices[_index] = i;
                _confirmExit = false;
              }),
            ),
          ),
        ],
        const SizedBox(height: AppSpace.s24),
        const Padding(
          padding: margin,
          child: NoteBox(icon: AppIcons.bulb, text: _disclaimer),
        ),
      ],
    );
  }

  Widget _exitPanel() => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const NoteBox(
            icon: AppIcons.alert,
            text: 'Pilihanmu di sesi ini tidak disimpan. Bila keluar, kamu '
                'mulai dari awal lagi.',
          ),
          const SizedBox(height: AppSpace.s12),
          FooterButtons(
            buttons: [
              AppButton(
                label: 'Tetap mengerjakan',
                variant: AppButtonVariant.secondary,
                onPressed: () => setState(() => _confirmExit = false),
              ),
              AppButton(label: 'Keluar dari sesi', onPressed: _leave),
            ],
          ),
        ],
      );

  Widget _reviewView(
    Widget header,
    PersonalityPool pool,
    List<PersonalityItem> items,
  ) {
    final c = context.tokens.colors;
    final tallies = PersonalityProfile.tally(pool, items, _choices);
    final role = ref.watch(activeProfileProvider).valueOrNull?.role;
    const margin = EdgeInsets.symmetric(horizontal: AppSpace.s16);

    Widget heading(String text) => Padding(
          padding: margin,
          child: Semantics(
            header: true,
            child: Text(text, style: AppType.title(c.ink)),
          ),
        );

    final sought = role == null
        ? const <PersonalityTrait>[]
        : [
            for (final t in pool.traits)
              if (t.relevansiRole[role.code] == 'tinggi') t,
          ];

    return OnboardingFrame(
      scrollController: _scroll,
      header: header,
      footer: FooterButtons(
        buttons: [
          AppButton(
            label: 'Kembali ke katalog',
            variant: AppButtonVariant.secondary,
            onPressed: _leave,
          ),
          AppButton(label: 'Ulangi dengan soal baru', onPressed: _restart),
        ],
      ),
      children: [
        const SizedBox(height: AppSpace.s8),
        heading('Profil kecenderungan'),
        const SizedBox(height: AppSpace.s8),
        Padding(
          padding: margin,
          child: Text(
            'Seberapa sering kamu memilih pernyataan tiap sifat, dari '
            '${items.length} soal.',
            style: AppType.body(c.inkMuted),
          ),
        ),
        const SizedBox(height: AppSpace.s16),
        for (final t in tallies) ...[
          Padding(
            padding: margin,
            child: ScoreBar(
              label: t.trait.nama,
              value: t.share,
              valueLabel: 'dipilih ${t.chosen} dari ${t.shown}',
            ),
          ),
          const SizedBox(height: AppSpace.s4),
          Padding(
            padding: margin,
            child: Text(t.trait.arti, style: AppType.label(c.inkMuted)),
          ),
          const SizedBox(height: AppSpace.s16),
        ],
        const Padding(
          padding: margin,
          child: NoteBox(icon: AppIcons.bulb, text: _disclaimer),
        ),
        const SizedBox(height: AppSpace.s24),
        heading(role == null
            ? 'Sifat yang dicari per role'
            : 'Untuk ${ProfileTemplates.roleName(role)}'),
        const SizedBox(height: AppSpace.s8),
        Padding(
          padding: margin,
          child: Text(
            sought.isEmpty
                ? 'Profilmu tidak memakai role QA, Mobile Dev, atau IT BA, '
                    'jadi sifat per role tidak ditampilkan.'
                : 'Lowongan ini umumnya mencari: '
                    '${sought.map((t) => t.nama.toLowerCase()).join(', ')}. '
                    'Ini gambaran umum, bukan syarat lulus.',
            style: AppType.body(c.ink),
          ),
        ),
        const SizedBox(height: AppSpace.s24),
        for (var i = 0; i < items.length; i++)
          if (_choices[i] case final pick?)
            _ChoiceMeaning(
              number: i + 1,
              chosen: items[i].option(pick),
              other: items[i].option(1 - pick),
              pool: pool,
            ),
      ],
    );
  }
}

/// "Arti pilihanmu di soal [n]": pernyataan yang dipilih dan sifatnya.
class _ChoiceMeaning extends StatelessWidget {
  const _ChoiceMeaning({
    required this.number,
    required this.chosen,
    required this.other,
    required this.pool,
  });

  final int number;
  final PersonalityStatement chosen;
  final PersonalityStatement other;
  final PersonalityPool pool;

  @override
  Widget build(BuildContext context) {
    final c = context.tokens.colors;
    final mine = pool.trait(chosen.traitId);
    final theirs = pool.trait(other.traitId);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.s16,
        vertical: AppSpace.s12,
      ),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: c.outlineVariant)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Arti pilihanmu di soal $number',
            style: AppType.label(c.ink).copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpace.s4),
          Text(chosen.teks, style: AppType.body(c.ink)),
          const SizedBox(height: AppSpace.s4),
          Text(
            'Menggambarkan ${mine.nama.toLowerCase()}: '
            '${mine.arti[0].toLowerCase()}${mine.arti.substring(1)} '
            'Pilihan lain menggambarkan ${theirs.nama.toLowerCase()}.',
            style: AppType.label(c.inkMuted),
          ),
        ],
      ),
    );
  }
}

/// Rangka kondisi memuat, galat, dan kosong.
class _Frame extends StatelessWidget {
  const _Frame({required this.header, required this.child});

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
