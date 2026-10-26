import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_chip.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/app_top_bar.dart';
import '../../core/widgets/empty_view.dart';
import '../../core/widgets/error_view.dart';
import '../../core/widgets/list_row.dart';
import '../../core/widgets/note_box.dart';
import '../../core/widgets/skeleton_list.dart';
import '../../core/widgets/status_tag.dart';
import '../../domain/providers.dart';
import '../../domain/services/profile_templates.dart';
import '../../domain/services/profile_validation.dart';
import 'onboarding_draft.dart';
import 'onboarding_frame.dart';

enum _Load { ready, loading, missing, failed }

/// S02 Profil tes target (F01). Membuat profil baru (alur onboarding) atau,
/// dengan [editId] dari S18, mengubah profil yang ada.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key, this.editId});

  final int? editId;

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final Map<String, TextEditingController> _fields = {};
  _Load _load = _Load.ready;
  bool _saving = false;
  bool _saveFailed = false;

  @override
  void initState() {
    super.initState();
    if (widget.editId == null) {
      Future.microtask(() {
        if (!mounted) return;
        if (ref.read(onboardingDraftProvider).editing) {
          ref.read(onboardingDraftProvider.notifier).reset();
        }
      });
    } else {
      _load = _Load.loading;
      Future.microtask(_loadForEdit);
    }
  }

  @override
  void dispose() {
    for (final c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadForEdit() async {
    try {
      final p = await ref.read(profileRepositoryProvider).byId(widget.editId!);
      if (!mounted) return;
      if (p == null) {
        setState(() => _load = _Load.missing);
        return;
      }
      ref.read(onboardingDraftProvider.notifier).loadForEdit(p);
      setState(() => _load = _Load.ready);
    } catch (_) {
      if (mounted) setState(() => _load = _Load.failed);
    }
  }

  /// Controller yang selalu mengikuti draf: bila nilai draf berubah dari luar
  /// (ganti format, muat profil), teks isian ikut berubah.
  TextEditingController _field(String key, String value) {
    final c = _fields.putIfAbsent(key, () => TextEditingController());
    if (c.text != value) {
      c.value = TextEditingValue(
        text: value,
        selection: TextSelection.collapsed(offset: value.length),
      );
    }
    return c;
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _saveFailed = false;
    });
    final editing = ref.read(onboardingDraftProvider).editing;
    try {
      final outcome = await ref.read(onboardingDraftProvider.notifier).save();
      if (!mounted) return;
      setState(() => _saving = false);
      if (outcome == SaveOutcome.saved) {
        if (!editing) {
          context.go(Routes.onboardingDiagnostik);
        } else if (context.canPop()) {
          context.pop();
        } else {
          context.go(Routes.beranda);
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _saveFailed = true;
        });
      }
    }
  }

  void _back() {
    // Profil baru: kembali ke langkah 1 yang ada di bawahnya di tumpukan.
    // Dibuka langsung lewat tautan (tanpa tumpukan): ke S01 untuk profil baru,
    // ke beranda untuk mengubah profil.
    if (context.canPop()) {
      context.pop();
    } else {
      context
          .go(widget.editId != null ? Routes.beranda : Routes.onboardingRole);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.tokens.colors;
    final editing = widget.editId != null;
    final header = AppTopBar(
      title: editing ? 'Ubah profil' : 'Profil tes target',
      onBack: _back,
      backLabel: editing ? 'Kembali' : 'Kembali ke pilihan role',
      actions: [
        if (!editing)
          Padding(
            padding: const EdgeInsets.only(right: AppSpace.s8),
            child: Semantics(
              label: 'Langkah 2 dari 3',
              excludeSemantics: true,
              child: Text('2 / 3', style: AppType.label(c.inkMuted)),
            ),
          ),
      ],
    );

    if (_load != _Load.ready) {
      return OnboardingFrame(
        header: header,
        footer: const AppButton(label: 'Simpan profil', onPressed: null),
        children: [
          switch (_load) {
            _Load.loading => const SkeletonList(
                rows: 5,
                semanticLabel: 'Memuat profil',
              ),
            _Load.missing => EmptyView(
                title: 'Profil tidak ditemukan',
                message: 'Profil ini sudah dihapus atau belum pernah dibuat.',
                actionLabel: 'Kembali',
                onAction: _back,
              ),
            _ => ErrorView(
                title: 'Profil tidak bisa dibuka',
                message: 'Data profil di perangkat gagal dibaca. Ketuk coba '
                    'lagi, atau kembali dan buka profil dari awal.',
                onRetry: () {
                  setState(() => _load = _Load.loading);
                  _loadForEdit();
                },
              ),
          },
        ],
      );
    }

    final draft = ref.watch(onboardingDraftProvider);
    final notifier = ref.read(onboardingDraftProvider.notifier);
    final errors = notifier.errors;
    final show = draft.submitted;
    final weights = draft.weights;
    final active = [
      for (final s in draft.subtests)
        if (s.aktif) s,
    ];

    return OnboardingFrame(
      header: header,
      footer: AppButton(
        label: editing ? 'Simpan profil' : 'Simpan dan lanjut',
        onPressed: _saving ? null : _save,
      ),
      children: [
        const SizedBox(height: AppSpace.s8),
        ScreenPadding(
          child: Semantics(
            header: true,
            child: Text('Format tes', style: AppType.title(c.ink)),
          ),
        ),
        const SizedBox(height: AppSpace.s8),
        ScreenPadding(
          child: Wrap(
            spacing: AppSpace.s8,
            children: [
              for (final f in ProfileTemplates.formats)
                AppChip(
                  label: ProfileTemplates.formatName(f),
                  selected: f == draft.format,
                  onTap: () => notifier.selectFormat(f),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpace.s24),
        ScreenPadding(
          child: Semantics(
            header: true,
            child: Text('Subtes', style: AppType.title(c.ink)),
          ),
        ),
        const SizedBox(height: AppSpace.s4),
        ScreenPadding(
          child: Text(
            'Nyalakan subtes yang keluar di tesmu, lalu isi jumlah dan menit.',
            style: AppType.label(c.inkMuted),
          ),
        ),
        const SizedBox(height: AppSpace.s8),
        ScreenPadding(
          child: Wrap(
            spacing: AppSpace.s8,
            children: [
              for (final s in draft.subtests)
                AppChip(
                  label: ProfileTemplates.categoryName(s.kategori),
                  selected: s.aktif,
                  onTap: () => notifier.toggleSubtest(s.kategori),
                ),
            ],
          ),
        ),
        if (show && errors.noSubtest) ...[
          const SizedBox(height: AppSpace.s8),
          ScreenPadding(
            child: Semantics(
              liveRegion: true,
              child: const NoteBox(
                icon: AppIcons.alert,
                text: 'Pilih minimal satu subtes agar latihan bisa disusun.',
              ),
            ),
          ),
        ],
        const SizedBox(height: AppSpace.s8),
        for (final s in active)
          _SubtestEditor(
            input: s,
            weight: weights[s.kategori] ?? 0,
            jumlahController: _field('jumlah-${s.kategori}', s.jumlah),
            menitController: _field('menit-${s.kategori}', s.menit),
            jumlahError: show ? errors.jumlah[s.kategori] : null,
            menitError: show ? errors.menit[s.kategori] : null,
            onJumlah: (v) => notifier.setJumlah(s.kategori, v),
            onMenit: (v) => notifier.setMenit(s.kategori, v),
          ),
        const SizedBox(height: AppSpace.s24),
        ScreenPadding(
          child: AppTextField(
            key: const ValueKey('tanggal'),
            label: 'Tanggal tes (opsional)',
            hint: 'hh/bb/tttt',
            controller: _field('tanggal', draft.tanggal),
            keyboardType: TextInputType.datetime,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9/]')),
              LengthLimitingTextInputFormatter(10),
            ],
            onChanged: notifier.setTanggal,
            errorText: show ? _dateCopy(errors.tanggal) : null,
            helper: 'Dipakai untuk menaikkan porsi simulasi saat tes dekat.',
          ),
        ),
        const SizedBox(height: AppSpace.s16),
        ScreenPadding(
          child: AppTextField(
            key: const ValueKey('nama'),
            label: 'Nama profil',
            hint: draft.autoName,
            controller: _field('nama', draft.nama),
            onChanged: notifier.setNama,
            textInputAction: TextInputAction.done,
            helper: 'Kosongkan untuk memakai "${draft.autoName}".',
          ),
        ),
        const SizedBox(height: AppSpace.s24),
        const ListRow(
          title: 'CV untuk wawancara',
          subtitle: 'Opsional. Isian CV tersedia di v1.3, bersama wawancara.',
          divider: false,
          trailing: StatusTag(label: 'v1.3'),
        ),
        if (_saveFailed) ...[
          const SizedBox(height: AppSpace.s8),
          ScreenPadding(
            child: Semantics(
              liveRegion: true,
              child: const NoteBox(
                icon: AppIcons.alert,
                text: 'Profil belum tersimpan. Data di perangkat gagal '
                    'ditulis. Ketuk simpan sekali lagi.',
              ),
            ),
          ),
        ],
      ],
    );
  }
}

String? _dateCopy(DateError? e) => switch (e) {
      null => null,
      DateError.invalid => 'Tulis tanggal sebagai hh/bb/tttt, mis. 03/11/2026.',
      DateError.past =>
        'Tanggal tes sudah lewat. Isi hari ini atau sesudahnya, atau '
            'kosongkan.',
    };

String? _countCopy(NumberError? e, String unit) => switch (e) {
      null => null,
      NumberError.invalid => 'Isi jumlah $unit.',
      NumberError.outOfRange => 'Isi ${ProfileValidation.minCount} sampai '
          '${ProfileValidation.maxCount} $unit.',
    };

String? _minutesCopy(NumberError? e) => switch (e) {
      null => null,
      NumberError.invalid => 'Isi menit.',
      NumberError.outOfRange => 'Isi ${ProfileValidation.minMinutes} sampai '
          '${ProfileValidation.maxMinutes} menit.',
    };

/// Satu subtes aktif: nama dan bobot, lalu isian jumlah dan menit. Disusun dari
/// `ListRow` dan `AppTextField`; garis bawah memisahkan antar subtes.
class _SubtestEditor extends StatelessWidget {
  const _SubtestEditor({
    required this.input,
    required this.weight,
    required this.jumlahController,
    required this.menitController,
    required this.onJumlah,
    required this.onMenit,
    this.jumlahError,
    this.menitError,
  });

  final SubtestInput input;
  final double weight;
  final TextEditingController jumlahController;
  final TextEditingController menitController;
  final ValueChanged<String> onJumlah;
  final ValueChanged<String> onMenit;
  final NumberError? jumlahError;
  final NumberError? menitError;

  @override
  Widget build(BuildContext context) {
    final c = context.tokens.colors;
    final unit = ProfileTemplates.countUnit(input.kategori);
    final percent = (weight * 100).round();
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.outlineVariant)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListRow(
            title: ProfileTemplates.categoryName(input.kategori),
            subtitle: 'Bobot $percent% di latihan campuran',
            divider: false,
          ),
          ScreenPadding(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: AppTextField(
                    key: ValueKey('jumlah-${input.kategori}'),
                    label: 'Jumlah $unit',
                    controller: jumlahController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(3),
                    ],
                    onChanged: onJumlah,
                    errorText: _countCopy(jumlahError, unit),
                  ),
                ),
                const SizedBox(width: AppSpace.s12),
                Expanded(
                  child: AppTextField(
                    key: ValueKey('menit-${input.kategori}'),
                    label: 'Menit',
                    controller: menitController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(3),
                    ],
                    onChanged: onMenit,
                    errorText: _minutesCopy(menitError),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.s16),
        ],
      ),
    );
  }
}
