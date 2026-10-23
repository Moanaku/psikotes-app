import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/time_format.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_chip.dart';
import '../../core/widgets/app_icon_button.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/app_top_bar.dart';
import '../../core/widgets/empty_view.dart';
import '../../core/widgets/error_view.dart';
import '../../core/widgets/list_row.dart';
import '../../core/widgets/note_box.dart';
import '../../core/widgets/segmented_control.dart';
import '../../core/widgets/skeleton_list.dart';
import '../../core/widgets/status_tag.dart';
import '../../domain/models/codes.dart';
import '../../domain/models/profile.dart';
import '../../domain/providers.dart';
import '../../domain/repositories/repositories.dart';
import '../../domain/services/backup.dart';
import '../../domain/services/secret_store.dart';
import '../onboarding/onboarding_draft.dart';
import 'settings_provider.dart';

const Map<String, String> _tableNames = {
  'test_profile': 'Profil tes',
  'session': 'Sesi',
  'answer': 'Jawaban',
  'mistake_card': 'Kartu buku kesalahan',
  'captured_question': 'Soal Capture',
  'company_test_log': 'Catatan tes',
  'app_setting': 'Pengaturan',
};

/// S18 Pengaturan (F11): profil, backup, wawancara AI, dan tampilan.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _key = TextEditingController();
  bool _busy = false;
  bool _keyError = false;
  String? _keyMessage;

  /// Hasil terakhir ekspor atau impor, dengan tanda galat.
  ({String text, bool error})? _backupMessage;

  /// Backup yang sudah dibaca dan menunggu konfirmasi penggabungan.
  ({String json, BackupSummary summary})? _pending;

  @override
  void dispose() {
    _key.dispose();
    super.dispose();
  }

  void _back() => context.canPop() ? context.pop() : context.go(Routes.beranda);

  // ---------------------------------------------------------------- backup

  Future<void> _export() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _backupMessage = null;
    });
    try {
      final now = ref.read(clockProvider).now();
      final text = await ref.read(backupServiceProvider).export(now);
      final local = now.toLocal();
      String two(int v) => v.toString().padLeft(2, '0');
      await ref.read(backupSharerProvider).share(
            fileName: 'simulator-psikotes-backup-${local.year}-'
                '${two(local.month)}-${two(local.day)}.json',
            content: text,
          );
      if (!mounted) return;
      setState(() {
        _busy = false;
        _backupMessage = (
          text: 'Backup dibagikan. Simpan berkasnya di tempat yang pribadi.',
          error: false,
        );
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _backupMessage = (
          text: 'Backup belum dibagikan. Data di perangkat gagal dibaca atau '
              'lembar bagikan tidak terbuka. Ketuk sekali lagi.',
          error: true,
        );
      });
    }
  }

  Future<void> _pickImport() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _backupMessage = null;
      _pending = null;
    });
    try {
      final json = await ref.read(backupFilePickerProvider)();
      if (json == null) {
        if (mounted) setState(() => _busy = false);
        return;
      }
      final summary = await ref.read(backupServiceProvider).preview(json);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _pending = (json: json, summary: summary);
      });
    } on BackupException catch (e) {
      _fail(e.message);
    } on BackupPickFailure {
      _fail('Pemilih berkas tidak bisa dibuka. Coba lagi.');
    } catch (_) {
      _fail(const BackupException(BackupProblem.unreadable).message);
    }
  }

  Future<void> _confirmImport() async {
    final pending = _pending;
    if (pending == null || _busy) return;
    setState(() {
      _busy = true;
      _backupMessage = null;
    });
    try {
      final summary =
          await ref.read(backupServiceProvider).import(pending.json);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _pending = null;
        _backupMessage = (
          text: 'Backup digabungkan: ${summary.added} baris baru, '
              '${summary.updated} diperbarui. Data lamamu tetap ada.',
          error: false,
        );
      });
    } on BackupException catch (e) {
      _fail(e.message);
    } catch (_) {
      _fail(const BackupException(BackupProblem.failed).message);
    }
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _busy = false;
      _pending = null;
      _backupMessage = (text: message, error: true);
    });
  }

  // ---------------------------------------------------------------- key API

  Future<void> _saveKey(AiProvider provider) async {
    final value = _key.text.trim();
    if (value.isEmpty) {
      setState(() => _keyError = true);
      return;
    }
    try {
      await ref.read(secretStoreProvider).write(provider.secretName, value);
      _key.clear();
      ref.invalidate(apiKeyPresentProvider(provider));
      if (mounted) {
        setState(() {
          _keyError = false;
          _keyMessage = 'Key ${provider.label} tersimpan.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _keyMessage = 'Key belum tersimpan. Penyimpanan aman '
            'di perangkat tidak bisa dipakai. Ketuk simpan sekali lagi.');
      }
    }
  }

  Future<void> _deleteKey(AiProvider provider) async {
    try {
      await ref.read(secretStoreProvider).delete(provider.secretName);
      ref.invalidate(apiKeyPresentProvider(provider));
      if (mounted) {
        setState(() => _keyMessage = 'Key ${provider.label} dihapus.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _keyMessage = 'Key belum terhapus. Ketuk hapus '
            'sekali lagi.');
      }
    }
  }

  // ---------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final profiles = ref.watch(profilesProvider);
    final theme = ref.watch(themeSettingProvider);
    final provider = ref.watch(aiProviderSettingProvider);
    final limit = ref.watch(interviewLimitProvider);
    final all = [profiles, theme, provider, limit];

    Widget body;
    if (all.any((v) => v is AsyncError)) {
      body = ErrorView(
        title: 'Pengaturan tidak bisa dibuka',
        message: 'Data pengaturan gagal dibaca. Ketuk coba lagi. Datamu '
            'tidak hilang.',
        onRetry: () {
          ref.invalidate(profilesProvider);
          ref.invalidate(themeSettingProvider);
          ref.invalidate(aiProviderSettingProvider);
          ref.invalidate(interviewLimitProvider);
        },
      );
    } else if (all.any((v) => !v.hasValue)) {
      body = const SkeletonList(rows: 8, semanticLabel: 'Memuat pengaturan');
    } else {
      body = _content(
        profiles.requireValue,
        theme.requireValue,
        provider.valueOrNull,
        limit.requireValue,
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            AppTopBar(title: 'Pengaturan', onBack: _back),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: AppSpace.s32),
                child: body,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _content(
    List<TestProfile> profiles,
    ThemeSetting theme,
    AiProvider? provider,
    int limit,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Section('Profil tes', child: _profileSection(profiles)),
        _Section('Data', child: _dataSection()),
        _Section('Wawancara AI', child: _interviewSection(provider, limit)),
        _Section('Tampilan', child: _themeSection(theme)),
        _Section('Tentang latihan ini', child: _disclaimer()),
      ],
    );
  }

  // ---------------------------------------------------------------- profil

  Widget _profileSection(List<TestProfile> profiles) {
    if (profiles.isEmpty) {
      return EmptyView(
        title: 'Belum ada profil tes',
        message: 'Buat profil agar rencana latihan bisa disusun.',
        actionLabel: 'Buat profil tes',
        onAction: _newProfile,
      );
    }
    return Column(
      children: [
        for (final p in profiles)
          ListRow(
            title: p.nama,
            subtitle: p.aktif
                ? 'Profil aktif. Ketuk untuk mengubah.'
                : 'Ketuk untuk menjadikan aktif.',
            trailing: p.aktif
                ? const StatusTag(label: 'Aktif', kind: StatusTagKind.strong)
                : null,
            onTap: () => p.aktif
                ? unawaited(context.push(Routes.profilUbah(p.id!)))
                : unawaited(
                    ref.read(profileRepositoryProvider).setActive(p.id!),
                  ),
          ),
        ListRow(
          title: 'Tambah profil tes',
          leading: AppIcons.plus,
          onTap: _newProfile,
        ),
        ListRow(
          title: 'Ulangi diagnostik',
          subtitle: 'Hasil lama tetap tersimpan.',
          leading: AppIcons.target,
          onTap: () => unawaited(context.push(Routes.onboardingDiagnostik)),
        ),
      ],
    );
  }

  void _newProfile() {
    ref.read(onboardingDraftProvider.notifier).reset();
    unawaited(context.push(Routes.onboardingRole));
  }

  // ---------------------------------------------------------------- data

  Widget _dataSection() {
    final pending = _pending;
    final message = _backupMessage;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const NoteBox(
            icon: AppIcons.lock,
            text: 'Backup memuat profil, riwayat sesi, buku kesalahan, soal '
                'Capture, dan catatan tes. Foto Capture, teks CV, dan API key '
                'tidak ikut. Simpan berkasnya di tempat yang pribadi.',
          ),
          const SizedBox(height: AppSpace.s12),
          AppButton(
            label: 'Ekspor backup',
            icon: AppIcons.download,
            onPressed: _busy ? null : () => unawaited(_export()),
          ),
          const SizedBox(height: AppSpace.s8),
          AppButton(
            label: 'Impor backup',
            icon: AppIcons.upload,
            variant: AppButtonVariant.outline,
            onPressed: _busy ? null : () => unawaited(_pickImport()),
          ),
          if (message != null) ...[
            const SizedBox(height: AppSpace.s12),
            Semantics(
              liveRegion: true,
              child: NoteBox(
                icon: message.error ? AppIcons.alert : AppIcons.check,
                text: message.text,
              ),
            ),
          ],
          if (pending != null) ..._importPreview(pending.summary),
        ],
      ),
    );
  }

  List<Widget> _importPreview(BackupSummary s) {
    final c = context.tokens.colors;
    final date = s.diekspor?.toLocal();
    final shown = [
      for (final name in _tableNames.keys)
        if ((s.tabel[name]?.total ?? 0) > 0) name,
    ];
    return [
      const SizedBox(height: AppSpace.s16),
      Semantics(
        header: true,
        child: Text('Isi backup', style: AppType.title(c.ink)),
      ),
      if (date != null)
        Padding(
          padding: const EdgeInsets.only(top: AppSpace.s4),
          child: Text(
            'Dibuat ${formatDay(date)} ${date.year}.',
            style: AppType.label(c.inkMuted),
          ),
        ),
      const SizedBox(height: AppSpace.s8),
      if (shown.isEmpty)
        const NoteBox(text: 'Backup ini tidak berisi data. Pilih berkas lain.')
      else ...[
        for (final name in shown)
          Semantics(
            container: true,
            child: _SummaryRow(
              title: _tableNames[name]!,
              count: s.tabel[name]!,
            ),
          ),
        const SizedBox(height: AppSpace.s12),
        Text(
          'Data di perangkat ini tidak dihapus. Bila id sama, baris yang '
          'lebih baru dipakai.',
          style: AppType.label(c.inkMuted),
        ),
        const SizedBox(height: AppSpace.s12),
        AppButton(
          label: 'Gabungkan ke data ini',
          onPressed: _busy ? null : () => unawaited(_confirmImport()),
        ),
      ],
      const SizedBox(height: AppSpace.s8),
      AppButton(
        label: 'Batal',
        variant: AppButtonVariant.secondary,
        onPressed: _busy ? null : () => setState(() => _pending = null),
      ),
    ];
  }

  // ---------------------------------------------------------------- AI

  Widget _interviewSection(AiProvider? selected, int limit) {
    final c = context.tokens.colors;
    final store = ref.watch(secretStoreProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Wawancara memakai key milikmu. Tanpa key, app memakai kartu '
            'pertanyaan template.',
            style: AppType.body(c.inkMuted),
          ),
          const SizedBox(height: AppSpace.s12),
          Semantics(
            container: true,
            label: 'Penyedia AI',
            child: Wrap(
              spacing: AppSpace.s8,
              children: [
                for (final p in AiProvider.values)
                  AppChip(
                    label: p.label,
                    selected: selected == p,
                    onTap: () {
                      setState(() {
                        _keyMessage = null;
                        _keyError = false;
                        _key.clear();
                      });
                      unawaited(ref
                          .read(settingsRepositoryProvider)
                          .set(SettingKeys.penyediaAi, p.code));
                    },
                  ),
              ],
            ),
          ),
          if (selected != null) ..._keyBlock(selected),
          const SizedBox(height: AppSpace.s12),
          NoteBox(
            icon: AppIcons.lock,
            text: store.persistent
                ? 'Disimpan terenkripsi di perangkat, tidak pernah ke server '
                    'kami.'
                : 'Key hanya disimpan selama tab ini terbuka.',
          ),
          const SizedBox(height: AppSpace.s12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Batas sesi per hari',
                      style: AppType.body(c.ink)
                          .copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: AppSpace.s4),
                    Text(
                      'Wawancara memakai internet dan kuota key-mu.',
                      style: AppType.label(c.inkMuted),
                    ),
                  ],
                ),
              ),
              AppIconButton(
                icon: AppIcons.minus,
                label: 'Kurangi batas sesi per hari',
                onPressed: limit <= minInterviewLimit
                    ? null
                    : () => _setLimit(limit - 1),
              ),
              Semantics(
                label: 'Batas $limit sesi per hari',
                excludeSemantics: true,
                child: SizedBox(
                  width: AppSpace.s32,
                  child: Text(
                    '$limit',
                    textAlign: TextAlign.center,
                    style: AppType.title(c.ink)
                        .copyWith(fontFeatures: AppType.tabular),
                  ),
                ),
              ),
              AppIconButton(
                icon: AppIcons.plus,
                label: 'Tambah batas sesi per hari',
                onPressed: limit >= maxInterviewLimit
                    ? null
                    : () => _setLimit(limit + 1),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _setLimit(int value) => unawaited(
        ref
            .read(settingsRepositoryProvider)
            .set(SettingKeys.batasWawancaraHarian, '$value'),
      );

  List<Widget> _keyBlock(AiProvider p) {
    final c = context.tokens.colors;
    final present = ref.watch(apiKeyPresentProvider(p));
    return [
      const SizedBox(height: AppSpace.s12),
      present.when(
        loading: () => const SkeletonList(
          rows: 1,
          semanticLabel: 'Memeriksa key',
        ),
        error: (_, __) => ErrorView(
          title: 'Key tidak bisa diperiksa',
          message: 'Penyimpanan aman di perangkat tidak bisa dibaca. Ketuk '
              'coba lagi.',
          onRetry: () => ref.invalidate(apiKeyPresentProvider(p)),
        ),
        data: (has) => has
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const StatusTag(
                        label: 'Tersimpan',
                        kind: StatusTagKind.strong,
                      ),
                      const SizedBox(width: AppSpace.s8),
                      Expanded(
                        child: Text(
                          'Key ${p.label} sudah ada.',
                          style: AppType.body(c.ink),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpace.s8),
                  AppButton(
                    label: 'Hapus key ${p.label}',
                    variant: AppButtonVariant.secondary,
                    expand: false,
                    onPressed: () => unawaited(_deleteKey(p)),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppTextField(
                    label: 'API key ${p.label}',
                    controller: _key,
                    obscureText: true,
                    hint: 'Tempel key di sini',
                    errorText: _keyError
                        ? 'Tempel key dari ${p.label} dulu, lalu simpan.'
                        : null,
                    onChanged: (_) {
                      if (_keyError) setState(() => _keyError = false);
                    },
                  ),
                  const SizedBox(height: AppSpace.s8),
                  AppButton(
                    label: 'Simpan key ${p.label}',
                    expand: false,
                    onPressed: () => unawaited(_saveKey(p)),
                  ),
                ],
              ),
      ),
      if (_keyMessage != null) ...[
        const SizedBox(height: AppSpace.s8),
        Semantics(
          liveRegion: true,
          child: Text(_keyMessage!, style: AppType.label(c.inkMuted)),
        ),
      ],
    ];
  }

  // ---------------------------------------------------------------- tema

  Widget _themeSection(ThemeSetting theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SegmentedControl(
            options: const ['Terang', 'Gelap', 'Sistem'],
            selectedIndex: ThemeSetting.values.indexOf(theme),
            onChanged: (i) => unawaited(
              ref
                  .read(settingsRepositoryProvider)
                  .setTheme(ThemeSetting.values[i]),
            ),
          ),
          if (theme != ThemeSetting.terang) ...[
            const SizedBox(height: AppSpace.s12),
            const NoteBox(
              text: 'Tema gelap tersedia di v1.1. Pilihanmu tersimpan dan '
                  'berlaku saat tema gelap rilis. Sekarang app tetap terang.',
            ),
          ],
        ],
      ),
    );
  }

  Widget _disclaimer() {
    final c = context.tokens.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.s16),
      child: Text(
        'Simulator ini untuk latihan mandiri. Soalnya dibuat sendiri dan '
        'tidak disalin dari tes perusahaan atau penyedia tes mana pun. Hasil '
        'latihan bukan penilaian resmi. Interpretasi kepribadian bersifat '
        'edukatif, bukan diagnosis.',
        style: AppType.label(c.inkMuted),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title, {required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.tokens.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.s16,
            AppSpace.s24,
            AppSpace.s16,
            AppSpace.s8,
          ),
          child: Semantics(
            header: true,
            child: Text(title, style: AppType.title(c.ink)),
          ),
        ),
        child,
      ],
    );
  }
}

/// Satu baris ringkasan impor: nama tabel dan hitungannya, tanpa chevron.
class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.title, required this.count});

  final String title;
  final BackupTableCount count;

  @override
  Widget build(BuildContext context) {
    final parts = [
      if (count.added > 0) '${count.added} baru',
      if (count.updated > 0) '${count.updated} diperbarui',
      if (count.kept > 0) '${count.kept} sudah ada',
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.s4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: AppType.body(context.tokens.colors.ink)
                  .copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: AppSpace.s12),
          Flexible(
            child: Text(
              parts.join(', '),
              textAlign: TextAlign.end,
              style: AppType.label(context.tokens.colors.inkMuted),
            ),
          ),
        ],
      ),
    );
  }
}
