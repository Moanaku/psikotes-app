import 'dart:async';
import 'dart:typed_data';

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
import '../../core/widgets/empty_view.dart';
import '../../core/widgets/error_view.dart';
import '../../core/widgets/note_box.dart';
import '../../core/widgets/skeleton_list.dart';
import '../../domain/models/notebook.dart';
import '../../domain/providers.dart';
import '../../domain/services/capture_form.dart';
import '../../domain/services/capture_service.dart';
import '../../domain/services/profile_templates.dart';
import '../onboarding/onboarding_frame.dart';
import 'capture_photo_view.dart';
import 'capture_provider.dart';

/// Kategori yang ditawarkan sebagai chip; selain itu pengguna mengetik tipe
/// baru.
const List<String> captureCategories = [
  'verbal',
  'numerik',
  'logika',
  'figural',
];

/// S12 Capture soal (F09): menyimpan soal dari tes asli ke bank pribadi.
/// [editId] membuka soal yang ada; [logId] menghubungkan soal baru ke catatan
/// tes; [tipe] mengisi nama tipe baru (dari saran di S13).
class CaptureScreen extends ConsumerWidget {
  const CaptureScreen({super.key, this.editId, this.logId, this.tipe});

  final int? editId;
  final int? logId;
  final String? tipe;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = editId;
    if (id == null) {
      return _CaptureForm(
        initial: CaptureDraft(companyLogId: logId, kategori: tipe ?? ''),
      );
    }
    void back() =>
        context.canPop() ? context.pop() : context.go(Routes.psikotes);
    final header = AppTopBar(title: 'Ubah soal Capture', onBack: back);
    final toBank = AppButton(
      label: 'Kembali ke bank pribadi',
      variant: AppButtonVariant.secondary,
      onPressed: back,
    );
    return ref.watch(capturedQuestionProvider(id)).when(
          loading: () => OnboardingFrame(
            header: header,
            footer: toBank,
            children: const [
              SkeletonList(rows: 6, semanticLabel: 'Memuat soal Capture'),
            ],
          ),
          error: (_, __) => OnboardingFrame(
            header: header,
            footer: toBank,
            children: [
              ErrorView(
                title: 'Soal Capture tidak bisa dibuka',
                message: 'Data soal gagal dibaca. Ketuk coba lagi. Soalmu '
                    'tidak hilang.',
                onRetry: () => ref.invalidate(capturedQuestionProvider(id)),
              ),
            ],
          ),
          data: (q) => q == null
              ? OnboardingFrame(
                  header: header,
                  footer: toBank,
                  children: [
                    EmptyView(
                      title: 'Soal Capture tidak ditemukan',
                      message: 'Soal ini sudah dihapus dari bank pribadi.',
                      actionLabel: 'Kembali ke bank pribadi',
                      onAction: back,
                    ),
                  ],
                )
              : _CaptureForm(
                  key: ValueKey('capture-$id'),
                  initial: CaptureDraft.from(q),
                  original: q,
                ),
        );
  }
}

class _CaptureForm extends ConsumerStatefulWidget {
  const _CaptureForm({super.key, required this.initial, this.original});

  final CaptureDraft initial;
  final CapturedQuestion? original;

  @override
  ConsumerState<_CaptureForm> createState() => _CaptureFormState();
}

class _CaptureFormState extends ConsumerState<_CaptureForm> {
  late final TextEditingController _teks;
  late final TextEditingController _pembahasan;
  late final TextEditingController _newType;
  late final List<TextEditingController> _opsi;
  int? _kunci;

  /// Kategori terpilih dari chip; null bila belum atau memakai tipe baru.
  String? _kategori;
  bool _useNewType = false;
  String? _foto;
  Uint8List? _newPhoto;
  bool _removePhoto = false;
  int? _logId;

  /// Isian saat formulir dibuka; pembanding untuk "belum tersimpan".
  late final CaptureDraft _baseline;
  final GlobalKey _kategoriKey = GlobalKey();
  final GlobalKey _teksKey = GlobalKey();
  final GlobalKey _opsiKey = GlobalKey();

  bool _submitted = false;
  bool _saving = false;
  bool _confirmDelete = false;
  bool _confirmLeave = false;
  String? _photoMessage;
  String? _saveMessage;

  int? get _editId => widget.original?.id;

