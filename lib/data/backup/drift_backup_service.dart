import 'dart:convert';

import 'package:drift/drift.dart';

import '../../domain/services/backup.dart';
import '../db/app_database.dart';

/// Ekspor dan impor backup lewat SQL mentah per tabel, supaya kolom persis
/// sama dengan database dan format backup (docs/03-data-model.md). Impor
/// berjalan dalam satu transaksi: semua baris masuk atau tidak ada yang
/// berubah.
class DriftBackupService implements BackupService {
  DriftBackupService(this._db, {this.afterTable});

  final AppDatabase _db;

  /// Dipanggil setelah tiap tabel selesai ditulis, di dalam transaksi. Dipakai
  /// test untuk membuktikan bahwa kegagalan di tengah membatalkan semuanya.
  final Future<void> Function(String table)? afterTable;

  TableInfo<Table, dynamic> _info(String name) => switch (name) {
        'test_profile' => _db.testProfileTable,
        'session' => _db.sessionTable,
        'answer' => _db.answerTable,
        'mistake_card' => _db.mistakeCardTable,
        'captured_question' => _db.capturedQuestionTable,
        'company_test_log' => _db.companyTestLogTable,
        'app_setting' => _db.appSettingTable,
        _ => throw ArgumentError('tabel tidak dikenal: $name'),
      };

  // ---------------------------------------------------------------- ekspor

  @override
  Future<String> export(DateTime now) async {
    final tabel = <String, Object?>{};
    for (final name in BackupFormat.order) {
      final cols = BackupFormat.columns[name];
      if (cols == null) {
        tabel[name] = const <Object>[];
        continue;
      }
      final names = [for (final c in cols) c.name];
      final order = name == 'app_setting' ? 'key' : 'id';
      final rows = await _db.customSelect(
        'SELECT ${names.join(', ')} FROM $name ORDER BY $order',
        readsFrom: {_info(name)},
      ).get();
      tabel[name] = [
        for (final r in rows)
          if (name != 'app_setting' ||
              !BackupFormat.isSecretKey(r.read<String>('key')))
            {for (final n in names) n: r.data[n]},
      ];
    }
    return jsonEncode({
      'format': BackupFormat.name,
      'versi': BackupFormat.currentVersion,
      'diekspor': now.millisecondsSinceEpoch,
      'tabel': tabel,
    });
  }

  // ---------------------------------------------------------------- impor

  @override
  Future<BackupSummary> preview(String json) async =>
      (await _plan(BackupFile.parse(json))).summary;

  @override
  Future<BackupSummary> import(String json) async {
    final file = BackupFile.parse(json);
    final plan = await _plan(file);
    try {
      await _db.transaction(() async {
        for (final name in BackupFormat.order) {
          final t = plan.tables[name];
          if (t == null) continue;
          if (name == 'answer') {
            for (final id in plan.replacedSessions) {
              await _write(
                'DELETE FROM answer WHERE session_id = ?',
                [Variable.withInt(id)],
                name,
                UpdateKind.delete,
              );
            }
          }
          for (final row in t.updates) {
            await _update(name, row, plan);
          }
          for (final row in t.inserts) {
            await _insert(name, row, plan);
          }
          await afterTable?.call(name);
        }
        await _ensureOneActiveProfile();
      });
    } on BackupException {
      rethrow;
    } catch (_) {
      throw const BackupException(BackupProblem.failed);
    }
    return plan.summary;
  }

