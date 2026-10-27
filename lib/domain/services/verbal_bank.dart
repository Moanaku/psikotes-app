/// Bank soal verbal (VRB-SYN, VRB-ANA) dari `assets/verbal_bank.json`
/// (docs/06-bank-konten.md, "Bank verbal"). Soal bank tidak dibuat generator:
/// rencana menyimpan nomor butir (`ref_id`) dan seed pemilihnya, lalu soalnya
/// dibaca dari bank ini.
///
/// Dart murni: berkas dibaca oleh pemanggil (di app lewat `rootBundle`) dan
/// dioper sebagai teks, sehingga kegagalan baca dan skema yang salah bisa
/// diuji tanpa Flutter.
library;

import 'dart:convert';

import 'package:question_engine/question_engine.dart';

/// Satu butir bank.
class BankQuestion {
  const BankQuestion({
    required this.type,
    required this.number,
    required this.difficulty,
    required this.stem,
    required this.options,
    required this.correctIndex,
    required this.explanation,
  });

  final QuestionType type;

  /// Nomor butir: `VRB-SYN-0042` bertipe `VRB-SYN` dengan nomor 42. Nilai ini
  /// yang ditulis ke `answer.ref_id`.
  final int number;
  final Difficulty difficulty;
  final String stem;
  final List<String> options;
  final int correctIndex;
  final String explanation;

  String get id => VerbalBank.idOf(type, number);
}

/// Hasil memuat bank untuk app: dimuat, gagal, atau belum dipasang.
class VerbalBankState {
  const VerbalBankState._(this.bank, this.error);

  /// Bank belum dipasang (test, atau sebelum pemuatan); tipe verbal tidak
  /// tersedia dan tidak dianggap galat.
  const VerbalBankState.absent() : this._(null, null);

  VerbalBankState.loaded(VerbalBank bank) : this._(bank, null);

  /// Bank gagal dibaca atau skemanya salah. [reason] untuk log pengembang,
  /// bukan untuk layar.
  const VerbalBankState.failed(String reason) : this._(null, reason);

  final VerbalBank? bank;
  final String? error;

  bool get isFailed => error != null;
}

/// Kegagalan memuat bank; pesan untuk pengembang.
class VerbalBankFormatException implements Exception {
  VerbalBankFormatException(this.message);

  final String message;

  @override
  String toString() => 'VerbalBankFormatException: $message';
}

class VerbalBank {
  VerbalBank._(this.versi, List<BankQuestion> items)
      : items = List.unmodifiable(items) {
    for (final q in this.items) {
      _byType.putIfAbsent(q.type, () => []).add(q);
      _byNumber['${q.type.code}#${q.number}'] = q;
    }
    for (final list in _byType.values) {
      list.sort((a, b) => a.number.compareTo(b.number));
    }
  }

  /// Tipe yang isinya dari bank, bukan generator.
  static const Set<QuestionType> bankTypes = {
    QuestionType.vrbSyn,
    QuestionType.vrbAna,
  };

  /// Perkiraan waktu per soal (detik) menurut tipe bila belum ada riwayat.
  static int estimatedSeconds(QuestionType type, Difficulty d) {
    final base = type == QuestionType.vrbAna ? 25 : 15;
    return switch (d) {
      Difficulty.easy => base,
      Difficulty.medium => base + 5,
      Difficulty.hard => base + 10,
    };
  }

  /// Nomor versi bank; ditulis ke `gen_versi` jawaban.
  final int versi;
  final List<BankQuestion> items;
  final Map<QuestionType, List<BankQuestion>> _byType = {};
  final Map<String, BankQuestion> _byNumber = {};

  static String idOf(QuestionType type, int number) =>
      '${type.code}-${number.toString().padLeft(4, '0')}';

  /// Kunci pasangan (tipe, butir) untuk himpunan `avoid`, terpisah dari kunci
  /// (tipe, seed) soal engine.
  static String keyOf(String typeCode, int number) => '$typeCode#$number';

  /// Tipe yang punya sedikitnya satu butir.
  Set<QuestionType> get types => _byType.keys.toSet();

  bool has(QuestionType type) => _byType.containsKey(type);

  List<BankQuestion> pool(QuestionType type, Difficulty d) => [
        for (final q in _byType[type] ?? const <BankQuestion>[])
          if (q.difficulty == d) q,
      ];

  BankQuestion? byRef(QuestionType type, int number) =>
      _byNumber['${type.code}#$number'];

  /// Memilih butir untuk ([type], [difficulty], [seed]) tanpa keacakan di luar
  /// seed: urutan butir berdasarkan nomor, mulai dari `seed mod jumlah`, butir
  /// pertama yang kuncinya tidak ada di [avoid]. Bila kesulitan itu habis,
  /// dicoba kesulitan lain yang terdekat; bila semuanya sudah muncul dalam
  /// jangka avoid, butir pertama tetap dipakai (soal terpaksa berulang). Null
  /// bila tipe tidak punya butir.
  BankQuestion? pick(
    QuestionType type,
    Difficulty difficulty,
    int seed, {
    Set<String> avoid = const {},
  }) {
    final order = [
      difficulty,
      ...Difficulty.values.where((d) => d != difficulty).toList()
        ..sort((a, b) => (a.index - difficulty.index)
            .abs()
            .compareTo((b.index - difficulty.index).abs())),
    ];
    BankQuestion? fallback;
    for (final d in order) {
      final list = pool(type, d);
      if (list.isEmpty) continue;
      final start = seed % list.length;
      fallback ??= list[start];
      for (var i = 0; i < list.length; i++) {
        final q = list[(start + i) % list.length];
        if (!avoid.contains(keyOf(type.code, q.number))) return q;
      }
    }
    return fallback;
  }

