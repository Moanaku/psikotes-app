import 'package:drift/drift.dart';

import '../../domain/models/codes.dart';
import '../../domain/repositories/repositories.dart';
import '../db/app_database.dart';

class DriftSettingsRepository implements SettingsRepository {
  DriftSettingsRepository(this._db);

  final AppDatabase _db;

  SimpleSelectStatement<$AppSettingTableTable, AppSettingRow> _row(
          String key) =>
      _db.select(_db.appSettingTable)..where((t) => t.key.equals(key));

  @override
  Future<String?> get(String key) async =>
      (await _row(key).getSingleOrNull())?.value;

  @override
  Stream<String?> watch(String key) =>
      _row(key).watchSingleOrNull().map((r) => r?.value);

  @override
  Future<void> set(String key, String value) =>
      _db.into(_db.appSettingTable).insertOnConflictUpdate(
          AppSettingTableCompanion.insert(key: key, value: value));

  @override
  Future<ThemeSetting> theme() async {
    final v = await get(SettingKeys.tema);
    if (v == null) return ThemeSetting.terang;
    try {
      return ThemeSetting.fromCode(v);
    } on FormatException {
      return ThemeSetting.terang;
    }
  }

  @override
  Future<void> setTheme(ThemeSetting theme) =>
      set(SettingKeys.tema, theme.code);
}
