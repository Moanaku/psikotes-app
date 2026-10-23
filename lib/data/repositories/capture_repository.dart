import 'dart:convert';

import 'package:drift/drift.dart';

import '../../domain/models/codes.dart';
import '../../domain/models/notebook.dart';
import '../../domain/repositories/repositories.dart';
import '../db/app_database.dart';

DateTime _utc(int ms) => DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);

List<String> _strings(String json) =>
    [for (final v in jsonDecode(json) as List) v as String];

CapturedQuestion _capture(CapturedQuestionRow r) => CapturedQuestion(
      id: r.id,
      teks: r.teks,
      opsi: _strings(r.opsiJson),
      kunci: r.kunci,
      pembahasan: r.pembahasan,
      kategori: r.kategori,
      fotoPath: r.fotoPath,
      companyLogId: r.companyLogId,
      dibuat: _utc(r.dibuat),
    );

CompanyTestLog _log(CompanyLogRow r) => CompanyTestLog(
      id: r.id,
      perusahaan: r.perusahaan,
      tanggal: _utc(r.tanggal),
      subtes: _strings(r.subtesJson),
      tipeBaru: _strings(r.tipeBaruJson),
      catatan: r.catatan,
    );

class DriftCaptureRepository implements CaptureRepository {
  DriftCaptureRepository(this._db);

  final AppDatabase _db;

  @override
  Stream<List<CapturedQuestion>> watchAll() {
    final q = _db.select(_db.capturedQuestionTable)
      ..orderBy(
          [(t) => OrderingTerm.desc(t.dibuat), (t) => OrderingTerm.desc(t.id)]);
    return q.watch().map((rows) => rows.map(_capture).toList());
  }

  @override
  Future<CapturedQuestion?> byId(int id) async {
    final row = await (_db.select(_db.capturedQuestionTable)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _capture(row);
  }

  @override
  Future<int> save(CapturedQuestion c) async {
    final issues = c.validate();
    if (issues.isNotEmpty) {
      throw ArgumentError('soal tangkapan tidak sah: ${issues.join(', ')}');
    }
    final fields = CapturedQuestionTableCompanion(
      teks: Value(c.teks),
      opsiJson: Value(jsonEncode(c.opsi)),
      kunci: Value(c.kunci),
      pembahasan: Value(c.pembahasan),
      kategori: Value(c.kategori),
      fotoPath: Value(c.fotoPath),
      companyLogId: Value(c.companyLogId),
      dibuat: Value(c.dibuat.millisecondsSinceEpoch),
    );
    if (c.id == null) {
      return _db.into(_db.capturedQuestionTable).insert(fields);
    }
    final n = await (_db.update(_db.capturedQuestionTable)
          ..where((t) => t.id.equals(c.id!)))
        .write(fields);
    if (n == 0) throw StateError('soal tangkapan ${c.id} tidak ada');
    return c.id!;
  }

  /// Menghapus soal beserta kartu buku kesalahannya dalam satu transaksi.
  /// Jawaban lama tetap ada sebagai riwayat; pembahasannya menampilkan bahwa
  /// soalnya sudah dihapus.
  @override
  Future<void> delete(int id) => _db.transaction(() async {
        await (_db.delete(_db.mistakeCardTable)
              ..where((t) =>
                  t.sumber.equals(AnswerSource.capture.code) &
                  t.refId.equals(id)))
            .go();
        await (_db.delete(_db.capturedQuestionTable)
              ..where((t) => t.id.equals(id)))
            .go();
      });
}

class DriftCompanyLogRepository implements CompanyLogRepository {
  DriftCompanyLogRepository(this._db);

  final AppDatabase _db;

  @override
  Stream<List<CompanyTestLog>> watchAll() {
    final q = _db.select(_db.companyTestLogTable)
      ..orderBy([
        (t) => OrderingTerm.desc(t.tanggal),
        (t) => OrderingTerm.desc(t.id)
      ]);
    return q.watch().map((rows) => rows.map(_log).toList());
  }

  @override
  Future<CompanyTestLog?> byId(int id) async {
    final row = await (_db.select(_db.companyTestLogTable)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _log(row);
  }

  @override
  Future<int> save(CompanyTestLog l) async {
    final fields = CompanyTestLogTableCompanion(
      perusahaan: Value(l.perusahaan),
      tanggal: Value(l.tanggal.millisecondsSinceEpoch),
      subtesJson: Value(jsonEncode(l.subtes)),
      tipeBaruJson: Value(jsonEncode(l.tipeBaru)),
      catatan: Value(l.catatan),
    );
    if (l.id == null) return _db.into(_db.companyTestLogTable).insert(fields);
    final n = await (_db.update(_db.companyTestLogTable)
          ..where((t) => t.id.equals(l.id!)))
        .write(fields);
    if (n == 0) throw StateError('catatan tes ${l.id} tidak ada');
    return l.id!;
  }
}