  @override
  void initState() {
    super.initState();
    final d = widget.initial;
    _teks = TextEditingController(text: d.teks);
    _pembahasan = TextEditingController(text: d.pembahasan);
    _opsi = [for (final o in d.opsi) TextEditingController(text: o)];
    _kunci = d.kunciSlot;
    _foto = d.fotoPath;
    _logId = d.companyLogId;
    final known = captureCategories.contains(d.kategori);
    _kategori = known ? d.kategori : null;
    _useNewType = !known && d.kategori.isNotEmpty;
    _newType = TextEditingController(text: _useNewType ? d.kategori : '');
    _baseline = _draft();
  }

  @override
  void dispose() {
    _teks.dispose();
    _pembahasan.dispose();
    _newType.dispose();
    for (final c in _opsi) {
      c.dispose();
    }
    super.dispose();
  }

  CaptureDraft _draft() => CaptureDraft(
        teks: _teks.text,
        // Foto baru belum punya nama; cukup untuk validasi "teks atau foto".
        fotoPath: _newPhoto != null ? '(baru)' : (_removePhoto ? null : _foto),
        opsi: [for (final c in _opsi) c.text],
        kunciSlot: _kunci,
        kategori: _useNewType ? _newType.text : (_kategori ?? ''),
        pembahasan: _pembahasan.text,
        companyLogId: _logId,
      );

  void _back() =>
      context.canPop() ? context.pop() : context.go(Routes.psikotes);

  /// Ada isian yang belum tersimpan: berbeda dari saat dibuka, atau foto
  /// diganti atau dihapus.
  bool get _dirty {
    final d = _draft();
    final b = _baseline;
    return _newPhoto != null ||
        _removePhoto ||
        d.teks != b.teks ||
        d.kategori != b.kategori ||
        d.pembahasan != b.pembahasan ||
        d.kunciSlot != b.kunciSlot ||
        d.companyLogId != b.companyLogId ||
        d.opsi.length != b.opsi.length ||
        !_sameList(d.opsi, b.opsi);
  }

  static bool _sameList(List<String> a, List<String> b) {
    for (var i = 0; i < a.length && i < b.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// Tombol tutup dan Back sistem: isian yang belum tersimpan meminta
  /// konfirmasi di bilah aksi bawah, seperti keluar dari sesi (A71).
  void _requestBack() {
    if (_saving) return;
    if (_dirty) {
      setState(() {
        _confirmLeave = true;
        _confirmDelete = false;
      });
    } else {
      _back();
    }
  }

  /// Menggulir ke isian pertama yang bermasalah.
  void _revealFirstError(CaptureErrors e) {
    final key = e.kategori != null
        ? _kategoriKey
        : e.soal != null
            ? _teksKey
            : _opsiKey;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = key.currentContext;
      if (!mounted || ctx == null) return;
      unawaited(Scrollable.ensureVisible(
        ctx,
        alignment: 0.1,
        duration: context.motion,
        curve: AppMotion.curve,
      ));
    });
  }

