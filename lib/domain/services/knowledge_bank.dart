import 'dart:convert';

import '../models/knowledge.dart';

/// Kegagalan memuat bank pengetahuan; pesan untuk pengembang, bukan layar.
class KnowledgeBankFormatException implements Exception {
  KnowledgeBankFormatException(this.message);

  final String message;

  @override
  String toString() => 'KnowledgeBankFormatException: $message';
}

/// Hasil memuat bank: dimuat atau gagal. Pola yang sama dengan
/// `VerbalBankState` (A100): kegagalan menjadi kondisi galat, bukan crash.
class KnowledgeBankState {
  const KnowledgeBankState._(this.bank, this.error);

  const KnowledgeBankState.loaded(KnowledgeBank bank) : this._(bank, null);

  /// [reason] untuk log pengembang, bukan untuk layar.
  const KnowledgeBankState.failed(String reason) : this._(null, reason);

  final KnowledgeBank? bank;
  final String? error;

  bool get isFailed => error != null;
}

/// Isi `assets/knowledge_bank.json` (docs/06-bank-konten.md).
class KnowledgeBank {
  KnowledgeBank._(this.versi, List<KnowledgeItem> items)
      : items = List.unmodifiable(items) {
    for (final i in this.items) {
      _byId[i.id] = i;
    }
  }

  /// Bank tanpa butir, untuk test dan bank yang belum diisi.
  KnowledgeBank.empty()
      : versi = 1,
        items = const [];

  /// Bank dari daftar butir; untuk test.
  KnowledgeBank.of(List<KnowledgeItem> items, {this.versi = 1})
      : items = List.unmodifiable(items) {
    for (final i in this.items) {
      _byId[i.id] = i;
    }
  }

  final int versi;
  final List<KnowledgeItem> items;
  final Map<String, KnowledgeItem> _byId = {};

  KnowledgeItem? byId(String id) => _byId[id];

  /// Butir lewat tipe kartu (`KB-QA-D`) dan nomornya, seperti kartu buku
  /// kesalahan menyimpannya.
  KnowledgeItem? byCard(String tipe, int number) =>
      _byId['$tipe-${number.toString().padLeft(3, '0')}'] ??
      _byId['$tipe-$number'];

  bool get isEmpty => items.isEmpty;

  /// Butir untuk [role] (Umum = semua role) pada [level].
  List<KnowledgeItem> of(KnowledgeRole role, KnowledgeLevel level) => [
        for (final i in items)
          if (i.level == level &&
              (role == KnowledgeRole.umum || i.role == role))
            i,
      ];

  /// Topik yang punya butir untuk [role] dan [level], urut abjad.
  List<String> topics(KnowledgeRole role, KnowledgeLevel level) =>
      ({for (final i in of(role, level)) i.topik}.toList()..sort());

  /// Membaca dan memvalidasi isi berkas. Melempar
  /// [KnowledgeBankFormatException] pada JSON rusak atau skema salah.
  factory KnowledgeBank.parse(String source) {
    final Object? root;
    try {
      root = jsonDecode(source);
    } on FormatException catch (e) {
      throw KnowledgeBankFormatException('bukan JSON: ${e.message}');
    }
    if (root is! Map<String, Object?>) {
      throw KnowledgeBankFormatException('akar harus objek');
    }
    final versi = root['versi'];
    if (versi is! int || versi < 1) {
      throw KnowledgeBankFormatException('versi harus bilangan bulat >= 1');
    }
    final butir = root['butir'];
    if (butir is! List) {
      throw KnowledgeBankFormatException('butir harus daftar');
    }
    final items = <KnowledgeItem>[];
    final seen = <String>{};
    for (var i = 0; i < butir.length; i++) {
      final item = _parseItem(butir[i], i);
      if (!seen.add(item.id)) {
        throw KnowledgeBankFormatException('butir[$i]: id kembar ${item.id}');
      }
      items.add(item);
    }
    return KnowledgeBank._(versi, items);
  }

  static KnowledgeItem _parseItem(Object? raw, int index) {
    Never bad(String why) =>
        throw KnowledgeBankFormatException('butir[$index]: $why');
    if (raw is! Map<String, Object?>) bad('bukan objek');
    String str(String key) {
      final v = raw[key];
      if (v is! String || v.trim().isEmpty) {
        bad('$key harus teks tidak kosong');
      }
      return v;
    }

    final id = str('id');
    final match = RegExp(r'^KB-([A-Z]+)-([DML])-(\d{3,})$').firstMatch(id);
    if (match == null) bad('id $id tidak berformat KB-ROLE-LEVEL-NNN');
    final role = KnowledgeRole.fromCode(str('role'));
    if (role == null) bad('role tidak dikenal');
    final level = KnowledgeLevel.fromCode(str('level'));
    if (level == null) bad('level tidak dikenal');
    if (match.group(1) != role.idCode || match.group(2) != level.idCode) {
      bad('id $id tidak cocok dengan role dan level');
    }
    final topik = str('topik');
    if (!RegExp(r'^[a-z0-9]+(-[a-z0-9]+)*$').hasMatch(topik)) {
      bad('topik harus slug huruf kecil dengan tanda hubung');
    }
    final poin = raw['poinKunci'];
    if (poin is! List ||
        poin.length < 2 ||
        poin.length > 8 ||
        poin.any((p) => p is! String || p.trim().isEmpty)) {
      bad('poinKunci harus 2 sampai 8 teks tidak kosong');
    }
    final sumberRaw = raw['sumber'];
    if (sumberRaw != null &&
        (sumberRaw is! String || sumberRaw.trim().isEmpty)) {
      bad('sumber harus teks atau null');
    }
    final needs = raw['needsVerification'];
    if (needs is! bool) bad('needsVerification harus true atau false');
    // Butir tanpa sumber wajib bertanda perlu verifikasi (F17).
    if (sumberRaw == null && !needs) {
      bad('butir tanpa sumber harus needsVerification: true');
    }
    return KnowledgeItem(
      id: id,
      role: role,
      level: level,
      topik: topik,
      pertanyaan: str('pertanyaan'),
      jawabanModel: str('jawabanModel'),
      poinKunci: [for (final p in poin) p as String],
      sumber: sumberRaw as String?,
      needsVerification: needs,
    );
  }
}

/// Memuat bank dari teks berkas. Tidak pernah melempar: kegagalan baca, JSON
/// rusak, dan skema salah menjadi [KnowledgeBankState.failed].
Future<KnowledgeBankState> loadKnowledgeBank(
  Future<String> Function(String path) read, {
  String path = 'assets/knowledge_bank.json',
}) async {
  try {
    return KnowledgeBankState.loaded(KnowledgeBank.parse(await read(path)));
  } on KnowledgeBankFormatException catch (e) {
    return KnowledgeBankState.failed(e.message);
  } catch (e) {
    return KnowledgeBankState.failed('gagal membaca $path: $e');
  }
}
