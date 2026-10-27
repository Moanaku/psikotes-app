import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:question_engine/question_engine.dart';

import '../../app/routes.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_top_bar.dart';
import '../../core/widgets/empty_view.dart';
import '../../core/widgets/list_row.dart';
import '../../core/widgets/note_box.dart';
import '../../core/widgets/stat_row.dart';
import '../../domain/providers.dart';
import '../../domain/services/kraepelin_run.dart';
import '../../domain/services/session_plan_builder.dart';
import '../onboarding/onboarding_frame.dart';
import '../session/session_widgets.dart' show TimerLabel;
import 'consistency_chart.dart';

const String _title = 'Kraepelin / Pauli';

/// Bilangan pecahan dengan satu angka di belakang koma ("12,5").
String oneDecimal(Fraction f) {
  final tenths = (f * Fraction(10)).roundHalfUp();
  return tenths % 10 == 0
      ? '${tenths ~/ 10}'
      : '${tenths ~/ 10},${tenths % 10}';
}

/// Sesi Kraepelin/Pauli (T23, F13; varian S06). Lembar dari [seed], kolom
/// dan waktu dari [config]. Hasil hanya ada di layar ini (A104).
class KraepelinScreen extends ConsumerStatefulWidget {
  const KraepelinScreen({super.key, required this.seed, required this.config});

  final int seed;
  final KrpConfig config;

  @override
  ConsumerState<KraepelinScreen> createState() => _KraepelinScreenState();
}

class _KraepelinScreenState extends ConsumerState<KraepelinScreen> {
  KraepelinRun? _run;
  Timer? _ticker;
  var _confirmExit = false;

  late final KrpSheet? _sheet = widget.config.isValid
      ? KrpSheet.generate(widget.seed, widget.config)
      : null;

  Duration get _now => ref.read(clockProvider).monotonic();

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _start() {
    setState(() => _run = KraepelinRun(_sheet!, start: _now));
    _ticker = ref.read(tickerFactoryProvider)(
      const Duration(seconds: 1),
      _onTick,
    );
  }

  void _onTick() {
    final run = _run;
    if (run == null || !mounted) return;
    run.tick(_now);
    if (run.finished) _ticker?.cancel();
    setState(() {});
  }

  void _type(int digit) {
    final run = _run!;
    run.input(digit, _now);
    if (run.finished) _ticker?.cancel();
    setState(() {});
  }