  Future<void> _pick(PhotoSource source) async {
    try {
      final bytes = await ref.read(photoPickerProvider)(source);
      if (bytes == null || !mounted) return;
      setState(() {
        _newPhoto = bytes;
        _removePhoto = false;
        _photoMessage = null;
      });
    } on PhotoPickFailure {
      if (!mounted) return;
      setState(() => _photoMessage = 'Kamera atau galeri tidak bisa dibuka. '
          'Cek izin app di pengaturan HP, lalu coba lagi.');
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _submitted = true;
      _saveMessage = null;
    });
    final draft = _draft();
    final problems = draft.validate();
    if (problems.any) {
      _revealFirstError(problems);
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(captureServiceProvider).save(
            draft: draft,
            now: ref.read(clockProvider).now(),
            id: _editId,
            newPhoto: _newPhoto,
            removePhoto: _removePhoto,
          );
      if (!mounted) return;
      // Konfirmasi tampil di layar asal setelah formulir ditutup.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Soal disimpan ke bank pribadi')),
      );
      _back();
    } on PhotoStoreException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _photoMessage = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saveMessage = 'Soal belum tersimpan. Data di perangkat gagal '
            'ditulis. Ketuk simpan sekali lagi.';
      });
    }
  }

  Future<void> _delete() async {
    final id = _editId;
    if (id == null || _saving) return;
    setState(() => _saving = true);
    try {
      await ref.read(captureServiceProvider).delete(id);
      if (!mounted) return;
      _back();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _confirmDelete = false;
        _saveMessage = 'Soal belum terhapus. Data di perangkat gagal ditulis. '
            'Coba lagi.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.tokens.colors;
    final errors = _submitted ? _draft().validate() : const CaptureErrors();
    final editing = _editId != null;
    final logs = ref.watch(companyLogsProvider);
    final existingPhoto = _newPhoto == null && !_removePhoto && _foto != null
        ? ref.watch(capturePhotoProvider(_foto!))
        : null;
    final hasPhoto = _newPhoto != null ||
        (!_removePhoto && _foto != null && _foto!.isNotEmpty);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _requestBack();
      },
      child: _frame(c, errors, editing, logs, existingPhoto, hasPhoto),
    );
  }

  Widget _frame(
    AppColors c,
    CaptureErrors errors,
    bool editing,
    AsyncValue<List<CompanyTestLog>> logs,
    AsyncValue<Uint8List?>? existingPhoto,
    bool hasPhoto,
  ) {
    return OnboardingFrame(
      header: AppTopBar(
        title: editing ? 'Ubah soal Capture' : 'Capture soal',
        onBack: _requestBack,
      ),
      footer: _confirmLeave
          ? _leaveFooter()
          : _confirmDelete
              ? _deleteFooter(c)
              : _saveFooter(errors),
      children: [
        const ScreenPadding(
          top: AppSpace.s8,
          child: NoteBox(
            icon: AppIcons.lock,
            text: 'Disimpan hanya di HP ini dan tidak ikut ke repo. Jangan '
                'bagikan soal asli perusahaan.',
          ),
        ),
        // Kategori
        ScreenPadding(
          top: AppSpace.s24,
          child: KeyedSubtree(
            key: _kategoriKey,
            child: const _Label('Kategori soal'),
          ),
        ),
        ScreenPadding(
          top: AppSpace.s4,
          child: Wrap(
            spacing: AppSpace.s8,
            children: [
              for (final k in captureCategories)
                AppChip(
                  label: ProfileTemplates.categoryName(k),
                  selected: !_useNewType && _kategori == k,
                  onTap: () => setState(() {
                    _useNewType = false;
                    _kategori = k;
                  }),
                ),
              AppChip(
                label: 'Tipe baru',
                selected: _useNewType,
                onTap: () => setState(() {
                  _useNewType = true;
                  _kategori = null;
                }),
              ),
            ],
          ),
        ),
        if (_useNewType)
          ScreenPadding(
            top: AppSpace.s12,
            child: AppTextField(
              label: 'Nama tipe baru',
              controller: _newType,
              hint: 'Misalnya lipat kertas',
              onChanged: (_) => setState(() {}),
            ),
          ),
        if (errors.kategori != null)
          ScreenPadding(
              top: AppSpace.s8, child: _InlineError(errors.kategori!)),
        // Foto
        const ScreenPadding(
          top: AppSpace.s24,
          child: _Label('Foto soal (opsional)'),
        ),
        if (hasPhoto)
          ScreenPadding(
            top: AppSpace.s8,
            child: _newPhoto != null
                ? PhotoFrame(bytes: _newPhoto!)
                : existingPhoto!.when(
                    loading: () => const SkeletonList(
                      rows: 2,
                      semanticLabel: 'Memuat foto soal',
                    ),
                    error: (_, __) => const _MissingPhoto(),
                    data: (b) => b == null
                        ? const _MissingPhoto()
                        : PhotoFrame(bytes: b),
                  ),
          ),
        ScreenPadding(
          top: AppSpace.s8,
          child: Wrap(
            spacing: AppSpace.s8,
            runSpacing: AppSpace.s8,
            children: [
              AppButton(
                label: 'Ambil foto soal',
                icon: AppIcons.camera,
                variant: AppButtonVariant.outline,
                expand: false,
                onPressed: () => unawaited(_pick(PhotoSource.camera)),
              ),
              AppButton(
                label: 'Pilih dari galeri',
                icon: AppIcons.image,
                variant: AppButtonVariant.outline,
                expand: false,
                onPressed: () => unawaited(_pick(PhotoSource.gallery)),
              ),
              if (hasPhoto)
                AppButton(
                  label: 'Hapus foto',
                  variant: AppButtonVariant.secondary,
                  expand: false,
                  onPressed: () => setState(() {
                    _newPhoto = null;
                    _removePhoto = true;
                  }),
                ),
            ],
          ),
        ),
        if (_photoMessage != null)
          ScreenPadding(
            top: AppSpace.s8,
            child: Semantics(
              liveRegion: true,
              child: NoteBox(icon: AppIcons.alert, text: _photoMessage!),
            ),
          ),
        // Teks soal
        ScreenPadding(
          top: AppSpace.s24,
          child: AppTextField(
            key: _teksKey,
            label: 'Teks soal',
            controller: _teks,
            minLines: 3,
            maxLines: 8,
            keyboardType: TextInputType.multiline,
            hint: 'Tulis soal seperti di tes asli',
            errorText: errors.soal,
            onChanged: (_) => setState(() {}),
          ),
        ),
        // Opsi
        ScreenPadding(
          top: AppSpace.s24,
          child: KeyedSubtree(
            key: _opsiKey,
            child: const _Label('Opsi jawaban'),
          ),
        ),
        ScreenPadding(
          top: AppSpace.s4,
          child: Text(
            'Pilih lingkaran di kiri opsi yang benar.',
            style: AppType.label(c.inkMuted),
          ),
        ),
        for (var i = 0; i < _opsi.length; i++)
          ScreenPadding(
            top: AppSpace.s8,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: AppSpace.s24),
                  child: _KeyRadio(
                    key: ValueKey('kunci-$i'),
                    letter: String.fromCharCode(0x41 + i),
                    selected: _kunci == i,
                    onTap: () => setState(() => _kunci = i),
                  ),
                ),
                const SizedBox(width: AppSpace.s4),
                Expanded(
                  child: AppTextField(
                    label: 'Opsi ${String.fromCharCode(0x41 + i)}',
                    controller: _opsi[i],
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
          ),
        if (errors.opsi != null)
          ScreenPadding(top: AppSpace.s8, child: _InlineError(errors.opsi!)),
        if (errors.kunci != null)
          ScreenPadding(top: AppSpace.s8, child: _InlineError(errors.kunci!)),
        if (_opsi.length < CaptureDraft.maxOptions)
          ScreenPadding(
            top: AppSpace.s8,
            child: AppButton(
              label: 'Tambah opsi',
              icon: AppIcons.plus,
              variant: AppButtonVariant.outline,
              expand: false,
              onPressed: () => setState(
                () => _opsi.add(TextEditingController()),
              ),
            ),
          ),
        // Pembahasan
        ScreenPadding(
          top: AppSpace.s24,
          child: AppTextField(
            label: 'Pembahasan (opsional)',
            controller: _pembahasan,
            minLines: 2,
            maxLines: 6,
            keyboardType: TextInputType.multiline,
            hint: 'Kenapa jawaban itu benar, dan polanya',
          ),
        ),
        // Catatan tes
        const ScreenPadding(
          top: AppSpace.s24,
          child: _Label('Hubungkan ke catatan tes'),
        ),
        ScreenPadding(
          top: AppSpace.s4,
          child: logs.when(
            loading: () => const SkeletonList(
              rows: 1,
              semanticLabel: 'Memuat catatan tes',
            ),
            error: (_, __) => const NoteBox(
              icon: AppIcons.alert,
              text: 'Catatan tes tidak bisa dibaca. Soal tetap bisa disimpan '
                  'tanpa catatan.',
            ),
            data: (items) => items.isEmpty
                ? Text(
                    'Belum ada catatan tes. Soal ini disimpan tanpa catatan.',
                    style: AppType.label(c.inkMuted),
                  )
                : Wrap(
                    spacing: AppSpace.s8,
                    children: [
                      for (final l in items)
                        AppChip(
                          label: l.perusahaan,
                          selected: _logId == l.id,
                          onTap: () => setState(
                            () => _logId = _logId == l.id ? null : l.id,
                          ),
                        ),
                    ],
                  ),
          ),
        ),
        ScreenPadding(
          top: AppSpace.s8,
          child: AppButton(
            label: 'Buka catatan tes',
            icon: AppIcons.note,
            variant: AppButtonVariant.outline,
            expand: false,
            onPressed: () => unawaited(context.push(Routes.catatanTes)),
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
        if (editing)
          ScreenPadding(
            top: AppSpace.s24,
            child: AppButton(
              label: 'Hapus soal ini',
              variant: AppButtonVariant.secondary,
              expand: false,
              onPressed:
                  _saving ? null : () => setState(() => _confirmDelete = true),
            ),
          ),
      ],
    );
  }

  Widget _saveFooter(CaptureErrors errors) {
    final button = AppButton(
      label: 'Simpan ke bank pribadi',
      onPressed: _saving ? null : () => unawaited(_save()),
    );
    if (!_submitted || !errors.any) return button;
    // Galat ditulis juga di dekat tombol simpan: isian yang bermasalah bisa
    // jauh di atas layar.
    final names = [
      if (errors.kategori != null) 'kategori',
      if (errors.soal != null) 'teks soal',
      if (errors.opsi != null) 'opsi jawaban',
      if (errors.kunci != null) 'kunci jawaban',
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          liveRegion: true,
          child: NoteBox(
            icon: AppIcons.alert,
            text: 'Belum bisa disimpan. Lengkapi ${names.join(', ')}.',
          ),
        ),
        const SizedBox(height: AppSpace.s12),
        button,
      ],
    );
  }

  Widget _leaveFooter() => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            liveRegion: true,
            child: const NoteBox(
              icon: AppIcons.alert,
              text: 'Isianmu belum disimpan. Kalau keluar, isian ini hilang.',
            ),
          ),
          const SizedBox(height: AppSpace.s12),
          AppButton(
            label: 'Tetap mengisi',
            onPressed: () => setState(() => _confirmLeave = false),
          ),
          const SizedBox(height: AppSpace.s8),
          AppButton(
            label: 'Buang isian',
            variant: AppButtonVariant.secondary,
            onPressed: _back,
          ),
        ],
      );

  Widget _deleteFooter(AppColors c) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Soal ini dan kartu buku kesalahannya dihapus dari perangkat.',
            style: AppType.label(c.ink),
          ),
          const SizedBox(height: AppSpace.s12),
          AppButton(
            label: 'Hapus soal',
            onPressed: _saving ? null : () => unawaited(_delete()),
          ),
          const SizedBox(height: AppSpace.s8),
          AppButton(
            label: 'Batal',
            variant: AppButtonVariant.secondary,
            onPressed: () => setState(() => _confirmDelete = false),
          ),
        ],
      );
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Semantics(
        header: true,
        child: Text(
          text,
          style: AppType.label(context.tokens.colors.ink)
              .copyWith(fontWeight: FontWeight.w600),
        ),
      );
}

