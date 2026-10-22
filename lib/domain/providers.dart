/// Provider domain. Repository dideklarasikan di sini dengan tipe antarmukanya
/// dan diisi lapisan data lewat `dataProviderOverrides` (lib/data/providers.dart)
/// di akar `ProviderScope`, sehingga domain tidak mengimpor `data/`.
library;

import 'dart:async';

import 'package:question_engine/question_engine.dart';
import 'package:riverpod/riverpod.dart';

import 'models/notebook.dart';
import 'models/profile.dart';
import 'models/session.dart';
import 'repositories/repositories.dart';
import 'services/clock.dart';
import 'services/daily_planner.dart';
import 'services/default_daily_planner.dart';
import 'services/diagnostic_planner.dart';
import 'services/mistake_book.dart';
import 'services/weakness_model.dart';

/// Membuat penanda waktu berkala; test menggantinya dengan penanda manual.
typedef TickerFactory = Timer Function(
  Duration interval,
  void Function() onTick,
);

Timer periodicTicker(Duration interval, void Function() onTick) =>
    Timer.periodic(interval, (_) => onTick());

/// Membuat ulang soal dari satu butir rencana.
typedef QuestionBuilder = Question Function(PlanItem item);

/// Soal lama hanya bisa dibuat ulang identik oleh generator versi yang sama
/// (docs/03-data-model.md).
class QuestionUnavailable implements Exception {
  QuestionUnavailable(this.item, this.reason);

  final PlanItem item;
  final String reason;

  @override
  String toString() =>
      'QuestionUnavailable(${item.type.code}, seed ${item.seed}: $reason)';
}

Question buildFromRegistry(PlanItem item) {
  if (!GeneratorRegistry.has(item.type)) {
    throw QuestionUnavailable(item, 'tipe belum terdaftar');
  }
  final generator = GeneratorRegistry.generator(item.type);
  if (generator.version != item.genVersi) {
    throw QuestionUnavailable(
        item, 'versi generator ${generator.version}, soal ${item.genVersi}');
  }
  return generator.generate(item.seed, item.difficulty);
}

final clockProvider = Provider<Clock>((ref) => SystemClock());

final tickerFactoryProvider = Provider<TickerFactory>((ref) => periodicTicker);

final questionBuilderProvider =
    Provider<QuestionBuilder>((ref) => buildFromRegistry);

Never _unbound(String name) => throw UnimplementedError(
    '$name belum diisi; pasang dataProviderOverrides di ProviderScope');

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => _unbound('profileRepositoryProvider'),
);

final sessionRepositoryProvider = Provider<SessionRepository>(
  (ref) => _unbound('sessionRepositoryProvider'),
);

final answerRepositoryProvider = Provider<AnswerRepository>(
  (ref) => _unbound('answerRepositoryProvider'),
);

final mistakeRepositoryProvider = Provider<MistakeRepository>(
  (ref) => _unbound('mistakeRepositoryProvider'),
);

final captureRepositoryProvider = Provider<CaptureRepository>(
  (ref) => _unbound('captureRepositoryProvider'),
);

final companyLogRepositoryProvider = Provider<CompanyLogRepository>(
  (ref) => _unbound('companyLogRepositoryProvider'),
);

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => _unbound('settingsRepositoryProvider'),
);

/// Semua profil, diperbarui setiap ada perubahan.
final profilesProvider = StreamProvider<List<TestProfile>>(
  (ref) => ref.watch(profileRepositoryProvider).watchAll(),
);

/// Profil aktif; null bila belum ada profil (onboarding). Selama memuat atau
/// galat, nilainya bukan data.
final activeProfileProvider = Provider<AsyncValue<TestProfile?>>((ref) {
  return ref.watch(profilesProvider).whenData((all) {
    for (final p in all) {
      if (p.aktif) return p;
    }
    return null;
  });
});

/// Tipe soal yang bisa dikerjakan sekarang: yang punya generator terdaftar.
/// Bank verbal (T07) dan modul v1.1 menambahkan tipenya lewat provider ini.
final availableTypesProvider = Provider<Set<QuestionType>>(
  (ref) => GeneratorRegistry.types.toSet(),
);

/// Rencana latihan harian dari riwayat 30 hari, kartu jatuh tempo, dan bobot
/// profil (T13).
final dailyPlannerProvider = Provider<DailyPlanner>(
  (ref) => DefaultDailyPlanner(
    answers: ref.watch(answerRepositoryProvider),
    mistakes: ref.watch(mistakeRepositoryProvider),
    available: ref.watch(availableTypesProvider),
  ),
);

/// Kelemahan per tipe dari riwayat 30 hari (T13).
final weaknessModelProvider = Provider<WeaknessModel>(
  (ref) => HistoryWeaknessModel(
    ref.watch(answerRepositoryProvider),
    ref.watch(availableTypesProvider),
  ),
);

/// Sesi diagnostik awal dari kategori aktif profil (T13).
final diagnosticPlannerProvider = Provider<DiagnosticPlanner>(
  (ref) => DiagnosticPlanner(
    answers: ref.watch(answerRepositoryProvider),
    available: ref.watch(availableTypesProvider),
  ),
);

/// Kartu buku kesalahan yang jatuh tempo hari ini (jam dari `Clock`, batas
/// hari kalender setempat, A80).
final dueCardsProvider = StreamProvider.autoDispose<List<MistakeCard>>(
  (ref) => ref
      .watch(mistakeRepositoryProvider)
      .watchDue(DueDay.cutoff(ref.watch(clockProvider).now())),
);

/// Jumlah soal Capture di bank pribadi.
final captureCountProvider = StreamProvider.autoDispose<int>(
  (ref) => ref
      .watch(captureRepositoryProvider)
      .watchAll()
      .map((items) => items.length),
);
