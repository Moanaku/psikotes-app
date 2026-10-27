import 'dart:convert';

import 'package:drift/drift.dart';

import '../../domain/models/codes.dart';
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
        'knowledge_progress' => _db.knowledgeProgressTable,
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
      final order = switch (name) {
        'app_setting' => 'key',
        'knowledge_progress' => 'butir_id',
        _ => 'id',
      };
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

  /// Menyusun penggabungan. Baris dianggap sama bila nomornya (id) sama dan
  /// waktu pembuatannya sama (`dibuat`, `mulai`, atau `tanggal`); baris sama
  /// dibiarkan. Nomor yang sama dengan isi lain berarti baris lain dari
  /// perangkat lain: ia diberi nomor baru, dan semua rujukan ke nomor itu
  /// (sesi ke profil, jawaban ke sesi, rencana sesi ke soal Capture dan kartu,
  /// soal Capture ke catatan tes) dipetakan ke nomor barunya. Kartu buku
  /// kesalahan dikenali dari soalnya, bukan dari nomornya.
  Future<_Plan> _plan(BackupFile file) async {
    const bad = BackupException(BackupProblem.unreadable);
    final plan = _Plan(file);

    // Baris yang sudah ada di perangkat: id dan sidik jarinya.
    Future<Map<int, String>> existing(String table) async {
      final rows = await _db.customSelect('SELECT * FROM $table').get();
      return {
        for (final r in rows) r.read<int>('id'): _fingerprint(table, r.data),
      };
    }

    final onDevice = <String, Map<int, String>>{
      for (final t in const [
        'test_profile',
        'company_test_log',
        'captured_question',
        'session',
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

    // Kartu di perangkat: id dan kunci soalnya.
    final cardRows = await _db
        .customSelect('SELECT id, sumber, tipe, seed, ref_id FROM mistake_card')
        .get();
    final deviceCardKeys = <String, int>{
      for (final r in cardRows)
        _cardKey(
          r.read<String>('sumber'),
          r.read<String>('tipe'),
          r.readNullable<int>('seed'),
          r.readNullable<int>('ref_id'),
        ): r.read<int>('id'),
    };
    final usedCardIds = {for (final r in cardRows) r.read<int>('id')};

    // Nomor baru dibagikan di atas semua nomor yang ada di perangkat dan di
    // berkas, jadi tidak pernah menabrak nomor lain.
    final nextId = <String, int>{};
    int maxOf(Iterable<int> ids) => ids.fold(0, (a, b) => a > b ? a : b);
    for (final t in const [
      'test_profile',
      'company_test_log',
      'captured_question',
      'session',
    ]) {
      nextId[t] = maxOf([
        ...?onDevice[t]?.keys,
        for (final r in file.rows(t)) r['id']! as int,
      ]);
    }
    nextId['mistake_card'] = maxOf([
      ...usedCardIds,
      for (final r in file.rows('mistake_card')) r['id']! as int,
    ]);
    int fresh(String table) => nextId[table] = nextId[table]! + 1;

    final hasActive = (await _db
            .customSelect(
                'SELECT COUNT(*) AS n FROM test_profile WHERE aktif = 1')
            .getSingle())
        .read<int>('n');
    var activeTaken = hasActive > 0;

    final profileMap = <int, int>{};
    final logMap = <int, int>{};
    final captureMap = <int, int>{};
    final cardMap = <int, int>{};
    final sessionMap = <int, int>{};

    // Sidik jari -> nomor di perangkat, dan nomor yang sudah terpakai.
    final byPrint = {
      for (final e in onDevice.entries)
        e.key: {for (final p in e.value.entries) p.value: p.key},
    };
    final usedIds = {
      for (final e in onDevice.entries) e.key: e.value.keys.toSet(),
    };

    /// Menempatkan baris dari berkas: baris yang sama sudah ada di perangkat
    /// (dibiarkan, rujukan diarahkan ke nomornya di sini), nomornya bebas
    /// (dipakai apa adanya), atau nomornya sudah dipakai baris lain (nomor
    /// baru). Mengembalikan nomor yang dipakai dan apakah baris perlu ditulis.
    ({int id, bool write}) place(
      String table,
      Map<String, Object?> row,
      Map<int, int> map,
      _TablePlan t,
    ) {
      final id = row['id']! as int;
      final print = _fingerprint(table, row);
      final known = byPrint[table]![print];
      if (known != null) {
        map[id] = known;
        return (id: known, write: false);
      }
      var nid = id;
      if (usedIds[table]!.contains(id)) {
        nid = fresh(table);
        t.renumbered++;
      }
      usedIds[table]!.add(nid);
      byPrint[table]![print] = nid;
      map[id] = nid;
      return (id: nid, write: true);
    }

    for (final name in const [
      'test_profile',
      'company_test_log',
      'captured_question',
      'mistake_card',
      'session',
      'answer',
      'knowledge_progress',
      'app_setting',
    ]) {
      if (BackupFormat.deferred.contains(name)) continue;
      final rows = file.rows(name);
      if (!file.tables.containsKey(name)) continue;
      final t = plan.tables[name] = _TablePlan(rows.length);

      switch (name) {
        case 'test_profile':
          for (final r in rows) {
            final p = place(name, r, profileMap, t);
            if (!p.write) continue;
            final wantsActive = r['aktif'] == 1 && !activeTaken;
            if (wantsActive) activeTaken = true;
            t.inserts.add({...r, 'id': p.id, 'aktif': wantsActive ? 1 : 0});
          }
        case 'company_test_log':
          for (final r in rows) {
            final p = place(name, r, logMap, t);
            if (p.write) t.inserts.add({...r, 'id': p.id});
          }
        case 'captured_question':
          for (final r in rows) {
            final p = place(name, r, captureMap, t);
            if (!p.write) continue;
            final log = r['company_log_id'] as int?;
            t.inserts.add({
              ...r,
              'id': p.id,
              'company_log_id': log == null ? null : (logMap[log] ?? log),
            });
          }
        case 'mistake_card':
          for (final r in rows) {
            final id = r['id']! as int;
            final capture = r['sumber'] == AnswerSource.capture.code;
            final ref = r['ref_id'] as int?;
            final mappedRef =
                capture && ref != null ? (captureMap[ref] ?? ref) : ref;
            final key = _cardKey(
              r['sumber']! as String,
              r['tipe']! as String,
              r['seed'] as int?,
              mappedRef,
            );
            final known = deviceCardKeys[key];
            if (known != null) {
              // Soal yang sama sudah punya kartu; kartu di perangkat dipakai.
              cardMap[id] = known;
              continue;
            }
            var nid = id;
            if (usedCardIds.contains(nid)) {
              nid = fresh(name);
              t.renumbered++;
            }
            usedCardIds.add(nid);
            deviceCardKeys[key] = nid;
            cardMap[id] = nid;
            t.inserts.add({...r, 'id': nid, 'ref_id': mappedRef});
          }
        case 'session':
          for (final r in rows) {
            final p = place(name, r, sessionMap, t);
            final id = r['id']! as int;
            if (!p.write) {
              plan.sessionDecision[id] = _Decision.keep;
              continue;
            }
            plan.sessionDecision[id] = _Decision.add;
            final profile = r['profile_id']! as int;
            t.inserts.add({
              ...r,
              'id': p.id,
              'profile_id': profileMap[profile] ?? profile,
              'rencana_json': _remapPlan(
                r['rencana_json']! as String,
                captureMap,
                cardMap,
              ),
            });
          }
        case 'answer':
          // Jawaban mengikuti keputusan sesinya: sesi baru membawa jawabannya,
          // sesi yang sama dibiarkan.
          final withoutId = <Map<String, Object?>>[];
          final usedIds = {
            for (final r
                in await _db.customSelect('SELECT id FROM answer').get())
              r.read<int>('id'),
          };
          for (final r in rows) {
            final session = r['session_id']! as int;
            if (plan.sessionDecision[session] != _Decision.add) continue;
            final capture = r['sumber'] == AnswerSource.capture.code;
            final ref = r['ref_id'] as int?;
            final row = {
              ...r,
              'session_id': sessionMap[session] ?? session,
              'ref_id': capture && ref != null ? (captureMap[ref] ?? ref) : ref,
            };
            if (usedIds.contains(r['id'])) {
              withoutId.add(row..remove('id'));
            } else {
              usedIds.add(r['id']! as int);
              t.inserts.add(row);
            }
          }
          // Id baru dibuat setelah semua id bawaan terpakai, supaya nomor
          // otomatis tidak menabrak id berikutnya dari berkas.
          t.inserts.addAll(withoutId);
        case 'knowledge_progress':
          // Kemajuan di perangkat ini tidak ditimpa; hanya butir yang belum
          // pernah dinilai di sini yang masuk.
          final known = {
            for (final r in await _db
                .customSelect('SELECT butir_id FROM knowledge_progress')
                .get())
              r.read<String>('butir_id'),
          };
          for (final r in rows) {
            if (!known.contains(r['butir_id'])) t.inserts.add(r);
          }
        case 'app_setting':
          final keys = {
            for (final r
                in await _db.customSelect('SELECT key FROM app_setting').get())
              r.read<String>('key'),
          };
          for (final r in rows) {
            if (!keys.contains(r['key'])) t.inserts.add(r);
          }
      }
    }
    return plan;
  }

  /// Sidik jari sebuah baris: apa yang membuatnya baris yang sama di perangkat
  /// lain, tidak bergantung pada nomornya. Waktu pembuatan (milidetik) dengan
  /// satu isian pembeda; isian yang bisa diubah pengguna tidak dipakai kecuali
  /// perlu.
  static String _fingerprint(String table, Map<String, Object?> r) =>
      switch (table) {
        'test_profile' => '${r['dibuat']}|${r['nama']}',
        'company_test_log' => '${r['perusahaan']}|${r['tanggal']}',
        'captured_question' => '${r['dibuat']}',
        'session' => '${r['mulai']}|${r['mode']}',
        _ => throw ArgumentError('tabel tanpa sidik jari: $table'),
      };

  /// Kunci soal sebuah kartu: soal engine dari (tipe, seed), soal lain dari
  /// (sumber, tipe, ref_id), sama dengan `MistakeRepository`.
  static String _cardKey(String sumber, String tipe, int? seed, int? ref) =>
      sumber == AnswerSource.engine.code
          ? '$sumber|$tipe|$seed'
          : '$sumber|$tipe|$ref';

  /// Rencana sesi dengan rujukan soal Capture dan kartu dipetakan ke nomor
  /// barunya.
  static String _remapPlan(
    String json,
    Map<int, int> captures,
    Map<int, int> cards,
  ) {
    final plan = (jsonDecode(json) as Map).cast<String, Object?>();
    final items = <Object?>[];
    for (final i in plan['items']! as List) {
      final item = Map<String, Object?>.from(i as Map);
      final ref = item['refId'];
      if (ref is int) item['refId'] = captures[ref] ?? ref;
      final card = item['cardId'];
      if (card is int) item['cardId'] = cards[card] ?? card;
      items.add(item);
    }
    return jsonEncode({...plan, 'items': items});
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

enum _Decision { add, keep }

class _TablePlan {
  _TablePlan(this.total);

  final int total;
  final List<Map<String, Object?>> inserts = [];

  /// Dari [inserts], yang diberi nomor baru karena bentrok.
  int renumbered = 0;
}

class _Plan {
  _Plan(this.file);

  final BackupFile file;
  final Map<String, _TablePlan> tables = {};
  final Map<int, _Decision> sessionDecision = {};

  BackupSummary get summary => BackupSummary(
        versi: file.versi,
        diekspor: file.diekspor,
        tabel: {
          for (final e in tables.entries)
            e.key: BackupTableCount(
              total: e.value.total,
              added: e.value.inserts.length,
              renumbered: e.value.renumbered,
            ),
        },
      );
}