  /// Mengubah butir menjadi `Question` yang dipahami layar sesi. [seed] adalah
  /// seed pemilih yang disimpan di rencana.
  Question toQuestion(BankQuestion q, {int seed = 0}) => Question(
        type: q.type,
        seed: seed,
        difficulty: q.difficulty,
        stem: QuestionContent(text: q.stem),
        options: [
          for (var i = 0; i < q.options.length; i++)
            Option(
              id: Option.idFor(i),
              content: QuestionContent(text: q.options[i]),
            ),
        ],
        correctIndex: q.correctIndex,
        explanation: q.explanation,
        estimatedSeconds: estimatedSeconds(q.type, q.difficulty),
        tags: ['bank:${q.id}'],
      );

  /// Membaca dan memvalidasi isi berkas. Melempar [VerbalBankFormatException]
  /// pada JSON rusak atau skema salah. Butir `needsReview: true` dibuang
  /// (aturan bundel).
  factory VerbalBank.parse(String source) {
    final Object? root;
    try {
      root = jsonDecode(source);
    } on FormatException catch (e) {
      throw VerbalBankFormatException('bukan JSON: ${e.message}');
    }
    if (root is! Map<String, Object?>) {
      throw VerbalBankFormatException('akar harus objek');
    }
    final versi = root['versi'];
    if (versi is! int || versi < 1) {
      throw VerbalBankFormatException('versi harus bilangan bulat >= 1');
    }
    final soal = root['soal'];
    if (soal is! List) {
      throw VerbalBankFormatException('soal harus daftar');
    }
    final items = <BankQuestion>[];
    final seen = <String>{};
    for (var i = 0; i < soal.length; i++) {
      final q = _parseItem(soal[i], i);
      if (q == null) continue;
      if (!seen.add(q.id)) {
        throw VerbalBankFormatException('soal[$i]: id kembar ${q.id}');
      }
      items.add(q);
    }
    return VerbalBank._(versi, items);
  }

  static BankQuestion? _parseItem(Object? raw, int index) {
    String fail(String why) => 'soal[$index]: $why';
    if (raw is! Map<String, Object?>) {
      throw VerbalBankFormatException(fail('bukan objek'));
    }
    String str(String key) {
      final v = raw[key];
      if (v is! String || v.trim().isEmpty) {
        throw VerbalBankFormatException(fail('$key harus teks tidak kosong'));
      }
      return v;
    }

    final id = str('id');
    final typeCode = str('type');
    final QuestionType type;
    try {
      type = QuestionType.fromCode(typeCode);
    } catch (_) {
      throw VerbalBankFormatException(fail('tipe $typeCode tidak dikenal'));
    }
    if (!bankTypes.contains(type)) {
      throw VerbalBankFormatException(fail('tipe $typeCode bukan tipe bank'));
    }
    final match = RegExp(r'^([A-Z]+-[A-Z]+)-(\d{4,})$').firstMatch(id);
    if (match == null || match.group(1) != type.code) {
      throw VerbalBankFormatException(fail('id $id tidak cocok dengan tipe'));
    }
    final difficulty =
        Difficulty.values.where((d) => d.code == str('difficulty')).firstOrNull;
    if (difficulty == null) {
      throw VerbalBankFormatException(fail('difficulty tidak dikenal'));
    }
    final options = raw['options'];
    if (options is! List ||
        options.length < Question.minOptions ||
        options.length > Question.maxOptions ||
        options.any((o) => o is! String || o.trim().isEmpty)) {
      throw VerbalBankFormatException(
          fail('options harus 2 sampai 8 teks tidak kosong'));
    }
    final texts = [for (final o in options) (o as String)];
    final normalized = {
      for (final t in texts)
        t.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase(),
    };
    if (normalized.length != texts.length) {
      throw VerbalBankFormatException(fail('opsi kembar'));
    }
    final correct = raw['correctIndex'];
    if (correct is! int || correct < 0 || correct >= texts.length) {
      throw VerbalBankFormatException(fail('correctIndex di luar opsi'));
    }
    final stem = str('stem');
    final explanation = str('explanation');
    if (raw['needsReview'] == true) return null;
    return BankQuestion(
      type: type,
      number: int.parse(match.group(2)!),
      difficulty: difficulty,
      stem: stem,
      options: texts,
      correctIndex: correct,
      explanation: explanation,
    );
  }
}

/// Memuat bank lewat [read] (di app: `rootBundle.loadString`). Tidak pernah
/// melempar: kegagalan baca, JSON rusak, dan skema salah menjadi
/// [VerbalBankState.failed].
Future<VerbalBankState> loadVerbalBank(
  Future<String> Function(String path) read, {
  String path = 'assets/verbal_bank.json',
}) async {
  try {
    final bank = VerbalBank.parse(await read(path));
    if (bank.items.isEmpty) {
      return const VerbalBankState.failed('bank tidak berisi soal');
    }
    return VerbalBankState.loaded(bank);
  } on VerbalBankFormatException catch (e) {
    return VerbalBankState.failed(e.message);
  } catch (e) {
    return VerbalBankState.failed('gagal membaca $path: $e');
  }
}
