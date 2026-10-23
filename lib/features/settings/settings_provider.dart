import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../domain/models/codes.dart';
import '../../domain/providers.dart';
import '../../domain/repositories/repositories.dart';
import '../../domain/services/backup.dart';
import '../../domain/services/secret_store.dart';

/// Batas sesi wawancara per hari: bawaan 3 (docs/02-arsitektur.md).
const int defaultInterviewLimit = 3;
const int minInterviewLimit = 1;
const int maxInterviewLimit = 10;

/// Tema terpilih; nilai tak dikenal kembali ke terang. Tema gelap baru berlaku
/// di T21 (A91).
final themeSettingProvider = StreamProvider.autoDispose<ThemeSetting>(
  (ref) =>
      ref.watch(settingsRepositoryProvider).watch(SettingKeys.tema).map((v) {
    try {
      return v == null ? ThemeSetting.terang : ThemeSetting.fromCode(v);
    } on FormatException {
      return ThemeSetting.terang;
    }
  }),
);

/// Penyedia LLM terpilih; null sampai pengguna memilih (Q2 belum dijawab).
final aiProviderSettingProvider = StreamProvider.autoDispose<AiProvider?>(
  (ref) => ref
      .watch(settingsRepositoryProvider)
      .watch(SettingKeys.penyediaAi)
      .map(AiProvider.fromCode),
);

final interviewLimitProvider = StreamProvider.autoDispose<int>(
  (ref) => ref
      .watch(settingsRepositoryProvider)
      .watch(SettingKeys.batasWawancaraHarian)
      .map(
        (v) => (int.tryParse(v ?? '') ?? defaultInterviewLimit)
            .clamp(minInterviewLimit, maxInterviewLimit),
      ),
);

/// Apakah key untuk [AiProvider] tersimpan. Isi key tidak pernah dibaca ke
/// state UI.
final apiKeyPresentProvider =
    FutureProvider.autoDispose.family<bool, AiProvider>((ref, p) async {
  final key = await ref.watch(secretStoreProvider).read(p.secretName);
  return key != null && key.isNotEmpty;
});

/// Berkas backup yang dipilih pengguna sebagai teks; null bila dibatalkan.
/// Melempar [BackupException] (tidak terbaca) atau [BackupPickFailure].
typedef BackupFilePicker = Future<String?> Function();

class BackupPickFailure implements Exception {
  const BackupPickFailure();
}

Future<String?> pickBackupFile() async {
  final FilePickerResult? result;
  try {
    result = await FilePicker.pickFiles(withData: true);
  } catch (_) {
    throw const BackupPickFailure();
  }
  final bytes = result?.files.single.bytes;
  if (result == null) return null;
  if (bytes == null || bytes.length > BackupFormat.maxBytes) {
    throw const BackupException(BackupProblem.unreadable);
  }
  try {
    return utf8.decode(bytes);
  } on FormatException {
    throw const BackupException(BackupProblem.unreadable);
  }
}

final backupFilePickerProvider =
    Provider<BackupFilePicker>((ref) => pickBackupFile);

/// Membagikan berkas backup lewat lembar bagikan sistem; dipisah agar test
/// tidak memanggil plugin.
abstract interface class BackupSharer {
  Future<void> share({required String fileName, required String content});
}

class SharePlusBackupSharer implements BackupSharer {
  const SharePlusBackupSharer();

  @override
  Future<void> share({
    required String fileName,
    required String content,
  }) async {
    final bytes = Uint8List.fromList(utf8.encode(content));
    await SharePlus.instance.share(ShareParams(
      files: [
        XFile.fromData(bytes, mimeType: 'application/json', name: fileName),
      ],
      fileNameOverrides: [fileName],
      title: 'Backup simulator psikotes',
    ));
  }
}

final backupSharerProvider =
    Provider<BackupSharer>((ref) => const SharePlusBackupSharer());
