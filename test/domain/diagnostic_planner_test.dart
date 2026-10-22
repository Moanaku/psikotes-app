import 'package:flutter_test/flutter_test.dart';
import 'package:question_engine/question_engine.dart';
import 'package:simulator_psikotes_it/domain/models/codes.dart';
import 'package:simulator_psikotes_it/domain/models/profile.dart';
import 'package:simulator_psikotes_it/domain/models/session_state.dart';
import 'package:simulator_psikotes_it/domain/services/diagnostic_planner.dart';
import 'package:simulator_psikotes_it/domain/services/profile_templates.dart';
import 'package:simulator_psikotes_it/domain/services/seed_allocator.dart';

import '../support/fake_repositories.dart';
import '../support/fixtures.dart';
import '../support/pump_app.dart' show appNow;
import 'daily_planner_test.dart' show ans, registered;

DiagnosticPlan? build(
  ProfileBlueprint blueprint, {
  Set<String> avoid = const {},
  Set<QuestionType>? available,
}) =>
    DiagnosticPlanner.build(
      blueprint,
      now: appNow,
      available: available ?? registered,
      avoid: avoid,
    );

void main() {
  final qaCcat = ProfileTemplates.blueprint(ProfileRole.qa, TestFormat.ccat);

  test('semua kategori aktif yang punya soal, paling banyak 20 menit', () {
    final d = build(qaCcat)!;
    expect(d.categories, ['numerik', 'logika', 'figural']);
    expect(d.skipped, ['verbal'], reason: 'belum punya soal (A59)');
    expect(d.totalMinutes, lessThanOrEqualTo(DiagnosticPlanner.maxMinutes));
    expect(d.plan.subtes.map((s) => s.menit), [6, 6, 6]);
  });

  test('rencana sah untuk SessionController dan tiap tipe muncul', () {
    final d = build(qaCcat)!;
    final ranges = SubtestRange.of(d.plan);
    expect(ranges.length, 3);
    for (final r in ranges) {
      expect(r.duration, isNotNull);
      expect(r.jumlah,
          inInclusiveRange(3, DiagnosticPlanner.maxQuestionsPerSubtest));
      final types = {
        for (var i = r.start; i < r.end; i++) d.plan.items[i].type,
      };
      final expected =
          registered.where((t) => t.category.code == r.kategori).toSet();
      expect(types, expected, reason: r.kategori);
    }
  });

  test('seed tidak kembar dan menghindari soal 30 hari terakhir', () {
    final first = build(qaCcat)!;
    final avoid = {
      for (final i in first.plan.items) SeedAllocator.key(i.type, i.seed),
    };
    final second = build(qaCcat, avoid: avoid)!;
    final keys = [
      for (final i in second.plan.items) SeedAllocator.key(i.type, i.seed),
    ];
    expect(keys.toSet().length, keys.length);
    expect(keys.toSet().intersection(avoid), isEmpty);
  });

  test('satu kategori mendapat seluruh 20 menit, soal dibatasi', () {
    final blueprint = ProfileBlueprint(
      subtes: [
        for (final s in qaCcat.subtes)
          SubtestSpec(
            kategori: s.kategori,
            aktif: s.kategori == 'logika',
            jumlah: s.jumlah,
            menit: s.menit,
          ),
      ],
      bobot: qaCcat.bobot,
    );
    final d = build(blueprint)!;
    expect(d.categories, ['logika']);
    expect(d.plan.subtes.single.menit, 20);
    expect(
        d.plan.subtes.single.jumlah, DiagnosticPlanner.maxQuestionsPerSubtest);
  });

  test('tanpa kategori yang punya soal: null', () {
    expect(build(qaCcat, available: {}), isNull);
    expect(build(qaCcat, available: {QuestionType.vrbSyn}), isNull);
  });

  test('planner membaca riwayat 30 hari dari repository', () async {
    final first = build(qaCcat)!;
    final repo = FakeSessionRepository()
      ..history = [
        for (final i in first.plan.items) ans(i.type, seed: i.seed),
      ];
    final planner = DiagnosticPlanner(answers: repo, available: registered);
    final d = (await planner.plan(activeProfile(), appNow))!;
    final avoid = {
      for (final i in first.plan.items) SeedAllocator.key(i.type, i.seed),
    };
    for (final i in d.plan.items) {
      expect(avoid, isNot(contains(SeedAllocator.key(i.type, i.seed))));
    }
  });
}
