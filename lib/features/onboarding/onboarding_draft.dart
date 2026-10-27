import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/codes.dart';
import '../../domain/models/profile.dart';
import '../../domain/providers.dart';
import '../../domain/services/profile_templates.dart';
import '../../domain/services/profile_validation.dart';

/// Isian onboarding yang dibawa dari S01 ke S02. Belum ditulis ke database;
/// baru tersimpan lewat [OnboardingDraftNotifier.save].
class OnboardingDraft {
  const OnboardingDraft({
    required this.role,
    required this.format,
    required this.subtests,
    this.tanggal = '',
    this.nama = '',
    this.editingId,
    this.submitted = false,
  });

  /// Awal onboarding: QA Engineer dengan format CCAT-style (S01, default).
  factory OnboardingDraft.initial() => OnboardingDraft(
        role: ProfileRole.qa,
        format: TestFormat.ccat,
        subtests: _inputs(TestFormat.ccat, ProfileRole.qa),
      );

  final ProfileRole role;
  final TestFormat format;
  final List<SubtestInput> subtests;
  final String tanggal;
  final String nama;

  /// Id profil yang sedang diubah; null saat membuat profil baru.
  final int? editingId;

  /// "Simpan" sudah diketuk sekali: galat isian tampil.
  final bool submitted;

  bool get editing => editingId != null;

  String get autoName => ProfileTemplates.autoName(role, format);

  /// Bobot per kategori untuk isian sekarang (subtes aktif saja).
  Map<String, double> get weights => ProfileTemplates.weights(
        role,
        format,
        ProfileValidation.toBlueprint(role, format, subtests).subtes,
      );

  OnboardingDraft copyWith({
    ProfileRole? role,
    TestFormat? format,
    List<SubtestInput>? subtests,
    String? tanggal,
    String? nama,
    bool? submitted,
  }) =>
      OnboardingDraft(
        role: role ?? this.role,
        format: format ?? this.format,
        subtests: subtests ?? this.subtests,
        tanggal: tanggal ?? this.tanggal,
        nama: nama ?? this.nama,
        editingId: editingId,
        submitted: submitted ?? this.submitted,
      );

  static List<SubtestInput> _inputs(TestFormat f, ProfileRole role) => [
        for (final s in ProfileTemplates.subtests(f, role: role))
          SubtestInput.fromSpec(s),
      ];
}

enum SaveOutcome { saved, invalid }

final onboardingDraftProvider =
    NotifierProvider<OnboardingDraftNotifier, OnboardingDraft>(
  OnboardingDraftNotifier.new,
);

class OnboardingDraftNotifier extends Notifier<OnboardingDraft> {
  @override
  OnboardingDraft build() => OnboardingDraft.initial();

  /// Mulai dari awal (S01 dibuka untuk profil baru).
  void reset() => state = OnboardingDraft.initial();

  /// Mengganti role menyalakan atau mematikan subtes khusus role
  /// ([ProfileTemplates.roleSubtests]) mengikuti template format plus role
  /// baru; angka dan subtes lain tidak berubah.
  void selectRole(ProfileRole role) {
    final byRole = {
      for (final set in ProfileTemplates.roleSubtests.values) ...set,
    };
    final want = {
      for (final s in ProfileTemplates.subtests(state.format, role: role))
        s.kategori: s.aktif,
    };
    state = state.copyWith(
      role: role,
      subtests: [
        for (final s in state.subtests)
          if (byRole.contains(s.kategori) && s.aktif != want[s.kategori])
            _toggled(s)
          else
            s,
      ],
    );
  }

  /// Mengganti format mengisi ulang subtes dari template format itu.
  void selectFormat(TestFormat format) {
    if (format == state.format) return;
    state = state.copyWith(
      format: format,
      subtests: OnboardingDraft._inputs(format, state.role),
    );
  }

  /// Menyalakan subtes tanpa angka mengisi angka awalnya.
  void toggleSubtest(String kategori) {
    state = state.copyWith(subtests: [
      for (final s in state.subtests)
        if (s.kategori == kategori) _toggled(s) else s,
    ]);
  }

  SubtestInput _toggled(SubtestInput s) {
    final on = !s.aktif;
    final d = ProfileTemplates.defaultSizes[s.kategori]!;
    return s.copyWith(
      aktif: on,
      jumlah: on && s.jumlah.trim().isEmpty ? '${d.$1}' : null,
      menit: on && s.menit.trim().isEmpty ? '${d.$2}' : null,
    );
  }

  void setJumlah(String kategori, String value) => _edit(
        kategori,
        (s) => s.copyWith(jumlah: value),
      );

  void setMenit(String kategori, String value) => _edit(
        kategori,
        (s) => s.copyWith(menit: value),
      );

  void _edit(String kategori, SubtestInput Function(SubtestInput) f) {
    state = state.copyWith(subtests: [
      for (final s in state.subtests)
        if (s.kategori == kategori) f(s) else s,
    ]);
  }

  void setTanggal(String value) => state = state.copyWith(tanggal: value);

  void setNama(String value) => state = state.copyWith(nama: value);

  /// Memuat profil yang ada untuk mode ubah (dari S18). Subtes yang tidak ada
  /// di blueprint dianggap nonaktif dengan angka awal.
  void loadForEdit(TestProfile p) {
    final byKategori = {for (final s in p.blueprint.subtes) s.kategori: s};
    state = OnboardingDraft(
      role: p.role,
      format: p.formatTes,
      subtests: [
        for (final k in ProfileTemplates.subtestCategories)
          if (byKategori[k] case final s?)
            SubtestInput.fromSpec(s)
          else
            SubtestInput(
              kategori: k,
              aktif: false,
              jumlah: '${ProfileTemplates.defaultSizes[k]!.$1}',
              menit: '${ProfileTemplates.defaultSizes[k]!.$2}',
            ),
      ],
      tanggal: p.tanggalTes == null
          ? ''
          : ProfileValidation.formatDate(p.tanggalTes!),
      nama: p.nama,
      editingId: p.id,
    );
  }

  ProfileErrors get errors => ProfileValidation.validate(
        subtests: state.subtests,
        tanggal: state.tanggal,
        today: ProfileValidation.dateOnly(
          ref.read(clockProvider).now().toLocal(),
        ),
      );

  /// Menyimpan profil bila isian sah. Membuat profil baru yang aktif, atau
  /// memperbarui profil yang diubah (aktif dan CV tidak berubah). Bila tidak
  /// sah, galat mulai tampil dan tidak ada yang ditulis.
  Future<SaveOutcome> save() async {
    if (!errors.isValid) {
      state = state.copyWith(submitted: true);
      return SaveOutcome.invalid;
    }
    final d = state;
    final repo = ref.read(profileRepositoryProvider);
    final nama = d.nama.trim().isEmpty ? d.autoName : d.nama.trim();
    final tanggal = d.tanggal.trim().isEmpty
        ? null
        : ProfileValidation.parseDate(d.tanggal);
    final blueprint = ProfileValidation.toBlueprint(
      d.role,
      d.format,
      d.subtests,
    );
    final existing = d.editingId == null ? null : await repo.byId(d.editingId!);
    final profile = TestProfile(
      id: existing?.id,
      nama: nama,
      role: d.role,
      formatTes: d.format,
      tanggalTes: tanggal,
      aktif: existing?.aktif ?? true,
      blueprint: blueprint,
      dibuat: existing?.dibuat ?? ref.read(clockProvider).now(),
    );
    await repo.save(profile);
    state = OnboardingDraft.initial();
    return SaveOutcome.saved;
  }
}
