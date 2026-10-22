import 'package:flutter_test/flutter_test.dart';
import 'package:question_engine/question_engine.dart';
import 'package:simulator_psikotes_it/domain/models/codes.dart';
import 'package:simulator_psikotes_it/domain/models/profile.dart';
import 'package:simulator_psikotes_it/domain/models/session_state.dart';
import 'package:simulator_psikotes_it/domain/services/planning_placeholders.dart';
import 'package:simulator_psikotes_it/domain/services/profile_templates.dart';
import 'package:simulator_psikotes_it/domain/services/session_plan_builder.dart';

final now = DateTime.utc(2026, 10, 22, 8);
final registered = GeneratorRegistry.types.toSet();

TestProfile profile(ProfileRole role, TestFormat format) => TestProfile(
      id: 1,
      nama: 'p',
      role: role,
      formatTes: format,
      aktif: true,
      blueprint: ProfileTemplates.blueprint(role, format),
      dibuat: now,
    );

void main() {
  group('latihan satu tipe', () {
    test('sepuluh soal medium dari tipe itu dengan versi generator', () {
      final plan = SessionPlanBuilder.practice(QuestionType.figMtx, now: now);
      expect(plan.items.length, 10);
      expect(plan.subtes, isEmpty, reason: 'tanpa subtes: tanpa timer');
      for (final i in plan.items) {
        expect(i.type, QuestionType.figMtx);
        expect(i.difficulty, Difficulty.medium);
        expect(i.subtes, 'figural');
        expect(i.genVersi,
            GeneratorRegistry.generator(QuestionType.figMtx).version);
      }
      expect(plan.items.map((i) => i.seed).toSet().length, 10,
          reason: 'seed tidak kembar');
    });

    test('deterministik untuk waktu yang sama, berbeda antar detik', () {
      final a = SessionPlanBuilder.practice(QuestionType.numSeq, now: now);
      final b = SessionPlanBuilder.practice(QuestionType.numSeq, now: now);
      final c = SessionPlanBuilder.practice(QuestionType.numSeq,
          now: now.add(const Duration(seconds: 1)));
      expect(
          [for (final i in a.items) i.seed], [for (final i in b.items) i.seed]);
      expect([for (final i in a.items) i.seed],
          isNot([for (final i in c.items) i.seed]));
    });

    test('seed selalu di rentang yang dipahami Rng, juga di tanggal ekstrem',
        () {
      for (final t in [
        DateTime.utc(1970, 1, 1),
        DateTime.utc(2038, 1, 19, 3, 14, 8),
        DateTime.utc(2100, 12, 31),
      ]) {
        for (final type in registered) {
          for (final i in SessionPlanBuilder.practice(type, now: t).items) {
            expect(i.seed, inInclusiveRange(0, 0x7FFFFFFE));
          }
        }
      }
    });

    test('semua soal bisa dibuat ulang dari rencana', () {
      for (final type in registered) {
        final plan = SessionPlanBuilder.practice(type, now: now, count: 2);
        for (final i in plan.items) {
          final q = GeneratorRegistry.generate(i.type, i.seed, i.difficulty);
          expect(q.type, type);
        }
      }
    });
  });

  group('campuran menurut bobot', () {
    test('jumlah tepat, hanya tipe terdaftar, dan menurut bobot', () {
      final p = profile(ProfileRole.umum, TestFormat.kustom);
      final plan = SessionPlanBuilder.mixed(
        p.blueprint,
        now: now,
        count: 20,
        available: registered,
      );
      expect(plan.items.length, 20);
      for (final i in plan.items) {
        expect(registered.contains(i.type), isTrue);
      }
      final counts = <String, int>{};
      for (final i in plan.items) {
        counts[i.subtes] = (counts[i.subtes] ?? 0) + 1;
      }
      // Kustom: verbal, numerik, logika, figural berbobot rata, tetapi verbal
      // tidak punya tipe terdaftar, jadi sisanya membagi 20 soal rata.
      expect(counts.keys.toSet(), {'numerik', 'logika', 'figural'});
      final sum = counts.values.fold<int>(0, (a, b) => a + b);
      expect(sum, 20);
      for (final n in counts.values) {
        expect(n, inInclusiveRange(6, 7));
      }
    });

    test('bobot besar mendapat jatah lebih banyak (QA menaikkan logika)', () {
      final p = profile(ProfileRole.qa, TestFormat.ccat);
      final plan = SessionPlanBuilder.mixed(
        p.blueprint,
        now: now,
        count: 30,
        available: registered,
      );
      final counts = <String, int>{};
      for (final i in plan.items) {
        counts[i.subtes] = (counts[i.subtes] ?? 0) + 1;
      }
      // Bobot CCAT QA: numerik 27, logika 27, figural 18 (verbal tak tersedia).
      expect(counts['logika']!, greaterThan(counts['figural']!));
      expect(counts['numerik']!, counts['logika']);
    });

    test('kategori berselang-seling dan berputar antar tipe', () {
      final p = profile(ProfileRole.umum, TestFormat.ccat);
      final plan = SessionPlanBuilder.mixed(
        p.blueprint,
        now: now,
        count: 12,
        available: registered,
      );
      final cats = [for (final i in plan.items) i.subtes];
      // Tidak ada tiga soal sekategori berturut-turut.
      for (var i = 2; i < cats.length; i++) {
        expect(cats[i] == cats[i - 1] && cats[i] == cats[i - 2], isFalse,
            reason: '$cats');
      }
      final figural = {
        for (final i in plan.items)
          if (i.subtes == 'figural') i.type,
      };
      expect(figural.length, greaterThan(1));
    });

    test('tanpa tipe terdaftar untuk kategori berbobot: rencana kosong', () {
      const onlyVerbal = ProfileBlueprint(
        subtes: [
          SubtestSpec(kategori: 'verbal', aktif: true, jumlah: 20, menit: 8),
        ],
        bobot: {'verbal': 1.0},
      );
      expect(
        SessionPlanBuilder.mixed(onlyVerbal,
                now: now, count: 10, available: registered)
            .items,
        isEmpty,
      );
    });

    test('jumlah nol atau negatif: kosong', () {
      final p = profile(ProfileRole.umum, TestFormat.ccat);
      for (final n in [0, -3]) {
        expect(
          SessionPlanBuilder.mixed(p.blueprint,
                  now: now, count: n, available: registered)
              .items,
          isEmpty,
        );
      }
    });

    test('tipe yang tidak ada di available diabaikan', () {
      final p = profile(ProfileRole.umum, TestFormat.ccat);
      final plan = SessionPlanBuilder.mixed(
        p.blueprint,
        now: now,
        count: 10,
        available: {QuestionType.numSeq},
      );
      expect(plan.items.map((i) => i.type).toSet(), {QuestionType.numSeq});
    });
  });

  group('simulasi penuh', () {
    test(
        'subtes aktif yang punya tipe menjadi subtes bertimer; verbal '
        'dilewati', () {
      final p = profile(ProfileRole.qa, TestFormat.ccat);
      final sim = SessionPlanBuilder.simulation(
        p.blueprint,
        now: now,
        available: registered,
      )!;
      expect(sim.skipped, ['verbal']);
      expect([for (final s in sim.plan.subtes) s.kategori],
          ['numerik', 'logika', 'figural']);
      expect([for (final s in sim.plan.subtes) (s.jumlah, s.menit)],
          [(15, 4), (10, 4), (10, 3)]);
      expect(sim.plan.items.length, 35);
      // Subtes valid untuk SessionController: tiap soal ada di subtesnya.
      final ranges = SubtestRange.of(sim.plan);
      expect(ranges.length, 3);
      for (final r in ranges) {
        expect(r.duration, isNotNull);
        for (var i = r.start; i < r.end; i++) {
          expect(sim.plan.items[i].subtes, r.kategori);
        }
      }
    });

    test('tipe berputar di dalam subtes dan seed tidak kembar', () {
      final p = profile(ProfileRole.umum, TestFormat.ccat);
      final sim = SessionPlanBuilder.simulation(
        p.blueprint,
        now: now,
        available: registered,
      )!;
      final figural = {
        for (final i in sim.plan.items)
          if (i.subtes == 'figural') i.type,
      };
      expect(figural, {
        QuestionType.figMtx,
        QuestionType.figMir,
        QuestionType.figSeq,
        QuestionType.figOdd,
      });
      expect(sim.plan.items.map((i) => (i.type, i.seed)).toSet().length,
          sim.plan.items.length);
    });

    test('tanpa subtes yang bisa disusun: null', () {
      final p = profile(ProfileRole.umum, TestFormat.ccat);
      expect(
        SessionPlanBuilder.simulation(p.blueprint,
            now: now, available: <QuestionType>{}),
        isNull,
      );
    });

    test('subtes nonaktif tidak ikut', () {
      final p = profile(ProfileRole.umum, TestFormat.ccat);
      final sim = SessionPlanBuilder.simulation(
        p.blueprint,
        now: now,
        available: registered,
      )!;
      expect(
          sim.plan.subtes.map((s) => s.kategori), isNot(contains('kraepelin')));
    });
  });

  group('PlaceholderDailyPlanner', () {
    test('15 menit, 15 soal campuran sesuai bobot profil', () async {
      final planner = PlaceholderDailyPlanner(registered);
      final plan = await planner.plan(
        profile(ProfileRole.umum, TestFormat.ccat),
        now,
      );
      expect(plan.estimatedMinutes, 15);
      expect(plan.session.items.length, 15);
      expect(plan.blocks.length, 1);
      expect(plan.blocks.single.count, 15);
    });

    test('tanpa soal yang tersedia: rencana kosong tanpa bagian', () async {
      const planner = PlaceholderDailyPlanner({});
      final plan = await planner.plan(
        profile(ProfileRole.umum, TestFormat.ccat),
        now,
      );
      expect(plan.session.items, isEmpty);
      expect(plan.blocks, isEmpty);
    });

    test('PlaceholderWeaknessModel: belum ada riwayat', () async {
      final w = await const PlaceholderWeaknessModel().weakest(
        profile(ProfileRole.umum, TestFormat.ccat),
        now,
      );
      expect(w, isEmpty);
    });
  });
}
