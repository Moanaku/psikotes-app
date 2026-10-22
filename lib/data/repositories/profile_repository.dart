import 'dart:convert';

import 'package:drift/drift.dart';

import '../../domain/models/codes.dart';
import '../../domain/models/profile.dart';
import '../../domain/repositories/repositories.dart';
import '../db/app_database.dart';

DateTime _utc(int ms) => DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);

class DriftProfileRepository implements ProfileRepository {
  DriftProfileRepository(this._db);

  final AppDatabase _db;

  TestProfile _map(ProfileRow r) => TestProfile(
        id: r.id,
        nama: r.nama,
        role: ProfileRole.fromCode(r.role),
        formatTes: TestFormat.fromCode(r.formatTes),
        tanggalTes: r.tanggalTes == null ? null : _utc(r.tanggalTes!),
        aktif: r.aktif,
        blueprint: ProfileBlueprint.fromJson(
          (jsonDecode(r.blueprintJson) as Map).cast<String, Object?>(),
        ),
        cvTeks: r.cvTeks,
        dibuat: _utc(r.dibuat),
      );

  @override
  Stream<List<TestProfile>> watchAll() {
    final q = _db.select(_db.testProfileTable)
      ..orderBy([(t) => OrderingTerm.asc(t.id)]);
    return q.watch().map((rows) => rows.map(_map).toList());
  }

  @override
  Future<TestProfile?> active() async {
    final row = await (_db.select(_db.testProfileTable)
          ..where((t) => t.aktif.equals(true))
          ..limit(1))
        .getSingleOrNull();
    return row == null ? null : _map(row);
  }

  @override
  Future<TestProfile?> byId(int id) async {
    final row = await (_db.select(_db.testProfileTable)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _map(row);
  }

  @override
  Future<int> save(TestProfile p) => _db.transaction(() async {
        final hasAny = await (_db.selectOnly(_db.testProfileTable)
              ..addColumns([_db.testProfileTable.id])
              ..limit(1))
            .get();
        final makeActive = p.aktif || hasAny.isEmpty;
        final companion = TestProfileTableCompanion(
          nama: Value(p.nama),
          role: Value(p.role.code),
          formatTes: Value(p.formatTes.code),
          tanggalTes: Value(p.tanggalTes?.millisecondsSinceEpoch),
          blueprintJson: Value(jsonEncode(p.blueprint.toJson())),
          dibuat: Value(p.dibuat.millisecondsSinceEpoch),
        );
        late int id;
        if (p.id == null) {
          id = await _db.into(_db.testProfileTable).insert(
                companion.copyWith(
                  aktif: const Value(false),
                  cvTeks: Value(p.cvTeks),
                ),
              );
        } else {
          id = p.id!;
          final updated = await (_db.update(_db.testProfileTable)
                ..where((t) => t.id.equals(id)))
              .write(p.cvTeks == null
                  ? companion
                  : companion.copyWith(cvTeks: Value(p.cvTeks)));
          if (updated == 0) throw StateError('profil $id tidak ada');
        }
        if (makeActive) await _setActive(id);
        return id;
      });

  @override
  Future<void> setCv(int id, String? cvTeks) async {
    final n = await (_db.update(_db.testProfileTable)
          ..where((t) => t.id.equals(id)))
        .write(TestProfileTableCompanion(cvTeks: Value(cvTeks)));
    if (n == 0) throw StateError('profil $id tidak ada');
  }

  @override
  Future<void> setActive(int id) => _db.transaction(() => _setActive(id));

  Future<void> _setActive(int id) async {
    final exists = await (_db.select(_db.testProfileTable)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (exists == null) throw StateError('profil $id tidak ada');
    await _db.update(_db.testProfileTable).write(
          const TestProfileTableCompanion(aktif: Value(false)),
        );
    await (_db.update(_db.testProfileTable)..where((t) => t.id.equals(id)))
        .write(const TestProfileTableCompanion(aktif: Value(true)));
  }
}
