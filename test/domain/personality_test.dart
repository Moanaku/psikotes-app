import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:simulator_psikotes_it/domain/services/personality.dart';

/// Pool kecil buatan tangan: [traits] sifat, [per] pernyataan per sifat.
String poolJson({int traits = 4, int per = 10, Object? versi = 1}) =>
    jsonEncode({
      'versi': versi,
      'sifat': [
        for (var t = 0; t < traits; t++)
          {
            'id': 's$t',
            'nama': 'Sifat $t',
            'arti': 'Arti sifat $t.',
            'relevansiRole': {'qa': t == 0 ? 'tinggi' : 'sedang'},
            'pernyataan': [
              for (var i = 0; i < per; i++)
                {'id': 'P-$t-$i', 'teks': 'Saya pernyataan $t nomor $i.'},
            ],
          },
      ],
    });

void main() {
  group('pool', () {
    test('aset terbundel sah: 8 sifat, 12 pernyataan, tanpa istilah klinis',
        () {
      final pool = PersonalityPool.parse(
          File('assets/personality_pool.json').readAsStringSync());
      expect(pool.traits, hasLength(8));
      final clinical = RegExp(
          r'\b(depresi|cemas|gangguan|diagnosis|trauma|terapi|obat|panik)',
          caseSensitive: false);
      for (final t in pool.traits) {
        expect(t.pernyataan, hasLength(12), reason: t.id);
        for (final p in t.pernyataan) {
          expect(p.teks, startsWith('Saya '));
          expect(clinical.hasMatch(p.teks), isFalse, reason: p.id);
          expect(p.teks.contains(RegExp(r'\b(benar|salah)\b')), isFalse);
        }
      }
    });

    test('skema salah ditolak', () {
      for (final bad in [
        'bukan json',
        '[]',
        poolJson(versi: 2),
        poolJson(traits: 1),
        poolJson(per: 9),
        poolJson(per: 21),
      ]) {
        expect(() => PersonalityPool.parse(bad),
            throwsA(isA<PersonalityPoolFormatException>()),
            reason: bad.length > 30 ? bad.substring(0, 30) : bad);
      }
      final dup = poolJson().replaceAll('"P-1-0"', '"P-0-0"');
      expect(() => PersonalityPool.parse(dup),
          throwsA(isA<PersonalityPoolFormatException>()));
    });
  });

  group('pasangan acak', () {
    final pool = PersonalityPool.parse(
        File('assets/personality_pool.json').readAsStringSync());

    test('deterministik: seed sama, soal sama; seed lain, soal lain', () {
      String key(List<PersonalityItem> items) =>
          items.map((i) => '${i.a.id}/${i.b.id}').join(',');
      expect(key(PersonalityPairs.build(pool, 42)),
          key(PersonalityPairs.build(pool, 42)));
      expect(key(PersonalityPairs.build(pool, 42)),
          isNot(key(PersonalityPairs.build(pool, 43))));
    });

    test('dua sifat berbeda, tanpa pernyataan berulang, sebaran rata', () {
      for (var seed = 0; seed < 500; seed++) {
        final items = PersonalityPairs.build(pool, seed);
        expect(items, hasLength(PersonalityPairs.defaultCount));
        final ids = <String>{};
        final perTrait = <String, int>{};
        for (final it in items) {
          expect(it.a.traitId, isNot(it.b.traitId));
          expect(ids.add(it.a.id) && ids.add(it.b.id), isTrue);
          for (final s in [it.a, it.b]) {
            perTrait.update(s.traitId, (v) => v + 1, ifAbsent: () => 1);
          }
        }
        // 24 soal x 2 pernyataan / 8 sifat = 6 per sifat; boleh selisih satu.
        for (final n in perTrait.values) {
          expect(n, inInclusiveRange(5, 7), reason: 'seed $seed $perTrait');
        }
      }
    });

    test('posisi A dan B tidak berpihak pada sifat tertentu', () {
      var first = 0;
      var total = 0;
      for (var seed = 0; seed < 200; seed++) {
        for (final it in PersonalityPairs.build(pool, seed)) {
          total++;
          if (it.a.traitId.compareTo(it.b.traitId) < 0) first++;
        }
      }
      expect(first / total, closeTo(0.5, 0.05));
    });

    test('pool kecil: berhenti saat pernyataan habis, tanpa ulang', () {
      final small = PersonalityPool.parse(poolJson(traits: 2, per: 10));
      final items = PersonalityPairs.build(small, 7, count: 50);
      expect(items, hasLength(10));
    });
  });

  group('profil', () {
    final pool = PersonalityPool.parse(poolJson(traits: 3));
    PersonalityStatement s(int t, int i) => pool.traits[t].pernyataan[i];

    test('menghitung dipilih dari muncul, urut dari yang paling sering', () {
      final items = [
        PersonalityItem(s(0, 0), s(1, 0)),
        PersonalityItem(s(0, 1), s(2, 0)),
        PersonalityItem(s(1, 1), s(2, 1)),
        PersonalityItem(s(2, 2), s(0, 2)),
      ];
      // Pilihan: sifat 0, sifat 0, sifat 2, sifat 0 (B di soal 4).
      final tally =
          PersonalityProfile.tally(pool, items, {0: 0, 1: 0, 2: 1, 3: 1});
      expect([
        for (final t in tally) (t.trait.id, t.chosen, t.shown)
      ], [
        ('s0', 3, 3),
        ('s2', 1, 3),
        ('s1', 0, 2),
      ]);
    });

    test('soal yang belum dijawab tidak dihitung', () {
      final items = [
        PersonalityItem(s(0, 0), s(1, 0)),
        PersonalityItem(s(0, 1), s(2, 0)),
      ];
      final tally = PersonalityProfile.tally(pool, items, {0: 1});
      expect([
        for (final t in tally) (t.trait.id, t.chosen, t.shown)
      ], [
        ('s1', 1, 1),
        ('s0', 0, 1),
      ]);
    });
  });
}