  void _leave() {
    _ticker?.cancel();
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.psikotes);
    }
  }

  void _restart() {
    var seed = SessionPlanBuilder.seedBase(ref.read(clockProvider).now());
    if (seed == widget.seed) seed++;
    context.pushReplacement(Routes.kraepelinPath(
      seed,
      columns: widget.config.columns,
      seconds: widget.config.secondsPerColumn,
    ));
  }

  void _requestExit() {
    final run = _run;
    if (run == null || run.finished) {
      _leave();
    } else {
      setState(() => _confirmExit = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final run = _run;
    final header = AppTopBar(
      title: _title,
      onBack: _requestExit,
      backIcon: AppIcons.close,
      backLabel: 'Tutup tes Kraepelin',
    );
    final Widget body;
    if (_sheet == null) {
      body = Scaffold(
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              header,
              EmptyView(
                title: 'Pengaturan tes tidak sah',
                message: 'Jumlah kolom atau waktu per kolom di luar batas. '
                    'Ubah subtes Kraepelin di profil.',
                actionLabel: 'Kembali ke katalog',
                onAction: _leave,
              ),
            ],
          ),
        ),
      );
    } else if (run == null) {
      body = _intro(header);
    } else if (run.finished) {
      body = _result(header, run);
    } else {
      body = _running(header, run);
    }
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _requestExit();
      },
      child: body,
    );
  }

  static const _margin = EdgeInsets.symmetric(horizontal: AppSpace.s16);

  Widget _intro(Widget header) {
    final c = context.tokens.colors;
    final cfg = widget.config;
    return OnboardingFrame(
      header: header,
      footer: AppButton(label: 'Mulai kolom 1', onPressed: _start),
      children: [
        const SizedBox(height: AppSpace.s8),
        Padding(
          padding: _margin,
          child: Text(
            '${cfg.columns} kolom, ${cfg.secondsPerColumn} detik per kolom',
            style: AppType.title(c.ink),
          ),
        ),
        const SizedBox(height: AppSpace.s12),
        Padding(
          padding: _margin,
          child: Text(
            'Jumlahkan dua angka yang bersebelahan dari atas ke bawah, lalu '
            'ketik angka terakhir hasilnya. Contoh: 7 dan 5 menjadi 12, '
            'ketik 2.',
            style: AppType.body(c.ink),
          ),
        ),
        const SizedBox(height: AppSpace.s12),
        Padding(
          padding: _margin,
          child: Text(
            'Kolom berganti sendiri saat waktunya habis. Waktu tetap berjalan '
            'bila app ditinggal.',
            style: AppType.body(c.inkMuted),
          ),
        ),
        const SizedBox(height: AppSpace.s24),
        const Padding(
          padding: _margin,
          child: NoteBox(
            icon: AppIcons.bulb,
            text: 'Jaga ritme. Salah ketik tidak bisa dihapus, sama seperti '
                'tes kertas.',
          ),
        ),
      ],
    );
  }

  Widget _running(Widget header, KraepelinRun run) {
    final c = context.tokens.colors;
    final sheet = run.sheet;
    final digits = sheet.digits[run.column];
    final i = run.index;
    return OnboardingFrame(
      header: header,
      footer: _confirmExit ? _exitPanel() : _keypad(run),
      children: [
        const SizedBox(height: AppSpace.s8),
        Padding(
          padding: _margin,
          child: Text(
            'Kolom ${run.column + 1} dari ${sheet.config.columns}, '
            '$i isian',
            style: AppType.label(c.inkMuted),
          ),
        ),
        // Timer di badan, bukan di bilah atas: di skala 2,0 judul "Kraepelin
        // / Pauli" tidak muat berdampingan dengan timer.
        Padding(
          padding: const EdgeInsets.only(left: AppSpace.s16),
          child: TimerLabel(remaining: run.remaining(_now)),
        ),
        const SizedBox(height: AppSpace.s16),
        if (run.columnFull)
          const Padding(
            padding: _margin,
            child: NoteBox(
              icon: AppIcons.clock,
              text: 'Kolom ini sudah penuh. Kolom berikutnya mulai saat '
                  'waktunya habis.',
            ),
          )
        else
          Center(
            child: Semantics(
              liveRegion: true,
              label: 'Jumlahkan ${digits[i]} dan ${digits[i + 1]}',
              excludeSemantics: true,
              child: Column(
                children: [
                  if (i > 0)
                    Text('${digits[i - 1]}', style: AppType.title(c.inkMuted)),
                  const SizedBox(height: AppSpace.s4),
                  Container(
                    width: AppSpace.s48 * 2,
                    padding: const EdgeInsets.symmetric(vertical: AppSpace.s8),
                    decoration: BoxDecoration(
                      color: c.accent,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Column(
                      children: [
                        Text('${digits[i]}',
                            style: AppType.display(c.onAccent)),
                        Text('${digits[i + 1]}',
                            style: AppType.display(c.onAccent)),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpace.s4),
                  if (i + 2 < digits.length)
                    Text('${digits[i + 2]}', style: AppType.title(c.inkMuted)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _keypad(KraepelinRun run) {
    Widget key(int d) => AppButton(
          label: '$d',
          variant: AppButtonVariant.secondary,
          onPressed: run.columnFull ? null : () => _type(d),
        );
    Widget line(List<int> ds) => Row(
          children: [
            for (var k = 0; k < ds.length; k++) ...[
              if (k > 0) const SizedBox(width: AppSpace.s8),
              Expanded(child: key(ds[k])),
            ],
          ],
        );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        line(const [1, 2, 3]),
        const SizedBox(height: AppSpace.s8),
        line(const [4, 5, 6]),
        const SizedBox(height: AppSpace.s8),
        line(const [7, 8, 9]),
        const SizedBox(height: AppSpace.s8),
        line(const [0]),
      ],
    );
  }

  Widget _exitPanel() => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const NoteBox(
            icon: AppIcons.alert,
            text: 'Hasil tes ini tidak disimpan. Waktu kolom tetap berjalan '
                'selama kamu memutuskan.',
          ),
          const SizedBox(height: AppSpace.s12),
          FooterButtons(
            buttons: [
              AppButton(
                label: 'Lanjut mengerjakan',
                variant: AppButtonVariant.secondary,
                onPressed: () => setState(() => _confirmExit = false),
              ),
              AppButton(label: 'Keluar dari tes', onPressed: _leave),
            ],
          ),
        ],
      );

  Widget _result(Widget header, KraepelinRun run) {
    final c = context.tokens.colors;
    final score = run.score;
    Widget heading(String text) => Padding(
          padding: _margin,
          child: Semantics(
            header: true,
            child: Text(text, style: AppType.title(c.ink)),
          ),
        );
    return OnboardingFrame(
      header: header,
      footer: FooterButtons(
        buttons: [
          AppButton(
            label: 'Kembali ke katalog',
            variant: AppButtonVariant.secondary,
            onPressed: _leave,
          ),
          AppButton(label: 'Ulangi dengan angka baru', onPressed: _restart),
        ],
      ),
      children: [
        const SizedBox(height: AppSpace.s8),
        heading('Hasil tes'),
        const SizedBox(height: AppSpace.s16),
        Padding(
          padding: _margin,
          child: StatRow(items: [
            StatItem(
              value: oneDecimal(score.speed),
              label: 'isian per kolom',
            ),
            StatItem(value: '${score.accuracyPercent}%', label: 'ketelitian'),
            StatItem(value: '${score.range}', label: 'selisih kolom'),
          ]),
        ),
        const SizedBox(height: AppSpace.s16),
        Padding(
          padding: _margin,
          child: Text(
            'Kecepatan: rata-rata ${oneDecimal(score.speed)} isian per kolom '
            'dari ${score.columns.length} kolom. Ketelitian: ${score.correct} '
            'benar dari ${score.filled} isian. Konsistensi: kolom tersibuk '
            '${score.maxFilled} isian, tersepi ${score.minFilled}, '
            'simpangan rata-rata ${oneDecimal(score.meanDeviation)}.',
            style: AppType.body(c.ink),
          ),
        ),
        const SizedBox(height: AppSpace.s24),
        heading('Grafik konsistensi'),
        const SizedBox(height: AppSpace.s8),
        Padding(
          padding: _margin,
          child: Text(
            'Garis yang datar berarti ritmemu stabil dari awal sampai akhir.',
            style: AppType.label(c.inkMuted),
          ),
        ),
        const SizedBox(height: AppSpace.s16),
        Padding(
          padding: const EdgeInsets.only(right: AppSpace.s16),
          child: ConsistencyChart(score: score),
        ),
        const SizedBox(height: AppSpace.s24),
        heading('Per kolom'),
        const SizedBox(height: AppSpace.s8),
        for (var k = 0; k < score.columns.length; k++)
          ListRow(
            title: 'Kolom ${k + 1}',
            subtitle: '${score.columns[k].filled} isian, '
                '${score.columns[k].wrong} salah',
          ),
        const SizedBox(height: AppSpace.s16),
        const Padding(
          padding: _margin,
          child: NoteBox(
            icon: AppIcons.bulb,
            text: 'Latihan, bukan penilaian resmi. Hasil tidak disimpan.',
          ),
        ),
      ],
    );
  }
}