/// Pesan galat di dekat bagian formulir selain isian teks (opsi dan kunci),
/// meniru pesan di `AppTextField`.
class _InlineError extends StatelessWidget {
  const _InlineError(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.tokens.colors;
    return Semantics(
      liveRegion: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            AppIcons.alert,
            size: AppSizes.iconInText,
            color: c.bad,
            semanticLabel: 'Galat',
          ),
          const SizedBox(width: AppSpace.s4),
          Expanded(child: Text(text, style: AppType.label(c.bad))),
        ],
      ),
    );
  }
}

/// Lingkaran penanda kunci di kiri opsi. Perakitan token (A87): `ChoiceRow`
/// adalah baris penuh, bukan penanda tunggal. Area sentuh 48.
class _KeyRadio extends StatelessWidget {
  const _KeyRadio({
    super.key,
    required this.letter,
    required this.selected,
    required this.onTap,
  });

  final String letter;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.tokens.colors;
    final ring = Border.all(color: selected ? c.ink : c.outline, width: 2);
    return Semantics(
      label: 'Jadikan opsi $letter sebagai kunci',
      inMutuallyExclusiveGroup: true,
      checked: selected,
      button: true,
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: AppSizes.touchTarget,
          height: AppSizes.touchTarget,
          child: Center(
            child: Container(
              width: AppSizes.radioOuter,
              height: AppSizes.radioOuter,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: ring,
              ),
              child: selected
                  ? Container(
                      width: AppSizes.radioDot,
                      height: AppSizes.radioDot,
                      decoration:
                          BoxDecoration(shape: BoxShape.circle, color: c.ink),
                    )
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

class _MissingPhoto extends StatelessWidget {
  const _MissingPhoto();

  @override
  Widget build(BuildContext context) => const NoteBox(
        icon: AppIcons.image,
        text: 'Foto soal tidak ada di perangkat ini. Foto tidak ikut backup. '
            'Ambil foto lagi bila perlu.',
      );
}
