import 'dart:convert';

import 'package:question_engine/question_engine.dart' show Rng;

/// Kepribadian Papi-style (F12, S14, docs/06-bank-konten.md "Pool kepribadian").
///
/// Dart murni: teks pool dibaca pemanggil (di app lewat `rootBundle`). Tidak
/// ada skor benar atau salah: profil hanya menghitung seberapa sering
/// pernyataan tiap sifat dipilih dibanding seberapa sering muncul.

class PersonalityStatement {
  const PersonalityStatement(this.id, this.teks, this.traitId);

  final String id;
  final String teks;
  final String traitId;
}

class PersonalityTrait {
  const PersonalityTrait({
    required this.id,
    required this.nama,
    required this.arti,
    required this.relevansiRole,
    required this.pernyataan,
  });

  final String id;
  final String nama;
  final String arti;

  /// Kode role (`qa`, `mobile`, `ba`) ke "tinggi" atau "sedang".
  final Map<String, String> relevansiRole;
  final List<PersonalityStatement> pernyataan;
}

class PersonalityPoolFormatException implements Exception {
  PersonalityPoolFormatException(this.message);

  final String message;

  @override
  String toString() => 'PersonalityPoolFormatException: $message';
}

class PersonalityPool {
  PersonalityPool._(this.versi, this.traits);

  static const int minPerTrait = 10;
  static const int maxPerTrait = 20;

  final int versi;
  final List<PersonalityTrait> traits;

  PersonalityTrait trait(String id) => traits.firstWhere((t) => t.id == id);

  /// Pool dari teks JSON. Melempar [PersonalityPoolFormatException] bila
  /// skema salah, ID kembar, atau jumlah pernyataan di luar 10 sampai 20.
  static PersonalityPool parse(String source) {
    Never bad(String m) => throw PersonalityPoolFormatException(m);
    final Object? json;
    try {
      json = jsonDecode(source);
    } on FormatException {
      bad('bukan JSON');
    }
    if (json is! Map<String, Object?>) bad('akar bukan objek');
    final versi = json['versi'];
    if (versi != 1) bad('versi $versi tidak dikenal');
    final list = json['sifat'];
    if (list is! List || list.length < 2) bad('sifat kurang dari dua');
    final ids = <String>{};
    final traits = <PersonalityTrait>[];
    for (final raw in list) {
      if (raw is! Map<String, Object?>) bad('sifat bukan objek');
      String str(String k) {
        final v = raw[k];
        return v is String && v.trim().isNotEmpty ? v : bad('sifat tanpa $k');
      }

      final id = str('id');
      final rel = raw['relevansiRole'];
      final items = raw['pernyataan'];
      if (items is! List ||
          items.length < minPerTrait ||
          items.length > maxPerTrait) {
        bad('$id: jumlah pernyataan di luar $minPerTrait..$maxPerTrait');
      }
      traits.add(PersonalityTrait(
        id: id,
        nama: str('nama'),
        arti: str('arti'),
        relevansiRole: {
          if (rel is Map)
            for (final e in rel.entries)
              if (e.key is String && e.value is String)
                e.key as String: e.value as String,
        },
        pernyataan: [
          for (final p in items)
            if (p is Map &&
                p['id'] is String &&
                p['teks'] is String &&
                ids.add(p['id'] as String))
              PersonalityStatement(p['id'] as String, p['teks'] as String, id)
            else
              bad('$id: pernyataan rusak atau ID kembar'),
        ],
      ));
    }
    if (traits.map((t) => t.id).toSet().length != traits.length) {
      bad('ID sifat kembar');
    }
    return PersonalityPool._(versi as int, List.unmodifiable(traits));
  }
}

/// Satu soal: dua pernyataan dari dua sifat berbeda, urutan A lalu B.
class PersonalityItem {
  const PersonalityItem(this.a, this.b);

  final PersonalityStatement a;
  final PersonalityStatement b;

  PersonalityStatement option(int i) => i == 0 ? a : b;
}

abstract final class PersonalityPairs {
  /// Jumlah soal bawaan satu sesi: tiap sifat (8) muncul enam kali.
  static const int defaultCount = 24;

  /// Pasangan acak yang ditentukan [seed] (sama seed, sama soal). Pasangan
  /// sifat diambil merata dari semua kombinasi; tiap pernyataan paling banyak
  /// sekali per sesi. Jumlah soal bisa kurang dari [count] bila pernyataan
  /// habis.
  static List<PersonalityItem> build(
    PersonalityPool pool,
    int seed, {
    int count = defaultCount,
  }) {
    final rng = Rng(seed);
    final left = {
      for (final t in pool.traits) t.id: rng.shuffle(t.pernyataan),
    };
    final combos = [
      for (var i = 0; i < pool.traits.length; i++)
        for (var j = i + 1; j < pool.traits.length; j++)
          (pool.traits[i].id, pool.traits[j].id),
    ];
    final items = <PersonalityItem>[];
    var round = rng.shuffle(combos);
    var stuck = 0;
    while (items.length < count && stuck < combos.length) {
      if (round.isEmpty) round = rng.shuffle(combos);
      // Pasangan dengan sifat yang paling jarang muncul didahulukan supaya
      // sebaran tiap sifat rata.
      final used = <String, int>{};
      for (final it in items) {
        used.update(it.a.traitId, (v) => v + 1, ifAbsent: () => 1);
        used.update(it.b.traitId, (v) => v + 1, ifAbsent: () => 1);
      }
      int load((String, String) c) => (used[c.$1] ?? 0) + (used[c.$2] ?? 0);
      var best = 0;
      for (var k = 1; k < round.length; k++) {
        if (load(round[k]) < load(round[best])) best = k;
      }
      final (x, y) = round.removeAt(best);
      if (left[x]!.isEmpty || left[y]!.isEmpty) {
        stuck++;
        continue;
      }
      stuck = 0;
      final sx = left[x]!.removeLast();
      final sy = left[y]!.removeLast();
      items.add(
          rng.nextBool() ? PersonalityItem(sx, sy) : PersonalityItem(sy, sx));
    }
    return items;
  }
}

/// Seberapa sering pernyataan satu sifat dipilih.
class TraitTally {
  const TraitTally(this.trait, this.chosen, this.shown);

  final PersonalityTrait trait;
  final int chosen;
  final int shown;

  double get share => shown == 0 ? 0 : chosen / shown;
}

abstract final class PersonalityProfile {
  /// Rekap per sifat dari [choices] (indeks soal ke 0 untuk A atau 1 untuk B),
  /// diurutkan dari yang paling sering dipilih. Sifat yang tidak pernah
  /// muncul tidak dicantumkan.
  static List<TraitTally> tally(
    PersonalityPool pool,
    List<PersonalityItem> items,
    Map<int, int> choices,
  ) {
    final shown = <String, int>{};
    final chosen = <String, int>{};
    for (var i = 0; i < items.length; i++) {
      final pick = choices[i];
      if (pick == null) continue;
      for (final s in [items[i].a, items[i].b]) {
        shown.update(s.traitId, (v) => v + 1, ifAbsent: () => 1);
      }
      final c = items[i].option(pick).traitId;
      chosen.update(c, (v) => v + 1, ifAbsent: () => 1);
    }
    final out = [
      for (final t in pool.traits)
        if (shown[t.id] != null) TraitTally(t, chosen[t.id] ?? 0, shown[t.id]!),
    ];
    out.sort((a, b) {
      final byShare = b.share.compareTo(a.share);
      return byShare != 0 ? byShare : b.chosen.compareTo(a.chosen);
    });
    return out;
  }
}
