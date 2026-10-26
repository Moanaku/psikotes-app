/// Format dan aturan backup (F11, docs/03-data-model.md, "Format backup").
///
/// Berkas JSON memuat baris mentah tiap tabel (kolom bernama seperti di
/// database). Teks CV mentah dan key API tidak pernah diekspor. Pembacaan dan
/// validasi ada di sini (Dart murni); penulisan satu transaksi ke database ada
/// di `data/backup`.
library;

import 'dart:convert';

import 'package:question_engine/question_engine.dart';

import '../models/codes.dart';
import '../models/session.dart';

enum BackupProblem {
  /// Bukan hasil ekspor app ini, rusak, atau barisnya tidak sah.
  unreadable,

  /// Dibuat oleh versi format yang lebih baru dari yang dikenal app ini.
  newer,

  /// Penggabungan gagal di tengah jalan; data di perangkat tidak berubah.
  failed,
}

/// Galat backup dengan kalimat untuk pengguna (S18), tanpa teks exception.
class BackupException implements Exception {
  const BackupException(this.problem, {this.version});

  final BackupProblem problem;

  /// Versi format di berkas, untuk [BackupProblem.newer].
  final int? version;

  String get message => switch (problem) {
        BackupProblem.unreadable => 'Backup tidak bisa dibaca. Berkasnya bukan '
            'hasil ekspor dari app ini. Pilih berkas lain.',
        BackupProblem.newer => 'Backup dibuat oleh versi app yang lebih baru '
            '(format versi $version, app ini membaca sampai versi '
            '${BackupFormat.currentVersion}). Perbarui app lalu coba lagi.',
        BackupProblem.failed => 'Backup belum digabungkan. Data di perangkat '
            'tidak berubah. Ketuk sekali lagi.',
      };

  @override
  String toString() => 'BackupException(${problem.name})';
}

/// Hitungan satu tabel: baris di berkas, yang baru di perangkat ini, dan yang
/// dibiarkan karena baris yang sama sudah ada. Dari yang baru, [renumbered]
/// adalah baris yang nomornya (id) bentrok dengan baris lain di perangkat ini
/// dan karena itu diberi nomor baru.
class BackupTableCount {
  const BackupTableCount({
    required this.total,
    required this.added,
    this.updated = 0,
    this.renumbered = 0,
  });

  final int total;
  final int added;

  /// Cadangan untuk penggantian baris; impor tidak lagi mengganti baris yang
  /// ada (nomor yang sama dengan isi lain dianggap baris lain), jadi nol.
  final int updated;
  final int renumbered;

  int get kept => total - added - updated;
}

/// Ringkasan isi backup dan dampaknya pada data di perangkat ini.
class BackupSummary {
  const BackupSummary({
    required this.versi,
    required this.diekspor,
    required this.tabel,
  });

  final int versi;
  final DateTime? diekspor;

  /// Menurut nama tabel; hanya tabel yang ada di berkas.
  final Map<String, BackupTableCount> tabel;

  int get totalRows => tabel.values.fold(0, (a, b) => a + b.total);
  int get added => tabel.values.fold(0, (a, b) => a + b.added);
  int get updated => tabel.values.fold(0, (a, b) => a + b.updated);
  int get renumbered => tabel.values.fold(0, (a, b) => a + b.renumbered);
}

abstract class BackupService {
  /// Seluruh data sebagai teks JSON, tanpa teks CV dan key API.
  Future<String> export(DateTime now);

  /// Memeriksa berkas dan menghitung dampaknya tanpa mengubah apa pun. Melempar
  /// [BackupException] bila berkas tidak sah atau lebih baru.
  Future<BackupSummary> preview(String json);

  /// Menggabungkan berkas ke data di perangkat dalam satu transaksi: semuanya
  /// masuk atau tidak ada yang berubah. Melempar [BackupException].
  Future<BackupSummary> import(String json);
}

abstract final class BackupFormat {
  static const String name = 'simulator-psikotes-backup';
  static const int currentVersion = 1;

  /// Berkas lebih besar dari ini ditolak sebelum dibaca.
  static const int maxBytes = 25 * 1024 * 1024;

  /// Urutan tabel yang menghormati kunci asing.
  static const List<String> order = [
    'test_profile',
    'company_test_log',
    'captured_question',
    'session',
    'answer',
    'mistake_card',
    'knowledge_progress',
    'app_setting',
  ];

  /// Tabel yang belum punya penyimpanan di app ini (v1.1); berkasnya diterima
  /// tetapi barisnya belum dipakai.
  static const Set<String> deferred = {'knowledge_progress'};

