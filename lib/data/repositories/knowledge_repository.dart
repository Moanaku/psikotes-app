import '../../domain/models/knowledge.dart';
import '../../domain/repositories/repositories.dart';
import '../db/app_database.dart';

KnowledgeProgress? _progress(KnowledgeProgressRow r) {
  final level = KnowledgeLevel.fromCode(r.level);
  // Baris dengan level yang tidak dikenal (dari backup versi lain) dilewati,
  // bukan membuat daftar gagal dibaca.
  if (level == null) return null;
  return KnowledgeProgress(
    butirId: r.butirId,
    level: level,
    terakhir: DateTime.fromMillisecondsSinceEpoch(r.terakhir, isUtc: true),
    dikuasai: r.dikuasai,
  );
}

Map<String, KnowledgeProgress> _map(List<KnowledgeProgressRow> rows) => {
      for (final r in rows)
        if (_progress(r) case final p?) p.butirId: p,
    };

class DriftKnowledgeRepository implements KnowledgeRepository {
  DriftKnowledgeRepository(this._db);

  final AppDatabase _db;

  @override
  Stream<Map<String, KnowledgeProgress>> watchAll() =>
      _db.select(_db.knowledgeProgressTable).watch().map(_map);

  @override
  Future<Map<String, KnowledgeProgress>> all() async =>
      _map(await _db.select(_db.knowledgeProgressTable).get());

  @override
  Future<void> save(KnowledgeProgress p) =>
      _db.into(_db.knowledgeProgressTable).insertOnConflictUpdate(
            KnowledgeProgressTableCompanion.insert(
              butirId: p.butirId,
              level: p.level.code,
              terakhir: p.terakhir.millisecondsSinceEpoch,
              dikuasai: p.dikuasai,
            ),
          );
}
