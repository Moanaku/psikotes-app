import 'dart:async';

import 'package:simulator_psikotes_it/domain/models/codes.dart';
import 'package:simulator_psikotes_it/domain/repositories/repositories.dart';
import 'package:simulator_psikotes_it/domain/services/backup.dart';
import 'package:simulator_psikotes_it/features/settings/settings_provider.dart';

/// `app_setting` di memori dengan aliran per kunci.
class FakeSettingsRepository implements SettingsRepository {
  FakeSettingsRepository([Map<String, String> initial = const {}])
      : values = {...initial};

  final Map<String, String> values;
  final StreamController<void> _changes =
      StreamController.broadcast(sync: true);

  /// Bila diisi, `watch` mengeluarkan galat ini.
  Object? failWith;

  /// Bila diisi, `watch` menahan data pertama sampai selesai (kondisi memuat).
  Completer<void>? gate;

  @override
  Future<String?> get(String key) async => values[key];

  @override
  Stream<String?> watch(String key) => Stream.multi((c) async {
        await gate?.future;
        if (failWith != null) {
          c.addError(failWith!);
          return;
        }
        c.add(values[key]);
        final sub = _changes.stream.listen((_) => c.add(values[key]));
        c.onCancel = sub.cancel;
      });

  @override
  Future<void> set(String key, String value) async {
    values[key] = value;
    _changes.add(null);
  }

  @override
  Future<ThemeSetting> theme() async {
    final v = values[SettingKeys.tema];
    return v == null ? ThemeSetting.terang : ThemeSetting.fromCode(v);
  }

  @override
  Future<void> setTheme(ThemeSetting theme) =>
      set(SettingKeys.tema, theme.code);
}

/// Layanan backup tiruan: mencatat panggilan dan mengembalikan hasil yang
/// diatur test.
class FakeBackupService implements BackupService {
  String exportText = '{"format":"simulator-psikotes-backup","versi":1}';
  Object? exportFailWith;
  BackupSummary? summary;
  Object? previewFailWith;
  Object? importFailWith;
  final List<DateTime> exports = [];
  final List<String> previews = [];
  final List<String> imports = [];

  @override
  Future<String> export(DateTime now) async {
    exports.add(now);
    if (exportFailWith != null) throw exportFailWith!;
    return exportText;
  }

  @override
  Future<BackupSummary> preview(String json) async {
    previews.add(json);
    if (previewFailWith != null) throw previewFailWith!;
    return summary!;
  }

  @override
  Future<BackupSummary> import(String json) async {
    imports.add(json);
    if (importFailWith != null) throw importFailWith!;
    return summary!;
  }
}

class FakeBackupSharer implements BackupSharer {
  final List<({String fileName, String content})> shared = [];
  Object? failWith;

  @override
  Future<void> share(
      {required String fileName, required String content}) async {
    if (failWith != null) throw failWith!;
    shared.add((fileName: fileName, content: content));
  }
}