  static const Map<String, List<BackupColumn>> columns = {
    'test_profile': [
      BackupColumn.int_('id'),
      BackupColumn.text('nama'),
      BackupColumn.text('role'),
      BackupColumn.text('format_tes'),
      BackupColumn.int_('tanggal_tes', nullable: true),
      BackupColumn.int_('aktif'),
      BackupColumn.text('blueprint_json'),
      BackupColumn.int_('dibuat'),
    ],
    'session': [
      BackupColumn.int_('id'),
      BackupColumn.int_('profile_id'),
      BackupColumn.text('mode'),
      BackupColumn.text('rencana_json'),
      BackupColumn.int_('mulai'),
      BackupColumn.int_('selesai', nullable: true),
      BackupColumn.int_('deadline', nullable: true),
      BackupColumn.int_('posisi'),
      BackupColumn.real('skor', nullable: true),
    ],
    'answer': [
      BackupColumn.int_('id'),
      BackupColumn.int_('session_id'),
      BackupColumn.int_('posisi'),
      BackupColumn.text('tipe'),
      BackupColumn.text('kategori'),
      BackupColumn.int_('seed'),
      BackupColumn.text('kesulitan'),
      BackupColumn.int_('gen_versi'),
      BackupColumn.text('sumber'),
      BackupColumn.int_('ref_id', nullable: true),
      BackupColumn.int_('opsi_dipilih', nullable: true),
      BackupColumn.int_('benar'),
      BackupColumn.int_('durasi_ms'),
      BackupColumn.text('label'),
    ],
    'mistake_card': [
      BackupColumn.int_('id'),
      BackupColumn.text('tipe'),
      BackupColumn.text('kategori'),
      BackupColumn.int_('seed', nullable: true),
      BackupColumn.text('sumber'),
      BackupColumn.int_('ref_id', nullable: true),
      BackupColumn.int_('jatuh_tempo'),
      BackupColumn.int_('interval_hari'),
      BackupColumn.int_('streak_benar'),
      BackupColumn.text('status'),
      BackupColumn.int_('dibuat'),
    ],
    'captured_question': [
      BackupColumn.int_('id'),
      BackupColumn.text('teks'),
      BackupColumn.text('opsi_json'),
      BackupColumn.int_('kunci'),
      BackupColumn.text('pembahasan', nullable: true),
      BackupColumn.text('kategori'),
      BackupColumn.text('foto_path', nullable: true),
      BackupColumn.int_('company_log_id', nullable: true),
      BackupColumn.int_('dibuat'),
    ],
    'company_test_log': [
      BackupColumn.int_('id'),
      BackupColumn.text('perusahaan'),
      BackupColumn.int_('tanggal'),
      BackupColumn.text('subtes_json'),
      BackupColumn.text('tipe_baru_json'),
      BackupColumn.text('catatan'),
    ],
    'app_setting': [
      BackupColumn.text('key'),
      BackupColumn.text('value'),
    ],
  };

  /// Key API tidak pernah disimpan di `app_setting`; bila ada baris seperti
  /// itu (salah tulis di versi lain), ia tidak diekspor dan tidak diimpor.
  static bool isSecretKey(String key) =>
      key.toLowerCase().startsWith('api_key');

  /// Kolom waktu yang menentukan baris mana yang lebih baru bila id sama.
  static const Map<String, String> recency = {
    'test_profile': 'dibuat',
    'session': 'mulai',
    'mistake_card': 'dibuat',
    'captured_question': 'dibuat',
    'company_test_log': 'tanggal',
  };
}

enum BackupType { integer, text, real }

class BackupColumn {
  const BackupColumn.int_(this.name, {this.nullable = false})
      : type = BackupType.integer;
  const BackupColumn.text(this.name, {this.nullable = false})
      : type = BackupType.text;
  const BackupColumn.real(this.name, {this.nullable = false})
      : type = BackupType.real;

  final String name;
  final BackupType type;
  final bool nullable;
}

/// Isi berkas backup yang sudah lolos validasi.
class BackupFile {
  BackupFile._(this.versi, this.diekspor, this.tables);

  final int versi;
  final DateTime? diekspor;

  /// Baris per tabel, hanya kolom yang dikenal. Tabel yang ditunda
  /// ([BackupFormat.deferred]) tidak ikut.
  final Map<String, List<Map<String, Object?>>> tables;

  List<Map<String, Object?>> rows(String table) => tables[table] ?? const [];

