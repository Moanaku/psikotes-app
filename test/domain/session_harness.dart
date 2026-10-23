import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:question_engine/question_engine.dart';
import 'package:simulator_psikotes_it/data/db/app_database.dart';
import 'package:simulator_psikotes_it/data/providers.dart';
import 'package:simulator_psikotes_it/data/repositories/profile_repository.dart';
import 'package:simulator_psikotes_it/data/repositories/session_repository.dart';
import 'package:simulator_psikotes_it/domain/models/codes.dart';
import 'package:simulator_psikotes_it/domain/models/session.dart';
import 'package:simulator_psikotes_it/domain/models/session_state.dart';
import 'package:simulator_psikotes_it/domain/providers.dart';
import 'package:simulator_psikotes_it/domain/services/session_controller.dart';

import '../data/db_helper.dart' as h;
import '../support/fake_clock.dart';
import '../support/manual_ticker.dart';

export '../support/fake_clock.dart';
export '../support/manual_ticker.dart' show ManualTimer;

/// Satu "perangkat": database dan jam yang bertahan saat proses app mati dan
/// dibuka lagi ([kill]).
class Harness {
  Harness({QuestionBuilder? builder, List<Override> Function(AppDatabase db)? overrides})
      : db = h.memoryDb(),
        clock = FakeClock(h.t0),
        _builder = builder,
        _extra = overrides {
    container = _make();
  }

  final AppDatabase db;
  final FakeClock clock;
  final QuestionBuilder? _builder;
  final List<Override> Function(AppDatabase db)? _extra;
  final List<ManualTimer> timers = [];
  late ProviderContainer container;
  int? profileId;

  ProviderContainer _make() => ProviderContainer(overrides: [
        ...dataProviderOverrides,
        appDatabaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(clock),
        tickerFactoryProvider.overrideWithValue((interval, onTick) {
          final t = ManualTimer(onTick);
          timers.add(t);
          return t;
        }),
        if (_builder != null)
          questionBuilderProvider.overrideWithValue(_builder),
        ...?_extra?.call(db),
      ]);

  SessionController get c => container.read(sessionControllerProvider.notifier);
  SessionState get s => container.read(sessionControllerProvider)!;
  SessionState? get maybe => container.read(sessionControllerProvider);
  DriftSessionRepository get repo => DriftSessionRepository(db);

  ManualTimer? get activeTimer {
    for (final t in timers.reversed) {
      if (t.isActive) return t;
    }
    return null;
  }

  Future<int> profile() async =>
      profileId ??= await DriftProfileRepository(db).save(h.profile());

  Future<void> start(SessionMode mode, SessionPlan plan) async =>
      c.start(profileId: await profile(), mode: mode, plan: plan);

  /// Proses app mati (ditutup paksa) lalu dibuka lagi: semua keadaan di
  /// memori hilang, database dan jam tetap.
  void kill() {
    container.dispose();
    timers.clear();
    container = _make();
  }

  Future<SessionRecord> session() async => (await repo.byId(s.sessionId))!;

  Future<Map<int, AnswerRecord>> answers(int sessionId) async => {
        for (final a in await DriftAnswerRepository(db).forSession(sessionId))
          a.posisi: a,
      };

  /// Indeks opsi yang salah untuk soal sekarang.
  int wrongOption() => s.question!.correctIndex == 0 ? 1 : 0;
  int rightOption() => s.question!.correctIndex;

  Future<void> dispose() async {
    container.dispose();
    await db.close();
  }
}

PlanItem item(QuestionType type, int seed, String subtes, {int? cardId}) =>
    PlanItem(
      type: type,
      seed: seed,
      difficulty: Difficulty.easy,
      genVersi: GeneratorRegistry.generator(type).version,
      subtes: subtes,
      cardId: cardId,
    );

/// Simulasi tiga subtes: numerik 3 soal 5 menit, logika 2 soal 4 menit,
/// figural 2 soal 3 menit. Posisi 0-2, 3-4, 5-6.
SessionPlan simPlan({int? menitNumerik = 5, int? menitLogika = 4}) =>
    SessionPlan(
      items: [
        for (var i = 0; i < 3; i++)
          item(QuestionType.numSeq, 10 + i, 'numerik'),
        for (var i = 0; i < 2; i++) item(QuestionType.logSyl, 20 + i, 'logika'),
        for (var i = 0; i < 2; i++)
          item(QuestionType.figOdd, 30 + i, 'figural'),
      ],
      subtes: [
        SubtestPlan(kategori: 'numerik', jumlah: 3, menit: menitNumerik),
        SubtestPlan(kategori: 'logika', jumlah: 2, menit: menitLogika),
        const SubtestPlan(kategori: 'figural', jumlah: 2, menit: 3),
      ],
    );

/// Latihan dua subtes: numerik 2 soal, figural 1 soal. Tanpa timer kecuali
/// [menit] diisi.
SessionPlan practicePlan({int? menit}) => SessionPlan(
      items: [
        item(QuestionType.numAri, 40, 'numerik'),
        item(QuestionType.numAri, 41, 'numerik'),
        item(QuestionType.figMtx, 50, 'figural'),
      ],
      subtes: [
        SubtestPlan(kategori: 'numerik', jumlah: 2, menit: menit),
        SubtestPlan(kategori: 'figural', jumlah: 1, menit: menit),
      ],
    );

Duration mins(num m) => Duration(milliseconds: (m * 60000).round());
const Duration min1 = Duration(minutes: 1);
