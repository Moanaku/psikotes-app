import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_chip.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/app_top_bar.dart';
import '../../core/widgets/note_box.dart';
import '../../domain/providers.dart';
import '../../domain/services/company_log_form.dart';
import '../../domain/services/profile_templates.dart';
import '../../domain/services/profile_validation.dart';
import '../onboarding/onboarding_frame.dart';

/// Subtes yang bisa ditandai keluar di tes asli.
const List<String> logSubtests = [
  'verbal',
  'numerik',
  'logika',
  'figural',
  'kraepelin',
  'kepribadian',
  'it',
];

/// Formulir "Tambah catatan tes" (S13). Rute `/catatan-tes/baru` (A88).
class CompanyLogFormScreen extends ConsumerStatefulWidget {
  const CompanyLogFormScreen({super.key});

  @override
  ConsumerState<CompanyLogFormScreen> createState() =>
      _CompanyLogFormScreenState();
}

class _CompanyLogFormScreenState extends ConsumerState<CompanyLogFormScreen> {
  final _perusahaan = TextEditingController();
  final _tanggal = TextEditingController();
  final _tipeBaru = TextEditingController();
  final _catatan = TextEditingController();
  final Set<String> _subtes = {};
  bool _submitted = false;
  bool _saving = false;
  String? _saveMessage;

  @override
  void initState() {
    super.initState();
    _tanggal.text = ProfileValidation.formatDate(
      ProfileValidation.dateOnly(ref.read(clockProvider).now().toLocal()),
    );
  }

  @override
  void dispose() {
    _perusahaan.dispose();
    _tanggal.dispose();
    _tipeBaru.dispose();
    _catatan.dispose();
    super.dispose();
  }

  CompanyLogDraft _draft() => CompanyLogDraft(
        perusahaan: _perusahaan.text,
        tanggal: _tanggal.text,
        subtes: [
          for (final k in logSubtests)
            if (_subtes.contains(k)) k,
        ],
        tipeBaru: _tipeBaru.text,
        catatan: _catatan.text,
      );

  void _back() =>
      context.canPop() ? context.pop() : context.go(Routes.catatanTes);

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _submitted = true;
      _saveMessage = null;
    });
    final log = _draft().build();
    if (log == null) return;
    setState(() => _saving = true);
    try {
      await ref.read(companyLogRepositoryProvider).save(log);
      if (!mounted) return;
      _back();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saveMessage = 'Catatan belum tersimpan. Data di perangkat gagal '
            'ditulis. Ketuk simpan sekali lagi.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final errors = _submitted ? _draft().validate() : const CompanyLogErrors();
    return OnboardingFrame(
      header: AppTopBar(title: 'Tambah catatan tes', onBack: _back),
      footer: AppButton(
        label: 'Simpan catatan tes',
        onPressed: _saving ? null : () => unawaited(_save()),
      ),
      children: [
        ScreenPadding(
          child: AppTextField(
            label: 'Nama perusahaan',
            controller: _perusahaan,
            errorText: errors.perusahaan,
            textInputAction: TextInputAction.next,
            onChanged: (_) => setState(() {}),
          ),
        ),
        ScreenPadding(
          top: AppSpace.s16,
          child: AppTextField(
            label: 'Tanggal tes',
            controller: _tanggal,
            hint: 'hh/bb/tttt',
            keyboardType: TextInputType.datetime,
            errorText: errors.tanggal,
            onChanged: (_) => setState(() {}),
          ),
        ),
        ScreenPadding(
          top: AppSpace.s16,
          child: Semantics(
            header: true,
            child: Text(
              'Subtes yang keluar',
              style: AppType.label(context.tokens.colors.ink)
                  .copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ),
        ScreenPadding(
          top: AppSpace.s4,
          child: Wrap(
            spacing: AppSpace.s8,
            children: [
              for (final k in logSubtests)
                AppChip(
                  label: ProfileTemplates.categoryName(k),
                  selected: _subtes.contains(k),
                  onTap: () => setState(() {
                    if (!_subtes.remove(k)) _subtes.add(k);
                  }),
                ),
            ],
          ),
        ),
        ScreenPadding(
          top: AppSpace.s16,
          child: AppTextField(
            label: 'Tipe baru yang keluar',
            controller: _tipeBaru,
            hint: 'Misalnya lipat kertas, rotasi kubus',
            helper: 'Pisahkan dengan koma. Tiap tipe jadi saran latihan.',
            minLines: 1,
            maxLines: 3,
          ),
        ),
        ScreenPadding(
          top: AppSpace.s16,
          child: AppTextField(
            label: 'Catatan (opsional)',
            controller: _catatan,
            minLines: 3,
            maxLines: 8,
            keyboardType: TextInputType.multiline,
            hint: 'Urutan subtes, waktu terasa kurang, hal yang sulit',
          ),
        ),
        if (_saveMessage != null)
          ScreenPadding(
            top: AppSpace.s16,
            child: Semantics(
              liveRegion: true,
              child: NoteBox(icon: AppIcons.alert, text: _saveMessage!),
            ),
          ),
      ],
    );
  }
}