  /// Membaca dan memvalidasi [text]. Melempar [BackupException].
  factory BackupFile.parse(String text) {
    const bad = BackupException(BackupProblem.unreadable);
    if (text.length > BackupFormat.maxBytes) throw bad;
    final Object? root;
    try {
      root = jsonDecode(text);
    } on FormatException {
      throw bad;
    }
    if (root is! Map || root['format'] != BackupFormat.name) throw bad;
    final versi = root['versi'];
    if (versi is! int || versi < 1) throw bad;
    if (versi > BackupFormat.currentVersion) {
      throw BackupException(BackupProblem.newer, version: versi);
    }
    final exported = root['diekspor'];
    final tabel = root['tabel'];
    if (exported != null && exported is! int) throw bad;
    if (tabel is! Map) throw bad;

    final tables = <String, List<Map<String, Object?>>>{};
    for (final entry in BackupFormat.columns.entries) {
      final raw = tabel[entry.key];
      if (raw == null) continue;
      if (raw is! List) throw bad;
      final rows = <Map<String, Object?>>[];
      for (final r in raw) {
        if (r is! Map) throw bad;
        final row = <String, Object?>{};
        for (final c in entry.value) {
          row[c.name] = _read(r[c.name], c, bad);
        }
        _check(entry.key, row, bad);
        if (entry.key == 'app_setting' &&
            BackupFormat.isSecretKey(row['key']! as String)) {
          continue;
        }
        rows.add(row);
      }
      tables[entry.key] = rows;
    }
    final deferred = tabel['knowledge_progress'];
    if (deferred != null && deferred is! List) throw bad;
    _checkReferences(tables, bad);
    return BackupFile._(
      versi,
      exported == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(exported as int, isUtc: true),
      tables,
    );
  }

  static Object? _read(Object? v, BackupColumn c, BackupException bad) {
    if (v == null) {
      if (c.nullable) return null;
      throw bad;
    }
    switch (c.type) {
      case BackupType.integer:
        if (v is int) return v;
        if (v is double && v == v.truncateToDouble()) return v.toInt();
        throw bad;
      case BackupType.real:
        if (v is num) return v.toDouble();
        throw bad;
      case BackupType.text:
        if (v is String) return v;
        throw bad;
    }
  }

  static bool _flag(Object? v) => v == 0 || v == 1;

  static List<Object?>? _list(Object? json) {
    try {
      final v = jsonDecode(json! as String);
      return v is List ? v : null;
    } on FormatException {
      return null;
    }
  }

  static bool _strings(Object? json) {
    final l = _list(json);
    return l != null && l.every((e) => e is String);
  }

  /// Aturan isi per tabel: kode enum, kolom JSON, rentang.
  static void _check(
      String table, Map<String, Object?> r, BackupException bad) {
    try {
      switch (table) {
        case 'test_profile':
          ProfileRole.fromCode(r['role']! as String);
          TestFormat.fromCode(r['format_tes']! as String);
          final blueprint = jsonDecode(r['blueprint_json']! as String);
          if (!_flag(r['aktif']) || blueprint is! Map) throw bad;
        case 'session':
          SessionMode.fromCode(r['mode']! as String);
          SessionPlan.fromJson(
            (jsonDecode(r['rencana_json']! as String) as Map)
                .cast<String, Object?>(),
          );
          if ((r['posisi']! as int) < 0) throw bad;
        case 'answer':
          Difficulty.fromCode(r['kesulitan']! as String);
          AnswerSource.fromCode(r['sumber']! as String);
          SpeedLabel.fromCode(r['label']! as String);
          if (!_flag(r['benar']) || (r['posisi']! as int) < 0) throw bad;
          if (AnswerSource.fromCode(r['sumber']! as String) !=
                  AnswerSource.engine &&
              r['ref_id'] == null) {
            throw bad;
          }
        case 'mistake_card':
          AnswerSource.fromCode(r['sumber']! as String);
          CardStatus.fromCode(r['status']! as String);
          final streak = r['streak_benar']! as int;
          if (streak < 0 || streak > 3) throw bad;
        case 'captured_question':
          final opsi = _list(r['opsi_json']);
          final kunci = r['kunci']! as int;
          if (opsi == null ||
              opsi.length < 2 ||
              opsi.length > 6 ||
              !_strings(r['opsi_json']) ||
              kunci < 0 ||
              kunci >= opsi.length) {
            throw bad;
          }
        case 'company_test_log':
          if (!_strings(r['subtes_json']) || !_strings(r['tipe_baru_json'])) {
            throw bad;
          }
      }
    } on BackupException {
      rethrow;
    } catch (_) {
      // FormatException dari kode enum atau JSON, atau tipe yang tidak cocok.
      throw bad;
    }
  }

  /// Id yang kembar di berkas dan rujukan ke baris yang tidak ada ditolak:
  /// berkas seperti itu tidak mungkin hasil ekspor yang utuh.
  static void _checkReferences(
    Map<String, List<Map<String, Object?>>> t,
    BackupException bad,
  ) {
    for (final table in const [
      'test_profile',
      'session',
      'answer',
      'mistake_card',
      'captured_question',
      'company_test_log',
    ]) {
      final ids = <Object?>{};
      for (final r in t[table] ?? const []) {
        if (!ids.add(r['id'])) throw bad;
      }
    }
    final keys = <Object?>{};
    for (final r in t['app_setting'] ?? const []) {
      if (!keys.add(r['key'])) throw bad;
    }
    final seen = <(Object?, Object?)>{};
    for (final r in t['answer'] ?? const []) {
      if (!seen.add((r['session_id'], r['posisi']))) throw bad;
    }
  }
}