  Future<_Plan> _plan(BackupFile file) async {
    const bad = BackupException(BackupProblem.unreadable);
    final plan = _Plan(file);

    // Baris yang sudah ada di perangkat: id dan waktu pembanding.
    Future<Map<int, int?>> existing(String table) async {
      final recency = BackupFormat.recency[table];
      final rows = await _db
          .customSelect(
            'SELECT id${recency == null ? '' : ', $recency'} FROM $table',
          )
          .get();
      return {
        for (final r in rows)
          r.read<int>('id'): recency == null ? null : r.read<int>(recency),
      };
    }

    final onDevice = {
      for (final t in const [
        'test_profile',
        'company_test_log',
        'captured_question',
        'session',
        'mistake_card',
      ])
        t: await existing(t),
    };

    // Rujukan antartabel harus menunjuk baris yang ada di perangkat atau di
    // berkas.
    Set<int> idsOf(String table) => {
          ...?onDevice[table]?.keys,
          for (final r in file.rows(table)) r['id']! as int,
        };
    final profileIds = idsOf('test_profile');
    final logIds = idsOf('company_test_log');
    final sessionIds = idsOf('session');
    for (final r in file.rows('session')) {
      if (!profileIds.contains(r['profile_id'])) throw bad;
    }
    for (final r in file.rows('captured_question')) {
      final log = r['company_log_id'];
      if (log != null && !logIds.contains(log)) throw bad;
    }
    for (final r in file.rows('answer')) {
      if (!sessionIds.contains(r['session_id'])) throw bad;
    }

    final hasActive = (await _db
            .customSelect(
                'SELECT COUNT(*) AS n FROM test_profile WHERE aktif = 1')
            .getSingle())
        .read<int>('n');
    var activeTaken = hasActive > 0;

    for (final name in BackupFormat.order) {
      if (BackupFormat.deferred.contains(name)) continue;
      final rows = file.rows(name);
      if (!file.tables.containsKey(name)) continue;
      final t = plan.tables[name] = _TablePlan(rows.length);

      switch (name) {
        case 'app_setting':
          final keys = {
            for (final r
                in await _db.customSelect('SELECT key FROM app_setting').get())
              r.read<String>('key'),
          };
          for (final r in rows) {
            if (!keys.contains(r['key'])) t.inserts.add(r);
          }
        case 'answer':
          // Jawaban mengikuti keputusan sesinya.
          final decided = plan.sessionDecision;
          final withoutId = <Map<String, Object?>>[];
          final usedIds = {
            for (final r in await _db
                .customSelect('SELECT id, session_id FROM answer')
                .get())
              if (!plan.replacedSessions.contains(r.read<int>('session_id')))
                r.read<int>('id'),
          };
          for (final r in rows) {
            final d = decided[r['session_id']];
            if (d != _Decision.add && d != _Decision.update) continue;
            if (usedIds.contains(r['id'])) {
              withoutId.add({...r}..remove('id'));
            } else {
              usedIds.add(r['id']! as int);
              t.inserts.add(r);
            }
          }
          // Id baru dibuat setelah semua id bawaan terpakai, supaya nomor
          // otomatis tidak menabrak id berikutnya dari berkas.
          t.inserts.addAll(withoutId);
        default:
          final have = onDevice[name]!;
          final recency = BackupFormat.recency[name]!;
          for (final r in rows) {
            final id = r['id']! as int;
            if (!have.containsKey(id)) {
              if (name == 'test_profile') {
                final wantsActive = r['aktif'] == 1 && !activeTaken;
                if (wantsActive) activeTaken = true;
                t.inserts.add({...r, 'aktif': wantsActive ? 1 : 0});
              } else {
                t.inserts.add(r);
              }
              if (name == 'session') plan.sessionDecision[id] = _Decision.add;
            } else if ((r[recency]! as int) > (have[id] ?? 0)) {
              t.updates.add(r);
              if (name == 'session') {
                plan.sessionDecision[id] = _Decision.update;
                plan.replacedSessions.add(id);
              }
            } else if (name == 'session') {
              plan.sessionDecision[id] = _Decision.keep;
            }
          }
      }
    }
    return plan;
  }

  Future<void> _write(
    String sql,
    List<Variable<Object>> vars,
    String table,
    UpdateKind kind,
  ) =>
      _db.customUpdate(
        sql,
        variables: vars,
        updates: {_info(table)},
        updateKind: kind,
      );

  Variable<Object> _variable(Object? v) => switch (v) {
        null => const Variable<Object>(null),
        int() => Variable.withInt(v),
        double() => Variable.withReal(v),
        String() => Variable.withString(v),
        _ => throw ArgumentError('nilai tidak didukung: ${v.runtimeType}'),
      };

  Future<void> _insert(String table, Map<String, Object?> row, _Plan plan) {
    final names = row.keys.toList();
    return _write(
      'INSERT INTO $table (${names.join(', ')}) '
      'VALUES (${List.filled(names.length, '?').join(', ')})',
      [for (final n in names) _variable(row[n])],
      table,
      UpdateKind.insert,
    );
  }

  Future<void> _update(String table, Map<String, Object?> row, _Plan plan) {
    // Profil yang diperbarui tetap memakai status aktif perangkat ini.
    final skip = {'id', if (table == 'test_profile') 'aktif'};
    final names = [
      for (final n in row.keys)
        if (!skip.contains(n)) n,
    ];
    return _write(
      'UPDATE $table SET ${[for (final n in names) '$n = ?'].join(', ')} '
      'WHERE id = ?',
      [for (final n in names) _variable(row[n]), _variable(row['id'])],
      table,
      UpdateKind.update,
    );
  }

  /// Tepat satu profil aktif setelah impor (docs/03-data-model.md).
  Future<void> _ensureOneActiveProfile() async {
    final active = (await _db
            .customSelect(
                'SELECT COUNT(*) AS n FROM test_profile WHERE aktif = 1')
            .getSingle())
        .read<int>('n');
    if (active == 1) return;
    if (active > 1) {
      await _write(
        'UPDATE test_profile SET aktif = 0 WHERE aktif = 1 AND id <> '
            '(SELECT id FROM test_profile WHERE aktif = 1 ORDER BY dibuat DESC, '
            'id DESC LIMIT 1)',
        const [],
        'test_profile',
        UpdateKind.update,
      );
      return;
    }
    await _write(
      'UPDATE test_profile SET aktif = 1 WHERE id = '
          '(SELECT id FROM test_profile ORDER BY dibuat DESC, id DESC LIMIT 1)',
      const [],
      'test_profile',
      UpdateKind.update,
    );
  }
}

enum _Decision { add, update, keep }

class _TablePlan {
  _TablePlan(this.total);

  final int total;
  final List<Map<String, Object?>> inserts = [];
  final List<Map<String, Object?>> updates = [];
}

class _Plan {
  _Plan(this.file);

  final BackupFile file;
  final Map<String, _TablePlan> tables = {};
  final Map<int, _Decision> sessionDecision = {};

  /// Sesi di perangkat yang digantikan; jawaban lamanya dihapus lebih dulu.
  final Set<int> replacedSessions = {};

  BackupSummary get summary => BackupSummary(
        versi: file.versi,
        diekspor: file.diekspor,
        tabel: {
          for (final e in tables.entries)
            e.key: BackupTableCount(
              total: e.value.total,
              added: e.value.inserts.length,
              updated: e.value.updates.length,
            ),
        },
      );
}
